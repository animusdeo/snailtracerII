// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;
import "abdk-libraries-solidity/ABDKMath64x64.sol";

library Vector3D {
    struct Vector {
        int128 x;
        int128 y;
        int128 z;
    }

    function add(Vector memory u, Vector memory v) internal pure returns (Vector memory) {
        return Vector(
            ABDKMath64x64.add(u.x, v.x), 
            ABDKMath64x64.add(u.y, v.y), 
            ABDKMath64x64.add(u.z, v.z)
        );
    }

    function sub(Vector memory u, Vector memory v) internal pure returns (Vector memory) {
        return Vector(
            ABDKMath64x64.sub(u.x, v.x), 
            ABDKMath64x64.sub(u.y, v.y), 
            ABDKMath64x64.sub(u.z, v.z)
        );
    }

    function mul(Vector memory v, int128 m) internal pure returns (Vector memory) {
        return Vector(
            ABDKMath64x64.mul(v.x, m), 
            ABDKMath64x64.mul(v.y, m), 
            ABDKMath64x64.mul(v.z, m)
        );
    }

    function mul(Vector memory u, Vector memory v) internal pure returns (Vector memory) {
        return Vector(
            ABDKMath64x64.mul(u.x, v.x), 
            ABDKMath64x64.mul(u.y, v.y), 
            ABDKMath64x64.mul(u.z, v.z)
        );
    }

    function div(Vector memory v, int128 d) internal pure returns (Vector memory) {
        return Vector(
            ABDKMath64x64.div(v.x, d), 
            ABDKMath64x64.div(v.y, d), 
            ABDKMath64x64.div(v.z, d)
        );
    }

    function dot(Vector memory u, Vector memory v) internal pure returns (int128) {
        return ABDKMath64x64.add(
            ABDKMath64x64.add(
                ABDKMath64x64.mul(u.x, v.x),
                ABDKMath64x64.mul(u.y, v.y)
            ),
            ABDKMath64x64.mul(u.z, v.z)
        );
    }

    function cross(Vector memory u, Vector memory v) internal pure returns (Vector memory) {
        return Vector(
            ABDKMath64x64.sub(ABDKMath64x64.mul(u.y, v.z), ABDKMath64x64.mul(u.z, v.y)),
            ABDKMath64x64.sub(ABDKMath64x64.mul(u.z, v.x), ABDKMath64x64.mul(u.x, v.z)),
            ABDKMath64x64.sub(ABDKMath64x64.mul(u.x, v.y), ABDKMath64x64.mul(u.y, v.x))
        );
    }

    function norm(Vector memory v) internal pure returns (Vector memory) {
        int128 length = ABDKMath64x64.sqrt(
            ABDKMath64x64.add(
                ABDKMath64x64.add(
                    ABDKMath64x64.mul(v.x, v.x),
                    ABDKMath64x64.mul(v.y, v.y)
                ),
                ABDKMath64x64.mul(v.z, v.z)
            )
        );
        return Vector(
            ABDKMath64x64.div(v.x, length),
            ABDKMath64x64.div(v.y, length),
            ABDKMath64x64.div(v.z, length)
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
        int128 zero = ABDKMath64x64.fromInt(0);
        int128 one = ABDKMath64x64.fromInt(1);
        if (x < zero) {
            return zero;
        }
        if (x > one) {
            return one;
        }
        return x;
    }
}
