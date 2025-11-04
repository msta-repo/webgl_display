precision highp float;

uniform sampler2D previousTrail;
uniform vec2 resolution;
uniform float fadeAmount;  // 0.0 = instant fade, 1.0 = no fade

void main() {
    vec2 uv = gl_FragCoord.xy / resolution;
    vec4 prevColor = texture2D(previousTrail, uv);
    
    // Fade the trail
    gl_FragColor = prevColor * fadeAmount;
}
