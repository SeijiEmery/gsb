
module gsb.text.textrenderer;

import std.stdio;
import std.file;
import std.format;
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

class ResourceError : Error {
	this (T...) (string fmt, T args) {
		super(format(fmt, args));
	}
}

class StbFont {
	stbtt_fontinfo fontInfo;
	ubyte[] fontData;

	this (string filename) {
		if (1/* run at compile time */)
			return;

		if (!exists(filename) || !attrIsFile(getAttributes(filename)))
			throw new ResourceError("Cannot load font file '%s'", filename);

		fontData = cast(ubyte[])read(filename);
		if (fontData.length == 0)
			throw new ResourceError("Failed to load font file '%s'", filename);

		if (!stbtt_InitFont(&fontInfo, fontData.ptr, 0))
			throw new ResourceError("stb: Failed to load font '%s'", filename);
	}
	auto getScaleForPixelHeight (float height) {
		return stbtt_ScaleForPixelHeight(&fontInfo, height);
	}
}

class PackedFontAtlas {
	StbFont font;
	stbtt_pack_context packCtx;
	ubyte[] bitmapData; // single channel bitmap
	int width, height;

	stbtt_packedchar[] packedChars;
	int nextPackedChar = 0;

	this (StbFont _font, int textureWidth, int textureHeight) {
		if (_font is null)
			throw new ResourceError("null font");

		font = _font;
		width = textureWidth;
		height = textureHeight;
		bitmapData = new ubyte[width * height];

		if (!stbtt_PackBegin(&packCtx, bitmapData.ptr, width, height, 0, 1, null))
			throw new ResourceError("stbtt_PackBegin(...) failed");
	}
	void packRange (float fontSize, int firstUChar, int nchars) {
		auto data = &packedChars[nextPackedChar++];
		auto size = font.getScaleForPixelHeight(fontSize);
		stbtt_PackFontRange(&packCtx, font.fontData.ptr, 0, size, firstUChar, nchars, data);
	}

	~this () {
		stbtt_PackEnd(&packCtx);
	}
}

class RasterizedTextElement {
	PackedFontAtlas atlas;
	vec2 nextPos;
	vec2 bounds;
	public float depth = 0;
	public mat4 transform;

	private GlTexture bitmapTexture;

	this (PackedFontAtlas _atlas)
	in { assert(!(atlas is null)); }
	body {
		atlas = _atlas;
	}
}

class Log {
	string title;
	string[] lines;
	public bool writeToStdout = true;

	this (string title_) {
		title = title_;
	}

	void write (string msg) {
		lines ~= msg;
		if (writeToStdout) {
			writefln("[%s] %s", title, msg);
		}
	}
	void write (T...)(string msg, T args) {
		write(format(msg, args));
	}
}

//immutable string DEFAULT_FONT = "/Library/Fonts/Verdana.ttf";
//immutable string[string] DEFAULT_TYPEFACE = [
//	"default": "~/Library/Application Support/GLSandbox/fonts/Anonymous Pro.ttf",
//	"bold":    "~/Library/Application Support/GLSandbox/fonts/Anonymous Pro B.ttf",
//	"italic":  "~/Library/Application Support/GLSandbox/fonts/Anonymous Pro I.ttf",
//	"bolditalic": "~/Library/Application Support/GLSandbox/fonts/Anonymous Pro BI.ttf"
//];

class LogView {
	Log log;
	uint lastLineCount = 0;

	public vec2 bounds;
	public mat4 transform;

	BasicTextRenderer textRenderer = new BasicTextRenderer();

	vec2 currentTextBounds; // total bounds of layouted text
	vec2 nextLayoutPosition;

	vec2 viewPosition;      // current position (scroll, etc) in view

	this (Log _log)
	in { assert(!(_log is null)); }
	body {
		log = _log;
	}

	void render () {
		maybeUpdate();
		textRenderer.render();	
	}

