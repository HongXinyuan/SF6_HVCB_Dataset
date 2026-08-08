//   Breaker opening phase-angle data table

//   No. Conditions       1        2        3        4        5        6        7
//   1	 252 kV,  40 kA  -122.61
//   2	 252 kV,  40 kA  -121.37  -29.84   -33.41   -30.56
//   3	 72.5 kV, 40 kA  -60.92   -57.18   -64.21
//   4	 72.5 kV, 40 kA  -118.23  -56.47   -63.76
//   5	 72.5 kV, 40 kA  -64.02   -56.86   -63.11   -54.29   -62.47
//   6	 72.5 kV, 40 kA  -117.81  -57.58   -120.45  -65.64   -60.29
//   7	 72.5 kV, 40 kA  -123.11  -115.72  -121.94  -124.56  -66.21   -55.17   -58.76
//   8	 72.5 kV, 40 kA  -123.88  -61.24   -122.17  -57.93   -59.26   -56.03   -61.87


#define PI 3.1415926
#define FREQ 50.0                            // Frequency
#define OMEGA (2.0 * PI * FREQ)              // Angular frequency
#define CURRENT_RMS 40000000.0               // Current intensity: 40 kA
#define CURRENT_PEAK (CURRENT_RMS * 1.414)   // Peak current
#define BASE_PHASE_RAD 0                     // Fixed initial phase offset
#define END_TIME 0.05                        // Simulation end time

/* BASE_PHASE_RAD is kept as 0.0 by default. If you need delayed current injection, modify this in the corresponding UDF */
/*    T_START     is kept as 0.0 by default. If you need delayed current injection, modify this in the corresponding UDF */
/* Case 1 | 252 kV, 40 kA | Phase angle = -122.61 deg */
DEFINE_PROFILE(current_change_01, thread, position)
{
    face_t f;
    cell_t c0;
    Thread *t0;
    real i0;
    real b = RP_Get_Real("flow-time");
    const real T_START = 0.0;
    const real phase_angle_deg = -122.61;
    const real phase_angle_rad = phase_angle_deg * PI / 180.0;

    if (b <= T_START)
    {
        i0 = 0.0;
    }
    else if (b <= END_TIME)
    {
        i0 = CURRENT_PEAK * sin(OMEGA * (b - T_START) + BASE_PHASE_RAD + phase_angle_rad);
    }
    else
    {
        i0 = 0.0;
    }

    t0 = THREAD_T0(thread);

    begin_f_loop(f, thread)
    {
        c0 = F_C0(f, thread);
        C_UDMI(c0, t0, 27) = i0;
        F_PROFILE(f, thread, position) = i0;
    }
    end_f_loop(f, thread)
}

/* Case 2 | 252 kV, 40 kA | Phase angle = -121.37 deg */
DEFINE_PROFILE(current_change_02, thread, position)
{
    face_t f;
    cell_t c0;
    Thread *t0;
    real i0;
    real b = RP_Get_Real("flow-time");
    const real T_START = 0.0;
    const real phase_angle_deg = -121.37;
    const real phase_angle_rad = phase_angle_deg * PI / 180.0;

    if (b <= T_START)
    {
        i0 = 0.0;
    }
    else if (b <= END_TIME)
    {
        i0 = CURRENT_PEAK * sin(OMEGA * (b - T_START) + BASE_PHASE_RAD + phase_angle_rad);
    }
    else
    {
        i0 = 0.0;
    }

    t0 = THREAD_T0(thread);

    begin_f_loop(f, thread)
    {
        c0 = F_C0(f, thread);
        C_UDMI(c0, t0, 27) = i0;
        F_PROFILE(f, thread, position) = i0;
    }
    end_f_loop(f, thread)
}

/* Case 2 | 252 kV, 40 kA | Phase angle = -29.84 deg */
DEFINE_PROFILE(current_change_03, thread, position)
{
    face_t f;
    cell_t c0;
    Thread *t0;
    real i0;
    real b = RP_Get_Real("flow-time");
    const real T_START = 0.0;
    const real phase_angle_deg = -29.84;
    const real phase_angle_rad = phase_angle_deg * PI / 180.0;

    if (b <= T_START)
    {
        i0 = 0.0;
    }
    else if (b <= END_TIME)
    {
        i0 = CURRENT_PEAK * sin(OMEGA * (b - T_START) + BASE_PHASE_RAD + phase_angle_rad);
    }
    else
    {
        i0 = 0.0;
    }

    t0 = THREAD_T0(thread);

    begin_f_loop(f, thread)
    {
        c0 = F_C0(f, thread);
        C_UDMI(c0, t0, 27) = i0;
        F_PROFILE(f, thread, position) = i0;
    }
    end_f_loop(f, thread)
}

