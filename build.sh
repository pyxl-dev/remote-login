#!/bin/sh
set -e
cd "$(dirname "$0")"
mkdir -p bin
swiftc -O helper/main.swift -o bin/rl-helper
