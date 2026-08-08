// Initialization function, used to initialize variables in UDF
DEFINE_INIT(my_init_func, d)
{
    Thread* t;
    cell_t c;
    thread_loop_c(t, d)  
    {
        begin_c_loop(c, t)  
        {
            C_UDMI(c, t, 0) = 0;  // Initialize Jx to 0
            C_UDMI(c, t, 1) = 0;  // Initialize Jy to 0
            C_UDMI(c, t, 2) = 0;  // Initialize Jz to 0
            C_UDMI(c, t, 3) = 0;  // Initialize 3D current density magnitude to 0
        }
        end_c_loop(c, t)
    }
}

// Define enum type for UDS indexing
enum
{
    V, Ax0, Ay1, Az2, Cu, N_REQUIRED_UDS
};

// Define a piecewise function net for calculating physical quantities
real net(real x)
{
    real y;
    if (x < 2200)
        y = 0;
    else if (x < 3000)
        y = ((x - 2200) / (3000 - 2200)) * (116);
    else if (x < 10000)
        y = 116 + ((x - 3000) / (10000 - 3000)) * (6659322493.1116 - 116);
    else if (x < 20000)
        y = 6659322493.1116 + ((x - 10000) / (20000 - 10000)) * (133240605237.293 - 6659322493.1116);
    else if (x < 30000)
        y = 133240605237.293 + ((x - 20000) / (30000 - 20000)) * (788312642696.99 - 133240605237.293);
    else
        y = 788312642696.99 + 1.4e8 * (x - 30000);
    return y;
}

// Define diffusivity function for electrical conductivity
DEFINE_DIFFUSIVITY(uds0_diff, c, t, i)
{
    real T = C_T(c, t);  // Get cell temperature
    if (T <= 3000)
        sigma = 20;
    else if (T <= 4300)
        sigma = 25;
    else if (T <= 5000)
        sigma = 100;
    else if (T <= 6000)
        sigma = 442;
    else if (T <= 7000)
        sigma = 442 + ((T - 6000) / (7000 - 6000)) * (1360 - 442);
    else if (T <= 8000)
        sigma = 1360 + ((T - 7000) / (8000 - 7000)) * (2510 - 1360);
    else if (T <= 9000)
        sigma = 2510 + ((T - 8000) / (9000 - 8000)) * (3590 - 2510);
    else if (T <= 10000)
        sigma = 3590 + ((T - 9000) / (10000 - 9000)) * (4510 - 3590);
    else if (T <= 12000)
        sigma = 4510 + ((T - 10000) / (12000 - 10000)) * (6180 - 4510);
    else if (T <= 15000)
        sigma = 6180 + ((T - 12000) / (15000 - 12000)) * (8320 - 6180);
    else if (T <= 19000)
        sigma = 8320 + ((T - 15000) / (19000 - 15000)) * (11500 - 8320);
    else if (T <= 24000)
        sigma = 11500 + ((T - 19000) / (24000 - 19000)) * (14300 - 11500);
    else if (T <= 30000)
        sigma = 14300 + ((T - 19000) / (24000 - 19000)) * (16400 - 14300);
    else
        sigma = 16400 + 0.25 * (T - 30000);
    return sigma;
}

// Define x-direction velocity source term (3D Lorentz force)
DEFINE_SOURCE(x_velocity_source, cell, thread, dS, eqn)
{
    real source;
    real x[ND_ND];
    real Bx, By, Bz;

    // Calculate magnetic field components (B = ∇ × A)
    Bx = C_UDSI_G(cell, thread, Az2)[1] - C_UDSI_G(cell, thread, Ay1)[2];  // Bx = ∂Az/∂y - ∂Ay/∂z
    By = C_UDSI_G(cell, thread, Ax0)[2] - C_UDSI_G(cell, thread, Az2)[0];  // By = ∂Ax/∂z - ∂Az/∂x
    Bz = C_UDSI_G(cell, thread, Ay1)[0] - C_UDSI_G(cell, thread, Ax0)[1];  // Bz = ∂Ay/∂x - ∂Ax/∂y

    // Calculate current density components
    // Jx = -Sig * Vx;
    // Jy = -Sig * Vy;
    // Jz = -Sig * Vz;

    // 3D Lorentz force F = J × B
    Fx = Jy*Bz - Jz*By
    source = Jy * Bz - Jz * By;

    C_CENTROID(x, cell, thread);  
    dS[eqn] = 0;  
    C_UDMI(cell, thread, 22) = source;  
    return source;
}

// Define y-direction velocity source term
DEFINE_SOURCE(y_velocity_source, cell, thread, dS, eqn)
{
    real source;
    real x[ND_ND];
    real Bx, By, Bz;

    // Calculate magnetic field components
    Bx = C_UDSI_G(cell, thread, Az2)[1] - C_UDSI_G(cell, thread, Ay1)[2];
    By = C_UDSI_G(cell, thread, Ax0)[2] - C_UDSI_G(cell, thread, Az2)[0];
    Bz = C_UDSI_G(cell, thread, Ay1)[0] - C_UDSI_G(cell, thread, Ax0)[1];

    Fy = Jz*Bx - Jx*Bz
    source = Jz * Bx - Jx * Bz;

    C_CENTROID(x, cell, thread);
    dS[eqn] = 0;
    C_UDMI(cell, thread, 23) = source;
    return source;
}

