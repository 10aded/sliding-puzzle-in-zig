#version 330 core

layout (location = 0) in vec2 aPos;
layout (location = 1) in vec3 aColor;

out vec3 ourColor;

void main() {
  vec4 unit_square_pos = vec4(aPos.x / 1000, aPos.y / 1000, 0, 1);
  gl_Position = 2 * unit_square_pos - 1;
  ourColor    = aColor;
}
