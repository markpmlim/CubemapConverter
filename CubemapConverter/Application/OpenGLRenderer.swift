//
//  OpenGLRenderer.swift
//  OpenGLRenderer
//
//  Created by mark lim pak mun on 25/5/2022.
//  Copyright © 2022 mark lim pak mun. All rights reserved.
//  This is shared by both the macOS and iOS demos.
//

#if os(iOS)
import UIKit
import OpenGLES
#else
import AppKit
import OpenGL.GL3
#endif

import simd
import GLKit

// More layouts can be supported e.g. compact, vertical strip etc.
enum CubemapLayout: Int {
    case horizontalCross = 1
    case verticalCross
}

class OpenGLRenderer: NSObject {
    var _defaultFBOName: GLuint = 0
    var _viewSize: CGSize = CGSize()
    var glslProgram: GLuint = 0
    // Parameters to be passed to the fragment shader.
    // The origin is at the left hand corner
    var mouseCoords: [GLfloat] = [0.0, 0.0]
    var currentTime: GLfloat = 0.0
    var resolutionLoc: GLint = 0
    var mouseLoc: GLint = 0
    var timeLoc: GLint = 0

    var triangleVAO: GLuint = 0
    var _projectionMatrix = matrix_identity_float4x4    // not used
    var crossMapTextureID: GLuint = 0                   // 2D texture ID
    var u_tex0Resolution: [GLfloat] = [0.0, 0.0]

    var cubeMapTextureID: GLuint = 0
    let faceSize: GLsizei = 512         // All faces must be squares
    var faceIndexLoc: GLint = 0
    var cubeLayoutLoc: GLint = 0
    var cubemapProgram: GLuint = 0

    init(_ defaultFBOName: GLuint) {
        super.init()
        // Build all of your objects and setup initial state here.
        _defaultFBOName = defaultFBOName
        //Swift.print(_defaultFBOName)
        let vertexSourceURL = Bundle.main.url(forResource: "VertexShader",
                                              withExtension: "glsl")
        var fragmentSourceURL = Bundle.main.url(forResource: "SkyboxFragmentShader",
                                                withExtension: "glsl")
        glslProgram = buildProgram(with: vertexSourceURL!,
                                   and: fragmentSourceURL!)
 
        // Locations of uniforms whose values are passed to the fragment shader
        resolutionLoc = glGetUniformLocation(glslProgram, "u_resolution")
        mouseLoc = glGetUniformLocation(glslProgram, "u_mouse")
        timeLoc = glGetUniformLocation(glslProgram, "u_time")

        glGenVertexArrays (1, &triangleVAO);    // Required

        // The GLSL program is used for an offscreen render to a framebuffer object (FBO)
        // The same vertex shader is used.
        fragmentSourceURL = Bundle.main.url(forResource: "CubemapFragmentShader",
                                            withExtension: "glsl")
        cubemapProgram = buildProgram(with: vertexSourceURL!,
                                      and: fragmentSourceURL!)
        faceIndexLoc = glGetUniformLocation(cubemapProgram, "faceIndex")
        cubeLayoutLoc = glGetUniformLocation(cubemapProgram, "graphicType")
        //print(faceIndexLoc, cubeLayoutLoc)

        // Note: set the name and isHDR parameters correctly.
        crossMapTextureID = loadTexture(name: "HorizontalCross.hdr",
                                        resolution: &u_tex0Resolution,
                                        isHDR: true)
        //Swift.print("texture size:", u_tex0Resolution)

        // Note: set the cubeLayout and isHDR parameters correctly.
        // For cubeLayout, see the enum declaration of CubemapLayout.
        cubeMapTextureID = createCubemapTexture(faceSize: faceSize,
                                                cubeLayout: .horizontalCross,
                                                isHDR: true)
    }

    private func updateTime() {
        currentTime += 1/60
    }