/* Case 2 | 252 kV, 40 kA | Phase angle = -33.41 deg */
DEFINE_PROFILE(current_change_04, thread, position)
{
    face_t f;
    cell_t c0;
    Thread *t0;
    real i0;
    real b = RP_Get_Real("flow-time");
    const real T_START = 0.0;
    const real phase_angle_deg = -33.41;
    const real phase_angle_rad = phase_angle_deg * PI / 180.0;

    if (b <= T_START)
    {
        i0 = 0.0;
    }
    else if (b <= END_TIME)
    {
        i0 = CURRENT_PEAK * sin(OMEGA * (b - T_START) + BASE_PHASE_RAD + phase_angle_rad);
    }
    else
    {
        i0 = 0.0;
    }

    t0 = THREAD_T0(thread);

    begin_f_loop(f, thread)
    {
        c0 = F_C0(f, thread);
        C_UDMI(c0, t0, 27) = i0;
        F_PROFILE(f, thread, position) = i0;
    }
    end_f_loop(f, thread)
}

/* Case 2 | 252 kV, 40 kA | Phase angle = -30.56 deg */
DEFINE_PROFILE(current_change_05, thread, position)
{
    face_t f;
    cell_t c0;
    Thread *t0;
    real i0;
    real b = RP_Get_Real("flow-time");
    const real T_START = 0.0;
    const real phase_angle_deg = -30.56;
    const real phase_angle_rad = phase_angle_deg * PI / 180.0;

    if (b <= T_START)
    {
        i0 = 0.0;
    }
    else if (b <= END_TIME)
    {
        i0 = CURRENT_PEAK * sin(OMEGA * (b - T_START) + BASE_PHASE_RAD + phase_angle_rad);
    }
    else
    {
        i0 = 0.0;
    }

    t0 = THREAD_T0(thread);

    begin_f_loop(f, thread)
    {
        c0 = F_C0(f, thread);
        C_UDMI(c0, t0, 27) = i0;
        F_PROFILE(f, thread, position) = i0;
    }
    end_f_loop(f, thread)
}

/* Case 3 | 72.5 kV, 40 kA | Phase angle = -60.92 deg */
DEFINE_PROFILE(current_change_06, thread, position)
{
    face_t f;
    cell_t c0;
    Thread *t0;
    real i0;
    real b = RP_Get_Real("flow-time");
    const real T_START = 0.0;
    const real phase_angle_deg = -60.92;
    const real phase_angle_rad = phase_angle_deg * PI / 180.0;

    if (b <= T_START)
    {
        i0 = 0.0;
    }
    else if (b <= END_TIME)
    {
        i0 = CURRENT_PEAK * sin(OMEGA * (b - T_START) + BASE_PHASE_RAD + phase_angle_rad);
    }
    else
    {
        i0 = 0.0;
    }

    t0 = THREAD_T0(thread);

    begin_f_loop(f, thread)
    {
        c0 = F_C0(f, thread);
        C_UDMI(c0, t0, 27) = i0;
        F_PROFILE(f, thread, position) = i0;
    }
    end_f_loop(f, thread)
}

/* Case 3 | 72.5 kV, 40 kA | Phase angle = -57.18 deg */
DEFINE_PROFILE(current_change_07, thread, position)
{
    face_t f;
    cell_t c0;
    Thread *t0;
    real i0;
    real b = RP_Get_Real("flow-time");
    const real T_START = 0.0;
    const real phase_angle_deg = -57.18;
    const real phase_angle_rad = phase_angle_deg * PI / 180.0;

    if (b <= T_START)
    {
        i0 = 0.0;
    }
    else if (b <= END_TIME)
    {
        i0 = CURRENT_PEAK * sin(OMEGA * (b - T_START) + BASE_PHASE_RAD + phase_angle_rad);
    }
    else
    {
        i0 = 0.0;
    }

    t0 = THREAD_T0(thread);

    begin_f_loop(f, thread)
    {
        c0 = F_C0(f, thread);
        C_UDMI(c0, t0, 27) = i0;
        F_PROFILE(f, thread, position) = i0;
    }
    end_f_loop(f, thread)
}

/* Case 3 | 72.5 kV, 40 kA | Phase angle = -64.21 deg */
DEFINE_PROFILE(current_change_08, thread, position)
{
    face_t f;
    cell_t c0;
    Thread *t0;
    real i0;
    real b = RP_Get_Real("flow-time");
    const real T_START = 0.0;
    const real phase_angle_deg = -64.21;
    const real phase_angle_rad = phase_angle_deg * PI / 180.0;

    if (b <= T_START)
    {
        i0 = 0.0;
    }
    else if (b <= END_TIME)
    {
        i0 = CURRENT_PEAK * sin(OMEGA * (b - T_START) + BASE_PHASE_RAD + phase_angle_rad);
    }
    else
    {
        i0 = 0.0;
    }

    t0 = THREAD_T0(thread);

    begin_f_loop(f, thread)
    {
        c0 = F_C0(f, thread);
        C_UDMI(c0, t0, 27) = i0;
        F_PROFILE(f, thread, position) = i0;
    }
    end_f_loop(f, thread)
}

