#!/bin/bash

# Configuration
PBXPROJ="Pint.xcodeproj/project.pbxproj"

if [[ ! -f "$PBXPROJ" ]]; then
    echo "Error: $PBXPROJ not found. Please run this script from the project root."
    exit 1
fi

COMMAND=$1

# Function to get current values
get_current_build() {
    grep "CURRENT_PROJECT_VERSION =" "$PBXPROJ" | sed -E 's/.*= ([0-9]+);/\1/' | head -n 1
}

get_current_version() {
    grep "MARKETING_VERSION =" "$PBXPROJ" | sed -E 's/.*= ([0-9.]+);/\1/' | head -n 1
}

# Function to update build number
bump_build() {
    CURRENT_BUILD=$(get_current_build)
    NEXT_BUILD=$((CURRENT_BUILD + 1))
    echo "Bumping build number: $CURRENT_BUILD -> $NEXT_BUILD"
    # Use different sed syntax for macOS compatibility
    sed -i '' "s/CURRENT_PROJECT_VERSION = $CURRENT_BUILD;/CURRENT_PROJECT_VERSION = $NEXT_BUILD;/g" "$PBXPROJ"
}

# Function to update marketing version
bump_version() {
    TYPE=$1
    CURRENT_VERSION=$(get_current_version)
    
    # Split version into components
    IFS='.' read -r major minor patch <<< "$CURRENT_VERSION"
    major=${major:-0}
    minor=${minor:-0}
    patch=${patch:-0}

    case $TYPE in
        major)
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        minor)
            minor=$((minor + 1))
            patch=0
            ;;
        patch)
            patch=$((patch + 1))
            ;;
    esac

    NEXT_VERSION="$major.$minor.$patch"
    echo "Bumping $TYPE version: $CURRENT_VERSION -> $NEXT_VERSION"
    sed -i '' "s/MARKETING_VERSION = $CURRENT_VERSION;/MARKETING_VERSION = $NEXT_VERSION;/g" "$PBXPROJ"
}

case $COMMAND in
    build)
        bump_build
        ;;
    major|minor|patch)
        bump_version "$COMMAND"
        ;;
    *)
        echo "Usage: ./bump-version.sh {build|patch|minor|major}"
        exit 1
        ;;
esac

echo "Done!"
