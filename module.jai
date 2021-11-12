
/*
Explanation:

Specify your OpenGL vertex format using a regular struct. For example:

  Vertex :: struct {
      position: struct { x, y, z: float; }
      normal:   struct { x, y, z: float; }
      texture:  struct { u, v: float; }
  }

When creating a vertex buffer, this is used to automatically generate
calls to "glVertexAttribPointer" with the correct strides, offsets, etc.
It is also used to validate the attributes in your shader, by using the
names of the struct fields (type_info) with the OpenGL introspection API.

When drawing, the vertex buffer and shader can be statically typechecked
based on the vertex formats they have been validated against. Trying to
draw to the screen using a shader and buffer that do not have matching
vertex formats is a compile-time type error.

If the vertex format matches but is not declared correctly in GLSL, then
this is a run-time assertion failure when compiling the shader.

Apart from being less fiddly and bug-prone, it's also just a nice API
design to take a regular struct from your CPU language and have a
function for specifying that layout to the GPU. It demonstrates a bunch
of Jai meta-features in a way that's not over-zealous.
*/

Vertex_Buffer :: struct(Vertex_Format: Type) {
    handle: u32;
}

Shader :: struct(Vertex_Format: Type) {
    handle: u32;
}

draw :: (shader: Shader($Vertex_Format), buffer: Vertex_Buffer(Vertex_Format)) {
    glUseProgram(shader.handle);
    glBindVertexArray(buffer.handle);

    attribute_count: s32;
    glGetIntegerv(GL_MAX_VERTEX_ATTRIBS, *attribute_count);

    vertex_count: u32;
    for 0..attribute_count-1 {
        vbo: s32;
        glGetVertexAttribiv(cast(u32) it, GL_VERTEX_ATTRIB_ARRAY_BUFFER_BINDING, *vbo);

        if (vbo > 0) {
            glBindBuffer(GL_ARRAY_BUFFER, cast(u32) vbo);
            buffer_size: s32;
            glGetBufferParameteriv(GL_ARRAY_BUFFER, GL_BUFFER_SIZE, *buffer_size);

            vertex_count = cast(u32) buffer_size / size_of(Vertex_Format);
            break;
        }
    }

    glDrawArrays(GL_TRIANGLES, 0, vertex_count);
}

validate_vertex_format :: ($Vertex_Format: Type) {
    vertex_format := type_info(Vertex_Format);
    for vertex_format.members {
        location := compiler_get_struct_location(get_current_workspace(), vertex_format);

        if it.type.type != .STRUCT {
            format := "Vertex formats only support having structs as attributes, but \"%\" is of type \"%\".";
            error := tprint(format, it.name, it.type.type);
            compiler_report(error, location);
        }

        vertex_attribute := cast(*Type_Info_Struct) it.type;
        size := vertex_attribute.members.count;

        if size < 1 || size > 4 {
            error := "Vertex attributes must have 1 - 4 values.";
            compiler_report(error, location);
        }

        for vertex_attribute.members {
            if it.type.type != .FLOAT || it.type.runtime_size != 4 {
                error := "At the moment, vertex attributes can only contain float 32s.";
                compiler_report(error, location);
            }
        }
    }
}

create_vertex_buffer :: (vertices: [] $Vertex_Format, $verbose := false) -> Vertex_Buffer(Vertex_Format) {
    vao: u32;
    glGenVertexArrays(1, *vao);
    glBindVertexArray(vao);

    vbo: u32;
    glGenBuffers(1, *vbo);
    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, vertices.count * size_of(Vertex_Format), vertices.data, GL_STATIC_DRAW);

    #run validate_vertex_format(Vertex_Format);

    #insert #run (verbose: bool) -> string {
        if verbose print("Generating attributes for vertex format \"%\".\n", Vertex_Format);

        to_insert: String_Builder;
        init_string_builder(*to_insert);
        vertex_format := type_info(Vertex_Format);

        offset: int;
        for vertex_format.members {
            vertex_attribute := cast(*Type_Info_Struct) it.type;
            size := vertex_attribute.members.count;

            format_string := "glVertexAttribPointer(%, %, GL_FLOAT, GL_FALSE, %, cast(*void) %);\n";
            append(*to_insert, tprint(format_string, it_index, size, size_of(Vertex_Format), offset));
            append(*to_insert, tprint("glEnableVertexAttribArray(%);\n", it_index));

            if verbose {
                print("Vertex attribute no.%:\t\"%\"\toffset is %,\tsize is %.\n", it_index, it.name, offset, size);
            }
            offset += it.type.runtime_size;
        }

        if verbose print("\n");
        return builder_to_string(*to_insert);
    }(verbose);

    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindVertexArray(0);

    vertex_buffer: Vertex_Buffer(Vertex_Format);
    vertex_buffer.handle = vao;
    return vertex_buffer;
}

create_shader :: (vertex_text: string, fragment_text: string, $Vertex_Format: Type) -> Shader(Vertex_Format) {
    compile_shader_stage :: (source_code: string, stage: u32) -> u32 {
        shader := glCreateShader(stage);
        _glShaderSource(shader, source_code);
        glCompileShader(shader);

        success: s32;
        glGetShaderiv(shader, GL_COMPILE_STATUS, *success);
        if success == 0 {
            message: [512] u8;
            glGetShaderInfoLog(shader, 512, null, *message[0]);
            text: [] u8 = message;
            print("%", cast(string) text);
        }

        return shader;
    }

    #run validate_vertex_format(Vertex_Format);

    vertex_shader   := compile_shader_stage(vertex_text,   GL_VERTEX_SHADER  );
    fragment_shader := compile_shader_stage(fragment_text, GL_FRAGMENT_SHADER);

    program := glCreateProgram();
    glAttachShader(program, vertex_shader);
    glAttachShader(program, fragment_shader);
    glLinkProgram(program);

    glDeleteShader(vertex_shader);
    glDeleteShader(fragment_shader);

    #insert #run () -> string {
        attributes: String_Builder;
        init_string_builder(*attributes);
        vertex_format := type_info(Vertex_Format);

        for vertex_format.members {
            vertex_attribute := cast(*Type_Info_Struct) it.type;
            size := vertex_attribute.members.count;

            /* Way more checks should be done here... and they should be optional so that they can be disabled in a release build. */

            append(*attributes, tprint("__attr%: GLint = glGetAttribLocation(program, \"%\");\n", it_index, it.name));
            append(*attributes, tprint("assert(__attr% != -1, \"Attribute \\\"%\\\" from vertex format \\\"%\\\" is not represented in the shader. (This can be cause by unused attributes as well.)\");\n", it_index, it.name, vertex_format.name));
            append(*attributes, tprint("assert(__attr% == %, \"Attribute \\\"%\\\" from vertex format \\\"%\\\" is at location %, but in the shader it is at a different location.\");\n", it_index, it_index, it.name, vertex_format.name, it_index));
        }

        return builder_to_string(*attributes);
    }();

    shader: Shader(Vertex_Format);
    shader.handle = program;
    return shader;
}



#scope_module

#import "Basic";
#import "Compiler";
#import "GL";
