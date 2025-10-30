attribute vec2 aPosition;
varying float vX;
varying float vY;

void main() {
    gl_Position = vec4(aPosition, 0.0, 1.0);
    vX = aPosition.x;
    vY = aPosition.y;
}