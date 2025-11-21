#ifdef GL_FRAGMENT_PRECISION_HIGH
    precision highp float;
#else
    precision mediump float;
#endif

uniform sampler2D fluidTexture;
uniform sampler2D trailTexture;

uniform vec2 resolution;

// Compressible fluid parameters
const float gamma = 1.4;

float squeeze(float x, float minVal, float maxVal){
    return (clamp(x, minVal, maxVal) - minVal)/(maxVal - minVal);
}

void main() {
    vec2 uv = gl_FragCoord.xy / resolution;

    // Read fluid state: [rho, momentum_x, momentum_y, energy]
    vec4 state = texture2D(fluidTexture, uv);
    vec4 trail = texture2D(trailTexture, uv);

    float rho = state.x;
    vec2 momentum = state.yz;
    float E = state.w;

    // Calculate velocity
    vec2 velocity = momentum / (rho + 1e-10);

    // Display density - map to color
    float density_factor = squeeze(rho, 0.9, 1.1);

    // Velocity magnitude for visualization
    float velocity_mag = length(velocity);
    float velocity_factor = squeeze(velocity_mag, 0.0, 1.0);

    // Color scheme for fluid density
    vec3 fluidColor = vec3(density_factor * 0.7, density_factor * 0.0, density_factor * 0.7);

    // Composite trail on top of fluid
    vec3 finalColor = mix(fluidColor, trail.rgb, 0.4);
    //vec3 finalColor = vec3(momentum.x, momentum.y, 0.0);
    gl_FragColor = vec4(finalColor, 1.0);
}
