// Sample shader for diff_patch unit tests (LF)
uniform sampler2D tex_source;
uniform float time;

const float BLUR_RADIUS = 5.0;

void main()
{
    vec4 color = texture2D(tex_source, gl_TexCoord[0].xy);
    gl_FragColor = color;
}
