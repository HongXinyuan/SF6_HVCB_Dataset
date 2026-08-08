#include "udf.h"  
#include "sg_udms.h"  
#include "mem.h"  
#include "math.h"  

/* Basic Constants */
#define epsion 8.854e-12  // Define vacuum permittivity
#define w 0.5             // Define relaxation factor
#define Wk 28             // Define gas molecular weight
#define R 8.31451         // Define universal gas constant
#define L 3.06e5          // Define latent heat
#define Tvap 2835         // Define evaporation temperature
#define EpsionRelative 1  // Define relative permittivity
#define Kb 1.38e-23       // Define Boltzmann constant (original definition, no error)
#define e 1.6e-19         // Define elementary charge
#define pi 3.141592653    // Define pi

real sigma = 0;           // Define electrical conductivity, initialized to 0

#define Bt C_UDMI(cell,thread,4)       // Define magnetic field strength (Tesla)
#define Rad C_UDMI(cell,thread,5)      // Define radiation power
#define Ohm C_UDMI(cell,thread,6)      // Define ohmic heating power
#define Lw C_UDMI(cell,thread,7)       // Define Lorentz force work power
#define Jx C_UDMI(cell,thread,10)      // Define x-direction current density (A/m^2)
#define Jy C_UDMI(cell,thread,11)      // Define y-direction current density (A/m^2)
#define Jz C_UDMI(cell,thread,12)      // Define z-direction current density (A/m^2)
#define J C_UDMI(cell,thread,13)       // Define current density (A/m^2)
#define S C_UDMI(cell,thread,14)       // Define a custom variable
#define Vcell C_UDMI(cell,thread,15)   // Define cell volume
#define Phicu C_UDMI(cell,thread,16)   // Define copper potential

#define Ax C_UDSI(cell,thread,Ax0)     // Define x-direction magnetic vector potential
#define Ay C_UDSI(cell,thread,Ay1)     // Define y-direction magnetic vector potential
#define Az C_UDSI(cell,thread,Az2)     // Define z-direction magnetic vector potential
#define Cumass C_UDSI(cell,thread,Cu)  // Define copper mass

// 3D gradient definitions
#define Vx C_UDSI_G(cell,thread,V)[0]  // Define x-direction potential gradient (electric field vector x-direction)
#define Vy C_UDSI_G(cell,thread,V)[1]  // Define y-direction potential gradient (electric field vector y-direction)
#define Vz C_UDSI_G(cell,thread,V)[2]  // Define z-direction potential gradient (electric field vector z-direction)

#define Sig C_UDSI_DIFF(cell,thread,0) // Define electrical conductivity
#define Mu 4*3.1415927e-7              // Define magnetic permeability
#define P (C_P(cell,thread)+101325.0)/101325  // Define pressure
#define M2 40                 // Define a constant
#define M1 2                  // Define a constant
#define e_charge  1.602e-19   // Define electron charge (original definition, no error)
#define kB  1.38e-23          // Define Boltzmann constant (original definition, no error)
#define A 3.0e+4              // Define a constant
#define phi_e 2.63            // Define a constant
#define phi_c 4.52            // Define a constant
#define m_e 9.1e-31           // Define electron mass
#define epsilon 0.35          // Define a constant
#define alpha 5.6705e-8       // Define Stefan-Boltzmann constant
#define Vi 15.68              // Define a constant
#define Vd 20                 // Define a constant
real v = 0.1;                 // Define a variable, initialized to 0.1