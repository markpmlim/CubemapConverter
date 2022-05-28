# Cubemap Converter


This project demonstrates how to create six 2D textures from a horizontal/vertical cross layout cubemap. The generated cubemap texture will be used to render a skybox.

The graphics engine is Apple's OpenGL implementation for the macOS or its OpenGLES implementation for the iOS.
Testing is done only for modern OpenGL 3.2 and OpenGLES 3.0.

<br />
<br />
<br />

**CubemapGen**

The demo will convert a single 2D (horizontal/vertical) cross shape cubemap texture to six 2D textures by rendering to an offscreen framebuffer object. A brief summary of the steps involved is as follows:

1) Build the first shader program which will be used to render the skybox using the textures of six 2D faces of a cubemap texture. The method


```swift
    buildProgram(with:, and:)
```

is called to build an OpenGL program *glslProgram* by passing the URLs of its vertex and fragment shader source files. The vertex shader is a hack where data for the triangle's position and texture attributes are calculated and output to the GPU on the fly. Basically, the vertex shader's job is to serve up a 2D (triangular) canvas which covers the entire (rectangular) clip space.

On the CPU side, we still need to get OpenGL to generate a Vertex Array Object (VAO) which is used for binding just before calling the OpenGL draw call:


```swift
    glDrawArrays(GLenum(GL_TRIANGLES), 0, 3)
```

2) Build the shader program named *cubemapProgram* that will be used to create the 2D textures of the six faces of a cubemap texture from a cross layout. 


3) Load a 2D image which has a resolution of 3:4 or 4:3 (vertical or horizontal cross layout) by calling the function:

```swift
    loadTexture(name:, resolution:, isHDR:)
```

An image with a resolution of 1536:2048 or 2048:1536 pixels is used for this demo. This function will create a texutre of type GL_TEXTURE_2D from the 2D image. The parameters passed must be set appropriately when the function is called or an incorrect texture will be created. The resolution of the texture and an OpenGL texture identifier (name) associated with the newly-created texture are returned by the loadTexture method.


3) Finally, the method:

```swift
    createCubemapTexture(faceSize:, cubeLayout:, isHDR:)
```

is called to instantiate a cubemap texture (GL_TEXTURE_CUBE_MAP). The parameters of the call must be set appropriately. In particular, the parameter *cubeLayout* should be *CubemapLayout.horizontalCross* or *CubemapLayout.verticalCross*. If the texture created by *loadTexture* is from a 16-bit image, the parameter *isHDR* must be set to true.


4a) Upon entry into the *createCubemapTexture* method, a texture name (or identifier) is generated by calling the OpenGL's function:

```swift
    glGenTextures(_ n: GLsizei, _ textures: UnsafeMutablePointer<GLuint>!)
```

The call

```swift
    glBindTexture(GLenum(GL_TEXTURE_CUBE_MAP), cubeMapID)
```

informs OpenGL to create the texture object as a cubemap texture and reset it to its default state.

After the binding call to OpenGL, the following OpenGL function:

```swift
    glTexImage2D(_ target: GLenum,
                 _ level: GLint,
                 _ internalformat: GLint,
                 _ width: GLsizei,
                 _ height: GLsizei,
                 _ border: GLint,
                 _ format: GLenum,
                 _ type: GLenum,
                 _ pixels: UnsafeRawPointer)
```

is called within a loop to allocate memory storage for the pixel data for each 2D texture of the six faces of the cubemap texture.

**Note:** the last parameter is set to nil. 

4b) Next, the name of an OpenGL framebuffer object (FBO) is generated by calling the OpenGL function:

```swift
    glGenFramebuffers(_ n: GLsizei, _ framebuffers: UnsafeMutablePointer<GLuint>!)
```

This is followed by a binding call: *glBindFramebuffer* to make it the active framebuffer.

The state of the FBO can only be setup properly on the first binding call as the active framebuffer.


4c) Before we can populate the six 2D textures with pixels read from the cross map, we need to bind the texture (GL_TEXTURE_2D) and VAO to be used by the OpenGL program *cubemapProgram*. To create the pixels for each face of the cubemap texture, a quad is rendered 6 times by sending a different face index to fragment shader as a uniform. Sending the cubeLayout type as a uniform enables the fragment shader to select a different mapping function.



**Bugs:**

a) The right and left textures or the front and back textures are swapped. Solved. 

b) Each 2D textures of the cubemap are flipped horizontally. Solved.


**Notes**:

a) The vertical cross layout was generated from six 2D images by the program *CubemapGen* made available for download by AMD. Notice the orientation of the -Z face is different from the other five faces. It is flipped horizontally before being mapped to its position on the 3x4 grid. The fragment shader has to take that into account.

b) The horizontal cross layout was generated online using the tool posted by Mateusz Wisniowski.

<br />
<br />

**Requirements:**
IDE: XCode 9.x, 
Language: Swift 4.x
OS: macOS 10.13.4 or later or iOS OpenGLES 3.0.
<br />
<br />

**References:**

https://learnopengl.com/PBR/IBL/Diffuse-irradiance

https://gpuopen.com/archived/cubemapgen/

https://matheowis.github.io/HDRI-to-CubeMap/

https://www.shadertoy.com/view/tlyXzG