// Define z-direction velocity source term (newly added)
DEFINE_SOURCE(z_velocity_source, cell, thread, dS, eqn)
{
    real source;
    real x[ND_ND];
    real Bx, By, Bz;

    // Calculate magnetic field components
    Bx = C_UDSI_G(cell, thread, Az2)[1] - C_UDSI_G(cell, thread, Ay1)[2];
    By = C_UDSI_G(cell, thread, Ax0)[2] - C_UDSI_G(cell, thread, Az2)[0];
    Bz = C_UDSI_G(cell, thread, Ay1)[0] - C_UDSI_G(cell, thread, Ax0)[1];

    Fz = Jx*By - Jy*Bx
    source = Jx * By - Jy * Bx;

    C_CENTROID(x, cell, thread);
    dS[eqn] = 0;

    C_UDMI(cell, thread, 28) = source;  
    return source;
}

// Define heat source term (3D version)
DEFINE_SOURCE(heat_source, cell, thread, dS, eqn)
{
    Domain* domain = Get_Domain(1);
    real source;
    real T = C_T(cell, thread);  
    real x[ND_ND];
    C_CENTROID(x, cell, thread); 
    
    // Calculate 3D current density
    C_UDMI(cell, thread, 0) = -C_UDSI_G(cell, thread, 0)[0] * Sig;  // Jx
    C_UDMI(cell, thread, 1) = -C_UDSI_G(cell, thread, 0)[1] * Sig;  // Jy  
    C_UDMI(cell, thread, 2) = -C_UDSI_G(cell, thread, 0)[2] * Sig;  // Jz (newly added)

    // 3D current density magnitude
    C_UDMI(cell, thread, 3) = sqrt(C_UDMI(cell, thread, 0) * C_UDMI(cell, thread, 0) +
        C_UDMI(cell, thread, 1) * C_UDMI(cell, thread, 1) +
        C_UDMI(cell, thread, 2) * C_UDMI(cell, thread, 2));

    // Ohmic heating source term
    source = C_UDMI(cell, thread, 3) * C_UDMI(cell, thread, 3) / Sig - 4. * 3.1415926 * net(T);

    dS[eqn] = 0;  
    
    // 3D electric field strength calculation
    C_UDMI(cell, thread, 16) = sqrt(C_UDSI_G(cell, thread, 0)[0] * C_UDSI_G(cell, thread, 0)[0] +
        C_UDSI_G(cell, thread, 0)[1] * C_UDSI_G(cell, thread, 0)[1] +
        C_UDSI_G(cell, thread, 0)[2] * C_UDSI_G(cell, thread, 0)[2]);

    C_UDMI(cell, thread, 24) = 4. * 3.1415926 * net(T);

    // 3D critical breakdown field strength calculation
    C_UDMI(cell, thread, 26) = sqrt(C_UDSI_G(cell, thread, 3)[0] * C_UDSI_G(cell, thread, 3)[0] +
        C_UDSI_G(cell, thread, 3)[1] * C_UDSI_G(cell, thread, 3)[1] +
        C_UDSI_G(cell, thread, 3)[2] * C_UDSI_G(cell, thread, 3)[2]);

    C_UDMI(cell, thread, 27) = 1167 * C_R(cell, thread) / C_UDMI(cell, thread, 26);

    // 3D electric field distribution
    C_UDMI(cell, thread, 60) = sqrt(C_UDSI_G(cell, thread, 0)[0] * C_UDSI_G(cell, thread, 0)[0] +
        C_UDSI_G(cell, thread, 0)[1] * C_UDSI_G(cell, thread, 0)[1] +
        C_UDSI_G(cell, thread, 0)[2] * C_UDSI_G(cell, thread, 0)[2]);

    C_UDMI(cell, thread, 25) = source;

    return source;
}

// Define x-direction magnetic potential source term
DEFINE_SOURCE(Ax_source, cell, thread, dS, eqn)
{
    real source;
    real x[ND_ND];
    C_CENTROID(x, cell, thread);  

    Jx = -Sig * Vx;  
    source = Mu * Jx;  
    dS[eqn] = 0;  
    return source;
}

// Define y-direction magnetic potential source term
DEFINE_SOURCE(Ay_source, cell, thread, dS, eqn)
{
    real source, r, x[ND_ND];
    C_CENTROID(x, cell, thread);  

    Jy = -Sig * Vy;  
    source = Mu * Jy;  
    dS[eqn] = 0;  
    return source;
}

// Define z-direction magnetic potential source term (newly added)
DEFINE_SOURCE(Az_source, cell, thread, dS, eqn)
{
    real source, r, x[ND_ND];
    C_CENTROID(x, cell, thread);  

    Jz = -Sig * Vz;  
    source = Mu * Jz;  
    dS[eqn] = 0;  
    return source;
}