    // Main draw function. Called by both iOS and macOS modules.
    // Renders a skybox
    func draw() {
        updateTime()
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT) | GLbitfield(GL_DEPTH_BUFFER_BIT))
        glClearColor(0.5, 0.5, 0.5, 1.0)

        glViewport(0, 0,
                   (GLsizei)(_viewSize.width),
                   (GLsizei)(_viewSize.height))
        glBindVertexArray(triangleVAO)
        glUseProgram(glslProgram)
        glUniform2f(resolutionLoc,
                    GLfloat(_viewSize.width), GLfloat(_viewSize.height))
        glUniform1f(timeLoc, GLfloat(currentTime))
        glUniform2fv(mouseLoc, 1, mouseCoords)
        glActiveTexture(GLenum(GL_TEXTURE_CUBE_MAP))
        glBindTexture(GLenum(GL_TEXTURE_CUBE_MAP),
                      cubeMapTextureID)

        glDrawArrays(GLenum(GL_TRIANGLES), 0, 3)
        glUseProgram(0)
        glBindVertexArray(0)
    }

    func resize(_ size: CGSize) {
        _viewSize = size
        let aspect = (Float)(size.width) / (Float)(size.height)
        _projectionMatrix = matrix_perspective_left_hand_gl(65.0 * (Float.pi / 180.0),
                                                            aspect,
                                                            1.0, 5000.0);
    }

    // Returns an OpenGL texture name (id) & the texture's width and height.
    // The function should return the 2D image right side up.
    // That might not be what is required.
    func loadTexture(name : String, resolution: inout [GLfloat],
                     isHDR: Bool) -> GLuint {
        let mainBundle = Bundle.main
        var width: Int32 = 0
        var height: Int32  = 0
        var textureID: UInt32 = 0
        if isHDR {
            let subStrings = name.components(separatedBy:".")
            let filePath = mainBundle.path(forResource: subStrings[0],
                                           ofType: subStrings[1])
            textureID = textureFromRadianceFile(filePath, &width, &height)
            resolution[0] = GLfloat(width)
            resolution[1] = GLfloat(height)
        }
        else {
            let subStrings = name.components(separatedBy:".")
            guard let url = mainBundle.url(forResource: subStrings[0],
                                           withExtension: subStrings[1])
                else {
                    Swift.print("File \(name): not found")
                    exit(2)
            }
            var textureInfo: GLKTextureInfo!
            do {
                let options: [String : NSNumber] = [
                    GLKTextureLoaderOriginBottomLeft: NSNumber(value: true)
                ]
                textureInfo = try GLKTextureLoader.texture(withContentsOf: url,
                                                           options: options)
            }
            catch let error {
                fatalError("Error loading picture file:\(error)")
            }
            resolution[0] = GLfloat(textureInfo.width)
            resolution[1] = GLfloat(textureInfo.height)
            textureID = textureInfo.name
        }
        return textureID
    }

    /*
     Only expect a pair of vertex and fragment shaders.
     This function should work for both fixed pipeline and modern OpenGL syntax.
     */
    func buildProgram(with vertSrcURL: URL,
                      and fragSrcURL: URL) -> GLuint {
        // Prepend the #version preprocessor directive to the vertex and fragment shaders.
        var  glLanguageVersion: Float = 0.0
        let glslVerstring = String(cString: glGetString(GLenum(GL_SHADING_LANGUAGE_VERSION)))
    #if os(iOS)
        let index = glslVerstring.index(glslVerstring.startIndex, offsetBy: 18)
    #else
        let index = glslVerstring.index(glslVerstring.startIndex, offsetBy: 0)
    #endif
        let range = index..<glslVerstring.endIndex
        let verStr = glslVerstring.substring(with: range)

        let scanner = Scanner(string: verStr)
        scanner.scanFloat(&glLanguageVersion)
        // We need to convert the float to an integer and then to a string.
        var shaderVerStr = String(format: "#version %d", Int(glLanguageVersion*100))
    #if os(iOS)
        if EAGLContext.current().api == .openGLES3 {
            shaderVerStr = shaderVerStr.appending(" es")
        }
    #endif

        var vertSourceString = String()
        var fragSourceString = String()
        do {
            vertSourceString = try String(contentsOf: vertSrcURL)
        }
        catch _ {
            Swift.print("Error loading vertex shader")
        }

        do {
            fragSourceString = try String(contentsOf: fragSrcURL)
        }
        catch _ {
            Swift.print("Error loading fragment shader")
        }
        vertSourceString = shaderVerStr + "\n" + vertSourceString
        //Swift.print(vertSourceString)
        fragSourceString = shaderVerStr + "\n" + fragSourceString
        //Swift.print(fragSourceString)

        // Create a GLSL program object.
        let prgName = glCreateProgram()

        // We can choose to bind our attribute variable names to specific
        //  numeric attribute locations. Must be done before linking.
        //glBindAttribLocation(prgName, AAPLVertexAttributePosition, "a_Position")

        let vertexShader = glCreateShader(GLenum(GL_VERTEX_SHADER))
        var cSource = vertSourceString.cString(using: .utf8)!
        var glcSource: UnsafePointer<GLchar>? = UnsafePointer<GLchar>(cSource)
        glShaderSource(vertexShader, 1, &glcSource, nil)
        glCompileShader(vertexShader)

        var compileStatus : GLint = 0
        glGetShaderiv(vertexShader, GLenum(GL_COMPILE_STATUS), &compileStatus)
        if compileStatus == GL_FALSE {
            var infoLength : GLsizei = 0
            glGetShaderiv(vertexShader, GLenum(GL_INFO_LOG_LENGTH), &infoLength)
            if infoLength > 0 {
                // Convert an UnsafeMutableRawPointer to UnsafeMutablePointer<GLchar>
                let log = malloc(Int(infoLength)).assumingMemoryBound(to: GLchar.self)
                glGetShaderInfoLog(vertexShader, infoLength, &infoLength, log)
                let errMsg = NSString(bytes: log,
                                      length: Int(infoLength),
                                      encoding: String.Encoding.ascii.rawValue)
                print(errMsg!)
                glDeleteShader(vertexShader)
                free(log)
            }
        }
        // Attach the vertex shader to the program.
        glAttachShader(prgName, vertexShader);

        // Delete the vertex shader because it's now attached to the program,
        //  which retains a reference to it.
        glDeleteShader(vertexShader);

        /*
         * Specify and compile a fragment shader.
         */
        let fragmentShader = glCreateShader(GLenum(GL_FRAGMENT_SHADER))
        cSource = fragSourceString.cString(using: .utf8)!
        glcSource = UnsafePointer<GLchar>(cSource)
        glShaderSource(fragmentShader, 1, &glcSource, nil)
        glCompileShader(fragmentShader)

        glGetShaderiv(fragmentShader, GLenum(GL_COMPILE_STATUS), &compileStatus)
        if compileStatus == GL_FALSE {
            var infoLength : GLsizei = 0
            glGetShaderiv(fragmentShader, GLenum(GL_INFO_LOG_LENGTH), &infoLength)
            if infoLength > 0 {
                // Convert an UnsafeMutableRawPointer to UnsafeMutablePointer<GLchar>
                let log = malloc(Int(infoLength)).assumingMemoryBound(to: GLchar.self)
                glGetShaderInfoLog(fragmentShader, infoLength, &infoLength, log)
                let errMsg = NSString(bytes: log,
                                      length: Int(infoLength),
                                      encoding: String.Encoding.ascii.rawValue)
                print(errMsg!)
                glDeleteShader(fragmentShader)
                free(log)
            }
        }

        // Attach the fragment shader to the program.
        glAttachShader(prgName, fragmentShader)

        // Delete the fragment shader because it's now attached to the program,
        //  which retains a reference to it.
        glDeleteShader(fragmentShader)

        /*
         * Link the program.
         */
        var linkStatus: GLint = 0
        glLinkProgram(prgName)
        glGetProgramiv(prgName, GLenum(GL_LINK_STATUS), &linkStatus)

        if (linkStatus == GL_FALSE) {
            var logLength : GLsizei = 0
            glGetProgramiv(prgName, GLenum(GL_INFO_LOG_LENGTH), &logLength)
            if (logLength > 0) {
                let log = malloc(Int(logLength)).assumingMemoryBound(to: GLchar.self)
                glGetProgramInfoLog(prgName, logLength, &logLength, log)
                NSLog("Program link log:\n%s.\n", log)
                free(log)
            }
        }

        // We can locate all uniform locations here
        //let samplerLoc = glGetUniformLocation(prgName, "image")
        //Swift.print(samplerLoc)

        //checkGLErrors()
        return prgName
    }

    // Create a cubemap consisting of six 2D textures from the
    //  2D vertical/horizontal cross layout
    func createCubemapTexture(faceSize: GLsizei,
                              cubeLayout layout: CubemapLayout,
                              isHDR: Bool) -> GLuint {

        var cubeMapID: GLuint = 0
        glGenTextures(1, &cubeMapID)
        glBindTexture(GLenum(GL_TEXTURE_CUBE_MAP), cubeMapID)
        if isHDR {
            for i in 0..<6 {
                glTexImage2D(GLenum(GL_TEXTURE_CUBE_MAP_POSITIVE_X + Int32(i)),
                             0,
                             GL_RGB16F,             // internal format
                             faceSize, faceSize,    // width, height
                             0,
                             GLenum(GL_RGB),        // format
                             GLenum(GL_FLOAT),      // type
                             nil)                   // allocate space for the pixels.
            }
        }
        else {
            // Assume 8-bit graphic image
            for i in 0..<6 {
                glTexImage2D(GLenum(GL_TEXTURE_CUBE_MAP_POSITIVE_X + Int32(i)),
                             0,
                             GL_RGBA,                   // internal format
                             faceSize, faceSize,        // width, height
                             0,
                             GLenum(GL_RGBA),           // format
                             GLenum(GL_UNSIGNED_BYTE),  // type
                             nil)                       // allocate space for the pixels.
            }
        }
 
        // Sampler settings for the cubemap
        glTexParameteri(GLenum(GL_TEXTURE_CUBE_MAP), GLenum(GL_TEXTURE_WRAP_S), GL_CLAMP_TO_EDGE)
        glTexParameteri(GLenum(GL_TEXTURE_CUBE_MAP), GLenum(GL_TEXTURE_WRAP_T), GL_CLAMP_TO_EDGE)
        glTexParameteri(GLenum(GL_TEXTURE_CUBE_MAP), GLenum(GL_TEXTURE_WRAP_R), GL_CLAMP_TO_EDGE)
        glTexParameteri(GLenum(GL_TEXTURE_CUBE_MAP), GLenum(GL_TEXTURE_MIN_FILTER), GL_LINEAR)
        glTexParameteri(GLenum(GL_TEXTURE_CUBE_MAP), GLenum(GL_TEXTURE_MAG_FILTER), GL_LINEAR)

        var captureFBO: UInt32 = 0
        var captureRBO: UInt32 = 0

        glGenFramebuffers(1, &captureFBO)
        glGenRenderbuffers(1, &captureRBO)

        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), captureFBO)
        // The following attachment is not necessary since a quad is rendered.
        glBindRenderbuffer(GLenum(GL_RENDERBUFFER), captureRBO)
        glRenderbufferStorage(GLenum(GL_RENDERBUFFER),
                              GLenum(GL_DEPTH_COMPONENT24),
                              faceSize, faceSize)
        glFramebufferRenderbuffer(GLenum(GL_FRAMEBUFFER),
                                  GLenum(GL_DEPTH_ATTACHMENT),
                                  GLenum(GL_RENDERBUFFER),
                                  captureRBO)

        let framebufferStatus = Int32(glCheckFramebufferStatus(GLenum(GL_FRAMEBUFFER)))
        if framebufferStatus != GL_FRAMEBUFFER_COMPLETE {
            Swift.print("FrameBuffer is incomplete")
            checkGLErrors()
            return 0
        }

        // Don't forget to configure the viewport to the capture dimensions.
        glViewport(0, 0,
                   faceSize, faceSize)
        glUseProgram(cubemapProgram)
        glActiveTexture(GLenum(GL_TEXTURE0))
        glBindTexture(GLenum(GL_TEXTURE_2D),
                      crossMapTextureID)

        glBindVertexArray(triangleVAO)
        // Extract the cube map
        for i in 0..<6 {
            glFramebufferTexture2D(GLenum(GL_FRAMEBUFFER),
                                   GLenum(GL_COLOR_ATTACHMENT0),
                                   GLenum(GL_TEXTURE_CUBE_MAP_POSITIVE_X + Int32(i)),
                                   cubeMapID,
                                   0);
            glClear(GLbitfield(GL_COLOR_BUFFER_BIT) | GLbitfield(GL_DEPTH_BUFFER_BIT))
            glUniform1i(faceIndexLoc, GLint(i))
            glUniform1i(cubeLayoutLoc, GLint(layout.rawValue))

            glDrawArrays(GLenum(GL_TRIANGLES), 0, 3)
            // Todo: Read the texture's pixel data and write out an image file.
            // Checking the output will tell us if a face needs to be flipped
            // horizontally or vertically.
        }
        // Remember to bind back the system provided framebuffer for macOS' OpenGL implementation.
        // For iOS's OpenGLES implementation, we must use the one created during a call to the
        // viewController method prepareView().
        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), _defaultFBOName)
        glBindVertexArray(0)

        // This texture name (or identifier) will be used in the draw() method.
        return cubeMapID
    }

    // A simple method to check for OpenGL specific errors.
    func checkGLErrors() {
        var glError: GLenum
        var hadError = false
        repeat {
            glError = glGetError()
            if glError != 0 {
                Swift.print(String(format: "OpenGL error %#x", glError))
                hadError = true
            }
        } while glError != 0
        assert(!hadError)
    }
}

