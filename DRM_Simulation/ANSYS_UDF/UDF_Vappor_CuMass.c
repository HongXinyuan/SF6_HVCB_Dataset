// Define x-direction mass source term
DEFINE_SOURCE(mass_vx_source, c, t, dS, eqn)
{
    real x[ND_ND];  
    C_CENTROID(x, c, t);  
    real x_lim = x[0];
    real y_lim = x[1];
    real z_lim = x[2];
    real pvap;
    real T_vap = 2835.0;   // Define evaporation temperature
    real L_vap = 3.6e5;    // Define latent heat
    real M_Cu = 0.063546;  // Define copper molecular weight
    real Pcu = C_P(c, t);  // Get cell pressure
    real T = C_T(c, t);    // Get cell temperature
    real source = 0.0;     
    real delta_t = CURRENT_TIMESTEP;  
    real nx = 0.0, ny = 0.0, nz = 0.0;
    pvap = exp(L_vap * (1.0 / T_vap - 1.0 / T) / 56.94);  
    real omiga = (pvap * M_Cu) / (pvap * M_Cu + (1.0 - pvap) * 0.14606);  
    real b = RP_Get_Real("flow-time");  

    if (b <= ***)      // The arc ignition time needs to be adjusted according to your settings in ANSYS
    {
        source = 0.0;  // If time is less than ***, source term is 0, this is a current-zero time
    }
    else {
        // Check if a point is in the top ablation region
        if (is_on_top_surface(x_lim, y_lim, z_lim))
        {
            // Get top surface normal direction
            get_top_surface_normal(x_lim, y_lim, z_lim, &nx, &ny, &nz);

            if (T >= T_vap)
            {
                source = (0.06 * 4.0 * 3.1415926 * net(T) / 4.6e6) * nx;  
            }
            else
            {
                source = (0.06 * 4.0 * 3.1415926 * net(T) / 4.6e6 - omiga * Pcu * M_Cu / (8.314 * T * delta_t)) * nx;  
            }
        }

        // Check if a point is in the side ablation region
        else if (is_on_side_surface(x_lim, y_lim, z_lim))
        {
            get_side_surface_normal(x_lim, y_lim, z_lim, &nx, &ny, &nz);

            if (T >= T_vap)
            {
                source = (0.06 * 4.0 * 3.1415926 * net(T) / 4.6e6) * nx; 
            }
            else
            {
                source = (0.06 * 4.0 * 3.1415926 * net(T) / 4.6e6 - omiga * Pcu * M_Cu / (8.314 * T * delta_t)) * nx;  
            }
        }
        else
        {
            source = 0.0;  
        }
    }

    dS[eqn] = 0.0;  
    return source;  
}

// Define y-direction mass source term
DEFINE_SOURCE(mass_vy_source, c, t, dS, eqn)
{
    real x[ND_ND];
    C_CENTROID(x, c, t);  
    real x_lim = x[0];
    real y_lim = x[1];
    real z_lim = x[2];
    real pvap;
    real T_vap = 2835.0;  
    real L_vap = 3.6e5;  
    real M_Cu = 0.063546; 
    real Pcu = C_P(c, t); 
    real T = C_T(c, t);  
    real source = 0.0;  
    real delta_t = CURRENT_TIMESTEP;  
    real nx = 0.0, ny = 0.0, nz = 0.0;
    pvap = exp(L_vap * (1.0 / T_vap - 1.0 / T) / 56.94);  
    real omiga = (pvap * M_Cu) / (pvap * M_Cu + (1.0 - pvap) * 0.14606);  
    real b = RP_Get_Real("flow-time"); 

    if (b <= ***)  // The arc ignition time needs to be adjusted according to your settings in ANSYS
    {
        source = 0.0;  
    }
    else {
        // Check if a point is in the top ablation region
        if (is_on_top_surface(x_lim, y_lim, z_lim))
        {
            // Get top surface normal direction
            get_top_surface_normal(x_lim, y_lim, z_lim, &nx, &ny, &nz);

            if (T >= T_vap)
            {
                source = (0.06 * 4.0 * 3.1415926 * net(T) / 4.6e6) * ny;  
            }
            else
            {
                source = (0.06 * 4.0 * 3.1415926 * net(T) / 4.6e6 - omiga * Pcu * M_Cu / (8.314 * T * delta_t)) * ny;  
            }
        }
        // Check if a point is in the side ablation region
        else if (is_on_side_surface(x_lim, y_lim, z_lim))
        {
            // Get side surface normal direction
            get_side_surface_normal(x_lim, y_lim, z_lim, &nx, &ny, &nz);

            if (T >= T_vap)
            {
                source = (0.06 * 4.0 * 3.1415926 * net(T) / 4.6e6) * ny;  
            }
            else
            {
                source = (0.06 * 4.0 * 3.1415926 * net(T) / 4.6e6 - omiga * Pcu * M_Cu / (8.314 * T * delta_t)) * ny;  
            }
        }
        else
        {
            source = 0.0;  
        }
    }

    dS[eqn] = 0.0;  
    return source;  
}

