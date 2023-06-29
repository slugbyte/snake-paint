#vertex_begin
#version 330 core
layout (location = 0) in vec2 a_point;

uniform vec2 window_size;
uniform vec2 canvas_size;
uniform vec4 cell_spec;

void main(){
  float window_width = window_size.x;
  float window_height = window_size.y;
  float canvas_width = canvas_size.x;
  float canvas_height = canvas_size.y;
  float cell_x = cell_spec.x;
  float cell_y = cell_spec.y;
  float cell_width = cell_spec.z;
  float cell_height = cell_spec.w;

  // offset cell by cell_x, cell_y
  float x = (cell_x * cell_width) + (a_point.x * cell_width);
  float y = (cell_y * cell_height) + (a_point.y * cell_height);

  // center grid horizontal
  x = x + ((window_width / 2.0) - (canvas_width / 2.0));
  // 75px margin to top
  y = y + 75.0;

  // normalize cell to opengl point (between -1 & 1)
  x = ((x / window_width) * 2.0) - 1.0 ;
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
