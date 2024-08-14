// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;
import "./Math.sol";

library Vector3D {
    struct Vector {
        int128 x;
        int128 y;
        int128 z;
    }

    function add(Vector memory u, Vector memory v) internal pure returns (Vector memory) {
        return Vector(
            u.x + v.x,
            u.y + v.y,
            u.z + v.z
        );
    }

    function sub(Vector memory u, Vector memory v) internal pure returns (Vector memory) {
        return Vector(
            u.x - v.x,
            u.y - v.y,
            u.z - v.z
        );
    }

    function mul(Vector memory v, int128 m) internal pure returns (Vector memory) {
        return Vector(
            v.x * m / 1e6, // Adjust scaling factor as per the `SnailTracer` contract
            v.y * m / 1e6,
            v.z * m / 1e6
        );
    }

    function mul(Vector memory u, Vector memory v) internal pure returns (Vector memory) {
        return Vector(
            u.x * v.x / 1e6, // Adjust scaling factor as per the `SnailTracer` contract
            u.y * v.y / 1e6,
            u.z * v.z / 1e6
        );
    }

    function div(Vector memory v, int128 d) internal pure returns (Vector memory) {
        return Vector(
            v.x * 1e6 / d, // Adjust scaling factor as per the `SnailTracer` contract
            v.y * 1e6 / d,
            v.z * 1e6 / d
        );
    }

    function dot(Vector memory u, Vector memory v) internal pure returns (int128) {
        return (u.x * v.x + u.y * v.y + u.z * v.z) / 1e6;
    }

    function cross(Vector memory u, Vector memory v) internal pure returns (Vector memory) {
        return Vector(
            (u.y * v.z - u.z * v.y) / 1e6,
            (u.z * v.x - u.x * v.z) / 1e6,
            (u.x * v.y - u.y * v.x) / 1e6
        );
    }

    function norm(Vector memory v) internal pure returns (Vector memory) {
        int128 length = Math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z);
        return Vector(
            v.x * 1e6 / length,
            v.y * 1e6 / length,
            v.z * 1e6 / length
        );
    }

    function clamp(Vector memory v) internal pure returns (Vector memory) {
        return Vector(
            clamp(v.x),
            clamp(v.y),
            clamp(v.z)
        );
    }

    function clamp(int128 x) internal pure returns (int128) {
        if (x < 0) {
            return 0;
        }
        if (x > 1e6) { // Clamp to the range [0, 1e6] as per the `SnailTracer` contract
            return 1e6;
        }
        return x;
    }
}
