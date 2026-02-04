#!/bin/bash

# Only for VSCode usage

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Determine the platform and architecture
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    if [[ "$(uname -m)" == "arm64" ]]; then
        PREBUILD_SCRIPT="$VS_WORKSPACE/00_build_env/conan/_generated/host/macos/arm64/conanbuild.sh"
    else
        PREBUILD_SCRIPT="$VS_WORKSPACE/00_build_env/conan/_generated/host/macos/x86_64/conanbuild.sh"
    fi
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux
    if [[ "$(uname -m)" == "aarch64" ]]; then
        PREBUILD_SCRIPT="$VS_WORKSPACE/00_build_env/conan/_generated/host/ubuntu/arm64/conanbuild.sh"
    else
        PREBUILD_SCRIPT="$VS_WORKSPACE/00_build_env/conan/_generated/host/ubuntu/x86_64/conanbuild.sh"
    fi
else
    echo "[CMAKE WRAPPER] Warning: Unknown platform $OSTYPE"
    PREBUILD_SCRIPT=""
fi

# Check if this is a configure step
if [[ "$*" == *"-B"* ]] || [[ "$*" == *"--preset"* ]] || [[ "$*" == *"configure"* ]]; then
    echo "[CMAKE WRAPPER] Running $OSTYPE prebuild environment setup..."
    
    if [[ -n "$PREBUILD_SCRIPT" ]] && [[ -f "$PREBUILD_SCRIPT" ]]; then
        if source "$PREBUILD_SCRIPT"; then
            echo "[CMAKE WRAPPER] Environment setup completed successfully"
        else
            echo "[CMAKE WRAPPER] Warning: Prebuild script failed, continuing..."
        fi
    else
        echo "[CMAKE WRAPPER] Warning: Prebuild script not found: $PREBUILD_SCRIPT"
    fi
fi

# Find and execute the real cmake
CMAKE_REAL=$(which cmake)
if [[ -z "$CMAKE_REAL" ]]; then
    echo "[CMAKE WRAPPER] Error: cmake not found in PATH"
    exit 1
fi

echo "[CMAKE WRAPPER] Executing: $CMAKE_REAL $*"
exec "$CMAKE_REAL" "$@"