// Define geometric parameters (Unit: meters)
// The electrode dimensions used in this work should based on the actual dimensions employed in your application. 
// Since this part involves confidential information, the electrode size parameters (in our research) have been intentionally obscured. 
// All other aspects of the model, including the algorithm and the melt pool modeling approach, are fully disclosed without concealment.

#define TOP_X         ***              
#define TOP_RADIUS    ***           

#define BOTTOM_X      ***          
#define BOTTOM_RADIUS ***        

#define ARC_CENTER_X  ***      
#define ARC_CENTER_Y  ***         
#define ARC_RADIUS    ***           
#define THETA_MIN     ***              
#define THETA_MAX     ***             

// Ablation region thickness parameters
#define SURFACE_THICKNESS 0.0001    // Ablation surface thickness (0.1mm)

#define TOP_SURFACE_MIN_X (TOP_X - SURFACE_THICKNESS/2.0)     
#define TOP_SURFACE_MAX_X (TOP_X + SURFACE_THICKNESS/2.0)    

// UDM variable definitions
#define delta_m C_UDMI(c,t,30)      // Stores copper vapor generation rate for the current time step
#define mass_plus C_UDMI(c,t,31)    // Store ablation generation term
#define mass_minus C_UDMI(c,t,32)   // Store condensation consumption term

static real cumulative_mass = 0.0;  // Define cumulative mass

// Auxiliary function: Check if a point is in the top ablation region
static int is_on_top_surface(real x, real y, real z)
{
    real r = sqrt(y * y + z * z);   // Distance to X-axis
    int result = 0;

    if (x >= TOP_SURFACE_MIN_X && x <= TOP_SURFACE_MAX_X && r <= TOP_RADIUS)
        result = 1;

    return result;
}

// Auxiliary function: Check if a point is in the side ablation region
static int is_on_side_surface(real x, real y, real z)
{
    real r = sqrt(y * y + z * z);

    real dx = x - ARC_CENTER_X;
    real dr = r - ARC_CENTER_Y;
    real distance_to_arc_center = sqrt(dx * dx + dr * dr);

    int is_near_arc = 0;
    if (fabs(distance_to_arc_center - ARC_RADIUS) <= SURFACE_THICKNESS)
        is_near_arc = 1;

    int is_in_axial_range = 0;
    if (x >= BOTTOM_X && x <= TOP_X)
        is_in_axial_range = 1;

    int is_in_radial_range = 0;
    if (r >= ARC_CENTER_Y && r <= BOTTOM_RADIUS)
        is_in_radial_range = 1;

    return (is_near_arc && is_in_axial_range && is_in_radial_range);
}

// Auxiliary function: Calculate normal direction of a point on the side surface
static void get_side_surface_normal(real x, real y, real z, real* nx, real* ny, real* nz)
{
    real r = sqrt(y * y + z * z);

    real dx = x - ARC_CENTER_X;
    real dr = r - ARC_CENTER_Y;
    real norm = sqrt(dx * dx + dr * dr);

    if (norm > 0.0) {
        *nx = dx / norm;

        if (r > 0.0) {
            *ny = dr * (y / r) / norm;
            *nz = dr * (z / r) / norm;
        }
        else {
            *ny = 0.0;
            *nz = dr / norm;  
        }
    }
    else {
        *nx = 1.0;
        *ny = 0.0;
        *nz = 0.0;
    }
}

// Auxiliary function: Calculate top surface normal direction (always along positive X-axis)
static void get_top_surface_normal(real x, real y, real z, real* nx, real* ny, real* nz)
{
    *nx = 1.0;  // Top surface normal along positive X-axis
    *ny = 0.0;
    *nz = 0.0;
}