/* Case 4 | 72.5 kV, 40 kA | Phase angle = -118.23 deg */
DEFINE_PROFILE(current_change_09, thread, position)
{
    face_t f;
    cell_t c0;
    Thread *t0;
    real i0;
    real b = RP_Get_Real("flow-time");
    const real T_START = 0.0;
    const real phase_angle_deg = -118.23;
    const real phase_angle_rad = phase_angle_deg * PI / 180.0;

    if (b <= T_START)
    {
        i0 = 0.0;
    }
    else if (b <= END_TIME)
    {
        i0 = CURRENT_PEAK * sin(OMEGA * (b - T_START) + BASE_PHASE_RAD + phase_angle_rad);
    }
    else
    {
        i0 = 0.0;
    }

    t0 = THREAD_T0(thread);

    begin_f_loop(f, thread)
    {
        c0 = F_C0(f, thread);
        C_UDMI(c0, t0, 27) = i0;
        F_PROFILE(f, thread, position) = i0;
    }
    end_f_loop(f, thread)
}

/* Case 4 | 72.5 kV, 40 kA | Phase angle = -56.47 deg */
DEFINE_PROFILE(current_change_10, thread, position)
{
    face_t f;
    cell_t c0;
    Thread *t0;
    real i0;
    real b = RP_Get_Real("flow-time");
    const real T_START = 0.0;
    const real phase_angle_deg = -56.47;
    const real phase_angle_rad = phase_angle_deg * PI / 180.0;

    if (b <= T_START)
    {
        i0 = 0.0;
    }
    else if (b <= END_TIME)
    {
        i0 = CURRENT_PEAK * sin(OMEGA * (b - T_START) + BASE_PHASE_RAD + phase_angle_rad);
    }
    else
    {
        i0 = 0.0;
    }

    t0 = THREAD_T0(thread);

    begin_f_loop(f, thread)
    {
        c0 = F_C0(f, thread);
        C_UDMI(c0, t0, 27) = i0;
        F_PROFILE(f, thread, position) = i0;
    }
    end_f_loop(f, thread)
}

/* Case 4 | 72.5 kV, 40 kA | Phase angle = -63.76 deg */
DEFINE_PROFILE(current_change_11, thread, position)
{
    face_t f;
    cell_t c0;
    Thread *t0;
    real i0;
    real b = RP_Get_Real("flow-time");
    const real T_START = 0.0;
    const real phase_angle_deg = -63.76;
    const real phase_angle_rad = phase_angle_deg * PI / 180.0;

    if (b <= T_START)
    {
        i0 = 0.0;
    }
    else if (b <= END_TIME)
    {
        i0 = CURRENT_PEAK * sin(OMEGA * (b - T_START) + BASE_PHASE_RAD + phase_angle_rad);
    }
    else
    {
        i0 = 0.0;
    }

    t0 = THREAD_T0(thread);

    begin_f_loop(f, thread)
    {
        c0 = F_C0(f, thread);
        C_UDMI(c0, t0, 27) = i0;
        F_PROFILE(f, thread, position) = i0;
    }
    end_f_loop(f, thread)
}

/* Case 5 | 72.5 kV, 40 kA | Phase angle = -64.02 deg */
DEFINE_PROFILE(current_change_12, thread, position)
{
    face_t f;
    cell_t c0;
    Thread *t0;
    real i0;
    real b = RP_Get_Real("flow-time");
    const real T_START = 0.0;
    const real phase_angle_deg = -64.02;
    const real phase_angle_rad = phase_angle_deg * PI / 180.0;

    if (b <= T_START)
    {
        i0 = 0.0;
    }
    else if (b <= END_TIME)
    {
        i0 = CURRENT_PEAK * sin(OMEGA * (b - T_START) + BASE_PHASE_RAD + phase_angle_rad);
    }
    else
    {
        i0 = 0.0;
    }

    t0 = THREAD_T0(thread);

    begin_f_loop(f, thread)
    {
        c0 = F_C0(f, thread);
        C_UDMI(c0, t0, 27) = i0;
        F_PROFILE(f, thread, position) = i0;
    }
    end_f_loop(f, thread)
}