	void maybeUpdate () {
		// TODO: Move this to async task; breakup logview / basictextrenderer into two parts:
		//	- async cpu-bound relayouting   (main thread => worker thread)
		//  - immediate gpu-bound rendering (gl thread)
		auto lines = log.lines;
		if (lastLineCount != lines.length) {
			for (auto i = lastLineCount; i < lines.length; ++i) {
				textRenderer.appendLine(log.lines[i]);
			}
			lastLineCount = lines.length;
		}
	}
	void render () {
		renderer.render();
	}
}

LogView setBounds (LogView view, float x, float y) {
	view.bounds.x = x;
	view.bounds.y = y;
	return view;
}
LogView setTransform (LogView view, mat4 transform) {
	view.transform = transform;
	return view;
}

class BasicTextRenderer {
	StbFont font = new StbFont("/Library/Fonts/Anonymous Pro.ttf");
	float   fontSize = 24;

	vec2 nextLayoutPosition;
	vec2 currentBounds;

	PackedFontAtlas atlas;
	auto shader = new TextShader();
	auto gbuffer = new TextGeometryBuffer();

	void render () {
		shader.bind();
		gbuffer.draw();
	}

	void appendLine (string line) {
		foreach (chr; line) {
			appendChar(chr);
		}
	}
	void appendChar (char chr) {
		if (chr == '\n') {
			nextLayoutPosition.y += // something...
			nextLayoutPosition.x = 0;
		} else {
			// get quad from atlas (atlas lazy loads char if not in charset)
			
			// do layout with quad and baseline, etc

			// push final quad + uvs to gbuffer (gbuffer.pushQuad(points, uvs))
		}
	}



}

class BasicTextLayouter {
	// tbd
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

		scale = stbtt_ScaleForPixelHeight(&font, 24);
		stbtt_GetFontVMetrics(&font, &ascent, null, null);
		baseline = cast(int)(ascent * scale);

		bitmapTexture = new GlTexture();
		ubyte[] bitmapData = new ubyte[512*512];
		stbtt_BakeFontBitmap(contents.ptr,0, 24.0, bitmapData.ptr,512,512, 32,96, chrdata.ptr);

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
	@output vec4 fragColor;

	@uniform sampler2D textureSampler;

	void main () {
		//fragColor = vec3(1.0, 0.2, 0.2) + 
		//			vec3(0.0, outCoords);

		vec4 color = texture(textureSampler, texCoord);
		fragColor = vec4(color.rgb, color.r);
	}
}
class TextShader {
	TextFragmentShader fs = null;
	TextVertexShader vs = null;
	Program!(TextVertexShader, TextFragmentShader) prog = null;

	void lazyInit ()
	in { assert(prog is null); }
	body {
		fs = new TextFragmentShader(); fs.compile(); CHECK_CALL("compiling text fragment shader");
		vs = new TextVertexShader();   vs.compile(); CHECK_CALL("compiling text vertex shader");
		prog = makeProgram(vs, fs); CHECK_CALL("compiling/linking text shader program");
	}

	void bind () {
		if (prog is null)
			lazyInit();
		glUseProgram(prog.id); CHECK_CALL("glUseProgram(text shader)");
	}
}
class TextGeometryBuffer {
	//uint gl_positionBuffer = 0;
	//uint gl_texcoordBuffer = 0;
	uint gl_vao = 0;
	uint[3] gl_buffers;

	vec3[] cachedPositionData;
	vec2[] cachedTexcoordData;
	vec4[] cachedColorData;

	bool dirtyPositionData = false;
	bool dirtyTexcoordData = false;
	bool dirtyColorData = false;

	void lazyInit ()
	in { assert(gl_vao == 0); }
	body {
		glGenVertexArrays(1, &gl_vao); CHECK_CALL("glGenVertexArray");
		glBindVertexArray(gl_vao); CHECK_CALL("glBindVertexArray");

		glGenBuffers(3, &gl_buffers[0]);  CHECK_CALL("glGenBuffers");

		glEnableVertexAttribArray(0); CHECK_CALL("glEnableVertexAttribArray")
		glBindBuffer(GL_ARRAY_BUFFER, gl_buffers[0]); CHECK_CALL("glBindBuffer");
		glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, null); CHECK_CALL("glVertexAttribPointer");

