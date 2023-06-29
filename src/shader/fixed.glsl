#vertex_begin
#version 330 core
layout (location = 0) in vec2 a_point;
uniform vec2 window_size;
uniform vec4 dimention;


void main(){
  float item_x = dimention.x;
  float item_y = dimention.y;
  float item_width = dimention.z;
  float item_height = dimention.w;

  float window_width = window_size.x;
  float window_height = window_size.y;

  float x = item_x  + (a_point.x * item_width);
  float y = item_y  + (a_point.y * item_height);

  // normalize cell to opengl point (between -1 & 1)
  x = ((x / window_width) * 2.0) - 1.0;
  y = (((window_height - y) / window_height) * 2.0) - 1.0;

  // output point
  gl_Position = vec4(x, y, 0.0, 1.0);
}

#vertex_end
#fragment_begin
#version 330 core
out vec4 FragColor;

uniform vec3 fg_color;

void main(){
  FragColor = vec4(fg_color, 1.0);
} 
#fragment_end
