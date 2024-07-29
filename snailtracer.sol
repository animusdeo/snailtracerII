// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;
import "abdk-libraries-solidity/ABDKMath64x64.sol";
import "./Vector3D.sol"; // Assuming Vector3D is in the same directory

contract SnailTracer {
    using Vector3D for Vector3D.Vector;

    int128 constant width = ABDKMath64x64.fromInt(1280);
    int128 constant height = ABDKMath64x64.fromInt(720);
    int256[] buffer;

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

    // TracePixel traces a single pixel of the configured image and returns the RGB
    // values to the caller. This method is meant to be used specifically for high
    // SPP renderings which would have a huge overhead otherwise.
    function TracePixel(int256 x, int256 y, int256 spp) public view returns (int256 r, int256 g, int256 b) {
        Vector memory color = trace(x, y, spp);
        return (color.x, color.y, color.z);
    }

    function TraceScanline(int256 y, int256 spp) public view returns (int256[] memory) {
        int256[] memory lineBuffer = new int256[](uint256(width) * 3);
        for (int256 x = 0; x < width; x++) {
            Vector memory color = trace(x, y, spp);
            uint256 index = uint256(x) * 3;
            lineBuffer[index] = color.x;
            lineBuffer[index + 1] = color.y;
            lineBuffer[index + 2] = color.z;
        }
        return lineBuffer;
    }

    function TraceImage(int256 spp) public view returns (int256[] memory) {
        int256[] memory imageBuffer = new int256[](uint256(width) * uint256(height) * 3);
        uint256 index = 0;
        for (int256 y = height - 1; y >= 0; y--) {
            for (int256 x = 0; x < width; x++) {
                Vector memory color = trace(x, y, spp);
                imageBuffer[index] = color.x;
                imageBuffer[index + 1] = color.y;
                imageBuffer[index + 2] = color.z;
                index += 3;
            }
        }
        return imageBuffer;
    }

    // Benchmark sets up an ephemeral image configuration and traces a select few
    // hand-picked pixels to measure EVM execution performance.
    function Benchmark() public returns (int256 r, int256 g, int256 b) {
        deltaX = Vector(width * 513500 / height, 0, 0);
        deltaY = div(mul(norm(cross(deltaX, camera.direction)), 513500), 1000000);

        // Trace a few pixels and collect their colors (sanity check)
        Vector memory color;

        color = add(color, trace(512, 384, 8)); // Flat diffuse surface, opposite wall
        color = add(color, trace(325, 540, 8)); // Reflective surface mirroring left wall
        color = add(color, trace(600, 600, 8)); // Refractive surface reflecting right wall
        color = add(color, trace(522, 524, 8)); // Reflective surface mirroring the refractive surface reflecting the light
        color = div(color, 4);

        return (color.x, color.y, color.z);
    }

    // trace executes the path tracing for a single pixel of the result image and
    // returns the RGB color vector normalized to [0, 256) value range.
    function trace(int256 x, int256 y, int256 spp) internal view returns (Vector3D memory color) {
        delete color;
        for (int256 k = 0; k < spp; k++) {
            Vector memory pixel = add(div(add(mul(deltaX, (1000000 * x + rand() % 500000) / width - 500000), mul(deltaY, (1000000 * y + rand() % 500000) / height - 500000)), 1000000), camera.direction);
            Ray memory ray = Ray(add(camera.origin, mul(pixel, 140)), norm(pixel), 0, false);

            color = add(color, div(radiance(ray), spp));
        }
        return div(mul(clamp(color), 255), 1000000);
    }

    // Trivial linear congruential pseudo-random number generator
    uint32 seed;

    function rand() internal view returns (int256) {
        uint256 newSeed = 1103515245 * uint256(seed) + 12345;
        return int256(newSeed % (2**32));
    }

    // Clamp bounds an int256 value to the allowed [0, 1] range.
    function clamp(int256 x) internal pure returns (int256) {
        if (x < 0) {
            return 0;
        }
        if (x > 1000000) {
            return 1000000;
        }
        return x;
    }

    // Square root calculation based on the Babylonian method
    function sqrt(int256 x) internal pure returns (int256 y) {
        int256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }

    // Sine calculation based on Taylor series expansion.
    function sin(int256 x) internal pure returns (int256 y) {
        // Ensure x is between [0, 2PI) (Taylor expansion is picky with large numbers)
        while (x < 0) {
            x += 6283184;
        }
        while (x >= 6283184) {
            x -= 6283184;
        }
        // Calculate the sin based on the Taylor series
        int256 s = 1;
        int256 n = x;
        int256 d = 1;
        int256 f = 2;
        while (n > d) {
            y += s * n / d;
            n = (n * x * x) / 1000000 / 1000000;
            d *= f * (f + 1);
            s *= -1;
            f += 2;
        }
    }

    // Cosine calculation based on sine and Pythagorean identity.
    function cos(int256 x) internal pure returns (int256) {
        int256 s = sin(x);
        return sqrt(1000000000000 - s * s);
    }

    // Abs returns the absolute value of x.
    function abs(int256 x) internal pure returns (int256) {
        if (x > 0) {
            return x;
        }
        return -x;
    }

    // Ray is a parametric line with an origin and a direction.
    struct Ray {
        Vector origin;
        Vector direction;
        int256 depth;
        bool refract;
    }

    // Material is the various types of light-altering surfaces
    enum Material { Diffuse, Specular, Refractive }

    // Primitive is the various types of geometric primitives
    enum Primitive { Sphere, Triangle }

    // Sphere is a physical object to intersect the light rays with
    struct Sphere {
        int256 radius;
        Vector position;
        Vector emission;
        Vector color;
        Material reflection;
    }

    // Triangle is a physical object to intersect the light rays with
    struct Triangle {
        Vector a;
        Vector b;
        Vector c;
        Vector normal;
        Vector emission;
        Vector color;
        Material reflection;
    }

    // intersect calculates the intersection of a ray with a sphere, returning the
    // distance till the first intersection point or zero in case of no intersection.
    function intersect(Sphere memory s, Ray memory r) internal pure returns (int256) {
        Vector memory op = sub(s.position, r.origin);

        int256 b = dot(op, r.direction) / 1000000;
        int256 det = b * b - dot(op, op) + s.radius * s.radius;

        // Bail out if ray misses the sphere
        if (det < 0) {
            return 0;
        }
        // Calculate the closer intersection point
        det = sqrt(det);
        if (b - det > 1000) {
            return b - det;
        }
        if (b + det > 1000) {
            return b + det;
        }
        return 0;
    }

    function intersect(Triangle memory t, Ray memory r) internal pure returns (int256) {
        Vector memory e1 = sub(t.b, t.a);
        Vector memory e2 = sub(t.c, t.a);

        Vector memory p = cross(r.direction, e2);

        // Bail out if ray is parallel to the triangle
        int256 det = dot(e1, p) / 1000000;
        if (det > -1000 && det < 1000) {
            return 0;
        }
        // Calculate and test the 'u' parameter
        Vector memory d = sub(r.origin, t.a);

        int256 u = dot(d, p) / det;
        if (u < 0 || u > 1000000) {
            return 0;
        }
        // Calculate and test the 'v' parameter
        Vector memory q = cross(d, e1);

        int256 v = dot(r.direction, q) / det;
        if (v < 0 || u + v > 1000000) {
            return 0;
        }
        // Calculate and return the distance
        int256 dist = dot(e2, q) / det;
        if (dist < 1000) {
            return 0;
        }
        return dist;
    }

    function radiance(Ray memory ray) internal view returns (Vector memory) {
        // Place a limit on the depth to prevent stack overflows
        if (ray.depth > 10) {
            return Vector(0, 0, 0);
        }
        // Find the closest object of intersection
        int256 dist;
        Primitive p;
        uint256 id;
        (dist, p, id) = traceray(ray);
        if (dist == 0) {
            return Vector(0, 0, 0);
        }
        Sphere memory sphere;
        Triangle memory triangle;
        Vector memory color;
        Vector memory emission;

        if (p == Primitive.Sphere) {
            sphere = spheres[id];
            color = sphere.color;
            emission = sphere.emission;
        } else {
            triangle = triangles[id];
            color = triangle.color;
            emission = triangle.emission;
        }
        // After a number of reflections, randomly stop radiance calculation
        int256 ref = 1;
        if (color.z > ref) {
            ref = color.z;
        }
        if (color.y > ref) {
            ref = color.y;
        }
        if (color.z > ref) {
            ref = color.z;
        }
        ray.depth++;
        if (ray.depth > 5) {
            if (rand() % 1000000 < ref) {
                color = div(mul(color, 1000000), ref);
            } else {
                return emission;
            }
        }
        // Calculate the primitive dependent radiance
        Vector memory result;
        if (p == Primitive.Sphere) {
            result = radiance(ray, sphere, dist);
        } else {
            result = radiance(ray, triangle, dist);
        }
        return add(emission, div(mul(color, result), 1000000));
    }

    function radiance(Ray memory ray, Sphere memory obj, int256 dist) internal view returns (Vector memory) {
        // Calculate the sphere intersection point and normal vectors for recursion
        Vector memory intersect = add(ray.origin, div(mul(ray.direction, dist), 1000000));
        Vector memory normal = norm(sub(intersect, obj.position));

        // For diffuse reflectivity
        if (obj.reflection == Material.Diffuse) {
            if (dot(normal, ray.direction) >= 0) {
                normal = mul(normal, -1);
            }
            return diffuse(ray, intersect, normal);
        } else { // For specular reflectivity
            return specular(ray, intersect, normal);
        }
    }

    function radiance(Ray memory ray, Triangle memory obj, int256 dist) internal view returns (Vector memory) {
        // Calculate the triangle intersection point for refraction
        // We're cheating here, we don't have diffuse triangles :P
        Vector memory intersect = add(ray.origin, div(mul(ray.direction, dist), 1000000));

        // Calculate the refractive indices based on whether we're in or out
        int256 nnt = 666666; // (1 air / 1.5 glass)
        if (ray.refract) {
            nnt = 1500000; // (1.5 glass / 1 air)
        }
        int256 ddn = dot(obj.normal, ray.direction) / 1000000;
        if (ddn >= 0) {
            ddn = -ddn;
        }
        // If the angle is too shallow, all light is reflected
        int256 cos2t = 1000000000000 - nnt * nnt * (1000000000000 - ddn * ddn) / 1000000000000;
        if (cos2t < 0) {
            return specular(ray, intersect, obj.normal);
        }
        return refractive(ray, intersect, obj.normal, nnt, ddn, cos2t);
    }

    function diffuse(Ray memory ray, Vector memory intersect, Vector memory normal) internal view returns (Vector memory) {
        // Generate a random angle and distance from center
        int256 r1 = int256(6283184) * (rand() % 1000000) / 1000000;
        int256 r2 = rand() % 1000000;
        int256 r2s = sqrt(r2) * 1000;

        // Create orthonormal coordinate frame
        Vector memory u;
        if (abs(normal.x) > 100000) {
            u = Vector(0, 1000000, 0);
        } else {
            u = Vector(1000000, 0, 0);
        }
        u = norm(cross(u, normal));
        Vector memory v = norm(cross(normal, u));

        // Generate the random reflection ray and continue path tracing
        u = norm(add(add(mul(u, cos(r1) * r2s / 1000000), mul(v, sin(r1) * r2s / 1000000)), mul(normal, sqrt(1000000 - r2) * 1000)));
        return radiance(Ray(intersect, u, ray.depth, ray.refract));
    }

    function specular(Ray memory ray, Vector memory intersect, Vector memory normal) internal view returns (Vector memory) {
        Vector memory reflection = norm(sub(ray.direction, mul(normal, 2 * dot(normal, ray.direction) / 1000000)));
        return radiance(Ray(intersect, reflection, ray.depth, ray.refract));
    }

    function refractive(Ray memory ray, Vector memory intersect, Vector memory normal, int256 nnt, int256 ddn, int256 cos2t) internal view returns (Vector memory) {
        // Calculate the refraction rays for fresnel effects
        int256 sign = -1;
        if (ray.refract) {
            sign = 1;
        }
        Vector memory refraction = norm(div(sub(mul(ray.direction, nnt), mul(normal, sign * (ddn * nnt / 1000000 + sqrt(cos2t)))), 1000000));

        // Calculate the fresnel probabilities
        int256 c = 1000000 + ddn;
        if (!ray.refract) {
            c = 1000000 - dot(refraction, normal) / 1000000;
        }
        int256 re = 40000 + (1000000 - 40000) * c * c * c * c * c / 1000000000000000000000000000000;

        // Split a direct hit, otherwise trace only one ray
        if (ray.depth <= 2) {
            refraction = mul(radiance(Ray(intersect, refraction, ray.depth, !ray.refract)), 1000000 - re); // Reuse refraction variable (lame)
            refraction = add(refraction, mul(specular(ray, intersect, normal), re));
            return div(refraction, 1000000);
        }
        if (rand() % 1000000 < 250000 + re / 2) {
            return div(mul(specular(ray, intersect, normal), re), 250000 + re / 2);
        }
        return div(mul(radiance(Ray(intersect, refraction, ray.depth, !ray.refract)), 1000000 - re), 750000 - re / 2);
    }

    // traceray calculates the intersection of a ray with all the objects and
    // returns the closest one.
    function traceray(Ray memory ray) internal view returns (int256, Primitive, uint256) {
        int256 dist = 0;
        Primitive p;
        uint256 id;

        // Intersect the ray with all the spheres
        for (uint256 i = 0; i < spheres.length; i++) {
            int256 d = intersect(spheres[i], ray);
            if (d > 0 && (dist == 0 || d < dist)) {
                dist = d;
                p = Primitive.Sphere;
                id = i;
            }
        }
        // Intersect the ray with all the triangles
        for (uint256 i = 0; i < triangles.length; i++) {
            int256 d = intersect(triangles[i], ray);
            if (d > 0 && (dist == 0 || d < dist)) {
                dist = d;
                p = Primitive.Triangle;
                id = i;
            }
        }
        return (dist, p, id);
    }
}
