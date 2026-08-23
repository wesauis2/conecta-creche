#!/bin/bash

flutter build apk --release --split-debug-info=build/app/outputs/symbols --obfuscate --split-per-abi