/* Case 5 | 72.5 kV, 40 kA | Phase angle = -56.86 deg */
DEFINE_PROFILE(current_change_13, thread, position)
{
    face_t f;
    cell_t c0;
    Thread *t0;
    real i0;
    real b = RP_Get_Real("flow-time");
    const real T_START = 0.0;
    const real phase_angle_deg = -56.86;
    const real phase_angle_rad = phase_angle_deg * PI / 180.0;

    if (b <= T_START)
    {
        i0 = 0.0;
    }
    else if (b <= END_TIME)
    {
        i0 = CURRENT_PEAK * sin(OMEGA * (b - T_START) + BASE_PHASE_RAD + phase_angle_rad);
    }
    else
    {
        i0 = 0.0;
    }

    t0 = THREAD_T0(thread);

    begin_f_loop(f, thread)
    {
        c0 = F_C0(f, thread);
        C_UDMI(c0, t0, 27) = i0;
        F_PROFILE(f, thread, position) = i0;
    }
    end_f_loop(f, thread)
}

/* Case 5 | 72.5 kV, 40 kA | Phase angle = -63.11 deg */
DEFINE_PROFILE(current_change_14, thread, position)
{
    face_t f;
    cell_t c0;
    Thread *t0;
    real i0;
    real b = RP_Get_Real("flow-time");
    const real T_START = 0.0;
    const real phase_angle_deg = -63.11;
    const real phase_angle_rad = phase_angle_deg * PI / 180.0;

    if (b <= T_START)
    {
        i0 = 0.0;
    }
    else if (b <= END_TIME)
    {
        i0 = CURRENT_PEAK * sin(OMEGA * (b - T_START) + BASE_PHASE_RAD + phase_angle_rad);
    }
    else
    {
        i0 = 0.0;
    }

    t0 = THREAD_T0(thread);

    begin_f_loop(f, thread)
    {
        c0 = F_C0(f, thread);
        C_UDMI(c0, t0, 27) = i0;
        F_PROFILE(f, thread, position) = i0;
    }
    end_f_loop(f, thread)
}

/* Case 5 | 72.5 kV, 40 kA | Phase angle = -54.29 deg */
DEFINE_PROFILE(current_change_15, thread, position)
{
    face_t f;
    cell_t c0;
    Thread *t0;
    real i0;
    real b = RP_Get_Real("flow-time");
    const real T_START = 0.0;
    const real phase_angle_deg = -54.29;
    const real phase_angle_rad = phase_angle_deg * PI / 180.0;

    if (b <= T_START)
    {
        i0 = 0.0;
    }
    else if (b <= END_TIME)
    {
        i0 = CURRENT_PEAK * sin(OMEGA * (b - T_START) + BASE_PHASE_RAD + phase_angle_rad);
    }
    else
    {
        i0 = 0.0;
    }

    t0 = THREAD_T0(thread);

    begin_f_loop(f, thread)
    {
        c0 = F_C0(f, thread);
        C_UDMI(c0, t0, 27) = i0;
        F_PROFILE(f, thread, position) = i0;
    }
    end_f_loop(f, thread)
}

/* Case 5 | 72.5 kV, 40 kA | Phase angle = -62.47 deg */
DEFINE_PROFILE(current_change_16, thread, position)
{
    face_t f;
    cell_t c0;
    Thread *t0;
    real i0;
    real b = RP_Get_Real("flow-time");
    const real T_START = 0.0;
    const real phase_angle_deg = -62.47;
    const real phase_angle_rad = phase_angle_deg * PI / 180.0;

    if (b <= T_START)
    {
        i0 = 0.0;
    }
    else if (b <= END_TIME)
    {
        i0 = CURRENT_PEAK * sin(OMEGA * (b - T_START) + BASE_PHASE_RAD + phase_angle_rad);
    }
    else
    {
        i0 = 0.0;
    }

    t0 = THREAD_T0(thread);

    begin_f_loop(f, thread)
    {
        c0 = F_C0(f, thread);
        C_UDMI(c0, t0, 27) = i0;
        F_PROFILE(f, thread, position) = i0;
    }
    end_f_loop(f, thread)
}

/* Case 6 | 72.5 kV, 40 kA | Phase angle = -117.81 deg */
DEFINE_PROFILE(current_change_17, thread, position)
{
    face_t f;
    cell_t c0;
    Thread *t0;
    real i0;
    real b = RP_Get_Real("flow-time");
    const real T_START = 0.0;
    const real phase_angle_deg = -117.81;
    const real phase_angle_rad = phase_angle_deg * PI / 180.0;

    if (b <= T_START)
    {
        i0 = 0.0;
    }
    else if (b <= END_TIME)
    {
        i0 = CURRENT_PEAK * sin(OMEGA * (b - T_START) + BASE_PHASE_RAD + phase_angle_rad);
    }
    else
    {
        i0 = 0.0;
    }

    t0 = THREAD_T0(thread);

    begin_f_loop(f, thread)
    {
        c0 = F_C0(f, thread);
        C_UDMI(c0, t0, 27) = i0;
        F_PROFILE(f, thread, position) = i0;
    }
    end_f_loop(f, thread)
}

