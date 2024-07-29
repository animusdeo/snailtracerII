// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;
import "abdk-libraries-solidity/ABDKMath64x64.sol";
import "./Vector3D.sol"; // Assuming Vector3D is in the same directory

contract SnailTracer {
    using Vector3D for Vector3D.Vector;

    int128 width = ABDKMath64x64.fromInt(1280);
    int128 height = ABDKMath64x64.fromInt(720);
    int128[] buffer;

    Ray camera;
    Vector3D.Vector deltaX;
    Vector3D.Vector deltaY;
    Sphere[] spheres;

    // SnailTracer is the ray tracer constructor to create the scene and pre-calculate
    // some constants that are the same throughout the path tracing procedure.
    constructor() {
        camera = Ray(
            Vector3D.Vector(
                ABDKMath64x64.fromInt(50), 
                ABDKMath64x64.fromInt(52), 
                ABDKMath64x64.divu(2956, 10)
            ),
            Vector3D.Vector(
                ABDKMath64x64.fromInt(0), 
                ABDKMath64x64.div(ABDKMath64x64.fromInt(-42612), ABDKMath64x64.fromInt(1000)),
                ABDKMath64x64.fromInt(-1000)
            ).norm(),
            0,
            false
        );

        deltaX = Vector3D.Vector(
            ABDKMath64x64.div(ABDKMath64x64.mul(width, ABDKMath64x64.divu(513500, 1000)), height), 
            ABDKMath64x64.fromInt(0), 
            ABDKMath64x64.fromInt(0)
        );

        deltaY = deltaX.cross(camera.direction).norm().mul(ABDKMath64x64.divu(513500, 1000));

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

    function render(int128 spp) public view returns (int128[] memory) {
        int128[] memory imageBuffer = new int128[](uint256(uint128(width)) * uint256(uint128(height)) * 3);
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

    // trace executes the path tracing for a single pixel of the result image and
    // returns the RGB color vector normalized to [0, 256) value range.
    function trace(int128 x, int128 y, int128 spp) internal view returns (Vector3D.Vector memory color) {
        delete color;
        for (int128 k = 0; k < spp; k++) {
          Vector3D.Vector memory pixel = camera.direction.add(
              deltaX.mul(
                  ABDKMath64x64.sub(
                      ABDKMath64x64.div(
                          ABDKMath64x64.fromInt(ABDKMath64x64.toInt(ABDKMath64x64.mul(ABDKMath64x64.fromInt(1000000), x)) + rand() % 500000),
                          width
                      ),
                      ABDKMath64x64.fromInt(500000)
                  )
              ).add(
                  deltaY.mul(
                      ABDKMath64x64.sub(
                          ABDKMath64x64.div(
                              ABDKMath64x64.fromInt(ABDKMath64x64.toInt(ABDKMath64x64.mul(ABDKMath64x64.fromInt(1000000), y)) + rand() % 500000),
                              height
                          ),
                          ABDKMath64x64.fromInt(500000)
                      )
                  )
              )
          );
        }
        return color.mul(ABDKMath64x64.fromInt(255)).div(ABDKMath64x64.fromInt(1000000));
    }

    uint32 seed;

    function rand() internal view returns (int128) {
        uint256 newSeed = 1103515245 * uint256(seed) + 12345;
        return ABDKMath64x64.fromUInt(newSeed % (2**32));
    }

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

    function intersect(Sphere memory s, Ray memory r) internal pure returns (int128) {
        Vector3D.Vector memory op = s.position.sub(r.origin);
        int128 b = ABDKMath64x64.div(op.dot(r.direction), ABDKMath64x64.fromInt(1000000));
        int128 bSquare = ABDKMath64x64.mul(b, b);
        int128 opDotOp = op.dot(op);
        int128 radiusSquare = ABDKMath64x64.mul(s.radius, s.radius);
        int128 det = ABDKMath64x64.sub(bSquare, ABDKMath64x64.sub(opDotOp, radiusSquare));

        if (det < ABDKMath64x64.fromInt(0)) {
            return ABDKMath64x64.fromInt(0);
        }

        det = ABDKMath64x64.sqrt(det);
        int128 bMinusDet = ABDKMath64x64.sub(b, det);
        int128 bPlusDet = ABDKMath64x64.add(b, det);
        int128 threshold = ABDKMath64x64.fromInt(1000);

        if (bMinusDet > threshold) {
            return bMinusDet;
        }
        if (bPlusDet > threshold) {
            return bPlusDet;
        }
        return ABDKMath64x64.fromInt(0);
    }



    function radiance(Ray memory ray) internal view returns (Vector3D.Vector memory) {
        if (ray.depth > 10) {
            return Vector3D.Vector(ABDKMath64x64.fromInt(0), ABDKMath64x64.fromInt(0), ABDKMath64x64.fromInt(0));
        }

        int128 dist;
        int128 id;
        (dist, , id) = traceray(ray);
        if (dist == 0) {
            return Vector3D.Vector(ABDKMath64x64.fromInt(0), ABDKMath64x64.fromInt(0), ABDKMath64x64.fromInt(0));
        }

        Sphere memory sphere = spheres[uint256(ABDKMath64x64.toUInt(id))];
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
        if (ray.depth > 5 && rand() % ABDKMath64x64.fromUInt(1000000) < ref) {
            color = color.mul(ABDKMath64x64.fromInt(1000000)).div(ref);
        } else {
            return emission;
        }

        return emission.add(color.mul(radiance(ray, sphere, dist)).div(ABDKMath64x64.fromInt(1000000)));
    }

    function radiance(Ray memory ray, Sphere memory obj, int128 dist) internal view returns (Vector3D.Vector memory) {
        Vector3D.Vector memory intersect = ray.origin.add(ray.direction.mul(dist).div(ABDKMath64x64.fromInt(1000000)));
        Vector3D.Vector memory normal = intersect.sub(obj.position).norm();

        if (normal.dot(ray.direction) >= ABDKMath64x64.fromInt(0)) {
            normal = normal.mul(ABDKMath64x64.fromInt(-1));
        }
        return diffuse(ray, intersect, normal);
    }

    function diffuse(Ray memory ray, Vector3D.Vector memory intersect, Vector3D.Vector memory normal) internal view returns (Vector3D.Vector memory) {
        // Generate a random angle and distance from center
        int128 r1 = ABDKMath64x64.div(ABDKMath64x64.mul(ABDKMath64x64.fromInt(6283184), rand()), ABDKMath64x64.fromUInt(1000000));
        int128 r2 = rand();
        int128 r2s = ABDKMath64x64.mul(ABDKMath64x64.sqrt(r2), ABDKMath64x64.fromInt(1000));

        // Create orthonormal coordinate frame
        Vector3D.Vector memory u;
        if (ABDKMath64x64.abs(normal.x) > ABDKMath64x64.fromInt(100000)) {
            u = Vector3D.Vector(ABDKMath64x64.fromInt(0), ABDKMath64x64.fromInt(1000000), ABDKMath64x64.fromInt(0));
        } else {
            u = Vector3D.Vector(ABDKMath64x64.fromInt(1000000), ABDKMath64x64.fromInt(0), ABDKMath64x64.fromInt(0));
        }
        u = Vector3D.norm(Vector3D.cross(u, normal));
        Vector3D.Vector memory v = Vector3D.norm(Vector3D.cross(normal, u));

        // Generate the random reflection ray and continue path tracing
        u = Vector3D.norm(Vector3D.add(
            Vector3D.add(
                Vector3D.mul(u, ABDKMath64x64.div(ABDKMath64x64.mul(ABDKMath64x64.cos(r1), r2s), ABDKMath64x64.fromInt(1000000))),
                Vector3D.mul(v, ABDKMath64x64.div(ABDKMath64x64.mul(ABDKMath64x64.sin(r1), r2s), ABDKMath64x64.fromInt(1000000)))
            ),
            Vector3D.mul(normal, ABDKMath64x64.mul(ABDKMath64x64.sqrt(ABDKMath64x64.sub(ABDKMath64x64.fromInt(1000000), r2)), ABDKMath64x64.fromInt(1000)))
        ));
        return radiance(Ray(intersect, u, ray.depth, ray.refract));
    }

    // traceray calculates the intersection of a ray with all the objects and
    // returns the closest one.
    function traceray(Ray memory ray) internal view returns (int128, Sphere memory, int128) {
        int128 dist = ABDKMath64x64.fromInt(0);
        Sphere memory p;
        int128 id;

        // Intersect the ray with all the spheres
        for (uint256 i = 0; i < spheres.length; i++) {
            int128 d = intersect(spheres[i], ray);
            if (ABDKMath64x64.cmp(d, ABDKMath64x64.fromInt(0)) > 0 && (ABDKMath64x64.cmp(dist, ABDKMath64x64.fromInt(0)) == 0 || ABDKMath64x64.cmp(d, dist) < 0)) {
                dist = d;
                p = Sphere;
                id = ABDKMath64x64.fromUInt(i);
            }
        }
        return (dist, p, id);
    }
}
