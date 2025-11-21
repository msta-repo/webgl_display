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

// Lax-Friedrichs flux at cell edges
vec4 laxFriedrichsFlux(vec4 stateLeft, vec4 stateRight, bool xDirection) {
    vec4 fluxLeft = calculateFlux(stateLeft, xDirection);
    vec4 fluxRight = calculateFlux(stateRight, xDirection);

    // Lax-Friedrichs: F_avg - (dx/2dt) * (U_right - U_left)
    vec4 avgFlux = 0.5 * (fluxLeft + fluxRight);
    vec4 diffusion = 0.5 * (dx / dt) * (stateRight - stateLeft);

    return avgFlux - diffusion * 0.0000001;
    //return avgFlux;
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

    // Compute fluxes at cell edges using Lax-Friedrichs scheme
    // Right edge (i+1/2)
    vec4 F_right = laxFriedrichsFlux(U_C, U_R, true);
    // Left edge (i-1/2)
    vec4 F_left = laxFriedrichsFlux(U_L, U_C, true);
    // Top edge (j+1/2)
    vec4 F_top = laxFriedrichsFlux(U_C, U_T, false);
    // Bottom edge (j-1/2)
    vec4 F_bottom = laxFriedrichsFlux(U_D, U_C, false);

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
