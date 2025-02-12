#version 330 core

layout (location = 0) in vec2 aPos;
layout (location = 1) in vec2 aTexCoord;

out vec2 TexCoord;

void main() {
  vec2 unit_square_pos = aPos / 1000;
  vec2 normalized = 2 * unit_square_pos - 1;
  vec2 inverted   = vec2(normalized.x, -normalized.y);
  gl_Position = vec4(inverted, 0, 1);
  TexCoord = aTexCoord;
}
