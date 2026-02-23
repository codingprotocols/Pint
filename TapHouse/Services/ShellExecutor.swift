//
//  ShellExecutor.swift
//  TapHouse
//
//  Created by Ajeet Yadav on 22/02/26.
//

import Foundation

/// A mutable box that is marked @unchecked Sendable for use in pipe handlers.
/// The readabilityHandler callbacks are serialised per-handle, so concurrent
/// mutation does not occur in practice.
final class UnsafeMutableSendableBox<T>: @unchecked Sendable {
    nonisolated(unsafe) var value: T
    nonisolated init(_ value: T) { self.value = value }
}

/// Low-level shell command executor with support for streaming output.
actor ShellExecutor {

    /// Known locations where Homebrew may be installed.
    private static let knownPaths = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]

    /// Resolve the path to the brew executable, or throw if not found.
    static func resolveBrewPath() throws -> String {
        for path in knownPaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        throw ShellError.brewNotFound
    }

    /// Build a PATH string that mirrors the user's shell: Homebrew dirs first,
    /// then any remaining entries from the current environment PATH.
    private static func buildBrewPATH(from currentPATH: String?) -> String {
        let brewPrefixes = ["/opt/homebrew/bin", "/opt/homebrew/sbin", "/usr/local/bin"]
        let systemFallbacks = ["/usr/bin", "/bin", "/usr/sbin", "/sbin"]

        // Start with Homebrew paths at the front.
        var components = brewPrefixes

        // Append existing entries that aren't already included.
        if let current = currentPATH {
            for entry in current.split(separator: ":").map(String.init) {
                if !components.contains(entry) {
                    components.append(entry)
                }
            }
        } else {
            // No PATH at all — add system fallbacks.
            for entry in systemFallbacks where !components.contains(entry) {
                components.append(entry)
            }
        }

        return components.joined(separator: ":")
    }

    /// Quick, non-throwing check for whether brew is available.
    static func isBrewInstalled() -> Bool {
        return knownPaths.contains { FileManager.default.fileExists(atPath: $0) }
    }

    /// Run a brew command and return the full output when complete.
    static func run(_ arguments: [String]) async throws -> String {
        let brewPath = try resolveBrewPath()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: brewPath)
        process.arguments = arguments

        var env = ProcessInfo.processInfo.environment
        env["HOMEBREW_NO_AUTO_UPDATE"] = "1"
        env["HOMEBREW_NO_INSTALL_CLEANUP"] = "1"
        env["PATH"] = Self.buildBrewPATH(from: env["PATH"])
        process.environment = env

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        // Collect data concurrently to avoid pipe buffer deadlock.
        // If we call waitUntilExit() before reading, the pipe buffer (~64KB)
        // can fill up, blocking the child process and causing a deadlock.
        let outputData = UnsafeMutableSendableBox(Data())
        let errorData = UnsafeMutableSendableBox(Data())

        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            if !chunk.isEmpty {
                outputData.value.append(chunk)
            }
        }

        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            if !chunk.isEmpty {
                errorData.value.append(chunk)
            }
        }

        try process.run()

        // Wait for process to finish asynchronously (non-blocking).
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            process.terminationHandler = { _ in
                outputPipe.fileHandleForReading.readabilityHandler = nil
                errorPipe.fileHandleForReading.readabilityHandler = nil
                continuation.resume()
            }
        }

        // Read any remaining data after process exit.
        outputData.value.append(outputPipe.fileHandleForReading.readDataToEndOfFile())
        errorData.value.append(errorPipe.fileHandleForReading.readDataToEndOfFile())

        let output = String(data: outputData.value, encoding: .utf8) ?? ""
        let errorOutput = String(data: errorData.value, encoding: .utf8) ?? ""

        if process.terminationStatus != 0 && !errorOutput.isEmpty {
            if arguments.first == "doctor" {
                return output + errorOutput
            }
            throw ShellError.commandFailed(
                command: "brew \(arguments.joined(separator: " "))",
                exitCode: process.terminationStatus,
                stderr: errorOutput
            )
        }

        return output
    }

    /// Run a brew command with real-time streaming output via a callback.
    /// Supports cancellation — if the calling Task is cancelled, the process is terminated.
    static func runStreaming(
        _ arguments: [String],
        onOutput: @escaping @Sendable (String) -> Void
    ) async throws {
        let brewPath = try resolveBrewPath()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: brewPath)
        process.arguments = arguments

        var env = ProcessInfo.processInfo.environment
        env["HOMEBREW_NO_AUTO_UPDATE"] = "1"
        env["PATH"] = Self.buildBrewPATH(from: env["PATH"])
        process.environment = env

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty, let str = String(data: data, encoding: .utf8) {
                onOutput(str)
            }
        }

        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty, let str = String(data: data, encoding: .utf8) {
                onOutput(str)
            }
        }

        try process.run()

        // Bridge Swift Task cancellation to Process termination.
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                process.terminationHandler = { proc in
                    outputPipe.fileHandleForReading.readabilityHandler = nil
                    errorPipe.fileHandleForReading.readabilityHandler = nil
                    // SIGTERM (exit 15) or interruption signals mean cancellation.
                    if proc.terminationStatus == 15 || proc.terminationReason == .uncaughtSignal {
                        continuation.resume(throwing: ShellError.cancelled)
                    } else {
                        continuation.resume()
                    }
                }
            }
        } onCancel: {
            if process.isRunning {
                process.terminate()
            }
        }
    }
}

/// Errors from shell execution.
enum ShellError: LocalizedError, Equatable {
    case commandFailed(command: String, exitCode: Int32, stderr: String)
    case brewNotFound
    case cancelled

    var errorDescription: String? {
        switch self {
        case .commandFailed(let command, let exitCode, let stderr):
            return "Command '\(command)' failed (exit \(exitCode)): \(stderr)"
        case .brewNotFound:
            return "Homebrew not found. Please install Homebrew first."
        case .cancelled:
            return "Operation was cancelled."
        }
    }
}

