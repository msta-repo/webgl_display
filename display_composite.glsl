#ifdef GL_FRAGMENT_PRECISION_HIGH
    precision highp float;
#else
    precision mediump float;
#endif

uniform sampler2D fluidTexture;
uniform sampler2D trailTexture;
uniform vec2 resolution;



float squeeze(float x, float minVal, float maxVal){
    return (clamp(x, minVal, maxVal) - minVal)/(maxVal -minVal) ;
}




void main() {
    vec2 uv = gl_FragCoord.xy / resolution;
    
    vec4 FC = texture2D(fluidTexture, uv);
    vec4 trail = texture2D(trailTexture, uv);
    
    
    //gl_FragColor = vec4(mPos, 1.0,mNeg, 1.0);
    vec3 color;
    color = vec3(0.05,0.15,0.9);

    float density_factor = squeeze( FC.z ,0.8,  2.0);

    float velocity_factor = squeeze( abs(FC.y),0.0, 0.1);


    //vec3 fluid = vec3(0.5, 0.0,0.7)*density_factor;
    vec3 fluid = vec3(abs(FC.x), abs(FC.y), 0.0)*10.0*density_factor;
    // Composite trail on top of fluid
    //vec3 finalColor = fluid.rgb+  trail.rgb;
    vec3 finalColor = fluid.rgb*1.5 + trail.rgb;
    //gl_FragColor = vec4(finalColor, 1.0);

    gl_FragColor = vec4(finalColor, 1.0);

}
