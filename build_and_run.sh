#!/bin/bash

# Compile for macOS
swiftc -o IconGenerator \
    -target x86_64-apple-macosx10.15 \
    -sdk $(xcrun --show-sdk-path --sdk macosx) \
    IconGenerator.swift

# Run the generator
./IconGenerator 