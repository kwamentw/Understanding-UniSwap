// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.20;

// Copied from https://github.com/Uniswap/v4-core

/// @title FixedPoint128
/// @notice A library for handling binary fixed point numbers, see https://en.wikipedia.org/wiki/Q_(number_format)
library FixedPoint128 {
    // Q128 = 2**128 = 1 << 128
    uint256 internal constant Q128 = 0x100000000000000000000000000000000;
}
