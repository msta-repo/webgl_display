#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif

uniform sampler2D fields_current;
uniform sampler2D fields_previous;
uniform vec2 resolution;
uniform float dt;
uniform float D;
uniform float t;

varying float vX;
varying float vY;

void main() {
    vec2 texCoord = (vec2(vX, vY) + 1.0) / 2.0;
    vec2 Step = 1.0 / resolution;
    
    // Algorithm constants
    vec2 CScale = 1.0 / (2.0 * Step); // Central finite difference scale: 1/(2*dx), 1/(2*dy)
    float K = 0.0002;                    // Density-invariant pressure constant
    float v = 0.5*0.0005;                    // Kinematic viscosity
    //float v = 0.0;                    // Kinematic viscosity
    float S = K / dt;                 // Pressure gradient scale
    
    // Sample current state and neighbors
    vec4 FC = texture2D(fields_current, texCoord);  // Center: (u, v, density, w)
    vec4 FC_prev = texture2D(fields_previous, texCoord);

    vec4 FC_init = FC;

    vec3 FR = texture2D(fields_current, texCoord + vec2(Step.x, 0.0)).xyz;  // Right
    vec3 FL = texture2D(fields_current, texCoord - vec2(Step.x, 0.0)).xyz;  // Left
    vec3 FT = texture2D(fields_current, texCoord + vec2(0.0, Step.y)).xyz;  // Top
    vec3 FD = texture2D(fields_current, texCoord - vec2(0.0, Step.y)).xyz;  // Down
    
    // ==================== COMPUTE SPATIAL DERIVATIVES ====================
    // Central finite differences: (du/dx, dv/dx, drho/dx)
    vec3 diffX = (FR - FL) /(2.0*Step.x);
    // Central finite differences: (du/dy, dv/dy, drho/dy)
    vec3 diffY = (FT - FD) /(2.0*Step.y);
    
    // Velocity divergence: div(u) = du/dx + dv/dy
    float div_u = diffX.x + diffY.y;
    
    // Density gradient: ∇rho = (drho/dx, drho/dy)
    // UdX.z = drho/dx, UdY.z = drho/dy
    vec2 grad_rho = vec2(diffX.z, diffY.z);
    
    // ==================== SOLVE MASS CONSERVATION ====================
    // drho/dt = -u·∇rho - rho*div(u)
    //FC.z -= dt * dot(vec3(DdX, Udiv), FC.xyz);
    //FC.z += - dt * (dot(FC.xy, grad_rho) + FC.z*div_u);

    FC.z -= dt*dot(vec3(grad_rho, div_u), FC.xyz);

    // Clamp density for stability
    FC.z = clamp(FC.z, 0.5, 3.0);
    
    // ==================== SOLVE MOMENTUM CONSERVATION ====================
    // Pressure gradient from density-invariant field: ∇P = K∇rho
    vec2 PdX = S * grad_rho;
    
    // Laplacian for viscosity: ∇²u
    //vec2 Laplacian_u = ((FR.xy + FL.xy + FT.xy + FD.xy) - 4.0 * FC.xy)/(Step*Step);
    vec2 Laplacian_u = ((FR.xy + FL.xy) / (Step.x * Step.x) + (FT.xy + FD.xy) / (Step.y * Step.y) - 4.0 * FC.xy * (1.0/(Step.x*Step.x) + 1.0/(Step.y*Step.y)));

    vec2 ViscosityForce = v * Laplacian_u;
    
    // Semi-Lagrangian advection: trace backward in time
    vec2 Was = texCoord - dt * FC.xy*Step;
    FC.xy = texture2D(fields_current, Was).xy;
    
    // Apply forces: viscosity, pressure, and external forces
    vec2 ExternalForces = vec2(0.0, 0.0001);  // Add custom forces here
    FC.xy += dt * (ViscosityForce - PdX + ExternalForces);

   // FC.xy += dt*(ViscosityForce),

    //FC.xy += dt*(- PdX);


    // boundary consitions

    // hard walls
    if (texCoord.x< Step.x*2.0){
        FC.x = 0.0;
    }

    if (texCoord.x> 1.0 -  Step.x*2.0){
        FC.x = 0.0;
    }

    if (texCoord.y< Step.y*2.0){
        FC.y = 0.0;
    }

    if (texCoord.y> 1.0 -  Step.y*2.0){
        FC.y = 0.0;
    }



    gl_FragColor = FC;

    
}