/* Case 6 | 72.5 kV, 40 kA | Phase angle = -57.58 deg */
DEFINE_PROFILE(current_change_18, thread, position)
{
    face_t f;
    cell_t c0;
    Thread *t0;
    real i0;
    real b = RP_Get_Real("flow-time");
    const real T_START = 0.0;
    const real phase_angle_deg = -57.58;
    const real phase_angle_rad = phase_angle_deg * PI / 180.0;

    if (b <= T_START)
    {
        i0 = 0.0;
    }
    else if (b <= END_TIME)
    {
        i0 = CURRENT_PEAK * sin(OMEGA * (b - T_START) + BASE_PHASE_RAD + phase_angle_rad);
    }
    else
    {
        i0 = 0.0;
    }

    t0 = THREAD_T0(thread);

    begin_f_loop(f, thread)
    {
        c0 = F_C0(f, thread);
        C_UDMI(c0, t0, 27) = i0;
        F_PROFILE(f, thread, position) = i0;
    }
    end_f_loop(f, thread)
}

/* Case 6 | 72.5 kV, 40 kA | Phase angle = -120.45 deg */
DEFINE_PROFILE(current_change_19, thread, position)
{
    face_t f;
    cell_t c0;
    Thread *t0;
    real i0;
    real b = RP_Get_Real("flow-time");
    const real T_START = 0.0;
    const real phase_angle_deg = -120.45;
    const real phase_angle_rad = phase_angle_deg * PI / 180.0;

    if (b <= T_START)
    {
        i0 = 0.0;
    }
    else if (b <= END_TIME)
    {
        i0 = CURRENT_PEAK * sin(OMEGA * (b - T_START) + BASE_PHASE_RAD + phase_angle_rad);
    }
    else
    {
        i0 = 0.0;
    }

    t0 = THREAD_T0(thread);

    begin_f_loop(f, thread)
    {
        c0 = F_C0(f, thread);
        C_UDMI(c0, t0, 27) = i0;
        F_PROFILE(f, thread, position) = i0;
    }
    end_f_loop(f, thread)
}

/* Case 6 | 72.5 kV, 40 kA | Phase angle = -65.64 deg */
DEFINE_PROFILE(current_change_20, thread, position)
{
    face_t f;
    cell_t c0;
    Thread *t0;
    real i0;
    real b = RP_Get_Real("flow-time");
    const real T_START = 0.0;
    const real phase_angle_deg = -65.64;
    const real phase_angle_rad = phase_angle_deg * PI / 180.0;

    if (b <= T_START)
    {
        i0 = 0.0;
    }
    else if (b <= END_TIME)
    {
        i0 = CURRENT_PEAK * sin(OMEGA * (b - T_START) + BASE_PHASE_RAD + phase_angle_rad);
    }
    else
    {
        i0 = 0.0;
    }

    t0 = THREAD_T0(thread);

    begin_f_loop(f, thread)
    {
        c0 = F_C0(f, thread);
        C_UDMI(c0, t0, 27) = i0;
        F_PROFILE(f, thread, position) = i0;
    }
    end_f_loop(f, thread)
}

/* Case 6 | 72.5 kV, 40 kA | Phase angle = -60.29 deg */
DEFINE_PROFILE(current_change_21, thread, position)
{
    face_t f;
    cell_t c0;
    Thread *t0;
    real i0;
    real b = RP_Get_Real("flow-time");
    const real T_START = 0.0;
    const real phase_angle_deg = -60.29;
    const real phase_angle_rad = phase_angle_deg * PI / 180.0;

    if (b <= T_START)
    {
        i0 = 0.0;
    }
    else if (b <= END_TIME)
    {
        i0 = CURRENT_PEAK * sin(OMEGA * (b - T_START) + BASE_PHASE_RAD + phase_angle_rad);
    }
    else
    {
        i0 = 0.0;
    }

    t0 = THREAD_T0(thread);

    begin_f_loop(f, thread)
    {
        c0 = F_C0(f, thread);
        C_UDMI(c0, t0, 27) = i0;
        F_PROFILE(f, thread, position) = i0;
    }
    end_f_loop(f, thread)
}

