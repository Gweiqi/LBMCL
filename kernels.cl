#include "constants.h"

#define FLOAT_ORDER_SAILFISH    1

#define COLLIDE_SCRATCH     (1 << 0)
#define COLLIDE_SAILFISH    (1 << 1)
#define COLLIDE_METHOD      COLLIDE_SAILFISH

#define STREAMING_PULL      (1 << 2)
#define STREAMING_PUSH      (1 << 3)
#define STREAMING_METHOD    STREAMING_PUSH


inline int get_cell_type(const int x, const int y, const int z)
{
    int cell_type = NONE;

    if (x == 1)           cell_type |= LEFT;
    if (x == (DIM_X - 2)) cell_type |= RIGHT;
    if (y == 1)           cell_type |= BOTTOM;
    if (y == (DIM_Y - 2)) cell_type |= TOP;
    if (z == 1)           cell_type |= BACK;
    if (z == (DIM_Z - 2)) cell_type |= FRONT;

    if (x == 0)           cell_type = WALL;
    if (x == (DIM_X - 1)) cell_type = WALL;
    if (y == 0)           cell_type = WALL;
    if (y == (DIM_Y - 1)) cell_type = WALL;
    if (z == 0)           cell_type = WALL;
    if (z == (DIM_Z - 1)) cell_type = WALL;

    if (cell_type == (LEFT  | BACK | BOTTOM) ||
        cell_type == (RIGHT | BACK | BOTTOM) ||
        cell_type == (LEFT  | BACK | TOP   ) ||
        cell_type == (RIGHT | BACK | TOP   ))
    {
        cell_type = CORNER;
    }

    if (cell_type == MOVING_BOUNDARY) cell_type |= MOVING;
    if (cell_type == NONE) cell_type = FLUID;

    return cell_type;
}


