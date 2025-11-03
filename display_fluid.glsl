#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif


uniform sampler2D fields_current;
uniform vec2 resolution;

float squeeze(float x, float maxVal){
    return (clamp(x, -maxVal, maxVal)/(maxVal) + 1.0 )/2.0;
}

float squeeze(float x, float minVal, float maxVal){
    return (clamp(x, minVal, maxVal)/(maxVal -minVal) + 1.0 )/2.0;
}


void main() {
    vec2 texCoord = gl_FragCoord.xy / resolution;


    vec4 FC = texture2D(fields_current, texCoord);
    
    //gl_FragColor = vec4(mPos, 1.0,mNeg, 1.0);
    vec3 color;
    color = vec3(0.05,0.15,0.9);

    float density_factor = (squeeze( FC.z ,0.5,  3.0) -0.5);

    float velocity_factor = squeeze( sqrt(dot(FC.xy, FC.xy)), 0.00001);

    //gl_FragColor = vec4(squeeze( FC.x, 1.0)*density_factor,squeeze( FC.y, 1.0)*density_factor,density_factor,  1.0);
    gl_FragColor = vec4(density_factor*vec3(1.0,0.1,0.7),  1.0);
}