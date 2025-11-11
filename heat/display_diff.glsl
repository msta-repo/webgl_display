#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif

uniform sampler2D u_psi;
uniform vec2 u_resolution;
varying float vX;
varying float vY;

vec3 color_map(float x) {
  const vec4 kRedVec4 = vec4(0.13572138, 4.61539260, -42.66032258, 132.13108234);
  const vec4 kGreenVec4 = vec4(0.09140261, 2.19418839, 4.84296658, -14.18503333);
  const vec4 kBlueVec4 = vec4(0.10667330, 12.64194608, -60.58204836, 110.36276771);
  const vec2 kRedVec2 = vec2(-152.94239396, 59.28637943);
  const vec2 kGreenVec2 = vec2(4.27729857, 2.82956604);
  const vec2 kBlueVec2 = vec2(-89.90310912, 27.34824973);
  
  x = clamp(x,0.0,1.0);
  vec4 v4 = vec4( 1.0, x, x * x, x * x * x);
  vec2 v2 = v4.zw * v4.z;
  return vec3(
    dot(v4, kRedVec4)   + dot(v2, kRedVec2),
    dot(v4, kGreenVec4) + dot(v2, kGreenVec2),
    dot(v4, kBlueVec4)  + dot(v2, kBlueVec2)
  );
}

void main() {
    // Use same coordinate system as compute shader for consistency
    vec2 texCoord = (vec2(vX, vY) + 1.0) / 2.0;
    
    // Sample the value
    float value = texture2D(u_psi, texCoord).r;

    float minTemp = 0.0;
    float maxTemp = 1.0;  // Adjust this based on your initial conditions
    float normalizedValue = (value - minTemp) / (maxTemp - minTemp);
    normalizedValue = clamp(normalizedValue, 0.0, 1.0);
    
    // Apply plasma colormap
    gl_FragColor = vec4(color_map(normalizedValue), 1.0);

    
}