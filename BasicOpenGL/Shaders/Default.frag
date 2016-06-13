#version 330 core

in vec3 outputColour;
out vec4 color;

void main()
{
    color = vec4(outputColour, 1.0);
}
