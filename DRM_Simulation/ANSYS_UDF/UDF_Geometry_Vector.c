// Define constants
#define E_ACT 1e8          
#define R_GAS 8314.5       
#define RHO_CU 8920.0      
#define T_CRIT 2900.0      

DEFINE_GRID_MOTION(ablation_deformation, domain, dt, time, dtime)
{
    Thread* tf = DT_THREAD(dt);

    face_t f;
    Node* v;
    int n;

    real temp;
    real ablation_rate;
    real displacement;
    real NV_VEC(normal);
    real mag_area;

    /* --- Step 1: Initialize node markers --- */
    // Before directly modifying node coordinates in dynamic mesh, it's recommended to traverse and reset markers first
    // Note: In parallel computing, node markers might need special handling; this is the basic version for serial logic
    begin_f_loop(f, tf)
    {
        f_node_loop(f, tf, n)
        {
            v = F_NODE(f, tf, n);
            NODE_MARK(v) = 0;
        }
    }
    end_f_loop(f, tf)

        /* --- Step 2: Calculate displacement and move --- */
        begin_f_loop(f, tf)
    {
        temp = F_T(f, tf);

        if (temp > T_CRIT)
        {
            // Calculate displacement
            ablation_rate = (A_PRE * exp(-E_ACT / (R_GAS * temp))) / RHO_CU;
            displacement = ablation_rate * dtime;

            // Get normal vector
            F_AREA(normal, f, tf);
            mag_area = NV_MAG(normal);

            if (mag_area > 1e-12) // Prevent division by zero
            {
                NV_VS(normal, =, normal, / , mag_area);
            }
            else
            {
                NV_D(normal, =, 0.0, 0.0, 0.0);
            }

            f_node_loop(f, tf, n)
            {
                v = F_NODE(f, tf, n);

                if (NODE_MARK(v) == 0)
                {
                    // Update node coordinates
                    NODE_X(v) += displacement * normal[0];
                    NODE_Y(v) += displacement * normal[1];
                    NODE_Z(v) += displacement * normal[2];

                    NODE_MARK(v) = 1;
                }
            }
        }
    }
    end_f_loop(f, tf)
}