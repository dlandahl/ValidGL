
#import "Basic";
#import "ValidGL";
#import "GL";
#import "glfw";

Jiggly_Coloured_Vertex :: struct {
    // The names and locations of these sub-structs have to match
    // the shader attributes in the GLSL code.
    attr_position: struct {
        x: float;
        y: float;
        z: float;
    }

    attr_colour: struct {
        r: float;
        g: float;
        b: float;
        a: float;
    }

    attr_jiggle: struct {
        amount: float;
    }

    /*
    In the future we should have notes such as:

      attribute: struct {
          u, v: float;
      } @Location=4

    To specify attribute locations.
    */
}

init :: (title: *u8) -> *GLFWwindow {
    glfwInit();
    window := glfwCreateWindow(640, 480, title, null, null);

    glfwMakeContextCurrent(window);
    gl_load(*gl, glfwGetProcAddress);

    return window;
}

main :: () {
    window := init("The fun colourful triangles");

    shader := create_shader(vertex_shader_text, fragment_shader_text, Jiggly_Coloured_Vertex);

    vertices := Jiggly_Coloured_Vertex.[
            .{ .{-0.5 - 0.3, -0.5      , 0}, .{0, 1, 0, 1}, .{0.05} },
            .{ .{-0.5 - 0.3,  0.5 + 0.3, 0}, .{0, 0, 1, 1}, .{0.05} },
            .{ .{ 0.5      ,  0.5 + 0.3, 0}, .{1, 0, 0, 1}, .{0.05} },

            .{ .{-0.5      , -0.5 - 0.3, 0}, .{1, 0, 0, 1}, .{0.01} },
            .{ .{ 0.5 + 0.3, -0.5 - 0.3, 0}, .{0, 0, 1, 1}, .{0.01} },
            .{ .{ 0.5 + 0.3,  0.5      , 0}, .{0, 1, 0, 1}, .{0.01} },
    ];

    // This call infers the format from the type of the array and generates calls to glVertexAttribPointer.
    vertex_buffer := create_vertex_buffer(vertices, verbose = true);

    while !glfwWindowShouldClose(window) {
        width, height : s32;
        glfwGetFramebufferSize(window, *width, *height);
        glViewport(0, 0, xx width, xx height);
        glClear(GL_COLOR_BUFFER_BIT);

        glUniform1f(0, cast(float) glfwGetTime());

        // This call only passes Jai typechecking if both the shader and the buffer are validated against the same vertex format.
        draw(shader, vertex_buffer);

        glfwSwapBuffers(window);
        glfwPollEvents();
    }

    glfwDestroyWindow(window);
    glfwTerminate();
}



/********VERTEX SHADER TEXT********/
vertex_shader_text :: #string END
#version 430 core

layout (location = 0) in vec3  attr_position;
layout (location = 1) in vec4  attr_colour;
layout (location = 2) in float attr_jiggle;

layout (location = 1) out vec4 vertex_colour;
layout (location = 0) uniform float uni_time;

float random(float seed) {
    return sin(seed * (6543.6346 * attr_position.x + 1449.62346 * attr_position.y));
}

void main() {
    vec3 offset = vec3(random(uni_time), random(uni_time * 2.523), random(uni_time * 3.6342));
    gl_Position = vec4(attr_position + offset * attr_jiggle, 1.0);
    vertex_colour = attr_colour;
}
END
/**********************************/



/*******FRAGMENT SHADER TEXT*******/
fragment_shader_text :: #string END
#version 430 core

layout (location = 1) in  vec4 vertex_colour;
layout (location = 0) out vec4 fragment_colour;

void main() {
    fragment_colour = vertex_colour;
}
END
/**********************************/
