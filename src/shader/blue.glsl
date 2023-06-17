#vertex_begin
#version 330 core
layout (location = 0) in vec2 a_point;

void main(){
  gl_Position = vec4(a_point.xy, 0.0, 1.0);
}
#vertex_end

#fragment_begin
#version 330 core
out vec4 FragColor;

void main(){
  FragColor = vec4(0.0, 0.0, 1.0, 1.0);
} 
#fragment_end
