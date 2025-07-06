#!/bin/bash

# For macOS BSD sed: use '' after -i, for Linux remove it

find . -type f -name "*.sol" -exec sed -i '' \
    -e '/pragma solidity 0\.8\.17;/ s/^/\/\//' \
    -e '/\/\/pragma solidity 0\.8\.17;/a\
pragma solidity ^0.8.17;
' {} +