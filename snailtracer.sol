// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import "./Vector3D.sol";
import "./Math.sol";

contract SnailTracer {
    using Vector3D for Vector3D.Vector;

    int128 immutable width = 1280 * 1e6;
    int128 immutable height = 720 * 1e6;
    int128[] buffer;

    Ray camera;
    Vector3D.Vector deltaX;
    Vector3D.Vector deltaY;
    Triangle[] triangles;

    constructor() {
        // Initialize the rendering parameters
        camera = Ray(
            Vector3D.Vector(50000000, 52000000, 295600000), 
            Vector3D.Vector(0, -42612, -1000000).norm(), 
            0, 
            false
        );
        deltaX = Vector3D.Vector(width * 513500 / height, 0, 0);
        deltaY = deltaX.cross(camera.direction).norm().mul(513500).div(1e6);

        // Initialize a single triangle
        Triangle memory triangle = Triangle(
            Vector3D.Vector(56500000, 25740000, 78000000), // Vertex A
            Vector3D.Vector(73000000, 25740000, 94500000), // Vertex B
            Vector3D.Vector(73000000, 49500000, 78000000), // Vertex C
            Vector3D.Vector(0, 0, 0),                      // Normal (will be calculated)
            Vector3D.Vector(0, 0, 0),                      // Emission color
            Vector3D.Vector(999000, 999000, 999000),       // Surface color
            Material.Specular                              // Reflection type
        );

        // Calculate the triangle surface normal
        triangle.normal = triangle.b.sub(triangle.a).cross(triangle.c.sub(triangle.a)).norm();
        triangles.push(triangle);
    }

    event Pixel(int128, int128, int128);

    function render(int128 spp) public {
        for (int128 y = height - 1; y >= 0; y--) {
            for (int128 x = 0; x < width; x++) {
                Vector3D.Vector memory color = trace(x, y, spp);
                emit Pixel(color.x, color.y, color.z);
            }
        }
    }

    function trace(int128 x, int128 y, int128 spp) internal view returns (Vector3D.Vector memory color) {
        uint32 localSeed = uint32(uint256(int256(y)) * uint256(int256(width)) + uint256(int256(x)));

        delete color;
        for (int128 k = 0; k < spp; k++) {
            localSeed = nextRand(localSeed);
            Vector3D.Vector memory pixel = calculatePixel(x, y, localSeed);
            Ray memory ray = Ray(
                camera.origin.add(pixel.mul(140)),
                pixel.norm(),
                0,
                false
            );

            color = color.add(radiance(ray, localSeed).div(spp));
        }
        return color.clamp().mul(255).div(1e6);
    }

    function calculatePixel(int128 x, int128 y, uint32 seed) internal view returns (Vector3D.Vector memory) {
        int128 randX = rand(seed);
        seed = nextRand(seed);
        int128 randY = rand(seed);

        Vector3D.Vector memory pixel = camera.direction.add(
            deltaX.mul((x * 1e6 + randX) / width - 500000).add(
                deltaY.mul((y * 1e6 + randY) / height - 500000)
            )
        );

        return pixel;
    }

    function rand(uint32 seed) internal pure returns (int128) {
        uint256 newSeed = 1103515245 * uint256(seed) + 12345;
        return int128(int256(newSeed % (2**32)));
    }

    function nextRand(uint32 seed) internal pure returns (uint32) {
        return 1103515245 * seed + 12345;
    }

    struct Ray {
        Vector3D.Vector origin;
        Vector3D.Vector direction;
        int128 depth;
        bool refract;
    }

    enum Material { Diffuse, Specular }

    struct Triangle {
        Vector3D.Vector a;
        Vector3D.Vector b;
        Vector3D.Vector c;
        Vector3D.Vector normal;
        Vector3D.Vector emission;
        Vector3D.Vector color;
        Material reflection;
    }

    function radiance(Ray memory ray, uint32 seed) internal view returns (Vector3D.Vector memory) {
        if (ray.depth > 10) {
            return Vector3D.Vector(0, 0, 0);
        }

        (int128 dist, Triangle memory triangle, ) = traceray(ray);
        if (dist == 0) {
            return Vector3D.Vector(0, 0, 0);
        }

        Vector3D.Vector memory color = triangle.color;
        Vector3D.Vector memory emission = triangle.emission;

        int128 ref = color.z;
        if (color.y > ref) {
            ref = color.y;
        }
        if (color.x > ref) {
            ref = color.x;
        }
        ray.depth++;
        if (ray.depth > 5 && rand(seed) % 1e6 < ref) {
            color = color.mul(1e6).div(ref);
        } else {
            return emission;
        }

        return emission.add(color.mul(radiance(ray, triangle, dist, seed)).div(1e6));
    }

    function radiance(Ray memory ray, Triangle memory obj, int128 dist, uint32 seed) internal view returns (Vector3D.Vector memory) {
        Vector3D.Vector memory intersection = ray.origin.add(ray.direction.mul(dist).div(1e6));
        Vector3D.Vector memory normal = intersection.sub(obj.a).norm();

        if (normal.dot(ray.direction) >= 0) {
            normal = normal.mul(-1);
        }
        return diffuse(ray, intersection, normal, seed);
    }

    function diffuse(Ray memory ray, Vector3D.Vector memory intersection, Vector3D.Vector memory normal, uint32 seed) internal view returns (Vector3D.Vector memory) {
        seed = nextRand(seed);
        int128 r1 = Math.sin(rand(seed) * 6283184 / 1e6);
        seed = nextRand(seed);
        int128 r2 = rand(seed);
        int128 r2s = Math.sqrt(r2) * 1000;

        Vector3D.Vector memory u;
        if (normal.x > 100000 || normal.x < -100000) {
            u = Vector3D.Vector(0, 1e6, 0);
        } else {
            u = Vector3D.Vector(1e6, 0, 0);
        }
        u = u.cross(normal).norm();
        Vector3D.Vector memory v = normal.cross(u).norm();

        u = u.mul(Math.cos(r1) * r2s / 1e6).add(
            v.mul(Math.sin(r1) * r2s / 1e6)
        ).add(
            normal.mul(1000).mul(Math.sqrt(1e6 - r2))
        );
        return radiance(Ray(intersection, u.norm(), ray.depth, ray.refract), seed);
    }

    function intersect(Triangle memory t, Ray memory r) internal pure returns (int128) {
        Vector3D.Vector memory e1 = t.b.sub(t.a);
        Vector3D.Vector memory e2 = t.c.sub(t.a);

        Vector3D.Vector memory p = r.direction.cross(e2);

        // Bail out if ray is parallel to the triangle
        int128 det = e1.dot(p) / 1e6;
        if (det > -1000 && det < 1000) {
            return 0;
        }
        // Calculate and test the 'u' parameter
        Vector3D.Vector memory d = r.origin.sub(t.a);

        int128 u = d.dot(p) / det;
        if (u < 0 || u > 1e6) {
            return 0;
        }
        // Calculate and test the 'v' parameter
        Vector3D.Vector memory q = d.cross(e1);

        int128 v = r.direction.dot(q) / det;
        if (v < 0 || u + v > 1e6) {
            return 0;
        }
        // Calculate and return the distance
        int128 dist = e2.dot(q) / det;
        if (dist < 1000) {
            return 0;
        }
        return dist;
    }

    function traceray(Ray memory ray) internal view returns (int128, Triangle memory, int128) {
        int128 dist = 0;
        Triangle memory p;
        int128 id;

        for (uint256 i = 0; i < triangles.length; i++) {
            int128 d = intersect(triangles[i], ray);
            if (d > 0 && (dist == 0 || d < dist)) {
                dist = d;
                p = triangles[i];
                id = int128(int256(i));
            }
        }
        return (dist, p, id);
    }
}
