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

// Mouse interaction uniforms
uniform int u_mouseActive;
uniform vec2 u_mousePos;
uniform vec2 u_mouseVel;
uniform float u_mouseRadius;

// Compressible fluid parameters
const float gamma = 1.4; // Ratio of specific heats (air)
const float dx = 1.0; // Grid spacing (normalized)

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

    //float kineticEnergy = 0.5 * rho * dot(u, u);
    float kineticEnergy = dot(m,m)/(2.0*(rho + 1E-10));

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
    vec2 u = m / (rho + 1e-10); // Add small epsilon to avoid division by zero

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

    // Sample current state and neighbors with wrapping
    // State: [rho, momentum_x, momentum_y, total_energy]
    vec4 U_C = texture2D(fields_current, wrap(texCoord));
    vec4 U_R = texture2D(fields_current, wrap(texCoord + vec2(Step.x, 0.0)));
    vec4 U_L = texture2D(fields_current, wrap(texCoord - vec2(Step.x, 0.0)));
    vec4 U_T = texture2D(fields_current, wrap(texCoord + vec2(0.0, Step.y)));
    vec4 U_D = texture2D(fields_current, wrap(texCoord - vec2(0.0, Step.y)));

    // Extended stencil for slope limiting
    vec4 U_RR = texture2D(fields_current, wrap(texCoord + vec2(2.0 * Step.x, 0.0)));
    vec4 U_LL = texture2D(fields_current, wrap(texCoord - vec2(2.0 * Step.x, 0.0)));
    vec4 U_TT = texture2D(fields_current, wrap(texCoord + vec2(0.0, 2.0 * Step.y)));
    vec4 U_DD = texture2D(fields_current, wrap(texCoord - vec2(0.0, 2.0 * Step.y)));

    // ==================== MUSCL RECONSTRUCTION ====================
    // Reconstruct left and right states at cell interfaces using slope limiting

    // X-direction reconstruction
    vec4 slope_C_x = limitSlope(U_L, U_C, U_R);
    vec4 slope_R_x = limitSlope(U_C, U_R, U_RR);
    vec4 slope_L_x = limitSlope(U_LL, U_L, U_C);

    // States at right interface (i+1/2): left and right extrapolated values
    vec4 U_right_L = U_C + 0.5 * slope_C_x;  // Extrapolate from left cell
    vec4 U_right_R = U_R - 0.5 * slope_R_x;  // Extrapolate from right cell

    // States at left interface (i-1/2)
    vec4 U_left_L = U_L + 0.5 * slope_L_x;
    vec4 U_left_R = U_C - 0.5 * slope_C_x;

    // Y-direction reconstruction
    vec4 slope_C_y = limitSlope(U_D, U_C, U_T);
    vec4 slope_T_y = limitSlope(U_C, U_T, U_TT);
    vec4 slope_D_y = limitSlope(U_DD, U_D, U_C);

    // States at top interface (j+1/2)
    vec4 U_top_L = U_C + 0.5 * slope_C_y;
    vec4 U_top_R = U_T - 0.5 * slope_T_y;

    // States at bottom interface (j-1/2)
    vec4 U_bottom_L = U_D + 0.5 * slope_D_y;
    vec4 U_bottom_R = U_C - 0.5 * slope_C_y;

    // Compute fluxes at cell edges using reconstructed states
    vec4 F_right = laxFriedrichsFlux(U_right_L, U_right_R, true);
    vec4 F_left = laxFriedrichsFlux(U_left_L, U_left_R, true);
    vec4 F_top = laxFriedrichsFlux(U_top_L, U_top_R, false);
    vec4 F_bottom = laxFriedrichsFlux(U_bottom_L, U_bottom_R, false);

    // Update state using finite volume method
    // U_new = U_old - (dt/dx) * (F_right - F_left + F_top - F_bottom)
    vec4 U_new = U_C - (dt / dx) * (F_right - F_left + F_top - F_bottom);
    //vec4 U_new = U_C - (dt / dx) * (F_right  + F_top );

    //vec4 U_new = U_C + (dt/dx)* (F_right) *0.000000000001;
    // Add mouse interaction as momentum source
    if (u_mouseActive == 1) {
        vec2 toMouse = texCoord - u_mousePos;
        float distSq = dot(toMouse, toMouse);
        float sigma = u_mouseRadius * 0.5;
        float sigmaSq = sigma * sigma;
        float gaussian = exp(-distSq / (2.0 * sigmaSq));

        // Add momentum (scaled by local density)
        vec2 forceMomentum = u_mouseVel * gaussian * 1.0* U_new.x;
        U_new.yz += dt * forceMomentum;

        // Add corresponding energy
        //vec2 u = U_new.yz / U_new.x;
        vec2 m = U_new.yz;
        float rho = U_new.x;
        //float kineticEnergy = 0.5 * U_new.x * dot(u, u);
        float kineticEnergy = dot(m,m)/(2.0*(rho + 1E-10));
        float p = calculatePressure(U_new.x, U_new.yz, U_new.w);
        U_new.w = p / (gamma - 1.0) + kineticEnergy;
    }

    // Clamp density to prevent negative values
    U_new.x = max(U_new.x, 0.01);

    // Clamp energy to prevent negative values
    U_new.w = max(U_new.w, 0.01);

    // Apply boundary conditions for walls (only if not periodic)
    if (usePeriodic < 0.5) {
        if (texCoord.x < Step.x * 3.0 || texCoord.x > 1.0 - Step.x * 3.0) {
            U_new.y = 0.0; // Zero x-momentum at x boundaries
        }
        if (texCoord.y < Step.y * 3.0 || texCoord.y > 1.0 - Step.y * 3.0) {
            U_new.z = 0.0; // Zero y-momentum at y boundaries
        }
    }

    gl_FragColor = U_new;
}
