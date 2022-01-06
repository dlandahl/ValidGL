
#import "Basic";
#load "../module.jai";
#import "GL";
#import "glfw";

Trembling_Vertex :: struct {
    // The names and locations of these sub-structs have to match the shader attributes in the GLSL code.
    position: struct {
        x: float;
        y: float;
        z: float;
    }

    colour: struct {
        r: float;
        g: float;
        b: float;
        a: float;
    }

    tremble: struct {
        amount: float;
    }

    // In the future we should have notes such as:
    // 
    //   attribute: struct {
    //       u, v: float;
    //   } @Location=4
    // 
    // To specify attribute locations.
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

    // This call generates asserts that validate that the shader inputs match the vertex struct.
    shader := create_shader(vertex_shader_text, fragment_shader_text, Trembling_Vertex);

    vertices := Trembling_Vertex.[
            .{ .{-0.8, -0.5, 0}, .{0, 1, 0, 1}, .{0.002} },
            .{ .{-0.8,  0.8, 0}, .{0, 0, 1, 1}, .{0.002} },
            .{ .{ 0.5,  0.8, 0}, .{1, 0, 0, 1}, .{0.002} },

            .{ .{-0.5, -0.8, 0}, .{1, 0, 0, 1}, .{0.005} },
            .{ .{ 0.8, -0.8, 0}, .{0, 0, 1, 1}, .{0.005} },
            .{ .{ 0.8,  0.5, 0}, .{0, 1, 0, 1}, .{0.005} },
    ];

    // This call infers the vertex format from the type of the array and generates calls to glVertexAttribPointer.
    vertex_buffer := create_vertex_buffer(vertices, verbose = true);

    while !glfwWindowShouldClose(window) {
        width, height : s32;
        glfwGetFramebufferSize(window, *width, *height);
        glViewport(0, 0, xx width, xx height);
        glClear(GL_COLOR_BUFFER_BIT);

        glUniform1f(0, cast(float) glfwGetTime());

        // This call only passes typechecking if both the shader and the buffer are getting validated against the same vertex format.
        draw(shader, vertex_buffer);

        glfwSwapBuffers(window);
        glfwPollEvents();
    }

    glfwDestroyWindow(window);
    glfwTerminate();
}



vertex_shader_text :: #string END
#version 430 core

layout (location = 0) in vec3  position;
layout (location = 1) in vec4  colour;
layout (location = 2) in float tremble;

layout (location = 1) out vec4 vertex_colour;
layout (location = 0) uniform float uni_time;

float random(float seed) {
    return sin(seed * (6543.6346 * position.x + 1449.62346 * position.y));
}

void main() {
    vec3 offset = vec3(random(uni_time), random(uni_time * 2.523), random(uni_time * 3.6342));
    gl_Position = vec4(position + offset * tremble, 1.0);
    vertex_colour = colour;
}
END



fragment_shader_text :: #string END
#version 430 core

layout (location = 1) in  vec4 vertex_colour;
layout (location = 0) out vec4 fragment_colour;

void main() {
    fragment_colour = vertex_colour;
}
END
