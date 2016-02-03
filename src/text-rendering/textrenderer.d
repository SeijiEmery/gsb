
module gsb.text.textrenderer;

import std.stdio;
import std.file;
import stb.truetype;
import gsb.glutils;
import derelict.opengl3.gl3;
import dglsl;


class GlTexture {
	uint id;

	this () {
		glGenTextures(1, &id); CHECK_CALL("glGenTexture");
	}
	~this () {
		glDeleteTextures(1, &id); CHECK_CALL("glDeleteTexture");
	}
}

class Font {
	stbtt_fontinfo font;
	float scale;
	int ascent, baseline;
	GlTexture bitmapTexture = null;
	stbtt_bakedchar[96] chrdata;

	this (string filename) {
		ubyte[] contents = cast(ubyte[])read(filename);
		stbtt_InitFont(&font, &contents[0], 0);

		scale = stbtt_ScaleForPixelHeight(&font, 40);
		stbtt_GetFontVMetrics(&font, &ascent, null, null);
		baseline = cast(int)(ascent * scale);

		bitmapTexture = new GlTexture();
		ubyte[] bitmapData = new ubyte[512*512];
		stbtt_BakeFontBitmap(contents.ptr,0, 40.0, bitmapData.ptr,512,512, 32,96, chrdata.ptr);

		writeln("Finished loading font");

		glActiveTexture(GL_TEXTURE0); CHECK_CALL("glActiveTexture");
		glBindTexture(GL_TEXTURE_2D, bitmapTexture.id); CHECK_CALL("glBindTexture");
		//glTexStorage2D(GL_TEXTURE_2D, 1, GL_RGBA8, 512,512); CHECK_CALL("glTexStorage2D");
		//glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, 512,512, GL_RGBA, GL_UNSIGNED_BYTE, bitmapData.ptr); CHECK_CALL("glTexSubImage2D");
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RED, 512,512, 0, GL_RED, GL_UNSIGNED_BYTE, bitmapData.ptr); CHECK_CALL("glTexImage2D");
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR); CHECK_CALL("set gl texture parameter MIN_FILTER=GL_LINEAR");
		glBindTexture(GL_TEXTURE_2D, 0); CHECK_CALL("glBindTexture");
	}

	//GLTexture getFontTexture () {
	//	if (!bitmapTexture) {
	//		bitmapTexture = new GlTexture();

	//		ubyte[] buffer = new ubyte[1<<20];
	//		ubyte[] bitmapData = new ubyte[512*512];
	//		stbtt_BakeFontBitmap(buffer, 0, 32.0, bitmapData,512,512, 32,96, cdata)


	//		glBindTexture()
	//	}
	//}
}

Font loadFont (string filename) {
	if (!exists(filename) || !attrIsFile(getAttributes(filename))) {
		writefln("Cannot open '%s'", filename);
		return null;
	}
	writefln("Loading font '%s'", filename);
	return new Font(filename);
}

class TextVertexShader: Shader!Vertex {
	@layout(location=0)
	@input vec3 textPosition;

	@layout(location=1)
	@input vec2 bitmapCoords;

	@output vec2 texCoord;

	void main () {
		gl_Position = vec4(textPosition, 1.0);
		//gl_Position = vec4(
		//	textPosition.x * (1.0 / 800.0),
		//	textPosition.y * (1.0 / 600.0),
		//	0.0, 1.0);
		texCoord = bitmapCoords;
	}
}
class TextFragmentShader: Shader!Fragment {
	@input vec2 texCoord;
	@output vec3 fragColor;

	@uniform sampler2D textureSampler;

	void main () {
		//fragColor = vec3(1.0, 0.2, 0.2) + 
		//			vec3(0.0, outCoords);

		fragColor = texture(textureSampler, texCoord).rgb;
	}
}


class TextBuffer {
	Font font;
	float[] quads;
	float[] uvs;
	float x = 0, y = 0;
	float y_baseline = 0;
	float x_origin = 0, y_origin = 0;
	bool data_needs_rebuffering = false;

	this (Font _font) {
		font = _font;
	}
	void appendText (string text) {

		writefln("appending text: '%s'", text);

		quads.reserve(quads.length + text.length * 6);
		uvs.reserve(quads.length + text.length * 6);

		foreach (chr; text) {
			if (chr >= 32 && chr < 128) {
				stbtt_aligned_quad q;
				//writeln("Getting baked quad");
				stbtt_GetBakedQuad(font.chrdata.ptr, 512,512, chr-32, &x,&y,&q,1);
				//writeln("got baked quad");

				//quads ~= [
				//	q.x0, q.y0,
				//	q.x1, q.y0,
				//	q.x0, q.y0,

				//	q.x1, q.y1,
				//	q.x0, q.y1,
				//	q.x0, q.y0
				//];

				quads ~= [
					q.x1 / 800.0, -q.y0 / 600.0, 0.0,
					q.x0 / 800.0, -q.y1 / 600.0, 0.0,
					q.x1 / 800.0, -q.y1 / 600.0, 0.0,

					q.x0 / 800.0, -q.y1 / 600.0, 0.0,
					q.x0 / 800.0, -q.y0 / 600.0, 0.0,
					q.x1 / 800.0, -q.y0 / 600.0, 0.0

					//q.x1 / 200.0, q.y1 / 150.0, 0.0,
					//q.x1 / 200.0, q.y0 / 150.0, 0.0,
					//q.x1 / 200.0, q.y0 / 150.0, 0.0

					//q.x1 / 400.0, q.y0 / 300.0, 1.0,
					//q.x0 / 400.0, q.y1 / 300.0, 1.0,
					//q.x1 / 400.0, q.y1 / 300.0, 1.0,
				];
				uvs ~= [
					q.s1, q.t0,
					q.s0, q.t1,
					q.s1, q.t1,

					q.s0, q.t1,
					q.s0, q.t0,
					q.s1, q.t0
				];

				//writefln("quad coords %s: %0.2f, %0.2f, %0.2f, %0.2f", chr, q.x0, q.y0, q.x1, q.y1);
			} 
			else if (chr == '\n') {
				x = x_origin;
				y = (y_baseline += font.baseline);
			}
		}
		data_needs_rebuffering = true;
	}
	void clear () {
		quads.length = 0;
		uvs.length = 0;

		x = x_origin;
		y = y_origin;
		y_baseline = y_origin;
	}
	