/* Case 7 | 72.5 kV, 40 kA | Phase angle = -123.11 deg */
DEFINE_PROFILE(current_change_22, thread, position)
{
    face_t f;
    cell_t c0;
    Thread *t0;
    real i0;
    real b = RP_Get_Real("flow-time");
    const real T_START = 0.0;
    const real phase_angle_deg = -123.11;
    const real phase_angle_rad = phase_angle_deg * PI / 180.0;

    if (b <= T_START)
    {
        i0 = 0.0;
    }
    else if (b <= END_TIME)
    {
        i0 = CURRENT_PEAK * sin(OMEGA * (b - T_START) + BASE_PHASE_RAD + phase_angle_rad);
    }
    else
    {
        i0 = 0.0;
    }

    t0 = THREAD_T0(thread);

    begin_f_loop(f, thread)
    {
        c0 = F_C0(f, thread);
        C_UDMI(c0, t0, 27) = i0;
        F_PROFILE(f, thread, position) = i0;
    }
    end_f_loop(f, thread)
}

/* Case 7 | 72.5 kV, 40 kA | Phase angle = -115.72 deg */
DEFINE_PROFILE(current_change_23, thread, position)
{
    face_t f;
    cell_t c0;
    Thread *t0;
    real i0;
    real b = RP_Get_Real("flow-time");
    const real T_START = 0.0;
    const real phase_angle_deg = -115.72;
    const real phase_angle_rad = phase_angle_deg * PI / 180.0;

    if (b <= T_START)
    {
        i0 = 0.0;
    }
    else if (b <= END_TIME)
    {
        i0 = CURRENT_PEAK * sin(OMEGA * (b - T_START) + BASE_PHASE_RAD + phase_angle_rad);
    }
    else
    {
        i0 = 0.0;
    }

    t0 = THREAD_T0(thread);

    begin_f_loop(f, thread)
    {
        c0 = F_C0(f, thread);
        C_UDMI(c0, t0, 27) = i0;
        F_PROFILE(f, thread, position) = i0;
    }
    end_f_loop(f, thread)
}

/* Case 7 | 72.5 kV, 40 kA | Phase angle = -121.94 deg */
DEFINE_PROFILE(current_change_24, thread, position)
{
    face_t f;
    cell_t c0;
    Thread *t0;
    real i0;
    real b = RP_Get_Real("flow-time");
    const real T_START = 0.0;
    const real phase_angle_deg = -121.94;
    const real phase_angle_rad = phase_angle_deg * PI / 180.0;

    if (b <= T_START)
    {
        i0 = 0.0;
    }
    else if (b <= END_TIME)
    {
        i0 = CURRENT_PEAK * sin(OMEGA * (b - T_START) + BASE_PHASE_RAD + phase_angle_rad);
    }
    else
    {
        i0 = 0.0;
    }

    t0 = THREAD_T0(thread);

    begin_f_loop(f, thread)
    {
        c0 = F_C0(f, thread);
        C_UDMI(c0, t0, 27) = i0;
        F_PROFILE(f, thread, position) = i0;
    }
    end_f_loop(f, thread)
}

/* Case 7 | 72.5 kV, 40 kA | Phase angle = -124.56 deg */
DEFINE_PROFILE(current_change_25, thread, position)
{
    face_t f;
    cell_t c0;
    Thread *t0;
    real i0;
    real b = RP_Get_Real("flow-time");
    const real T_START = 0.0;
    const real phase_angle_deg = -124.56;
    const real phase_angle_rad = phase_angle_deg * PI / 180.0;

    if (b <= T_START)
    {
        i0 = 0.0;
    }
    else if (b <= END_TIME)
    {
        i0 = CURRENT_PEAK * sin(OMEGA * (b - T_START) + BASE_PHASE_RAD + phase_angle_rad);
    }
    else
    {
        i0 = 0.0;
    }

    t0 = THREAD_T0(thread);

    begin_f_loop(f, thread)
    {
        c0 = F_C0(f, thread);
        C_UDMI(c0, t0, 27) = i0;
        F_PROFILE(f, thread, position) = i0;
    }
    end_f_loop(f, thread)
}

/* Case 7 | 72.5 kV, 40 kA | Phase angle = -66.21 deg */
DEFINE_PROFILE(current_change_26, thread, position)
{
    face_t f;
    cell_t c0;
    Thread *t0;
    real i0;
    real b = RP_Get_Real("flow-time");
    const real T_START = 0.0;
    const real phase_angle_deg = -66.21;
    const real phase_angle_rad = phase_angle_deg * PI / 180.0;

    if (b <= T_START)
    {
        i0 = 0.0;
    }
    else if (b <= END_TIME)
    {
        i0 = CURRENT_PEAK * sin(OMEGA * (b - T_START) + BASE_PHASE_RAD + phase_angle_rad);
    }
    else
    {
        i0 = 0.0;
    }

    t0 = THREAD_T0(thread);

    begin_f_loop(f, thread)
    {
        c0 = F_C0(f, thread);
        C_UDMI(c0, t0, 27) = i0;
        F_PROFILE(f, thread, position) = i0;
    }
    end_f_loop(f, thread)
}

