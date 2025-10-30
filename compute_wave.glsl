#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif


uniform sampler2D u_psi_current;
uniform sampler2D u_psi_previous;
uniform vec2 u_resolution;
uniform float u_dt;
uniform float u_D;
uniform float u_t;

uniform float u_attenuate;

varying float vX;
varying float vY;

float heaviside(float x) {
    return (x > 0.0) ? 1.0 : 0.0;
}

void main() {
    vec2 texCoord = (vec2(vX, vY) + 1.0) / 2.0;
    vec2 h = 1.0 / u_resolution;



    float psi_i = texture2D(u_psi_current, texCoord).r ;
    float psi_im1 = texture2D(u_psi_previous, texCoord).r ;
    
    float left   = texture2D(u_psi_current, texCoord + vec2(-h.x, 0.0)).r;
    float right  = texture2D(u_psi_current, texCoord + vec2(h.x, 0.0)).r;
    float up     = texture2D(u_psi_current, texCoord + vec2(0.0, h.y)).r;
    float down   = texture2D(u_psi_current, texCoord + vec2(0.0, -h.y)).r;
    
    float h_sq = h.x * h.x;
    float laplacian = (left + right + up + down - 4.0 * psi_i) / h_sq;
    

    vec2 srcPos = vec2(0.5, 0.5+cos(u_t*10.0)/16.0 );
    float r = length(texCoord - srcPos);

    float src = heaviside(0.02 - r);

    float dt_sq = u_dt * u_dt;
    //float psi_next = (2.0 * psi_i) - psi_im1 + (dt_sq * u_D) * laplacian + 0.0*dt_sq* src*cos(u_t*20.0)*100.0;
    float psi_next =  psi_i + (1.0 - u_attenuate)*(psi_i -  psi_im1) + (dt_sq * u_D) * laplacian + 0.0*dt_sq* src*cos(u_t*20.0)*100.0;


    gl_FragColor = vec4(psi_next, psi_next, psi_next, 1.0);
}