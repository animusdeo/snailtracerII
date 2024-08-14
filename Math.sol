// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

library Math {
    int128 constant SCALE = 1e6;
    int128 constant SCALE_SQUARED = 1e12;

    // Coefficients for Chebyshev polynomial approximation
    int128 constant COEF1 = SCALE;            // 1 in fixed-point format
    int128 constant COEF3 = -166667;          // -1/6 * SCALE
    int128 constant COEF5 = 833;              // 1/120 * SCALE

    function sin(int128 x) public pure returns (int128) {
        // Normalize x to the range -π to π
        int128 pi = 3141593; // π in fixed-point format (3.141593 * 1e6)
        x = x % (2 * pi);
        if (x > pi) x -= 2 * pi;
        if (x < -pi) x += 2 * pi;

        // Compute the sine using the Chebyshev polynomial approximation
        int128 x2 = (x * x) / SCALE;
        int128 x3 = (x2 * x) / SCALE;
        int128 x5 = (x2 * x3) / SCALE;

        return (COEF1 * x + COEF3 * x3 / SCALE + COEF5 * x5 / SCALE) / SCALE;
    }

    function cos(int128 x) public pure returns (int128) {
        // Compute cosine as sin(x + π/2)
        int128 piOverTwo = 1570796; // π/2 in fixed-point format (1.570796 * 1e6)
        return sin(x + piOverTwo);
    }    
    
    function sqrt(int128 x) internal pure returns (int128) {
        require(x >= 0, "Input must be non-negative");
        if (x == 0) return 0;
        
        int128 z = (x + SCALE) / 2;  // Initial guess
        int128 y = x;

        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }

        return y;
    }
}