/* Case 7 | 72.5 kV, 40 kA | Phase angle = -55.17 deg */
DEFINE_PROFILE(current_change_27, thread, position)
{
    face_t f;
    cell_t c0;
    Thread *t0;
    real i0;
    real b = RP_Get_Real("flow-time");
    const real T_START = 0.0;
    const real phase_angle_deg = -55.17;
    const real phase_angle_rad = phase_angle_deg * PI / 180.0;

    if (b <= T_START)
    {
        i0 = 0.0;
    }
    else if (b <= END_TIME)
    {
        i0 = CURRENT_PEAK * sin(OMEGA * (b - T_START) + BASE_PHASE_RAD + phase_angle_rad);
    }
    else
    {
        i0 = 0.0;
    }

    t0 = THREAD_T0(thread);

    begin_f_loop(f, thread)
    {
        c0 = F_C0(f, thread);
        C_UDMI(c0, t0, 27) = i0;
        F_PROFILE(f, thread, position) = i0;
    }
    end_f_loop(f, thread)
}

/* Case 7 | 72.5 kV, 40 kA | Phase angle = -58.76 deg */
DEFINE_PROFILE(current_change_28, thread, position)
{
    face_t f;
    cell_t c0;
    Thread *t0;
    real i0;
    real b = RP_Get_Real("flow-time");
    const real T_START = 0.0;
    const real phase_angle_deg = -58.76;
    const real phase_angle_rad = phase_angle_deg * PI / 180.0;

    if (b <= T_START)
    {
        i0 = 0.0;
    }
    else if (b <= END_TIME)
    {
        i0 = CURRENT_PEAK * sin(OMEGA * (b - T_START) + BASE_PHASE_RAD + phase_angle_rad);
    }
    else
    {
        i0 = 0.0;
    }

    t0 = THREAD_T0(thread);

    begin_f_loop(f, thread)
    {
        c0 = F_C0(f, thread);
        C_UDMI(c0, t0, 27) = i0;
        F_PROFILE(f, thread, position) = i0;
    }
    end_f_loop(f, thread)
}

/* Case 8 | 72.5 kV, 40 kA | Phase angle = -123.88 deg */
DEFINE_PROFILE(current_change_29, thread, position)
{
    face_t f;
    cell_t c0;
    Thread *t0;
    real i0;
    real b = RP_Get_Real("flow-time");
    const real T_START = 0.0;
    const real phase_angle_deg = -123.88;
    const real phase_angle_rad = phase_angle_deg * PI / 180.0;

    if (b <= T_START)
    {
        i0 = 0.0;
    }
    else if (b <= END_TIME)
    {
        i0 = CURRENT_PEAK * sin(OMEGA * (b - T_START) + BASE_PHASE_RAD + phase_angle_rad);
    }
    else
    {
        i0 = 0.0;
    }

    t0 = THREAD_T0(thread);

    begin_f_loop(f, thread)
    {
        c0 = F_C0(f, thread);
        C_UDMI(c0, t0, 27) = i0;
        F_PROFILE(f, thread, position) = i0;
    }
    end_f_loop(f, thread)
}

/* Case 8 | 72.5 kV, 40 kA | Phase angle = -61.24 deg */
DEFINE_PROFILE(current_change_30, thread, position)
{
    face_t f;
    cell_t c0;
    Thread *t0;
    real i0;
    real b = RP_Get_Real("flow-time");
    const real T_START = 0.0;
    const real phase_angle_deg = -61.24;
    const real phase_angle_rad = phase_angle_deg * PI / 180.0;

    if (b <= T_START)
    {
        i0 = 0.0;
    }
    else if (b <= END_TIME)
    {
        i0 = CURRENT_PEAK * sin(OMEGA * (b - T_START) + BASE_PHASE_RAD + phase_angle_rad);
    }
    else
    {
        i0 = 0.0;
    }

    t0 = THREAD_T0(thread);

    begin_f_loop(f, thread)
    {
        c0 = F_C0(f, thread);
        C_UDMI(c0, t0, 27) = i0;
        F_PROFILE(f, thread, position) = i0;
    }
    end_f_loop(f, thread)
}