// Define z-direction mass source term
DEFINE_SOURCE(mass_vz_source, c, t, dS, eqn)
{
    real x[ND_ND];
    C_CENTROID(x, c, t);  
    real x_lim = x[0];
    real y_lim = x[1];
    real z_lim = x[2];
    real pvap;
    real T_vap = 2835.0;  
    real L_vap = 3.6e5; 
    real M_Cu = 0.063546;  
    real Pcu = C_P(c, t);  
    real T = C_T(c, t);  
    real source = 0.0;  
    real delta_t = CURRENT_TIMESTEP;  
    real nx = 0.0, ny = 0.0, nz = 0.0;
    pvap = exp(L_vap * (1.0 / T_vap - 1.0 / T) / 56.94);  
    real omiga = (pvap * M_Cu) / (pvap * M_Cu + (1.0 - pvap) * 0.14606); 
    real b = RP_Get_Real("flow-time");  // Get current flow time

    if (b <= ***)  // The arc ignition time needs to be adjusted according to your settings in ANSYS
    {
        source = 0.0; 
    }
    else {
        // Check if a point is in the top ablation region
        if (is_on_top_surface(x_lim, y_lim, z_lim))
        {
            // Get top surface normal direction
            get_top_surface_normal(x_lim, y_lim, z_lim, &nx, &ny, &nz);

            if (T >= T_vap)
            {
                source = (0.06 * 4.0 * 3.1415926 * net(T) / 4.6e6) * nz; 
            }
            else
            {
                source = (0.06 * 4.0 * 3.1415926 * net(T) / 4.6e6 - omiga * Pcu * M_Cu / (8.314 * T * delta_t)) * nz;  
            }
        }
        // Check if a point is in the side ablation region
        else if (is_on_side_surface(x_lim, y_lim, z_lim))
        {
            // Get side surface normal direction
            get_side_surface_normal(x_lim, y_lim, z_lim, &nx, &ny, &nz);

            if (T >= T_vap)
            {
                source = (0.06 * 4.0 * 3.1415926 * net(T) / 4.6e6) * nz; 
            }
            else
            {
                source = (0.06 * 4.0 * 3.1415926 * net(T) / 4.6e6 - omiga * Pcu * M_Cu / (8.314 * T * delta_t)) * nz; 
            }
        }
        else
        {
            source = 0.0;  
        }
    }

    dS[eqn] = 0.0; 
    return source;  
}

