#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif


uniform sampler2D u_psi;
uniform vec2 u_resolution;

vec3 plasma(float t) {
    const vec3 c0 = vec3(0.05873234392399702, 0.02333670892565664, 0.5433401826748754);
    const vec3 c1 = vec3(2.176514634195958, 0.2383834171260182, 0.7539604599784036);
    const vec3 c2 = vec3(-2.689460476458034, -7.455851135738909, 3.110799939717086);
    const vec3 c3 = vec3(6.130348345893603, 42.3461881477227, -28.51885465332158);
    const vec3 c4 = vec3(-11.10743619062271, -82.66631109428045, 60.13984767418263);
    const vec3 c5 = vec3(10.02306557647065, 71.41361770095349, -54.07218655560067);
    const vec3 c6 = vec3(-3.658713842777788, -22.93153465461149, 18.19190778539828);

    return c0 + t * (c1 + t * (c2 + t * (c3 + t * (c4 + t * (c5 + t * c6)))));
}

void main() {
    vec2 texCoord = gl_FragCoord.xy / u_resolution;
    float value = texture2D(u_psi, texCoord).r;
    float magnitude = value;

    float mPos = (value > 0.0) ? value*5.0 : 0.0;
    float mNeg = (value < 0.0) ? abs(value*5.0) : 0.0;
    
    //gl_FragColor = vec4(mPos, 1.0,mNeg, 1.0);
    vec3 color;
    color = vec3(0.05,0.15,0.15) + vec3(0.2,0.7,0.9)* clamp(mPos*1.0,0.0,1.0)- vec3(0.1,0.2,0.4)* clamp(mNeg*1.0, 0.0,1.0);
    gl_FragColor = vec4(color, 1.0);
}