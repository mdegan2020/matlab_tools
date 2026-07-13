#pragma once

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct sl_vec2d {
    double x;
    double y;
} sl_vec2d;

typedef struct sl_vec3d {
    double x;
    double y;
    double z;
} sl_vec3d;

typedef struct sl_plane {
    sl_vec3d origin;
    sl_vec3d normal;
    sl_vec3d basis_x;
    sl_vec3d basis_y;
} sl_plane;

typedef enum sl_intersection_status {
    SL_INTERSECTION_OK = 0,
    SL_INTERSECTION_PARALLEL = 1,
    SL_INTERSECTION_BEHIND_ORIGIN = 2,
    SL_INTERSECTION_INVALID_INPUT = 3
} sl_intersection_status;

typedef struct sl_plane_intersection {
    sl_intersection_status status;
    double range;
    sl_vec3d world;
    sl_vec2d plane;
} sl_plane_intersection;

const char* sl_version(void);

sl_intersection_status sl_intersect_forward_plane(
    const sl_plane* plane,
    sl_vec3d ray_origin,
    sl_vec3d ray_direction,
    double parallel_tolerance,
    sl_plane_intersection* output);

#ifdef __cplusplus
}
#endif
