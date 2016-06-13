//
//  Shader.h
//  BasicOpenGL
//
//  Created by Krishna Satyanarayana on 2016-06-13.
//  Copyright © 2016 Krishna Satyanarayana. All rights reserved.
//

#ifndef Shader_h
#define Shader_h

#include <OpenGL/gl3.h>

namespace basicGL {

/// Returns the shader program resulting from compiling and linking the
/// given vertex and fragment shader file paths.
GLuint compileShaders(const GLchar *vertexShaderPath, const GLchar *fragmentShaderPath);

}

#endif /* Shader_h */
