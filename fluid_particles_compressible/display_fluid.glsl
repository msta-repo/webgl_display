#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif

uniform sampler2D fields_current;
uniform vec2 resolution;

// Compressible fluid parameters
const float gamma = 1.4;

float squeeze(float x, float maxVal){
    return (clamp(x, -maxVal, maxVal)/(maxVal) + 1.0 )/2.0;
}

float squeeze(float x, float minVal, float maxVal){
    return (clamp(x, minVal, maxVal) - minVal)/(maxVal - minVal);
}

void main() {
    vec2 texCoord = gl_FragCoord.xy / resolution;

    // Read fluid state: [rho, momentum_x, momentum_y, energy]
    vec4 state = texture2D(fields_current, texCoord);

    float rho = state.x;
    vec2 momentum = state.yz;
    float E = state.w;

    // Calculate velocity
    vec2 velocity = momentum / (rho + 1e-10);

    // Display density
    // Map density to color - assuming typical range 0.1 to 2.0
    float density_factor = squeeze(rho, 0.1, 2.0);

    // Velocity magnitude for additional visualization
    float velocity_mag = length(velocity);
    float velocity_factor = squeeze(velocity_mag, 0.0, 1.0);

    // Color scheme: density mapped to brightness
    vec3 color = vec3(density_factor * 0.8, density_factor * 0.4, density_factor);

    gl_FragColor = vec4(color, 1.0);
}
