#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif

uniform sampler2D fields_current;

uniform vec2 resolution;
uniform float dt;
uniform float t;
varying float vX;
varying float vY;

uniform float usePeriodic;
uniform float useGhosts;

// Mouse interaction uniforms
uniform int u_mouseActive;
uniform vec2 u_mousePos;
uniform vec2 u_mouseVel;
uniform float u_mouseRadius;

// Compressible fluid parameters
const float gamma = 1.4; // Ratio of specific heats (air)
const float dx = 1.0; // Grid spacing (normalized)

// Spherical boundary parameters
const vec2 sphereCenter = vec2(0.2, 0.5); // Center of domain
const float sphereRadius = 0.071;

// Wrap texture coordinates for periodic boundaries
vec2 wrap(vec2 coord) {
    return fract(coord);
}

// Minmod slope limiter (prevents oscillations)
float minmod(float a, float b) {
    if (a * b <= 0.0) return 0.0; // Different signs or one is zero
    if (abs(a) < abs(b)) return a;
    return b;
}

// Apply minmod limiter to each component of a vec4
vec4 limitSlope(vec4 left, vec4 center, vec4 right) {
    vec4 slopeLeft = center - left;
    vec4 slopeRight = right - center;

    return vec4(
        minmod(slopeLeft.x, slopeRight.x),
        minmod(slopeLeft.y, slopeRight.y),
        minmod(slopeLeft.z, slopeRight.z),
        minmod(slopeLeft.w, slopeRight.w)
    );
}

// Calculate pressure from conserved variables
// p = (gamma - 1) * (E - 1/2 * rho * u^2)
float calculatePressure(float rho, vec2 m, float E) {
    float kineticEnergy = dot(m,m)/(2.0*(rho + 1e-10));
    return (gamma - 1.0) * (E - kineticEnergy);
}

// Calculate flux vector for conserved variables
// State: [rho, mx, my, E]
// Flux: [rho*u, rho*u*u + p, rho*u*v, u*(E + p)]
vec4 calculateFlux(vec4 state, bool xDirection) {
    float rho = state.x;
    vec2 m = state.yz;
    float E = state.w;

    // Calculate velocity
    vec2 u = m / (rho + 1e-10); 

    // Calculate pressure
    float p = calculatePressure(rho, m, E);
    
    vec4 flux;
    if (xDirection) {
        // Flux in x-direction
        flux.x = rho * u.x;
        flux.y = rho * u.x * u.x + p;
        flux.z = rho * u.x * u.y;
        flux.w = u.x * (E + p);
    } else {
        // Flux in y-direction
        flux.x = rho * u.y;
        flux.y = rho * u.y * u.x;
        flux.z = rho * u.y * u.y + p;
        flux.w = u.y * (E + p);
    }

    return flux;
}

// Lax-Friedrichs flux at cell edges with wave-speed-based diffusion
vec4 laxFriedrichsFlux(vec4 stateLeft, vec4 stateRight, bool xDirection) {
    vec4 fluxLeft = calculateFlux(stateLeft, xDirection);
    vec4 fluxRight = calculateFlux(stateRight, xDirection);

    // Extract conserved variables
    float rhoL = stateLeft.x;
    float rhoR = stateRight.x;
    vec2 mL = stateLeft.yz;
    vec2 mR = stateRight.yz;
    float EL = stateLeft.w;
    float ER = stateRight.w;

    // Calculate pressures
    float pL = calculatePressure(rhoL, mL, EL);
    float pR = calculatePressure(rhoR, mR, ER);

    // Calculate speeds of sound: c = sqrt(gamma * p / rho)
    float cL = sqrt(gamma * max(pL, 0.01) / (rhoL + 1e-10));
    float cR = sqrt(gamma * max(pR, 0.01) / (rhoR + 1e-10));

    // Calculate velocities
    vec2 uL = mL / (rhoL + 1e-10);
    vec2 uR = mR / (rhoR + 1e-10);

    // Maximum characteristic speed (eigenvalue)
    float speedL = (xDirection ? abs(uL.x) : abs(uL.y)) + cL;
    float speedR = (xDirection ? abs(uR.x) : abs(uR.y)) + cR;
    float maxSpeed = max(speedL, speedR);

    // Lax-Friedrichs flux with wave-speed-based diffusion
    vec4 avgFlux = 0.5 * (fluxLeft + fluxRight);
    vec4 diffusion = 0.5 * maxSpeed * (stateRight - stateLeft);

    return avgFlux - diffusion;
}

