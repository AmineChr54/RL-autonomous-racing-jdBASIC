#!/usr/bin/env bash
# Builds tools/capped.exe (the memory-capped runner) with the C# compiler that ships with Windows.
set -e
cd "$(dirname "$0")"
/c/Windows/Microsoft.NET/Framework64/v4.0.30319/csc.exe -nologo -optimize -out:capped.exe capped.cs
echo "built tools/capped.exe"
