#include "sightline/c_api.h"

#include <math.h>
#include <stddef.h>
#include <string.h>

int main(void) {
    const sl_plane plane = {
        {0.0, 0.0, 0.0},
        {0.0, 0.0, 1.0},
        {1.0, 0.0, 0.0},
        {0.0, 1.0, 0.0}};
    const sl_vec3d origin = {1.0, 2.0, 10.0};
    const sl_vec3d direction = {0.0, 0.0, -1.0};
    sl_plane_intersection result = {0};

    const sl_intersection_status status = sl_intersect_forward_plane(
        &plane, origin, direction, 1.0e-12, &result);
    if (status != SL_INTERSECTION_OK || fabs(result.range - 10.0) > 1.0e-12 ||
        fabs(result.world.x - 1.0) > 1.0e-12 ||
        fabs(result.world.y - 2.0) > 1.0e-12 ||
        fabs(result.world.z) > 1.0e-12 ||
        strcmp(sl_version(), "0.1.0") != 0) {
        return 1;
    }
    if (sl_intersect_forward_plane(
            NULL, origin, direction, 1.0e-12, &result) !=
        SL_INTERSECTION_INVALID_INPUT) {
        return 1;
    }
    return 0;
}
