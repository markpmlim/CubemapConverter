#ifdef GL_ES
precision mediump float;
#endif

#if __VERSION__ >= 140
in vec2 texCoords;

out vec4 FragColor;

#else

in vec2 texCoords;

#endif

uniform sampler2D image;

uniform int faceIndex;

uniform int graphicType;

// OpenGL has a radians() function.
vec2 rotate2d(vec2 uv, float angle) {
    float s = sin(radians(angle));
    float c = cos(radians(angle));
    return mat2(c, -s, s, c) * uv;
}

/*
 Assume we have a 4x3 canvas consisting of 12 squares each having
 an area of 1x1 squared unit. In other words, the entire canvas is a
 rectangular grid of 12 squared units.
 We are only interested in 6 of those squares which make up the
 horizontal cross. We map the input uv to one of these 6 squares.
 Then we scale the resulting uv by 4x3 which can then be used to
 access the texture which has a resolution of 4:3.
 We are using a texture with dimensions 2048 by 1536 pixels.
 (4x512 by 3x512)
 */
vec2 mappingTo4by3(vec2 uv, int faceIndex) {
    // The coords of bottom left corner of 6 faces of the horizontal cross.
    const vec2 translateVectors[6] = vec2[6](vec2(2.0, 1.0),    // bottom left of face +X
                                             vec2(0.0, 1.0),    // bottom left of face -X
                                             vec2(1.0, 2.0),    // bottom left of face +Y
                                             vec2(1.0, 0.0),    // bottom left of face -Y
                                             vec2(1.0, 1.0),    // bottom left of face +Z
                                             vec2(3.0, 1.0));   // bottom left of face -Z
    // The pixels must be rotated 180 degrees first
    // Convert the range of the incoming uv from [0.0, 1.0] to [-1.0, 1.0]
    uv = 2.0 * uv - 1.0;
    uv = rotate2d(uv, 180.0);
    // Convert the range back to [0.0, 1.0]
    uv = (uv + 1.0) * 0.5;
    // Need to flip horizontally
    uv.x = 1.0 - uv.x;

    // Map it to a point on a 4:3 quad made up of 12 squares of 1x1 unit squared.
    uv += translateVectors[faceIndex];
    // Scale it down so that we can access the pixels of the texture passed as a uniform.
    uv /= vec2(4.0, 3.0);

    return uv;
}

/*
 We are using a texture with dimensions 1536 by 2048 pixels.
 (3x512 by 4x512)
 */
vec2 mappingTo3by4(vec2 uv, int faceIndex) {
    // The coords of bottom left corner of 6 faces of the vertical cross.
    const vec2 translateVectors[6] = vec2[6](vec2(2.0, 2.0),    // bottom left of face +X
                                             vec2(0.0, 2.0),    // bottom left of face -X
                                             vec2(1.0, 3.0),    // bottom left of face +Y
                                             vec2(1.0, 1.0),    // bottom left of face -Y
                                             vec2(1.0, 2.0),    // bottom left of face +Z
                                             vec2(1.0, 0.0));   // bottom left of face -Z
    // No need to rotate face 5 (-Z) but have to flip horizontally.
    if (faceIndex != 5) {
        uv = 2.0 * uv - 1.0;
        uv = rotate2d(uv, 180.0);
        uv = (uv + 1.0) * 0.5;
    }
    uv.x = 1.0 - uv.x;

    // Map it to a point on a 3:4 quad made up of 12 squares of 1x1 unit squared.
    uv += translateVectors[faceIndex];
    // Scale it down so that we can access the pixels of the texture passed as a uniform.
    uv /= vec2(3.0, 4.0);
    
    return uv;
    
}
void main(void) {
    vec2 uv = vec2(0.0);
    if (graphicType == 1)
        uv = mappingTo4by3(texCoords, faceIndex);
    else
        uv = mappingTo3by4(texCoords, faceIndex);
#if __VERSION__ >= 140
    FragColor = texture(image, uv);
#else
    gl_FragColor = texture2D(image, uv);
#endif
}
