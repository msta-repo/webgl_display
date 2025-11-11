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


varying float vX;
varying float vY;

void main() {
    vec2 texCoord = (vec2(vX, vY) + 1.0) / 2.0;
    vec2 h = 1.0 / u_resolution;
    
    float psi_i = texture2D(u_psi_current, texCoord).r;
    float psi_im1 = texture2D(u_psi_previous, texCoord).r;
    
    // Sample neighbors for Laplacian
    float left   = texture2D(u_psi_current, texCoord + vec2(-h.x, 0.0)).r;
    float right  = texture2D(u_psi_current, texCoord + vec2(h.x, 0.0)).r;
    float up     = texture2D(u_psi_current, texCoord + vec2(0.0, h.y)).r;
    float down   = texture2D(u_psi_current, texCoord + vec2(0.0, -h.y)).r;
    
    float h_sq = h.x * h.x;
    float laplacian = (left + right + up + down - 4.0 * psi_i) / h_sq;
    
    // Wave equation update
    float dt_sq = u_dt * u_dt;
    float psi_next = psi_i +  (psi_i - psi_im1) + (dt_sq * u_D) * laplacian;
    
    gl_FragColor = vec4(psi_next, psi_next, psi_next, 1.0);
}