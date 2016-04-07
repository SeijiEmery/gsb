
module gsb.coregl.texture;
import gsb.coregl.batch;
import gsb.coregl.sharedimpl;

import gsb.core.mathutils;
import gsb.gl.state;

bool isValidTextureType (GLenum type) {
    return type == GL_TEXTURE_2D;
}
bool isValidTextureFormat (GLenum type) {
    return type == GL_RED || type == GL_RGB || type == GL_RGBA;
}

size_t glTexComponentSize ( GLenum internalType ) {
    switch (internalType) {
        default: return 0;
    }
}


class GLTexture2d : GLResource {
private:
    GLuint _id = 0;
    GLenum _format;
    uint   _width, _height;

    public @property auto id () { return _id; }
    public @property auto format () { return _format; }

public:
    this () {}
    void create () {
        if (!_id) {
            _id = 1;
            GLCommandBuffer.instance.pushImmediate({
                glchecked!glGenTextures(1, &_id);
                //glchecked!(glGenTextures, __FILE__, __LINE__, int, uint*)(1, &_id);
            });
        }
    }
    void release () {
        if (_id) {
            auto texid = _id; _id = 0;
            GLCommandBuffer.instance.pushImmediate({
                glchecked!glDeleteTextures(1, &texid);
            });
        }
    }
    void bind (uint textureUnit) {
        assert( id != 0 );
        GLCommandBuffer.instance.pushImmediate({
            glState.activeTexture( textureUnit );
            glState.bindTexture( GL_TEXTURE_2D, id );
        });
    }
    void setFiltering (GLenum minFilter, GLenum magFilter) {
        GLCommandBuffer.instance.pushImmediate({
            glState.bindTexture( GL_TEXTURE_2D, id );
            glchecked!glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, minFilter);
            glchecked!glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, magFilter);
        });
    }
    void setWrap () {

    }
    void bufferData (T)( GLenum internalFormat, GLenum type, uint imgWidth, uint imgHeight, T[] data, bool generateMipmaps = false ) {
        assert( data.length >= width * height * glTexComponentSize(type, internalFormat) );
        if (!id) create( format );

        if (imgWidth == _width && imgHeight == _height) {
            GLCommandBuffer.instance.pushImmediate({
                glState.bindTexture( id );
                checked_glTexSubImage2D( GL_TEXTURE_2D, 0, 0, 0, width, height, format, type, cast(void*)data.ptr );
                if (generateMipmaps) checked_glGenerateMipmap( GL_TEXTURE_2D );
            });
        } else {
            _width = imgWidth; _height = imgHeight;
            GLCommandBuffer.instance.pushImmediate({
                glState.bindTexture( id );
                checked_glTexImage2D( GL_TEXTURE_2D, 0, internalFormat, imgWidth, imgHeight, 0, format, type, cast(void*)data.ptr );
                if (generateMipmaps) checked_glGenerateMipmap( GL_TEXTURE_2D );
            });
        }
        textureDimensions.x = width;
        textureDimensions.y = height;
    }
}


































