__kernel
void init(__global float * f_stream, __global float * f_collide, __global float * density, __global float * u, __global int * map)
{
    const int x = get_global_id(0);
    const int y = get_global_id(1);
    const int z = get_global_id(2);
    const int id = IDxyz(x, y, z);
    const int cell_type = get_cell_type(x, y, z);

    const float rho = INITIAL_DENSITY;
    const float ux  = (is_moving_init(cell_type) ? INITIAL_VELOCITY_X : 0.0f);
    const float uy  = (is_moving_init(cell_type) ? INITIAL_VELOCITY_Y : 0.0f);
    const float uz  = (is_moving_init(cell_type) ? INITIAL_VELOCITY_Z : 0.0f);

#if (COLLIDE_METHOD == COLLIDE_SCRATCH)
    float eu = 0.0f;
    const float u2 = (ux * ux) + (uy * uy) + (uz * uz);
#undef  UNROLL_X
#define UNROLL_X(i)                                                                             \
    eu = (ux * E##i##_X) + (uy * E##i##_Y) + (uz * E##i##_Z);                                   \
    const float f##i = (rho * OMEGA_##i) * (1.0f + (3.0f * eu) + (4.5f * eu * eu) - (1.5f * u2));
    UNROLL_19();

#elif (COLLIDE_METHOD == COLLIDE_SAILFISH)
    const float f0  = (OMEGA_0  * rho) * (-1.5 * (ux * ux) - 1.5 * (uy * uy) - 1.5 * (uz * uz))                             + (OMEGA_0  * rho);
    const float f1  = (OMEGA_1  * rho) * (ux * (3.0f * ux + 3.0f) - 1.5 * (uy * uy) - 1.5 * (uz * uz))                      + (OMEGA_1  * rho);
    const float f2  = (OMEGA_2  * rho) * (-1.5 * (ux * ux) + uy * (3.0f * uy + 3.0f) - 1.5 * (uz * uz))                     + (OMEGA_2  * rho);
    const float f3  = (OMEGA_3  * rho) * (ux * (3.0f * ux - 3.0f) - 1.5 * (uy * uy) - 1.5 * (uz * uz))                      + (OMEGA_3  * rho);
    const float f4  = (OMEGA_4  * rho) * (-1.5 * (ux * ux) + uy * (3.0f * uy - 3.0f) - 1.5 * (uz * uz))                     + (OMEGA_4  * rho);
    const float f5  = (OMEGA_5  * rho) * (-1.5 * (ux * ux) - 1.5 * (uy * uy) + uz * (3.0f * uz - 3.0f))                     + (OMEGA_5  * rho);
    const float f6  = (OMEGA_6  * rho) * (-1.5 * (ux * ux) - 1.5 * (uy * uy) + uz * (3.0f * uz + 3.0f))                     + (OMEGA_6  * rho);
    const float f7  = (OMEGA_7  * rho) * (ux * (3.0f * ux + 9.0f * uy + 3.0f) + uy * (3.0f * uy + 3.0f) - 1.5 * (uz * uz))  + (OMEGA_7  * rho);
    const float f8  = (OMEGA_8  * rho) * (ux * (3.0f * ux - 9.0f * uy - 3.0f) + uy * (3.0f * uy + 3.0f) - 1.5 * (uz * uz))  + (OMEGA_8  * rho);
    const float f9  = (OMEGA_9  * rho) * (ux * (3.0f * ux + 9.0f * uy - 3.0f) + uy * (3.0f * uy - 3.0f) - 1.5 * (uz * uz))  + (OMEGA_9  * rho);
    const float f10 = (OMEGA_10 * rho) * (ux * (3.0f * ux - 9.0f * uy + 3.0f) + uy * (3.0f * uy - 3.0f) - 1.5 * (uz * uz))  + (OMEGA_10 * rho);
    const float f11 = (OMEGA_11 * rho) * (ux * (3.0f * ux - 9.0f * uz + 3.0f) - 1.5 * (uy * uy) + uz * (3.0f * uz - 3.0f))  + (OMEGA_11 * rho);
    const float f12 = (OMEGA_12 * rho) * (-1.5 * (ux * ux) + uy * (3.0f * uy - 9.0f * uz + 3.0f) + uz * (3.0f * uz - 3.0f)) + (OMEGA_12 * rho);
    const float f13 = (OMEGA_13 * rho) * (ux * (3.0f * ux + 9.0f * uz - 3.0f) - 1.5 * (uy * uy) + uz * (3.0f * uz - 3.0f))  + (OMEGA_13 * rho);
    const float f14 = (OMEGA_14 * rho) * (-1.5 * (ux * ux) + uy * (3.0f * uy + 9.0f * uz - 3.0f) + uz * (3.0f * uz - 3.0f)) + (OMEGA_14 * rho);
    const float f15 = (OMEGA_15 * rho) * (ux * (3.0f * ux + 9.0f * uz + 3.0f) - 1.5 * (uy * uy) + uz * (3.0f * uz + 3.0f))  + (OMEGA_15 * rho);
    const float f16 = (OMEGA_16 * rho) * (-1.5 * (ux * ux) + uy * (3.0f * uy + 9.0f * uz + 3.0f) + uz * (3.0f * uz + 3.0f)) + (OMEGA_16 * rho);
    const float f17 = (OMEGA_17 * rho) * (ux * (3.0f * ux - 9.0f * uz - 3.0f) - 1.5 * (uy * uy) + uz * (3.0f * uz + 3.0f))  + (OMEGA_17 * rho);
    const float f18 = (OMEGA_18 * rho) * (-1.5 * (ux * ux) + uy * (3.0f * uy - 9.0f * uz - 3.0f) + uz * (3.0f * uz + 3.0f)) + (OMEGA_18 * rho);
#endif

#undef  UNROLL_X
#define UNROLL_X(i) f_collide[IDxyzw(id, i)] = (is_wall(cell_type) ? NAN : f##i);
    UNROLL_19();

#undef  UNROLL_X
#define UNROLL_X(i) f_stream[IDxyzw(id, i)] = (is_wall(cell_type) ? NAN : f##i);
    UNROLL_19();

    density[id] = (is_store_macro(cell_type) ? rho : NAN);
    UX(id)      = (is_store_macro(cell_type) ? ux : NAN);
    UY(id)      = (is_store_macro(cell_type) ? uy : NAN);
    UZ(id)      = (is_store_macro(cell_type) ? uz : NAN);

    map[id] = cell_type;

    //if (id == 0) _print_map(map);

    // if (id == 0) {
    //     float eps = 0.05f;
    //     float prev_eps; 
    //     while ((1 + eps) != 1) { 
    //         prev_eps = eps;   
    //         eps /= 2; 
    //     }
    //     printf("eps = %g\n", eps);
    // }
}


__kernel
void prestreaming(__global float * f_collide, __global float * density, __global float * u, __global const int * map, __global float * f_stream)
{
    const int x = get_global_id(0);
    const int y = get_global_id(1);
    const int z = get_global_id(2);
    const int id = IDxyz(x, y, z);
    const int cell_type = map[id];

    // if (is_wall(cell_type) || is_corner(cell_type)) return;

    // Update meaningless values with proper ones
    // if (is_moving(cell_type)) {
    //     f_collide[IDxyzw(id,  5)] = f_collide[IDxyzw(id,  S_5)];
    //     f_collide[IDxyzw(id, 11)] = f_collide[IDxyzw(id, S_11)];
    //     f_collide[IDxyzw(id, 12)] = f_collide[IDxyzw(id, S_12)];
    //     f_collide[IDxyzw(id, 13)] = f_collide[IDxyzw(id, S_13)];
    //     f_collide[IDxyzw(id, 14)] = f_collide[IDxyzw(id, S_14)];
    // }

#undef  UNROLL_X
#define UNROLL_X(i) float f##i = f_collide[IDxyzw(id, i)];
    UNROLL_19();

if (is_moving(cell_type)) {
    f5  = F_S( 5);
    f11 = F_S(11);
    f12 = F_S(12);
    f13 = F_S(13);
    f14 = F_S(14);
}

    /***   Compute Macro quantities (rho & u)   ***/
#if FLOAT_ORDER_SAILFISH
    const float rho = f5 + f11 + f12 + f14 + f13 + f0 + f1 + f2 + f7 + f8 + f4 + f10 + f9 + f6 + f15 + f16 + f18 + f17 + f3;
#else                   
    const float rho = f0 + f1 + f2 + f3 + f4 + f5 + f6 + f7 + f8 + f9 + f10 + f11 + f12 + f13 + f14 + f15 + f16 + f17 + f18;
#endif

    float ux = NAN;
    float uy = NAN;
    float uz = NAN;

    if (is_moving(cell_type)) {
        // rho = rho / (INITIAL_VELOCITY_Z + 1.0f);
        ux = INITIAL_VELOCITY_X;
        uy = INITIAL_VELOCITY_Y;
        uz = INITIAL_VELOCITY_Z;
    } else {

#if FLOAT_ORDER_SAILFISH
            //fBE - fBW +  fE + fNE - fNW + fSE - fSW + fTE - fTW -  fW) / zero;
        ux = (f11 - f13 +  f1 +  f7 -  f8 + f10 -  f9 + f15 - f17 -  f3) / rho;
           //(fBN - fBS +  fN + fNE + fNW -  fS - fSE - fSW + fTN - fTS) / zero;
        uy = (f12 - f14 +  f2 +  f7 +  f8 -  f4 - f10 -  f9 + f16 - f18) / rho;
           //(-fB - fBE - fBN - fBS - fBW +  fT + fTE + fTN + fTS + fTW) / zero;
        uz = (-f5 - f11 - f12 - f14 - f13  + f6 + f15 + f16 + f18 + f17) / rho;
#else 
        // ux = (f1     -f3             +f7 -f8 -f9 +f10 +f11      -f13      +f15      -f17     ) / rho;
        // uy = (    f2     -f4         +f7 +f8 -f9 -f10      +f12      -f14      +f16      -f18) / rho;
        // uz = (               -f5 +f6                  -f11 -f12 -f13 -f14 +f15 +f16 +f17 +f18) / rho;
        ux = (( f1 +  f7 + f10 + f11 + f15) - ( f3 +  f8 +  f9 + f13 + f17)) / rho;
        uy = (( f2 +  f7 +  f8 + f12 + f16) - ( f4 +  f9 + f10 + f14 + f18)) / rho;
        uz = (( f6 + f15 + f16 + f17 + f18) - ( f5 + f11 + f12 + f13 + f14)) / rho;
#endif 
    }

    /***   Store macro quantities (rho & u)   ***/
    if (is_store_macro(cell_type)) {
        density[id] = rho;
        UX(id) = ux;
        UY(id) = uy;
        UZ(id) = uz;
    }


    /***   Boundary Conditions   ***/
    if (is_moving(cell_type)) {

#if (COLLIDE_METHOD == COLLIDE_SCRATCH)
        float eu = 0.0f;
        const float u2 = (ux * ux) + (uy * uy) + (uz * uz);

#undef  UNROLL_X
#define UNROLL_X(i)                                                                      \
        eu = (ux * E##i##_X) + (uy * E##i##_Y) + (uz * E##i##_Z);                        \
        f##i = (rho * OMEGA_##i) * (1.0f + (3.0f * eu) + (4.5f * eu * eu) - (1.5f * u2));
        UNROLL_19();
#endif

#if (COLLIDE_METHOD == COLLIDE_SAILFISH)
        f0  = (OMEGA_0  * rho) * (-1.5 * (ux * ux) - 1.5 * (uy * uy) - 1.5 * (uz * uz))                             + (OMEGA_0  * rho);
        f1  = (OMEGA_1  * rho) * (ux * (3.0f * ux + 3.0f) - 1.5 * (uy * uy) - 1.5 * (uz * uz))                      + (OMEGA_1  * rho);
        f2  = (OMEGA_2  * rho) * (-1.5 * (ux * ux) + uy * (3.0f * uy + 3.0f) - 1.5 * (uz * uz))                     + (OMEGA_2  * rho);
        f3  = (OMEGA_3  * rho) * (ux * (3.0f * ux - 3.0f) - 1.5 * (uy * uy) - 1.5 * (uz * uz))                      + (OMEGA_3  * rho);
        f4  = (OMEGA_4  * rho) * (-1.5 * (ux * ux) + uy * (3.0f * uy - 3.0f) - 1.5 * (uz * uz))                     + (OMEGA_4  * rho);
        f5  = (OMEGA_5  * rho) * (-1.5 * (ux * ux) - 1.5 * (uy * uy) + uz * (3.0f * uz - 3.0f))                     + (OMEGA_5  * rho);
        f6  = (OMEGA_6  * rho) * (-1.5 * (ux * ux) - 1.5 * (uy * uy) + uz * (3.0f * uz + 3.0f))                     + (OMEGA_6  * rho);
        f7  = (OMEGA_7  * rho) * (ux * (3.0f * ux + 9.0f * uy + 3.0f) + uy * (3.0f * uy + 3.0f) - 1.5 * (uz * uz))  + (OMEGA_7  * rho);
        f8  = (OMEGA_8  * rho) * (ux * (3.0f * ux - 9.0f * uy - 3.0f) + uy * (3.0f * uy + 3.0f) - 1.5 * (uz * uz))  + (OMEGA_8  * rho);
        f9  = (OMEGA_9  * rho) * (ux * (3.0f * ux + 9.0f * uy - 3.0f) + uy * (3.0f * uy - 3.0f) - 1.5 * (uz * uz))  + (OMEGA_9  * rho);
        f10 = (OMEGA_10 * rho) * (ux * (3.0f * ux - 9.0f * uy + 3.0f) + uy * (3.0f * uy - 3.0f) - 1.5 * (uz * uz))  + (OMEGA_10 * rho);
        f11 = (OMEGA_11 * rho) * (ux * (3.0f * ux - 9.0f * uz + 3.0f) - 1.5 * (uy * uy) + uz * (3.0f * uz - 3.0f))  + (OMEGA_11 * rho);
        f12 = (OMEGA_12 * rho) * (-1.5 * (ux * ux) + uy * (3.0f * uy - 9.0f * uz + 3.0f) + uz * (3.0f * uz - 3.0f)) + (OMEGA_12 * rho);
        f13 = (OMEGA_13 * rho) * (ux * (3.0f * ux + 9.0f * uz - 3.0f) - 1.5 * (uy * uy) + uz * (3.0f * uz - 3.0f))  + (OMEGA_13 * rho);
        f14 = (OMEGA_14 * rho) * (-1.5 * (ux * ux) + uy * (3.0f * uy + 9.0f * uz - 3.0f) + uz * (3.0f * uz - 3.0f)) + (OMEGA_14 * rho);
        f15 = (OMEGA_15 * rho) * (ux * (3.0f * ux + 9.0f * uz + 3.0f) - 1.5 * (uy * uy) + uz * (3.0f * uz + 3.0f))  + (OMEGA_15 * rho);
        f16 = (OMEGA_16 * rho) * (-1.5 * (ux * ux) + uy * (3.0f * uy + 9.0f * uz + 3.0f) + uz * (3.0f * uz + 3.0f)) + (OMEGA_16 * rho);
        f17 = (OMEGA_17 * rho) * (ux * (3.0f * ux - 9.0f * uz - 3.0f) - 1.5 * (uy * uy) + uz * (3.0f * uz + 3.0f))  + (OMEGA_17 * rho);
        f18 = (OMEGA_18 * rho) * (-1.5 * (ux * ux) + uy * (3.0f * uy - 9.0f * uz - 3.0f) + uz * (3.0f * uz + 3.0f)) + (OMEGA_18 * rho);
#endif

    } else if (is_bounceback(cell_type)) {
#undef  UNROLL_X
#define UNROLL_X(i)                \
        {                          \
            const float tmp = f##i;\
            f##i = F_S(i);         \
            F_S(i) = tmp;          \
        }
        UNROLL_HALF_19();

        // float tmp = f_collide[IDxyzw(id, 1)];;
        // f_collide[IDxyzw(id,  1)]   = f_collide[IDxyzw(id,  S_1)];
        // f_collide[IDxyzw(id, S_1)] = tmp;

        // tmp = f_collide[IDxyzw(id, 2)];;
        // f_collide[IDxyzw(id,  2)]   = f_collide[IDxyzw(id,  S_2)];
        // f_collide[IDxyzw(id, S_2)] = tmp;

        // tmp = f_collide[IDxyzw(id, 5)];;
        // f_collide[IDxyzw(id,  5)]   = f_collide[IDxyzw(id,  S_5)];
        // f_collide[IDxyzw(id, S_5)] = tmp;

        // tmp = f_collide[IDxyzw(id, 7)];;
        // f_collide[IDxyzw(id,  7)]   = f_collide[IDxyzw(id,  S_7)];
        // f_collide[IDxyzw(id, S_7)] = tmp;

        // tmp = f_collide[IDxyzw(id, 8)];;
        // f_collide[IDxyzw(id,  8)]   = f_collide[IDxyzw(id,  S_8)];
        // f_collide[IDxyzw(id, S_8)] = tmp;

        // tmp = f_collide[IDxyzw(id, 11)];;
        // f_collide[IDxyzw(id, 11)]   = f_collide[IDxyzw(id, S_11)];
        // f_collide[IDxyzw(id, S_11)] = tmp;

        // tmp = f_collide[IDxyzw(id, 12)];;
        // f_collide[IDxyzw(id, 12)]   = f_collide[IDxyzw(id, S_12)];
        // f_collide[IDxyzw(id, S_12)] = tmp;


        // tmp = f_collide[IDxyzw(id, 13)];;
        // f_collide[IDxyzw(id, 13)]   = f_collide[IDxyzw(id, S_13)];
        // f_collide[IDxyzw(id, S_13)] = tmp;

        // tmp = f_collide[IDxyzw(id, 14)];;
        // f_collide[IDxyzw(id, 14)]   = f_collide[IDxyzw(id, S_14)];
        // f_collide[IDxyzw(id, S_14)] = tmp;
    }


    /***   Collision   ***/
    if (is_collision(cell_type)) {

#if (COLLIDE_METHOD == COLLIDE_SCRATCH)
        float eu = 0.0f;
        const float u2 = (ux * ux) + (uy * uy) + (uz * uz);
#undef  UNROLL_X
#define UNROLL_X(i)                                                                                     \
        eu = (ux * E##i##_X) + (uy * E##i##_Y) + (uz * E##i##_Z);                                       \
        const float fnew##i = (rho * OMEGA_##i) * (1.0f + (3.0f * eu) + (4.5f * eu * eu) - (1.5f * u2));
        UNROLL_19();
#endif

#if (COLLIDE_METHOD == COLLIDE_SAILFISH)
        const float fnew0  = (OMEGA_0  * rho) * (-1.5 * (ux * ux) - 1.5 * (uy * uy) - 1.5 * (uz * uz))                             + (OMEGA_0  * rho);
        const float fnew1  = (OMEGA_1  * rho) * (ux * (3.0f * ux + 3.0f) - 1.5 * (uy * uy) - 1.5 * (uz * uz))                      + (OMEGA_1  * rho);
        const float fnew2  = (OMEGA_2  * rho) * (-1.5 * (ux * ux) + uy * (3.0f * uy + 3.0f) - 1.5 * (uz * uz))                     + (OMEGA_2  * rho);
        const float fnew3  = (OMEGA_3  * rho) * (ux * (3.0f * ux - 3.0f) - 1.5 * (uy * uy) - 1.5 * (uz * uz))                      + (OMEGA_3  * rho);
        const float fnew4  = (OMEGA_4  * rho) * (-1.5 * (ux * ux) + uy * (3.0f * uy - 3.0f) - 1.5 * (uz * uz))                     + (OMEGA_4  * rho);
        const float fnew5  = (OMEGA_5  * rho) * (-1.5 * (ux * ux) - 1.5 * (uy * uy) + uz * (3.0f * uz - 3.0f))                     + (OMEGA_5  * rho);
        const float fnew6  = (OMEGA_6  * rho) * (-1.5 * (ux * ux) - 1.5 * (uy * uy) + uz * (3.0f * uz + 3.0f))                     + (OMEGA_6  * rho);
        const float fnew7  = (OMEGA_7  * rho) * (ux * (3.0f * ux + 9.0f * uy + 3.0f) + uy * (3.0f * uy + 3.0f) - 1.5 * (uz * uz))  + (OMEGA_7  * rho);
        const float fnew8  = (OMEGA_8  * rho) * (ux * (3.0f * ux - 9.0f * uy - 3.0f) + uy * (3.0f * uy + 3.0f) - 1.5 * (uz * uz))  + (OMEGA_8  * rho);
        const float fnew9  = (OMEGA_9  * rho) * (ux * (3.0f * ux + 9.0f * uy - 3.0f) + uy * (3.0f * uy - 3.0f) - 1.5 * (uz * uz))  + (OMEGA_9  * rho);
        const float fnew10 = (OMEGA_10 * rho) * (ux * (3.0f * ux - 9.0f * uy + 3.0f) + uy * (3.0f * uy - 3.0f) - 1.5 * (uz * uz))  + (OMEGA_10 * rho);
        const float fnew11 = (OMEGA_11 * rho) * (ux * (3.0f * ux - 9.0f * uz + 3.0f) - 1.5 * (uy * uy) + uz * (3.0f * uz - 3.0f))  + (OMEGA_11 * rho);
        const float fnew12 = (OMEGA_12 * rho) * (-1.5 * (ux * ux) + uy * (3.0f * uy - 9.0f * uz + 3.0f) + uz * (3.0f * uz - 3.0f)) + (OMEGA_12 * rho);
        const float fnew13 = (OMEGA_13 * rho) * (ux * (3.0f * ux + 9.0f * uz - 3.0f) - 1.5 * (uy * uy) + uz * (3.0f * uz - 3.0f))  + (OMEGA_13 * rho);
        const float fnew14 = (OMEGA_14 * rho) * (-1.5 * (ux * ux) + uy * (3.0f * uy + 9.0f * uz - 3.0f) + uz * (3.0f * uz - 3.0f)) + (OMEGA_14 * rho);
        const float fnew15 = (OMEGA_15 * rho) * (ux * (3.0f * ux + 9.0f * uz + 3.0f) - 1.5 * (uy * uy) + uz * (3.0f * uz + 3.0f))  + (OMEGA_15 * rho);
        const float fnew16 = (OMEGA_16 * rho) * (-1.5 * (ux * ux) + uy * (3.0f * uy + 9.0f * uz + 3.0f) + uz * (3.0f * uz + 3.0f)) + (OMEGA_16 * rho);
        const float fnew17 = (OMEGA_17 * rho) * (ux * (3.0f * ux - 9.0f * uz - 3.0f) - 1.5 * (uy * uy) + uz * (3.0f * uz + 3.0f))  + (OMEGA_17 * rho);
        const float fnew18 = (OMEGA_18 * rho) * (-1.5 * (ux * ux) + uy * (3.0f * uy - 9.0f * uz - 3.0f) + uz * (3.0f * uz + 3.0f)) + (OMEGA_18 * rho);
#endif

// #undef  UNROLL_X
// #define UNROLL_X(i) f_collide[IDxyzw(id, i)] = compute_bgk(f##i, fnew##i);
//         UNROLL_19();
//     }
//     else {
// #undef  UNROLL_X
// #define UNROLL_X(i) f_collide[IDxyzw(id, i)] = f##i;
//         UNROLL_19();
//     }

#undef  UNROLL_X
#define UNROLL_X(i) f##i = compute_bgk(f##i, fnew##i);
        UNROLL_19();
    }

    int lx = get_local_id(0);

    bool alive = true;
    if (is_wall(cell_type)) {
        alive = false;
    }

    bool propagation_only = false;
    if (is_corner(cell_type)) {
        propagation_only = true;
    }

#define IDXYZW(x, y, z, w)  (((x) + ((y) * DIM_X) + ((z) * DIM_X * DIM_Y)) * Q_DIM + (w))

    __local float  _f1[Q_DIM];
    __local float  _f7[Q_DIM];
    __local float _f10[Q_DIM];
    __local float _f11[Q_DIM];
    __local float _f15[Q_DIM];
#define  _f3  _f1
#define  _f8 _f10
#define  _f9  _f7
#define _f13 _f15
#define _f17 _f11
    _f1[lx] = -1.0f;
    barrier(CLK_LOCAL_MEM_FENCE);
    if (!propagation_only && alive)
    {
        // Update the 0-th direction distribution
        f_stream[IDxyzw(id, 0)] = f0;                                                           //  0  0  0
        // Propagation in directions orthogonal to the X axis (global memory)
        if (y < 7) f_stream[IDXYZW(   x, y+1,   z,  2)] = f2;                                   //  0 +1  0
        if (y > 0) f_stream[IDXYZW(   x, y-1,   z,  4)] = f4;                                   //  0 -1  0
        if (z < 7) f_stream[IDXYZW(   x,   y, z+1,  6)] = f6;                                   //  0  0 +1
        if (z > 0) f_stream[IDXYZW(   x,   y, z-1,  5)] = f5;                                   //  0  0 -1

        if (y < 7 && z < 7) f_stream[IDXYZW(   x, y+1, z+1, 16)] = f16;                         //  0 +1 +1
        if (y > 0 && z < 7) f_stream[IDXYZW(   x, y-1, z+1, 18)] = f18;                         //  0 -1 +1
        if (y < 7 && z > 0) f_stream[IDXYZW(   x, y+1, z-1, 12)] = f12;                         //  0 +1 -1
        if (y > 0 && z > 0) f_stream[IDXYZW(   x, y-1, z-1, 14)] = f14;                         //  0 -1 -1

        // E propagation in shared memory
        if (x < 7) {
            // Note: propagation to ghost nodes is done directly in global memory as there
            // are no threads running for the ghost nodes.
            if (lx < 63 && x != 6) {
                 _f1[lx + 1] =  f1;
                 _f7[lx + 1] =  f7;
                _f10[lx + 1] = f10;
                _f11[lx + 1] = f11;
                _f15[lx + 1] = f15;
                // E propagation in global memory (at right block boundary)
            } else {
                           f_stream[IDXYZW( x+1,   y,   z,  1)] =  f1;                          // +1  0  0
                if (y < 7) f_stream[IDXYZW( x+1, y+1,   z,  7)] =  f7;                          // +1 +1  0
                if (y > 0) f_stream[IDXYZW( x+1, y-1,   z, 10)] = f10;                          // +1 -1  0
                if (z < 7) f_stream[IDXYZW( x+1,   y, z+1, 15)] = f15;                          // +1  0 +1
                if (z > 0) f_stream[IDXYZW( x+1,   y, z-1, 11)] = f11;                          // +1  0 -1
            }
        }
    }

    barrier(CLK_LOCAL_MEM_FENCE);
    // Save locally propagated distributions into global memory.
    // The leftmost thread is not updated in this block.
    if (lx > 0 && x < 8 && !propagation_only && alive)
    {
        if (_f1[lx] != -1.0f) {
                       f_stream[IDXYZW( x,   y,   z,  1)] =  _f1[lx];                                      //  0  0  0
            if (y < 7) f_stream[IDXYZW( x, y+1,   z,  7)] =  _f7[lx];                                      //  0 +1  0
            if (y > 0) f_stream[IDXYZW( x, y-1,   z, 10)] = _f10[lx];                                      //  0 -1  0
            if (z < 7) f_stream[IDXYZW( x,   y, z+1, 15)] = _f15[lx];                                      //  0  0 +1
            if (z > 0) f_stream[IDXYZW( x,   y, z-1, 11)] = _f11[lx];                                      //  0  0 -1
        }
    }

    barrier(CLK_LOCAL_MEM_FENCE);
    // Refill the propagation buffer with sentinel values.
    _f1[lx] = -1.0f;
    barrier(CLK_LOCAL_MEM_FENCE);
    if (!propagation_only && alive)
    {
        // W propagation in shared memory
        // Note: propagation to ghost nodes is done directly in global memory as there
        // are no threads running for the ghost nodes.
        if ((lx > 1 || (lx > 0 && x >= 64)) && !propagation_only) {
             _f3[lx - 1] = f3;
             _f8[lx - 1] = f8;
             _f9[lx - 1] = f9;
            _f13[lx - 1] = f13;
            _f17[lx - 1] = f17;
            // W propagation in global memory (at left block boundary)
        } else if (x > 0) {
                       f_stream[IDXYZW( x-1,   y,   z,  3)] =  f3;                                         // -1  0  0
            if (y < 7) f_stream[IDXYZW( x-1, y+1,   z,  8)] =  f8;                                         // -1 +1  0
            if (y > 0) f_stream[IDXYZW( x-1, y-1,   z,  9)] =  f9;                                         // -1 -1  0
            if (z < 7) f_stream[IDXYZW( x-1,   y, z+1, 17)] = f17;                                         // -1  0 +1
            if (z > 0) f_stream[IDXYZW( x-1,   y, z-1, 13)] = f13;                                         // -1  0 -1
        }
    }

    barrier(CLK_LOCAL_MEM_FENCE);
    // The rightmost thread is not updated in this block.
    if (lx < 63 && x < 7 && !propagation_only && alive)
    {
        if (_f1[lx] != -1.0f) {
                       f_stream[IDXYZW( x,   y,   z,  3)] =  _f3[lx];                                     //  0  0  0
            if (y < 7) f_stream[IDXYZW( x, y+1,   z,  8)] =  _f8[lx];                                     //  0 +1  0
            if (y > 0) f_stream[IDXYZW( x, y-1,   z,  9)] =  _f9[lx];                                     //  0 -1  0
            if (z < 7) f_stream[IDXYZW( x,   y, z+1, 17)] = _f17[lx];                                     //  0  0 +1
            if (z > 0) f_stream[IDXYZW( x,   y, z-1, 13)] = _f13[lx];                                     //  0  0 -1
        }
    }
}


// #define BLOCK_SIZE 64

// __kernel
// void streaming(__global float * f_stream, __global const float * f_collide, __global const int * map)
// {
//     const int x = get_global_id(0);
//     const int y = get_global_id(1);
//     const int z = get_global_id(2);
//     const int id = IDxyz(x, y, z);
//     const int cell_type = map[id];

// //     __local float prop_fE[BLOCK_SIZE];
// //     __local float prop_fNE[BLOCK_SIZE];
// //     __local float prop_fSE[BLOCK_SIZE];
// //     __local float prop_fTE[BLOCK_SIZE];
// //     __local float prop_fBE[BLOCK_SIZE];
// // #define prop_fW prop_fE
// // #define prop_fSW prop_fNE
// // #define prop_fNW prop_fSE
// // #define prop_fBW prop_fTE
// // #define prop_fTW prop_fBE


// #define IDXYZW(x, y, z, w)  (((x) + ((y) * DIM_X) + ((z) * DIM_X * DIM_Y)) * Q + (w))
// #define IDNXNYNZW(x, y, z, w) IDXYZW(x + E##w##_X, y + E##w##_Y, z + E##w##_Z, w)

//     // if (is_wall(cell_type)) return;
//     if (is_corner(cell_type)) return;

//     f_stream[IDxyzw(id, 0)] = f_collide[IDXYZW(x, y, z, 0)];

//     // Propagation in directions orthogonal to the X axis (global memory)
//     if (y < 7) f_stream[IDxyzw(id,  2)] = f_collide[IDNXNYNZW(x, y, z,  2)]; 
//     if (y > 0) f_stream[IDxyzw(id,  4)] = f_collide[IDNXNYNZW(x, y, z,  4)];
//     if (z < 7) f_stream[IDxyzw(id,  6)] = f_collide[IDNXNYNZW(x, y, z,  6)];
//     if (z > 0) f_stream[IDxyzw(id,  5)] = f_collide[IDNXNYNZW(x, y, z,  5)];

//     if (y < 7 && z < 7) f_stream[IDxyzw(id, 16)] = f_collide[IDNXNYNZW(x, y, z, 16)];
//     if (y > 0 && z < 7) f_stream[IDxyzw(id, 18)] = f_collide[IDNXNYNZW(x, y, z, 18)];
//     if (y < 7 && z > 0) f_stream[IDxyzw(id, 12)] = f_collide[IDNXNYNZW(x, y, z, 12)];
//     if (y > 0 && z > 0) f_stream[IDxyzw(id, 14)] = f_collide[IDNXNYNZW(x, y, z, 14)];

//     if (x < 7) {
//         f_stream[IDxyzw(id,  1)] = f_collide[IDNXNYNZW(x, y, z,  1)];
//         if (y < 7) f_stream[IDxyzw(id,  7)] = f_collide[IDNXNYNZW(x, y, z,  7)];
//         if (y > 0) f_stream[IDxyzw(id, 10)] = f_collide[IDNXNYNZW(x, y, z, 10)];
//         if (z < 7) f_stream[IDxyzw(id, 15)] = f_collide[IDNXNYNZW(x, y, z, 15)];
//         if (z > 0) f_stream[IDxyzw(id, 11)] = f_collide[IDNXNYNZW(x, y, z, 11)];
//     }

//      if (x > 0) {
//         f_stream[IDxyzw(id,  3)] = f_collide[IDNXNYNZW(x, y, z,  3)];
//         if (y < 7) f_stream[IDxyzw(id,  8)] = f_collide[IDNXNYNZW(x, y, z,  8)];
//         if (y > 0) f_stream[IDxyzw(id,  9)] = f_collide[IDNXNYNZW(x, y, z,  9)];
//         if (z < 7) f_stream[IDxyzw(id, 17)] = f_collide[IDNXNYNZW(x, y, z, 17)];
//         if (z > 0) f_stream[IDxyzw(id, 13)] = f_collide[IDNXNYNZW(x, y, z, 13)];
//     }
// }

__kernel
void streaming(__global float * f_stream, __global const float * f_collide, __global const int * map)
{
    const int x = get_global_id(0);
    const int y = get_global_id(1);
    const int z = get_global_id(2);
    const int id = IDxyz(x, y, z);
    const int cell_type = map[id];

// #if (STREAMING_METHOD == STREAMING_PULL)
//     // if (is_wall(cell_type) || is_corner(cell_type)) return;
// #undef  UNROLL_X
// #define UNROLL_X(i)                                                       \
//     {                                                                     \
//         const int index = IDxyz(x - E##i##_X, y - E##i##_Y, z - E##i##_Z);\
//         f_stream[IDxyzw(id, i)] = f_collide[IDxyzw(index, i)];            \
//     }
//     UNROLL_19();
// #endif

#if (STREAMING_METHOD == STREAMING_PULL)
    // if (is_wall(cell_type)) return;
    if (is_corner(cell_type)) return;
#undef  UNROLL_X
#define UNROLL_X(i)                                                                   \
    {                                                                                 \
        const int nx = x - E##i##_X;                                                  \
        const int ny = y - E##i##_Y;                                                  \
        const int nz = z - E##i##_Z;                                                  \
        if (0 <= nx && nx < DIM_X && 0 <= ny && ny < DIM_Y && 0 <= nz && nz < DIM_Z) {\
            const int index = IDxyz(nx, ny, nz);                                      \
            f_stream[IDxyzw(id, i)] = f_collide[IDxyzw(index, i)];                    \
        }                                                                             \
    }
    UNROLL_19();
#endif


#if (STREAMING_METHOD == STREAMING_PUSH)

#if 0
    if (is_wall(cell_type)) return;
    if (is_corner(cell_type)) return;
#undef  UNROLL_X
#define UNROLL_X(i)                                                                   \
    {                                                                                 \
        const int nx = x + E##i##_X;                                                  \
        const int ny = y + E##i##_Y;                                                  \
        const int nz = z + E##i##_Z;                                                  \
        const int index = IDxyz(nx, ny, nz);                                          \
        if (0 <= nx && nx < DIM_X && 0 <= ny && ny < DIM_Y && 0 <= nz && nz < DIM_Z) {\
            f_stream[IDxyzw(index, i)] = f_collide[IDxyzw(id, i)];                    \
        }                                                                             \
    }
    UNROLL_19();
#else 

    int lx = get_local_id(0);

    bool alive = true;
    if (is_wall(cell_type)) {
        alive = false;
    }

    bool propagation_only = false;
    if (is_corner(cell_type)) {
        propagation_only = true;
    }

#define IDXYZW(x, y, z, w)  (((x) + ((y) * DIM_X) + ((z) * DIM_X * DIM_Y)) * Q_DIM + (w))

    __local float  f1[Q_DIM];
    __local float  f7[Q_DIM];
    __local float f10[Q_DIM];
    __local float f11[Q_DIM];
    __local float f15[Q_DIM];
#define  f3  f1
#define  f8 f10
#define  f9  f7
#define f13 f15
#define f17 f11
    f1[lx] = -1.0f;
    barrier(CLK_LOCAL_MEM_FENCE);
    if (!propagation_only && alive)
    {
        // Update the 0-th direction distribution
        f_stream[IDxyzw(id, 0)] = f_collide[IDxyzw(id, 0)];                                     //  0  0  0
        // Propagation in directions orthogonal to the X axis (global memory)
        if (y < 7) f_stream[IDXYZW(   x, y+1,   z,  2)] = f_collide[IDxyzw(id, 2)];             //  0 +1  0
        if (y > 0) f_stream[IDXYZW(   x, y-1,   z,  4)] = f_collide[IDxyzw(id, 4)];             //  0 -1  0
        if (z < 7) f_stream[IDXYZW(   x,   y, z+1,  6)] = f_collide[IDxyzw(id, 6)];             //  0  0 +1
        if (z > 0) f_stream[IDXYZW(   x,   y, z-1,  5)] = f_collide[IDxyzw(id, 5)];             //  0  0 -1

        if (y < 7 && z < 7) f_stream[IDXYZW(   x, y+1, z+1, 16)] = f_collide[IDxyzw(id, 16)];   //  0 +1 +1
        if (y > 0 && z < 7) f_stream[IDXYZW(   x, y-1, z+1, 18)] = f_collide[IDxyzw(id, 18)];   //  0 -1 +1
        if (y < 7 && z > 0) f_stream[IDXYZW(   x, y+1, z-1, 12)] = f_collide[IDxyzw(id, 12)];   //  0 +1 -1
        if (y > 0 && z > 0) f_stream[IDXYZW(   x, y-1, z-1, 14)] = f_collide[IDxyzw(id, 14)];   //  0 -1 -1

        // E propagation in shared memory
        if (x < 7) {
            // Note: propagation to ghost nodes is done directly in global memory as there
            // are no threads running for the ghost nodes.
            if (lx < 63 && x != 6) {
                 f1[lx + 1] = f_collide[IDxyzw(id,  1)];
                 f7[lx + 1] = f_collide[IDxyzw(id,  7)];
                f10[lx + 1] = f_collide[IDxyzw(id, 10)];
                f11[lx + 1] = f_collide[IDxyzw(id, 11)];
                f15[lx + 1] = f_collide[IDxyzw(id, 15)];
                // E propagation in global memory (at right block boundary)
            } else {
                           f_stream[IDXYZW( x+1,   y,   z,  1)] = f_collide[IDxyzw(id,  1)];    // +1  0  0
                if (y < 7) f_stream[IDXYZW( x+1, y+1,   z,  7)] = f_collide[IDxyzw(id,  7)];    // +1 +1  0
                if (y > 0) f_stream[IDXYZW( x+1, y-1,   z, 10)] = f_collide[IDxyzw(id, 10)];    // +1 -1  0
                if (z < 7) f_stream[IDXYZW( x+1,   y, z+1, 15)] = f_collide[IDxyzw(id, 15)];    // +1  0 +1
                if (z > 0) f_stream[IDXYZW( x+1,   y, z-1, 11)] = f_collide[IDxyzw(id, 11)];    // +1  0 -1
            }
        }
    }

    barrier(CLK_LOCAL_MEM_FENCE);
    // Save locally propagated distributions into global memory.
    // The leftmost thread is not updated in this block.
    if (lx > 0 && x < 8 && !propagation_only && alive)
    {
        if (f1[lx] != -1.0f) {
                       f_stream[IDXYZW( x,   y,   z,  1)] =  f1[lx];                                      //  0  0  0
            if (y < 7) f_stream[IDXYZW( x, y+1,   z,  7)] =  f7[lx];                                      //  0 +1  0
            if (y > 0) f_stream[IDXYZW( x, y-1,   z, 10)] = f10[lx];                                      //  0 -1  0
            if (z < 7) f_stream[IDXYZW( x,   y, z+1, 15)] = f15[lx];                                      //  0  0 +1
            if (z > 0) f_stream[IDXYZW( x,   y, z-1, 11)] = f11[lx];                                      //  0  0 -1
        }
    }

    barrier(CLK_LOCAL_MEM_FENCE);
    // Refill the propagation buffer with sentinel values.
    f3[lx] = -1.0f;
    barrier(CLK_LOCAL_MEM_FENCE);
    if (!propagation_only && alive)
    {
        // W propagation in shared memory
        // Note: propagation to ghost nodes is done directly in global memory as there
        // are no threads running for the ghost nodes.
        if ((lx > 1 || (lx > 0 && x >= 64)) && !propagation_only) {
             f3[lx - 1] = f_collide[IDxyzw(id,  3)];
             f8[lx - 1] = f_collide[IDxyzw(id,  8)];
             f9[lx - 1] = f_collide[IDxyzw(id,  9)];
            f13[lx - 1] = f_collide[IDxyzw(id, 13)];
            f17[lx - 1] = f_collide[IDxyzw(id, 17)];
            // W propagation in global memory (at left block boundary)
        } else if (x > 0) {
                       f_stream[IDXYZW( x-1,   y,   z,  3)] = f_collide[IDxyzw(id,  3)];       // -1  0  0
            if (y < 7) f_stream[IDXYZW( x-1, y+1,   z,  8)] = f_collide[IDxyzw(id,  8)];       // -1 +1  0
            if (y > 0) f_stream[IDXYZW( x-1, y-1,   z,  9)] = f_collide[IDxyzw(id,  9)];       // -1 -1  0
            if (z < 7) f_stream[IDXYZW( x-1,   y, z+1, 17)] = f_collide[IDxyzw(id, 17)];       // -1  0 +1
            if (z > 0) f_stream[IDXYZW( x-1,   y, z-1, 13)] = f_collide[IDxyzw(id, 13)];       // -1  0 -1
        }
    }

    barrier(CLK_LOCAL_MEM_FENCE);
    // The rightmost thread is not updated in this block.
    if (lx < 63 && x < 7 && !propagation_only && alive)
    {
        if (f3[lx] != -1.0f) {
                       f_stream[IDXYZW( x,   y,   z,  3)] =  f3[lx];                                     //  0  0  0
            if (y < 7) f_stream[IDXYZW( x, y+1,   z,  8)] =  f8[lx];                                     //  0 +1  0
            if (y > 0) f_stream[IDXYZW( x, y-1,   z,  9)] =  f9[lx];                                     //  0 -1  0
            if (z < 7) f_stream[IDXYZW( x,   y, z+1, 17)] = f17[lx];                                     //  0  0 +1
            if (z > 0) f_stream[IDXYZW( x,   y, z-1, 13)] = f13[lx];                                     //  0  0 -1
        }
    }
#endif

#if 0
#define IDXYZW(x, y, z, w)  (((x) + ((y) * DIM_X) + ((z) * DIM_X * DIM_Y)) * Q_DIM + (w))
    if (is_wall(cell_type)) return;
    if (is_corner(cell_type)) return;

    f_stream[IDxyzw(id, 0)] = f_collide[IDxyzw(id, 0)];

    // Propagation in directions orthogonal to the X axis (global memory)
    if (y < DIM - 1) f_stream[IDXYZW(x, y + 1, z,     2)] = f_collide[IDxyzw(id, 2)];
    if (y > 0      ) f_stream[IDXYZW(x, y - 1, z,     4)] = f_collide[IDxyzw(id, 4)];
    if (z < DIM - 1) f_stream[IDXYZW(x, y,     z + 1, 6)] = f_collide[IDxyzw(id, 6)];
    if (z > 0      ) f_stream[IDXYZW(x, y,     z - 1, 5)] = f_collide[IDxyzw(id, 5)];

    if (y < DIM - 1 && z < DIM - 1) f_stream[IDXYZW(x, y + 1, z + 1, 16)] = f_collide[IDxyzw(id, 16)];
    if (y > 0       && z < DIM - 1) f_stream[IDXYZW(x, y - 1, z + 1, 18)] = f_collide[IDxyzw(id, 18)];
    if (y < DIM - 1 && z > 0      ) f_stream[IDXYZW(x, y + 1, z - 1, 12)] = f_collide[IDxyzw(id, 12)];
    if (y > 0       && z > 0      ) f_stream[IDXYZW(x, y - 1, z - 1, 14)] = f_collide[IDxyzw(id, 14)];

    // ->E Propagation
    if (x < DIM - 1) {
        // if (is_moving(cell_type)) {
        //     if (y < DIM - 1) f_stream[IDXYZW(x + 1, y + 1, z,      S_7)] = f_collide[IDxyzw(id,  7)];
        //     if (y > 0      ) f_stream[IDXYZW(x + 1, y - 1, z,     S_10)] = f_collide[IDxyzw(id, 10)];
        //     if (z > 0      ) f_stream[IDXYZW(x + 1, y,     z - 1, S_11)] = f_collide[IDxyzw(id, 11)];
        //     if (z < DIM - 1) f_stream[IDXYZW(x + 1, y,     z + 1, S_15)] = f_collide[IDxyzw(id, 15)];
        // } else {
                             f_stream[IDXYZW(x + 1, y,     z,      1)] = f_collide[IDxyzw(id,  1)];
            if (y < DIM - 1) f_stream[IDXYZW(x + 1, y + 1, z,      7)] = f_collide[IDxyzw(id,  7)];
            if (y > 0      ) f_stream[IDXYZW(x + 1, y - 1, z,     10)] = f_collide[IDxyzw(id, 10)];
            if (z < DIM - 1) f_stream[IDXYZW(x + 1, y,     z + 1, 15)] = f_collide[IDxyzw(id, 15)];
            if (z > 0      ) f_stream[IDXYZW(x + 1, y,     z - 1, 11)] = f_collide[IDxyzw(id, 11)];
        // }
    }

    // ->W Propagation
    if (x > 0) {
                         f_stream[IDXYZW(x - 1, y,     z,      3)] = f_collide[IDxyzw(id,  3)];
        if (y < DIM - 1) f_stream[IDXYZW(x - 1, y + 1, z,      8)] = f_collide[IDxyzw(id,  8)];
        if (y > 0      ) f_stream[IDXYZW(x - 1, y - 1, z,      9)] = f_collide[IDxyzw(id,  9)];
        if (z < DIM - 1) f_stream[IDXYZW(x - 1, y,     z + 1, 17)] = f_collide[IDxyzw(id, 17)];
        if (z > 0      ) f_stream[IDXYZW(x - 1, y,     z - 1, 13)] = f_collide[IDxyzw(id, 13)];
    }
#endif

#endif

    // barrier(CLK_GLOBAL_MEM_FENCE);
    // if (is_moving(cell_type)) {
    //     f_stream[IDxyzw(id,  5)] = 666.0f;
    //     f_stream[IDxyzw(id, 11)] = 666.0f;
    //     f_stream[IDxyzw(id, 12)] = 666.0f;
    //     f_stream[IDxyzw(id, 13)] = 666.0f;
    //     f_stream[IDxyzw(id, 14)] = 666.0f;
    // }

// #define IDXYZW(x, y, z, w)  (((x) + ((y) * DIM_X) + ((z) * DIM_X * DIM_Y)) * Q + (w))

//     barrier(CLK_GLOBAL_MEM_FENCE);
//     f_stream[IDXYZW(1, 1, 0, 13)] = NAN;
//     f_stream[IDXYZW(6, 1, 0, 11)] = NAN;
//     f_stream[IDXYZW(1, 6, 0, 13)] = NAN;
//     f_stream[IDXYZW(6, 6, 0, 11)] = NAN;
//     f_stream[IDXYZW(1, 0, 1,  9)] = NAN;
//     f_stream[IDXYZW(6, 0, 1, 10)] = NAN;
//     f_stream[IDXYZW(1, 7, 1,  8)] = NAN;
//     f_stream[IDXYZW(6, 7, 1,  7)] = NAN;

    // if (x == 2 && y == 1 && z == 1) {
    //     const int nx = x + E13_X;
    //     const int ny = y + E13_Y;
    //     const int nz = z + E13_Z;
    //     const int index = IDxyz(nx, ny, nz);
    //     f_stream[IDxyzw(index, 13)] = 100.0f;
    // }
}