// Define mass source term
DEFINE_SOURCE(mass1, c, t, dS, eqn)
{
    real x[ND_ND];
    C_CENTROID(x, c, t);  
    real x_lim = x[0];
    real y_lim = x[1];
    real z_lim = x[2];
    real pvap;
    real T_vap = 2835.0;  
    real L_vap = 3.6e5;  
    real M_Cu = 0.063546;  
    real Pcu = C_P(c, t);  
    real T = C_T(c, t);  
    real source = 0.0;  
    real delta_t = CURRENT_TIMESTEP;  
    pvap = exp(L_vap * (1.0 / T_vap - 1.0 / T) / 56.94);  
    real omiga = (pvap * M_Cu) / (pvap * M_Cu + (1.0 - pvap) * 0.14606);  
    real b = RP_Get_Real("flow-time");  

    if (b <= ***)  // The arc ignition time needs to be adjusted according to your settings in ANSYS
    {
        source = 0.0;  
        C_UDMI(c, t, 31) = 0.0;  
        C_UDMI(c, t, 32) = 0.0; 
        C_UDMI(c, t, 33) = 0.0; 
    }
    else {
        // Check if a point is in the top ablation region
        if (is_on_top_surface(x_lim, y_lim, z_lim))
        {
            if (T >= T_vap)
            {
                source = 0.06 * 4.0 * 3.1415926 * net(T) / 4.6e6;            // Top surface evaporation source term
                C_UDMI(c, t, 31) = 0.06 * 4.0 * 3.1415926 * net(T) / 4.6e6;  // Store evaporation mass
                C_UDMI(c, t, 32) = 0.0;                                      // Condensation mass is 0
                C_UDMI(c, t, 33) = 0.06 * 4.0 * 3.1415926 * net(T) - omiga * Pcu * M_Cu / (8.314 * T * delta_t);
            }
            else
            {
                source = 0.06 * 4.0 * 3.1415926 * net(T) / 4.6e6 - omiga * Pcu * M_Cu / (8.314 * T * delta_t); 
                C_UDMI(c, t, 31) = 0.06 * 4.0 * 3.1415926 * net(T) / 4.6e6; 
                C_UDMI(c, t, 32) = -omiga * Pcu * M_Cu / (8.314 * T * delta_t); 
                C_UDMI(c, t, 33) = 0.06 * 4.0 * 3.1415926 * net(T) - omiga * Pcu * M_Cu / (8.314 * T * delta_t);
            }
        }
        // Check if a point is in the side ablation region
        else if (is_on_side_surface(x_lim, y_lim, z_lim))
        {
            if (T >= T_vap)
            {
                source = 0.06 * 4.0 * 3.1415926 * net(T) / 4.6e6;  
                C_UDMI(c, t, 31) = 0.06 * 4.0 * 3.1415926 * net(T) / 4.6e6;  
                C_UDMI(c, t, 32) = 0.0;  // Condensation mass is 0
                C_UDMI(c, t, 33) = 0.06 * 4.0 * 3.1415926 * net(T) - omiga * Pcu * M_Cu / (8.314 * T * delta_t);
            }
            else
            {
                source = 0.06 * 4.0 * 3.1415926 * net(T) / 4.6e6 - omiga * Pcu * M_Cu / (8.314 * T * delta_t);  
                C_UDMI(c, t, 31) = 0.06 * 4.0 * 3.1415926 * net(T) / 4.6e6;  
                C_UDMI(c, t, 32) = -omiga * Pcu * M_Cu / (8.314 * T * delta_t); 
                C_UDMI(c, t, 33) = 0.06 * 4.0 * 3.1415926 * net(T) - omiga * Pcu * M_Cu / (8.314 * T * delta_t);
            }
        }
        else
        {
            source = 0.0;  
            C_UDMI(c, t, 31) = 0.0;  
            C_UDMI(c, t, 32) = 0.0; 
            C_UDMI(c, t, 33) = 0.06 * 4.0 * 3.1415926 * net(T) - omiga * Pcu * M_Cu / (8.314 * T * delta_t);
        }
    }
    C_UDMI(c, t, 30) = source;  
    dS[eqn] = 0.0;  
    return source;  
}

