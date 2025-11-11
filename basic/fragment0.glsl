precision mediump float;
varying float vX;
varying float vY;
void main() {
    // vX is in clip space (-1 to 1), remap to 0-1 for brightness
    float brightness = 0.5 + 0.5 * (vX + 1.0);
    gl_FragColor = vec4( (sin(vX*vY*100.0)+1.0)/2.0, cos(vY*vX*120.0), 0.0, 1.0);
}