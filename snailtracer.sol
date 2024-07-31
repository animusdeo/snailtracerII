// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

import "abdk-libraries-solidity/ABDKMath64x64.sol";
import "./Vector3D.sol"; // Assuming Vector3D is in the same directory
import "./Math.sol";

contract SnailTracer {
    using Vector3D for Vector3D.Vector;
    using ABDKMath64x64 for int128;

    int128 private immutable width;
    int128 private immutable height;
    int128[] private buffer;
    Ray private camera;
    Vector3D.Vector private deltaX;
    Vector3D.Vector private deltaY;
    Sphere[] private spheres;

    struct Ray {
        Vector3D.Vector origin;
        Vector3D.Vector direction;
        int128 depth;
        bool refract;
    }

    enum Material { Diffuse }

    struct Sphere {
        int128 radius;
        Vector3D.Vector position;
        Vector3D.Vector emission;
        Vector3D.Vector color;
        Material reflection;
    }

    /**
     * @dev Initializes the contract with specified screen dimensions and camera parameters.
     */
    constructor() {
        width = ABDKMath64x64.fromInt(1280);
        height = ABDKMath64x64.fromInt(720);

        // Initialize camera parameters
        camera = Ray(
            Vector3D.Vector(
                ABDKMath64x64.fromInt(50), 
                ABDKMath64x64.fromInt(52), 
                ABDKMath64x64.divu(2956, 10)
            ),
            Vector3D.Vector(
                ABDKMath64x64.fromInt(0), 
                ABDKMath64x64.fromInt(-42612).div(ABDKMath64x64.fromInt(1000)),
                ABDKMath64x64.fromInt(-1000)
            ).norm(),
            0,
            false
        );

        deltaX = Vector3D.Vector(
            width.mul(ABDKMath64x64.divu(513500, 1000)).div(height), 
            ABDKMath64x64.fromInt(0), 
            ABDKMath64x64.fromInt(0)
        );

        deltaY = deltaX.cross(camera.direction).norm().mul(ABDKMath64x64.divu(513500, 1000));

        // Initialize spheres
        spheres.push(Sphere(
            ABDKMath64x64.fromInt(100000), 
            Vector3D.Vector(
                ABDKMath64x64.fromInt(100001),                 
                ABDKMath64x64.divu(408, 10),
                ABDKMath64x64.divu(816, 10)
            ),
            Vector3D.Vector(
                ABDKMath64x64.fromInt(0), 
                ABDKMath64x64.fromInt(0), 
                ABDKMath64x64.fromInt(0)
            ),
            Vector3D.Vector(
                ABDKMath64x64.divu(750, 1000), 
                ABDKMath64x64.divu(250, 1000), 
                ABDKMath64x64.divu(250, 1000)
            ),
            Material.Diffuse
        ));
    }

    /**
     * @notice Renders the scene with the specified samples per pixel (spp).
     * @param spp Samples per pixel.
     * @return An array representing the rendered image.
     */
    function render(int128 spp) public view returns (int128[] memory) {
        int128[] memory imageBuffer = new int128[](uint256(width.toUInt()) * uint256(height.toUInt()) * 3);
        uint256 index = 0;
        for (int128 y = height - 1; y >= 0; y--) {
            for (int128 x = 0; x < width; x++) {
                Vector3D.Vector memory color = trace(x, y, spp);
                imageBuffer[index] = color.x;
                imageBuffer[index + 1] = color.y;
                imageBuffer[index + 2] = color.z;
                index += 3;
            }
        }
        return imageBuffer;
    }

    /**
     * @notice Traces a ray for the given pixel coordinates and samples per pixel.
     * @param x X-coordinate of the pixel.
     * @param y Y-coordinate of the pixel.
     * @param spp Samples per pixel.
     * @return color The color vector of the traced ray.
     */
    function trace(int128 x, int128 y, int128 spp) internal view returns (Vector3D.Vector memory color) {
        uint32 localSeed = uint32(y.toUInt() * width.toUInt() + x.toUInt()); // Deterministic seed for image

        delete color;
        for (int128 k = 0; k < spp; k++) {
            localSeed = nextRand(localSeed);
            Vector3D.Vector memory pixel = calculatePixel(x, y, localSeed);
            Ray memory ray = Ray(
                camera.origin.add(pixel.mul(ABDKMath64x64.fromInt(140))),
                pixel.norm(),
                0,
                false
            );

            color = color.add(radiance(ray, localSeed).div(spp));
        }
        return color.clamp().mul(ABDKMath64x64.fromInt(255)).div(ABDKMath64x64.fromInt(1000000));
    }

    /**
     * @notice Calculates the pixel vector for the given coordinates and seed.
     * @param x X-coordinate of the pixel.
     * @param y Y-coordinate of the pixel.
     * @param seed Seed for randomness.
     * @return The pixel vector.
     */
    function calculatePixel(int128 x, int128 y, uint32 seed) internal view returns (Vector3D.Vector memory) {
        int128 randX = rand(seed);
        seed = nextRand(seed);
        int128 randY = rand(seed);

        Vector3D.Vector memory pixel = camera.direction.add(
            deltaX.mul(
                transform(x, randX, width)
            ).add(
                deltaY.mul(
                    transform(y, randY, height)
                )
            )
        );

        return pixel;
    }

    /**
    * @notice Applies transformations to the pixel coordinates to account for anti-aliasing and mapping to the scene's coordinate system.
    * @param coordinate The original coordinate value (either x or y).
    * @param randomOffset The random value associated with the coordinate for anti-aliasing.
    * @param dimension The dimension value (either width or height).
    * @return The transformed coordinate value.
    */
    function transform(int128 coordinate, int128 randomOffset, int128 dimension) internal pure returns (int128) {
        return coordinate.mul(ABDKMath64x64.fromInt(1000000)).add(randomOffset).div(dimension).sub(ABDKMath64x64.fromInt(500000));
    }

    /**
     * @notice Generates a random 64.64 fixed point number from a seed.
     * @param seed The seed for randomness.
     * @return A random 64.64 fixed point number.
     */
    function rand(uint32 seed) internal pure returns (int128) {
        uint256 newSeed = 1103515245 * uint256(seed) + 12345;
        return ABDKMath64x64.fromUInt(newSeed % (2**32));
    }

    /**
     * @notice Generates the next random seed.
     * @param seed The current seed.
     * @return The next seed.
     */
    function nextRand(uint32 seed) internal pure returns (uint32) {
        return 1103515245 * seed + 12345;
    }

    /**
     * @notice Computes the intersection distance of a ray with a sphere.
     * @param s The sphere to check for intersection.
     * @param r The ray to check for intersection.
     * @return The intersection distance.
     */
    function intersect(Sphere memory s, Ray memory r) internal pure returns (int128) {
        Vector3D.Vector memory op = s.position.sub(r.origin);
        int128 b = op.dot(r.direction).div(ABDKMath64x64.fromInt(1000000));
        int128 det = b.mul(b).sub(op.dot(op).sub(s.radius.mul(s.radius)));

        if (det < 0) {
            return 0;
        }

        det = det.sqrt();
        int128 bMinusDet = b.sub(det);
        int128 bPlusDet = b.add(det);
        int128 threshold = ABDKMath64x64.fromInt(1000);

        if (bMinusDet > threshold) {
            return bMinusDet;
        }
        if (bPlusDet > threshold) {
            return bPlusDet;
        }
        return 0;
    }

    /**
     * @notice Computes the radiance along a ray.
     * @param ray The ray to trace.
     * @param seed The seed for randomness.
     * @return The color vector representing the radiance.
     */
    function radiance(Ray memory ray, uint32 seed) internal view returns (Vector3D.Vector memory) {
        if (ray.depth > 10) {
            return Vector3D.Vector(0, 0, 0);
        }

        (int128 dist, , int128 id) = traceray(ray);
        if (dist == 0) {
            return Vector3D.Vector(0, 0, 0);
        }

        Sphere memory sphere = spheres[uint256(id.toUInt())];
        Vector3D.Vector memory color = sphere.color;
        Vector3D.Vector memory emission = sphere.emission;

        int128 ref = color.z;
        if (color.y > ref) {
            ref = color.y;
        }
        if (color.x > ref) {
            ref = color.x;
        }
        ray.depth++;
        if (ray.depth > 5 && rand(seed) % ABDKMath64x64.fromUInt(1000000) < ref) {
            color = color.mul(ABDKMath64x64.fromInt(1000000)).div(ref);
        } else {
            return emission;
        }

        return emission.add(color.mul(radiance(ray, sphere, dist, seed)).div(ABDKMath64x64.fromInt(1000000)));
    }

    /**
     * @notice Computes the radiance along a ray after intersecting with a sphere.
     * @param ray The ray to trace.
     * @param obj The sphere intersected.
     * @param dist The intersection distance.
     * @param seed The seed for randomness.
     * @return The color vector representing the radiance.
     */
    function radiance(Ray memory ray, Sphere memory obj, int128 dist, uint32 seed) internal view returns (Vector3D.Vector memory) {
        Vector3D.Vector memory intersection = ray.origin.add(ray.direction.mul(dist).div(ABDKMath64x64.fromInt(1000000)));
        Vector3D.Vector memory normal = intersection.sub(obj.position).norm();

        if (normal.dot(ray.direction) >= 0) {
            normal = normal.mul(ABDKMath64x64.fromInt(-1));
        }
        return diffuse(ray, intersection, normal, seed);
    }

    /**
     * @notice Computes the diffuse radiance at an intersection point.
     * @param ray The incoming ray.
     * @param intersection The intersection point.
     * @param normal The normal at the intersection point.
     * @param seed The seed for randomness.
     * @return The color vector representing the diffuse radiance.
     */
    function diffuse(Ray memory ray, Vector3D.Vector memory intersection, Vector3D.Vector memory normal, uint32 seed) internal view returns (Vector3D.Vector memory) {
        seed = nextRand(seed);
        int128 r1 = ABDKMath64x64.fromInt(6283184).mul(rand(seed)).div(ABDKMath64x64.fromUInt(1000000));
        seed = nextRand(seed);
        int128 r2 = rand(seed);
        int128 r2s = r2.sqrt().mul(ABDKMath64x64.fromInt(1000));

        Vector3D.Vector memory u;
        if (normal.x.abs() > ABDKMath64x64.fromInt(100000)) {
            u = Vector3D.Vector(0, 1000000, 0);
        } else {
            u = Vector3D.Vector(1000000, 0, 0);
        }
        u = u.cross(normal).norm();
        Vector3D.Vector memory v = normal.cross(u).norm();

        u = u.mul(Math.cos(r1).mul(r2s).div(ABDKMath64x64.fromInt(1000000))).add(
            v.mul(Math.sin(r1).mul(r2s).div(ABDKMath64x64.fromInt(1000000)))
        ).add(
            normal.mul(ABDKMath64x64.fromInt(1000).mul((ABDKMath64x64.fromInt(1000000).sub(r2)).sqrt()))
        );
        return radiance(Ray(intersection, u.norm(), ray.depth, ray.refract), seed);
    }

    /**
     * @notice Traces a ray through the scene to find the nearest intersection.
     * @param ray The ray to trace.
     * @return The intersection distance, intersected sphere, and sphere index.
     */
    function traceray(Ray memory ray) internal view returns (int128, Sphere memory, int128) {
        int128 dist = 0;
        Sphere memory p;
        int128 id;

        for (uint256 i = 0; i < spheres.length; i++) {
            int128 d = intersect(spheres[i], ray);
            if (d > 0 && (dist == 0 || d < dist)) {
                dist = d;
                p = spheres[i];
                id = ABDKMath64x64.fromUInt(i);
            }
        }
        return (dist, p, id);
    }
}
