#version 330

uniform float time;
uniform float radius;
const   float SMOOTHSTEP_WIDTH = 0.015;

uniform int reps;
uniform float lp;

const vec2 CENTER1 = vec2(0.25, 0.25);
const vec2 CENTER2 = vec2(0.75, 0.75);

const vec4 WHITE      = vec4(1, 1, 1, 1);
const vec4 KUSAMA_RED = vec4(0.843, 0.059, 0.102, 1);

const vec4 BACKGROUND = KUSAMA_RED;
const vec4 DISK_COLOR = WHITE; 
void main(void)
{
    // JUST USING MAGIC (NUMBER) COORDS FOR THE MOMENT...
    vec2 normalized_coords = gl_FragCoord.xy / 1000;
    vec2 unit_coord = 2 * normalized_coords - 1.0;
    
    vec2 scaled = float(reps) * unit_coord;
    vec2 coord = fract(scaled);
    
    vec2 diff1 = abs(coord - CENTER1);
    vec2 diff2 = abs(coord - CENTER2);
    
    // Apply a Lp norm, where p varies between 1 and 2.
    float dot1_lp = pow(pow(diff1.x, lp) + pow(diff1.y, lp), 1.0 / lp);
    float dot2_lp = pow(pow(diff2.x, lp) + pow(diff2.y, lp), 1.0 / lp);
    
    float dot1 = 1 - smoothstep(radius, radius + SMOOTHSTEP_WIDTH, dot1_lp);
    float dot2 = 1 - smoothstep(radius, radius + SMOOTHSTEP_WIDTH, dot2_lp);
    
    float in_disk = dot1 + dot2;
    
    vec4 final_color = (1 - in_disk) * BACKGROUND + in_disk * DISK_COLOR;
    
    gl_FragColor = final_color;
}
