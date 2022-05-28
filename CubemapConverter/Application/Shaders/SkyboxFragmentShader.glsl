

#ifdef GL_ES
precision mediump float;
#endif

#if __VERSION__ >= 140
in vec2 texCoords;

out vec4 FragColor;

#else

in vec2 texCoords;

#endif

uniform samplerCube cubemap;
uniform vec2 u_resolution;  // Canvas size (width, height)
uniform vec2 u_mouse;       // mouse position in screen pixels
uniform float u_time;       // Time in seconds since load

#define iResolution u_resolution
#define iMouse      u_mouse
#define iTime       u_time
const float PI = 3.14159265359;

void main(void) {
    // [0, width] & [0, height]
    vec2 fragCoord = vec2(gl_FragCoord.xy);
    vec2 mouseUV = iMouse;
    if (mouseUV == vec2(0.0, 0.0))
        mouseUV = vec2(iResolution/2.0);
    // rotX
    // 1) Get mouse position between 0 and 1
    // 2) Multiply by 2pi
    // rotX varies between 0 and 2π
    // rotY varies between 0 and π
    // 0 at left side, 2π at right
    float rotX = (mouseUV.x / iResolution.x) * 2.0 * PI;
    float rotY = (mouseUV.y / iResolution.y) * PI;

    // Calculate the camera's orientation
    vec3 camO = vec3(cos(rotX), cos(rotY), sin(rotX));

    // The forward vector
    vec3 camD = normalize(vec3(0) - camO);

    // The vec3(0, 1, 0) does not have to be perpendicular to camD.
    // The right vector is orthogonal to both camD and vec3(0, 1, 0).
    vec3 camR = normalize(cross(camD, vec3(0, 1, 0)));

    // Calculate the UP vector wrt to the camera (no need to normalize
    // since the right and forward vectors are already unit vectors.)
    // The vectors camD, camR and camU are mutually orthogonal vectors.
    // These 3 vectors can form a set of orthonormal basis vectors.
    vec3 camU = cross(camR, camD);

    vec2 uv = 2.5 * (fragCoord.xy - 0.5 * iResolution.xy) / iResolution.xx;

    // Compute the ray direction
    vec3 dir =  normalize(camD + uv.x * camR + uv.y * camU);
    dir.z = -dir.z;

#if __VERSION__ >= 140
    FragColor = texture(cubemap, dir);
#else
    gl_FragColor = textureCube(cubemap, dir);
#endif
}