	TextFragmentShader fs = null;
	TextVertexShader vs = null;
	Program!(TextVertexShader,TextFragmentShader) program = null;

	uint quadBuffer = 0;
	uint uvBuffer = 0;
	uint vao = 0;

	void render (Camera camera) {
		if (quadBuffer == 0) {
			writeln("Loading textrenderer gl stuff");

			fs = new TextFragmentShader(); fs.compile(); CHECK_CALL("new TextRenderer.FragmentShader()");
			vs = new TextVertexShader(); vs.compile(); CHECK_CALL("new TextRenderer.VertexShader()");
			program = makeProgram(vs, fs); CHECK_CALL("Compiled/linked TextRenderer shaders");

			glActiveTexture(GL_TEXTURE0); CHECK_CALL("glActiveTexture");
			glBindTexture(GL_TEXTURE_2D, font.bitmapTexture.id); CHECK_CALL("glBindTexture");
			auto loc = glGetUniformLocation(program.id, "textureSampler"); CHECK_CALL("glGetUniformLocation");
			writefln("texture uniform = %d", loc);
			glUniform1i(loc, 0); CHECK_CALL("glUniform1i");
			//program.tex = 0; CHECK_CALL("program.texture_sampler_uniform = 0");

			glGenVertexArrays(1, &vao); CHECK_CALL("glGenVertexArrays (tr vao)");
			glBindVertexArray(vao); CHECK_CALL("glBindVertexArray (tr vao)");
			glEnableVertexAttribArray(0); CHECK_CALL("glEnableVertexAttribArray (tr vao)");
			glEnableVertexAttribArray(1); CHECK_CALL("glEnableVertexAttribArray (tr vao)");

			glGenBuffers(1, &quadBuffer); CHECK_CALL("glGenBuffer (tr quad buffer)");
			glBindBuffer(GL_ARRAY_BUFFER, quadBuffer); CHECK_CALL("glBindBuffer (tr quad buffer)");
			glBufferData(GL_ARRAY_BUFFER, quads.length * 4, quads.ptr, GL_STATIC_DRAW); CHECK_CALL("glBufferData (tr quad buffer)");
			glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, null); CHECK_CALL("glVertexAttribPointer (tr quad buffer)");

			glGenBuffers(1, &uvBuffer); CHECK_CALL("glGenBuffer (tr uv buffer)");
			glBindBuffer(GL_ARRAY_BUFFER, uvBuffer); CHECK_CALL("glBindBuffer (tr uv buffer)");
			glBufferData(GL_ARRAY_BUFFER, uvs.length * 4, uvs.ptr, GL_STATIC_DRAW); CHECK_CALL("glBufferData (tr uv buffer)");
			glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 0, null); CHECK_CALL("glVertexAttribPointer (tr uv buffer)");

			glBindVertexArray(0); CHECK_CALL("glBindVertexArray (unbinding textrenderer vao)");

			data_needs_rebuffering = false;
		} else if (data_needs_rebuffering) {

			glBindBuffer(GL_ARRAY_BUFFER, quadBuffer); CHECK_CALL("glBindBuffer (rebinding tr quad buffer)");
			glBufferData(GL_ARRAY_BUFFER, quads.length * 4, quads.ptr, GL_STATIC_DRAW); CHECK_CALL("glBufferData (rebuffering tr quad buffer)");

			glBindBuffer(GL_ARRAY_BUFFER, uvBuffer); CHECK_CALL("glBindBuffer (rebinding text uvs)");
			glBufferData(GL_ARRAY_BUFFER, uvs.length * 4, uvs.ptr, GL_STATIC_DRAW); CHECK_CALL("glBufferData (rebuffering text uvs)");

			data_needs_rebuffering = false;
		}
		glActiveTexture(GL_TEXTURE0); CHECK_CALL("glActiveTexture");
		glBindTexture(GL_TEXTURE_2D, font.bitmapTexture.id); CHECK_CALL("glBindTexture");

		glUseProgram(program.id); CHECK_CALL("glUseProgram");
		glBindVertexArray(vao); CHECK_CALL("glBindVertexArray");
		glDrawArrays(GL_TRIANGLES, 0, cast(int)quads.length / 3); CHECK_CALL("glDrawArrays");
	}
}
































































