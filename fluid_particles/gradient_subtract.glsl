#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif



uniform sampler2D fields_current; // uncorrected velocity fields

uniform sampler2D pressure; // pressure and new velocities

uniform vec2 resolution;

varying float vX;
varying float vY;

uniform float usePeriodic; 

uniform float omega;


// Wrap texture coordinates for periodic boundaries
vec2 wrap(vec2 coord) {
    return fract(coord);
}

void main() {
    vec2 texCoord = (vec2(vX, vY) + 1.0) / 2.0;
    vec2 Step = 1.0 / resolution;
    
    float CScale = 0.5;


    // Sample pressure
    vec4 p = texture2D(pressure, wrap(texCoord));
    
    // Sample with wrapping
    vec4 FC = texture2D(fields_current, wrap(texCoord));
    

    gl_FragColor = FC; // return 
}