void main() {
    vec2 texCoord = (vec2(vX, vY) + 1.0) / 2.0;
    vec2 Step = 1.0 / resolution;

    // Sample current state and neighbors with wrapping (default for periodic)
    vec4 U_C = texture2D(fields_current, wrap(texCoord));
    vec4 U_R = texture2D(fields_current, wrap(texCoord + vec2(Step.x, 0.0)));
    vec4 U_L = texture2D(fields_current, wrap(texCoord - vec2(Step.x, 0.0)));
    vec4 U_T = texture2D(fields_current, wrap(texCoord + vec2(0.0, Step.y)));
    vec4 U_D = texture2D(fields_current, wrap(texCoord - vec2(0.0, Step.y)));

    // Extended stencil
    vec4 U_RR = texture2D(fields_current, wrap(texCoord + vec2(2.0 * Step.x, 0.0)));
    vec4 U_LL = texture2D(fields_current, wrap(texCoord - vec2(2.0 * Step.x, 0.0)));
    vec4 U_TT = texture2D(fields_current, wrap(texCoord + vec2(0.0, 2.0 * Step.y)));
    vec4 U_DD = texture2D(fields_current, wrap(texCoord - vec2(0.0, 2.0 * Step.y)));

    // Calculate ramped inflow parameters
    float t_rampup = 6000.0;
    float targetVelocity = 0.5;
    float currentInflowVelocity = targetVelocity * min(t / t_rampup, 1.0);
    
    // Define inflow state variables for reuse
    float rho_inflow = 1.0;
    float p_inflow = 1.0;
    vec2 u_inflow = vec2(currentInflowVelocity, 0.0);
    
    // Add small vertical perturbation to inflow to trigger vortex shedding
    if (t > t_rampup) {
        float perturbAmplitude = 0.09 * currentInflowVelocity;
        float perturbFrequency = 0.5;
        u_inflow.y = perturbAmplitude * sin(perturbFrequency * t + texCoord.y * 6.28);
    }
    
    vec2 m_inflow = rho_inflow * u_inflow;
    float E_inflow = p_inflow / (gamma - 1.0) + 0.5 * rho_inflow * dot(u_inflow, u_inflow);
    vec4 U_inflow_state = vec4(rho_inflow, m_inflow, E_inflow);

    // ==================== BOUNDARY CONDITIONS (GHOST CELLS) ====================
    // If we are not using periodic boundaries, we modify the neighbors (ghosts)
    // to enforce open/inflow boundaries.
    if (useGhosts > 0.5){
        
        // --- LEFT BOUNDARY (Inflow) ---
        if (texCoord.x < Step.x * 4.5){
            // Force the left neighbor to be the fixed inflow state
            U_L = U_inflow_state;
            U_LL = U_inflow_state; 
        }

        // --- RIGHT BOUNDARY (Outflow) ---
        if (texCoord.x > 1.0 - Step.x * 4.5){
            // Zero-order extrapolation (Continuative Boundary)
            // We copy the current cell's state into the ghost cells.
            // This allows waves to propagate out without reflection.
            U_R = U_C;
            U_RR = U_C;
        }

        // --- BOTTOM BOUNDARY (Slip/Outflow) ---
        if (texCoord.y < Step.y * 4.5){
            // Continuative Boundary. 
            // By copying U_C to U_D, we allow vertical momentum to carry mass out.
            U_D = U_C;
            U_DD = U_C;
        }

        // --- TOP BOUNDARY (Slip/Outflow) ---
        if (texCoord.y > 1.0 - Step.y * 4.5){
            // Continuative Boundary.
            U_T = U_C;
            U_TT = U_C;
        }
    }

    // ==================== MUSCL RECONSTRUCTION ====================
    
    // X-direction reconstruction
    vec4 slope_C_x = limitSlope(U_L, U_C, U_R);
    vec4 slope_R_x = limitSlope(U_C, U_R, U_RR);
    vec4 slope_L_x = limitSlope(U_LL, U_L, U_C);

    vec4 U_right_L = U_C + 0.5 * slope_C_x;
    vec4 U_right_R = U_R - 0.5 * slope_R_x;
    vec4 U_left_L = U_L + 0.5 * slope_L_x;
    vec4 U_left_R = U_C - 0.5 * slope_C_x;

    // Y-direction reconstruction
    vec4 slope_C_y = limitSlope(U_D, U_C, U_T);
    vec4 slope_T_y = limitSlope(U_C, U_T, U_TT);
    vec4 slope_D_y = limitSlope(U_DD, U_D, U_C);

    vec4 U_top_L = U_C + 0.5 * slope_C_y;
    vec4 U_top_R = U_T - 0.5 * slope_T_y;
    vec4 U_bottom_L = U_D + 0.5 * slope_D_y;
    vec4 U_bottom_R = U_C - 0.5 * slope_C_y;

    // Compute fluxes
    vec4 F_right = laxFriedrichsFlux(U_right_L, U_right_R, true);
    vec4 F_left = laxFriedrichsFlux(U_left_L, U_left_R, true);
    vec4 F_top = laxFriedrichsFlux(U_top_L, U_top_R, false);
    vec4 F_bottom = laxFriedrichsFlux(U_bottom_L, U_bottom_R, false);

    // Update state
    vec4 U_new = U_C - (dt / dx) * (F_right - F_left + F_top - F_bottom);

    // ==================== INTERACTION & CLAMPING ====================

    // Mouse interaction
    if (u_mouseActive == 1) {
        vec2 toMouse = texCoord - u_mousePos;
        float distSq = dot(toMouse, toMouse);
        float sigma = u_mouseRadius * 0.5;
        float sigmaSq = sigma * sigma;
        float gaussian = exp(-distSq / (2.0 * sigmaSq));

        vec2 forceMomentum = u_mouseVel * gaussian * 1.0 * U_new.x;
        U_new.yz += dt * forceMomentum;

        vec2 m = U_new.yz;
        float rho = U_new.x;
        float kineticEnergy = dot(m,m)/(2.0*(rho + 1e-10));
        float p = calculatePressure(U_new.x, U_new.yz, U_new.w);
        U_new.w = p / (gamma - 1.0) + kineticEnergy;
    }

    // Clamp density/energy to prevent NaNs
    U_new.x = max(U_new.x, 0.01);
    U_new.w = max(U_new.w, 0.01);

    // ==================== FINAL BOUNDARY ENFORCEMENT ====================
    
    // 1. Spherical Internal Obstacle
    vec2 toCenter = (texCoord - sphereCenter) * resolution/resolution.y ;
    float distToCenter = length(toCenter);

    if (distToCenter < sphereRadius) {
        vec2 normal = normalize(toCenter);
        vec2 velocity = U_new.yz / (U_new.x + 1e-10);
        float vDotN = dot(velocity, normal);
        if (vDotN < 0.0) {
            vec2 velocityReflected = velocity - 2.0 * vDotN * normal;
            U_new.yz = U_new.x * velocityReflected;
        }
    }

    // 2. Inflow Enforcement (Left Wall)
    // We strictly overwrite the pixels at the very left edge to ensure 
    // the inflow condition remains constant and isn't eroded by numerical diffusion.
    if (usePeriodic < 0.5) {
        if (texCoord.x < Step.x * 1.5) {
            U_new = U_inflow_state;
        }
        // NOTE: Top, Bottom, and Right clamps have been removed.
        // The ghost cell logic above handles the outflow.
    }

    gl_FragColor = U_new;
}