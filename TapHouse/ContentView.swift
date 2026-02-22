//
//  ContentView.swift
//  TapHouse
//
//  Created by Ajeet Yadav on 22/02/26.
//

import SwiftUI

/// Root view with NavigationSplitView layout.
struct ContentView: View {
    @Environment(AppViewModel.self) private var viewModel

    var body: some View {
        @Bindable var vm = viewModel

        NavigationSplitView {
            SidebarView()
        } detail: {
            Group {
                switch viewModel.selectedNav {
                case .dashboard:
                    DashboardView()
                case .installed:
                    InstalledView()
                case .upgrades:
                    UpgradesView()
                case .search:
                    SearchView()
                case .doctor:
                    DoctorView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationSplitViewStyle(.balanced)
        .onAppear {
            viewModel.loadAll()
        }
        .sheet(isPresented: $vm.showingTerminal) {
            TerminalOutputView()
                .environment(viewModel)
        }
        .alert("Error", isPresented: $vm.showError) {
            Button("OK") { }
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred.")
        }
    }
}
