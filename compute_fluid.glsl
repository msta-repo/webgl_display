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
    
    // Paper's constants (K ≈ 0.2, dt = 0.15)
    // The paper assumes dx = dy = 1.0 (grid units, not texture units)
    float CScale = 0.5;       // For central differences with dx=1: (f[i+1]-f[i-1])/2
    float K = 0.2;            // Density-invariant pressure constant
    float v = 0.5;            // Kinematic viscosity
    float S = K / dt;         // Pressure gradient scale
    
    // Sample current state and neighbors
    vec4 FC = texture2D(fields_current, texCoord);
    vec3 FR = texture2D(fields_current, texCoord + vec2(Step.x, 0.0)).xyz;
    vec3 FL = texture2D(fields_current, texCoord - vec2(Step.x, 0.0)).xyz;
    vec3 FT = texture2D(fields_current, texCoord + vec2(0.0, Step.y)).xyz;
    vec3 FD = texture2D(fields_current, texCoord - vec2(0.0, Step.y)).xyz;
    
    // ==================== SPATIAL DERIVATIVES (in grid units, dx=1) ====================
    // Just multiply by CScale = 0.5, as in the paper
    vec3 UdX = (FR - FL) * CScale;  // du/dx, dv/dx, drho/dx (in grid units)
    vec3 UdY = (FT - FD) * CScale;  // du/dy, dv/dy, drho/dy (in grid units)
    
    float Udiv = UdX.x + UdY.y;     // Velocity divergence
    vec2 DdX = vec2(UdX.z, UdY.z);  // Density gradient
    
    // ==================== MASS CONSERVATION ====================
    // drho/dt = -u·∇rho - rho*div(u)
    FC.z -= dt * dot(vec3(DdX, Udiv), FC.xyz);
    FC.z = clamp(FC.z, 0.5, 3.0);
    
    // ==================== MOMENTUM CONSERVATION ====================
    // Pressure gradient
    vec2 PdX = S * DdX;
    
    // Laplacian (with dx=1): (u[i+1] + u[i-1] + u[j+1] + u[j-1] - 4*u[i,j])
    vec2 Laplacian = (FR.xy + FL.xy + FT.xy + FD.xy) - 4.0 * FC.xy;
    vec2 ViscosityForce = v * Laplacian;
    
    // Semi-Lagrangian advection FIRST (as in paper)
    // Velocity is in grid units (pixels/timestep), Step converts to texture space
    vec2 Was = texCoord - dt * FC.xy * Step;
    FC.xy = texture2D(fields_current, Was).xy;
    
    // Then apply forces
    vec2 ExternalForces = vec2(0.0, 0.00000001);
    FC.xy += dt * (ViscosityForce - PdX + ExternalForces);
    
    // ==================== BOUNDARY CONDITIONS ====================
    if (texCoord.x < Step.x * 2.0 || texCoord.x > 1.0 - Step.x * 2.0) {
        FC.x = 0.0;
    }
    if (texCoord.y < Step.y * 2.0 || texCoord.y > 1.0 - Step.y * 2.0) {
        FC.y = 0.0;
    }
    
    gl_FragColor = FC;
}