// Define mass change function
DEFINE_PROFILE(mass_change, thread, position)
{
    face_t f;
    cell_t c0;
    Thread* t0;
    real b = RP_Get_Real("flow-time");  

    real x_lim, y_lim, z_lim;
    real T_vap = 2835.0;  
    real L_vap = 3.6e5;  
    real M_Cu = 0.063546;  
    real delta_t = CURRENT_TIMESTEP;  

    t0 = THREAD_T0(thread); 

    if (b <= ***)  // The arc ignition time needs to be adjusted according to your settings in ANSYS.
    {
        begin_f_loop(f, thread)
        {
            c0 = F_C0(f, thread);  
            real T = C_T(c0, t0); 
            C_UDMI(c0, t0, 33) = 0;  
            F_PROFILE(f, thread, position) = 0;  
        }
        end_f_loop(f, thread)
    }
    else
    {
        begin_f_loop(f, thread)
        {
            c0 = F_C0(f, thread); 
            real x[ND_ND];
            C_CENTROID(x, c0, t0);  
            x_lim = x[0];
            y_lim = x[1];
            z_lim = x[2];

            real Pcu = C_P(c0, t0); 
            real T = C_T(c0, t0); 
            real pvap = exp(L_vap * (1.0 / T_vap - 1.0 / T) / 56.94); 
            real omiga = (pvap * M_Cu) / (pvap * M_Cu + (1.0 - pvap) * 0.14606); 

            C_UDMI(c0, t0, 33) = 0.06 * 4.0 * 3.1415926 * net(T); 
            F_PROFILE(f, thread, position) = 0.06 * 4.0 * 3.1415926 * net(T) - omiga * Pcu * M_Cu / (8.314 * T * delta_t); 
        }
        end_f_loop(f, thread)
    }
}

// Define copper diffusivity function
DEFINE_DIFFUSIVITY(uds3_diff, c, t, i)
{
    real T = C_T(c, t); 
    real pp = C_P(c, t); 
    real dd;
    real midu;
    dd = (2.669e-8) * pow(T, 1.5) / (pp * sqrt(0.06355));  
    midu = C_R(c, t);

    return dd * midu; 
}

// Define copper generation function
DEFINE_EXECUTE_AT_END(CU_generate)
{
    Thread* t, * t1;
    face_t f;
    Domain* domain = Get_Domain(1);  
    int zone_ID = ***;  // Based on your settings in ANSYS  
    real Enrg_Source = 0;

    t = Lookup_Thread(domain, zone_ID);  
    begin_f_loop(f, t)
    {
        real x[ND_ND];
        C_CENTROID(x, F_C0(f, t), THREAD_T0(t)); 
        real x_lim = x[0];
        real y_lim = x[1];
        real z_lim = x[2];

        // Check if in ablation region
        if (is_on_top_surface(x_lim, y_lim, z_lim) || is_on_side_surface(x_lim, y_lim, z_lim))
        {
            if (C_T(F_C0(f, t), THREAD_T0(t)) > 2900)  // If temperature is greater than 2900
                C_UDMI(F_C0(f, t), THREAD_T0(t), 34) = 785 * exp(-1e8 / 8314.5 / C_T(F_C0(f, t), THREAD_T0(t)));  
            else
                C_UDMI(F_C0(f, t), THREAD_T0(t), 34) = 0;  // If temperature is less than 2900, copper generation amount is 0
        }
        else
        {
            C_UDMI(F_C0(f, t), THREAD_T0(t), 34) = 0;  // If not in ablation region, copper generation amount is 0
        }
    }
    end_f_loop(f, t)
}

// Define copper source term function
DEFINE_SOURCE(Cu_source, c, t, dS, eqn)
{
    real x[ND_ND];
    C_CENTROID(x, c, t);  // Get cell centroid coordinates
    real x_lim = x[0];
    real y_lim = x[1];
    real z_lim = x[2];

    // Check if in ablation region
    if (is_on_top_surface(x_lim, y_lim, z_lim) || is_on_side_surface(x_lim, y_lim, z_lim))
    {
        dS[eqn] = 0;  
        return C_UDMI(c, t, 34); 
    }
    else
    {
        dS[eqn] = 0; 
        return 0.0; 
    }
}
