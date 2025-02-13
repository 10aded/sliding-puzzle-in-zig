#version 330 core

in vec3  Color;
in vec2  TexCoord;
in float Lambda;

out vec4 FragColor;

uniform sampler2D texture0;

void main() {
  vec4 flat_color         = vec4(Color, 1);
  vec4 texture_color      = texture(texture0, TexCoord);
  vec4 interpolated_color = Lambda * texture_color + (1 - Lambda) * flat_color;
  FragColor = interpolated_color;
}
