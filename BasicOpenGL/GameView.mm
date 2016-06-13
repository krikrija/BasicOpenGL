//
//  GameView.mm
//  BasicOpenGL
//
//  Created by Krishna Satyanarayana on 2016-05-01.
//  Copyright © 2016 Krishna Satyanarayana. All rights reserved.
//

#import "GameView.h"
#import "Shader.h"
#import <OpenGL/gl3.h>

NSOpenGLPixelFormatAttribute attrs[] =
{
    NSOpenGLPFADoubleBuffer,
    NSOpenGLPFADepthSize, 24,

    // We must specify the 3.2 Core Profile to use OpenGL 3.2/3.3.
    NSOpenGLPFAOpenGLProfile, NSOpenGLProfileVersion3_2Core,
    0
};

GLfloat vertices[] = {
     // Positions        // Colours
     0.5f,  0.5f, 0.0f,  1.0f, 0.0f, 0.0f,  // Top Right
     0.5f, -0.5f, 0.0f,  0.0f, 1.0f, 0.0f,  // Bottom Right
    -0.5f, -0.5f, 0.0f,  0.0f, 0.0f, 1.0f,  // Bottom Left
    -0.5f,  0.5f, 0.0f,  1.0f, 0.0f, 1.0f   // Top Left
};

GLuint indices[] = {
    0, 1, 3,   // First Triangle
    1, 2, 3    // Second Triangle
};


@interface GameView ()

@property (assign) GLuint vbo;
@property (assign) GLuint ebo;
@property (assign) GLuint vao;
@property (assign) GLuint shaderProgram;
@property (assign) CVDisplayLinkRef displayLink; // Manages the rendering thread
@property (assign) NSTimeInterval timeSinceStart;

@end


@implementation GameView

- (void)awakeFromNib {
    [super awakeFromNib];

    self.timeSinceStart = 0.0;

    NSOpenGLPixelFormat *pixelFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:attrs];
    NSOpenGLContext *context = [[NSOpenGLContext alloc] initWithFormat:pixelFormat shareContext:nil];

    self.pixelFormat = pixelFormat;
    self.openGLContext = context;

    NSLog(@"OpenGL Version: %s", glGetString(GL_VERSION));

    GLint attributeCount = -1;
    glGetIntegerv(GL_MAX_VERTEX_ATTRIBS, &attributeCount);
    NSLog(@"Max # of vertex attributes supported: %d", attributeCount);

    [self initGL];
}

- (void)initGL {
    // Initialize the Core Video display link
    {
        // Synchronize buffer swaps with vertical refresh rate
        GLint swapInt = 1;
        [self.openGLContext setValues:&swapInt forParameter:NSOpenGLCPSwapInterval];

        // Create a display link capable of being used with all active displays
        CVDisplayLinkCreateWithActiveCGDisplays(&_displayLink);

        // Set the renderer output callback function
        CVDisplayLinkSetOutputCallback(self.displayLink, &displayLinkCallback, (__bridge void *)self);

        // Set the display link for the current renderer
        CGLContextObj cglContext = [self.openGLContext CGLContextObj];
        CGLPixelFormatObj cglPixelFormat = [self.pixelFormat CGLPixelFormatObj];
        CVDisplayLinkSetCurrentCGDisplayFromOpenGLContext(_displayLink, cglContext, cglPixelFormat);

        // Activate the display link
        CVDisplayLinkStart(_displayLink);
    }

    // Compile the vertex and fragment shaders.
    NSBundle *bundle = [NSBundle mainBundle];
    const GLchar *vertexShaderPath = [bundle pathForResource:@"Default" ofType:@"vert"].UTF8String;
    const GLchar *fragmentShaderPath = [bundle pathForResource:@"Default" ofType:@"frag"].UTF8String;
    self.shaderProgram = basicGL::compileShaders(vertexShaderPath, fragmentShaderPath);

    // Generate a vertex array object to store our vertex binding and attribute pointer
    // so we only have to input them once.
    glGenVertexArrays(1, &_vao);
    NSLog(@"VAO location: %u", self.vao);

    // Generate a vertex buffer object to store our the vertices in the GPU's memory.
    glGenBuffers(1, &_vbo);
    NSLog(@"VBO location: %u", self.vbo);

    // Generate an element buffer object to store our vertex indices for optimized drawing.
    glGenBuffers(1, &_ebo);
    NSLog(@"EBO location: %u", self.ebo);

    // NOTE(KS): All commands performed within the following block are stored within the
    // vertex array object.
    glBindVertexArray(self.vao);
    {
        // Bind the VBO to the GL_ARRAY_BUFFER target so that we can perform operations on it.
        glBindBuffer(GL_ARRAY_BUFFER, self.vbo);

        // Copy the vertex data from vertices into the GL_ARRAY_BUFFER target, which is
        // bound to the VBO we just created.
        // NOTE(KS): GL_STATIC_DRAW is a hint to the graphics card for how to manage the vertex data.
        // It tells the graphics card that the data will most likely not change at all or very rarely.
        glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);

        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, self.ebo);
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indices), indices, GL_STATIC_DRAW);

        // Position attribute
        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 6 * sizeof(GLfloat), (GLvoid *)0);
        glEnableVertexAttribArray(0);

        // Colour attribute
        glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 6 * sizeof(GLfloat), (GLvoid *)(3 * sizeof(GLfloat)));
        glEnableVertexAttribArray(1);

        // Unbind the buffer object.
        glBindBuffer(GL_ARRAY_BUFFER, 0);
    }
    glBindVertexArray(0);

    // NOTE(KS): Unlike with the VBO, we should NOT unbind the EBO within the VAO block.
    // Not exactly sure why. But we can unbind it here without any issues.
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);

    // Uncommenting this call will result in wireframe polygons.
    // glPolygonMode(GL_FRONT_AND_BACK, GL_LINE);
}

static CVReturn displayLinkCallback(CVDisplayLinkRef displayLink, const CVTimeStamp *now,
                                    const CVTimeStamp *outputTime, CVOptionFlags flagsIn,
                                    CVOptionFlags *flagsOut, void *displayLinkContext) {
    @autoreleasepool {
        GameView *openGLView = (__bridge GameView *)displayLinkContext;
        CVReturn result = [openGLView updateAndRenderForTime:outputTime];
        return result;
    }
}

- (CVReturn)updateAndRenderForTime:(const CVTimeStamp *)time {
    [self.openGLContext makeCurrentContext];
    double frameRate = time->rateScalar * (double)time->videoTimeScale / (double)time->videoRefreshPeriod;
    NSTimeInterval deltaTime = 1.0 / frameRate;
    self.timeSinceStart += deltaTime;

    // We must lock GL context because the display link is threaded.
    CGLLockContext((CGLContextObj)self.openGLContext.CGLContextObj);
    {
        glClearColor(0.2f, 0.3f, 0.3f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);

        // Draw the two triangles
        glUseProgram(self.shaderProgram);
        glBindVertexArray(self.vao);
        glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);
        glBindVertexArray(0);

        [self.openGLContext flushBuffer];
    }
    CGLUnlockContext((CGLContextObj)self.openGLContext.CGLContextObj);
    return kCVReturnSuccess;
}

@end
