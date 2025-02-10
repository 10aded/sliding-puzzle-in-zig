#version 330

uniform float time;
uniform float radius;
uniform int reps;

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
    vec2 coord = 2 * normalized_coords - 1.0;
    
    
    vec2 scaled = float(reps) * coord;
    
    vec2 floor_coord = fract(scaled);
    
    bool disk1 = distance(floor_coord, CENTER1) < radius;
    bool disk2 = distance(floor_coord, CENTER2) < radius;
    
    float in_disk = float(disk1 || disk2);
    
    vec4 final_color = (1 - in_disk) * BACKGROUND + in_disk * DISK_COLOR;
    
    gl_FragColor = final_color;
}