/* Case 8 | 72.5 kV, 40 kA | Phase angle = -122.17 deg */
DEFINE_PROFILE(current_change_31, thread, position)
{
    face_t f;
    cell_t c0;
    Thread *t0;
    real i0;
    real b = RP_Get_Real("flow-time");
    const real T_START = 0.0;
    const real phase_angle_deg = -122.17;
    const real phase_angle_rad = phase_angle_deg * PI / 180.0;

    if (b <= T_START)
    {
        i0 = 0.0;
    }
    else if (b <= END_TIME)
    {
        i0 = CURRENT_PEAK * sin(OMEGA * (b - T_START) + BASE_PHASE_RAD + phase_angle_rad);
    }
    else
    {
        i0 = 0.0;
    }

    t0 = THREAD_T0(thread);

    begin_f_loop(f, thread)
    {
        c0 = F_C0(f, thread);
        C_UDMI(c0, t0, 27) = i0;
        F_PROFILE(f, thread, position) = i0;
    }
    end_f_loop(f, thread)
}

/* Case 8 | 72.5 kV, 40 kA | Phase angle = -57.93 deg */
DEFINE_PROFILE(current_change_32, thread, position)
{
    face_t f;
    cell_t c0;
    Thread *t0;
    real i0;
    real b = RP_Get_Real("flow-time");
    const real T_START = 0.0;
    const real phase_angle_deg = -57.93;
    const real phase_angle_rad = phase_angle_deg * PI / 180.0;

    if (b <= T_START)
    {
        i0 = 0.0;
    }
    else if (b <= END_TIME)
    {
        i0 = CURRENT_PEAK * sin(OMEGA * (b - T_START) + BASE_PHASE_RAD + phase_angle_rad);
    }
    else
    {
        i0 = 0.0;
    }

    t0 = THREAD_T0(thread);

    begin_f_loop(f, thread)
    {
        c0 = F_C0(f, thread);
        C_UDMI(c0, t0, 27) = i0;
        F_PROFILE(f, thread, position) = i0;
    }
    end_f_loop(f, thread)
}

/* Case 8 | 72.5 kV, 40 kA | Phase angle = -59.26 deg */
DEFINE_PROFILE(current_change_33, thread, position)
{
    face_t f;
    cell_t c0;
    Thread *t0;
    real i0;
    real b = RP_Get_Real("flow-time");
    const real T_START = 0.0;
    const real phase_angle_deg = -59.26;
    const real phase_angle_rad = phase_angle_deg * PI / 180.0;

    if (b <= T_START)
    {
        i0 = 0.0;
    }
    else if (b <= END_TIME)
    {
        i0 = CURRENT_PEAK * sin(OMEGA * (b - T_START) + BASE_PHASE_RAD + phase_angle_rad);
    }
    else
    {
        i0 = 0.0;
    }

    t0 = THREAD_T0(thread);

    begin_f_loop(f, thread)
    {
        c0 = F_C0(f, thread);
        C_UDMI(c0, t0, 27) = i0;
        F_PROFILE(f, thread, position) = i0;
    }
    end_f_loop(f, thread)
}

/* Case 8 | 72.5 kV, 40 kA | Phase angle = -56.03 deg */
DEFINE_PROFILE(current_change_34, thread, position)
{
    face_t f;
    cell_t c0;
    Thread *t0;
    real i0;
    real b = RP_Get_Real("flow-time");
    const real T_START = 0.0;
    const real phase_angle_deg = -56.03;
    const real phase_angle_rad = phase_angle_deg * PI / 180.0;

    if (b <= T_START)
    {
        i0 = 0.0;
    }
    else if (b <= END_TIME)
    {
        i0 = CURRENT_PEAK * sin(OMEGA * (b - T_START) + BASE_PHASE_RAD + phase_angle_rad);
    }
    else
    {
        i0 = 0.0;
    }

    t0 = THREAD_T0(thread);

    begin_f_loop(f, thread)
    {
        c0 = F_C0(f, thread);
        C_UDMI(c0, t0, 27) = i0;
        F_PROFILE(f, thread, position) = i0;
    }
    end_f_loop(f, thread)
}

/* Case 8 | 72.5 kV, 40 kA | Phase angle = -61.87 deg */
DEFINE_PROFILE(current_change_35, thread, position)
{
    face_t f;
    cell_t c0;
    Thread *t0;
    real i0;
    real b = RP_Get_Real("flow-time");
    const real T_START = 0.0;
    const real phase_angle_deg = -61.87;
    const real phase_angle_rad = phase_angle_deg * PI / 180.0;

    if (b <= T_START)
    {
        i0 = 0.0;
    }
    else if (b <= END_TIME)
    {
        i0 = CURRENT_PEAK * sin(OMEGA * (b - T_START) + BASE_PHASE_RAD + phase_angle_rad);
    }
    else
    {
        i0 = 0.0;
    }

    t0 = THREAD_T0(thread);

    begin_f_loop(f, thread)
    {
        c0 = F_C0(f, thread);
        C_UDMI(c0, t0, 27) = i0;
        F_PROFILE(f, thread, position) = i0;
    }
    end_f_loop(f, thread)
}