		glEnableVertexAttribArray(1); CHECK_CALL("glEnableVertexAttribArray")
		glBindBuffer(GL_ARRAY_BUFFER, gl_buffers[0]); CHECK_CALL("glBindBuffer");
		glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 0, null); CHECK_CALL("glVertexAttribPointer");

		glEnableVertexAttribArray(2); CHECK_CALL("glEnableVertexAttribArray")
		glBindBuffer(GL_ARRAY_BUFFER, gl_buffers[0]); CHECK_CALL("glBindBuffer");
		glVertexAttribPointer(2, 4, GL_FLOAT, GL_FALSE, 0, null); CHECK_CALL("glVertexAttribPointer");

		glBindVertexArray(0); CHECK_CALL("glBindVertexArray(0)");
	}
	~this () {
		if (gl_vao) {
			glDeleteVertexArrays(1, &gl_vao);
			glDeleteBuffers(3, &gl_buffers[0]);
		}
	}

	void pushQuad (vec2[4] points, vec2[4] uvs, float depth = 0) {
		cachedPositionData ~= vec3(points[0], depth);
		cachedPositionData ~= vec3(points[1], depth);
		cachedPositionData ~= vec3(points[2], depth);

		cachedPositionData ~= vec3(points[2], depth);
		cachedPositionData ~= vec3(points[1], depth);
		cachedPositionData ~= vec3(points[3], depth);

		cachedTexcoordData ~= uvs[0];
		cachedTexcoordData ~= uvs[1];
		cachedTexcoordData ~= uvs[2];

		cachedTexcoordData ~= uvs[2];
		cachedTexcoordData ~= uvs[1];
		cachedTexcoordData ~= uvs[3];

		dirtyPositionData = dirtyTexcoordData = true;
	}
	void clear () {
		dirtyPositionData = cachedPositionData.length != 0;
		dirtyTexcoordData = cachedPositionData.length != 0;
		cachedPositionData.length = 0;
		cachedTexcoordData.length = 0;
	}
	void flushChanges () {
		if (dirtyPositionData) {
			glBindBuffer(GL_ARRAY_BUFFER, gl_buffers[0]); CHECK_CALL("glBindBuffer");
			glBufferData(GL_ARRAY_BUFFER, cachedPositionData.length * 4, cachedPositionData.ptr, GL_STATIC_DRAW); 
			CHECK_CALL("glBufferData (TextGeometryBuffer.flushChanges() (quads))");
			dirtyPositionData = false;
		}
		if (dirtyTexcoordData) {
			glBindBuffer(GL_ARRAY_BUFFER, gl_buffers[1]); CHECK_CALL("glBindBuffer");
			glBufferData(GL_ARRAY_BUFFER, cachedTexcoordData.length * 4, cachedTexcoordData.ptr, GL_STATIC_DRAW); 
			CHECK_CALL("glBufferData (TextGeometryBuffer.flushChanges() (uvs))");
			dirtyTexcoordData = false;
		}
		if (dirtyColorData) {
			// Note: look into using vertex divisor for color data (ie. only upload 1 color per every quad (6 verts), not every vert...)
			glBindBuffer(GL_ARRAY_BUFFER, gl_buffers[2]); CHECK_CALL("glBindBuffer");
			glBufferData(GL_ARRAY_BUFFER, cachedColorData.length * 4, cachedColorData.ptr, GL_STATIC_DRAW);
			CHECK_CALL("glBufferData (TextGeometryBuffer.flushChanges() (colors))");
			dirtyColorData = false;
		}

	}

	void bind () {
		if (!gl_vao) lazyInit();
		flushChanges();
		glBindVertexArray(gl_vao); CHECK_CALL("glBindVertexArray (TextGeometryBuffer.bind())");
	}
	void draw () {
		if (cachedPositionData.length != 0) {
			bind();
			glDrawArrays(GL_TRIANGLES, 0, cast(int) cachedPositionData.length); CHECK_CALL("glDrawArrays (TextGeometryBuffer.draw())");
		}
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
































































