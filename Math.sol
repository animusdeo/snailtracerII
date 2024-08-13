// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import "abdk-libraries-solidity/ABDKMath64x64.sol";

library Math {
    using ABDKMath64x64 for int128;

    // Coefficients for Chebyshev polynomial approximation
    int128 constant COEF1 = 0x10000000000000000; // 1 in 64.64 fixed point format
    int128 constant COEF3 = -0x2AAAAAAAAB000000; // -1/6 in 64.64 fixed point format
    int128 constant COEF5 = 0x2AAAAAAAB000000;   // 1/120 in 64.64 fixed point format

    function sin(int128 x) public pure returns (int128) {
        // Normalize x to the range -π to π
        int128 pi = 0x3243F6A8885A308D313198A2E037073; // π in 64.64 fixed point format
        x = x % (2 * pi);
        if (x > pi) x -= 2 * pi;
        if (x < -pi) x += 2 * pi;

        // Compute the sine using the Chebyshev polynomial approximation
        int128 x2 = x.mul(x);
        int128 x3 = x2.mul(x);
        int128 x5 = x2.mul(x3);

        return COEF1.mul(x).add(COEF3.mul(x3)).add(COEF5.mul(x5));
    }

    function cos(int128 x) public pure returns (int128) {
        // Compute cosine as sine(x + π/2)
        int128 piOverTwo = 0x1921FB54442D18469898CC51701B839A; // π/2 in 64.64 fixed point format
        return sin(x.add(piOverTwo));
    }
}

