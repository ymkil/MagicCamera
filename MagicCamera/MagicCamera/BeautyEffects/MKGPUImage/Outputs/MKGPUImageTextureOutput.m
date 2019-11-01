//
//  MKGPUImageTextureOutput.m
//  MKBeautyEffectsDemo
//
//  Created by mkil on 2019/8/19.
//  Copyright © 2019 黎宁康. All rights reserved.
//

#import "MKGPUImageTextureOutput.h"

#import "MKGLProgram.h"
#import "MKGPUImageFramebuffer.h"

@interface MKGPUImageTextureOutput (){
    MKGPUImageFramebuffer *firstInputFramebuffer;
    
    MKGLProgram *dataProgram;
    GLint dataPositionAttribute, dataTextureCoordinateAttribute;
    GLint dataInputTextureUniform;
    
    GLuint framebuffer;
    GLint _texture;
    int _textureWidth;
    int _textureHeight;
}

@property (nonatomic, weak) MKGPUImageContext *context;
@property (nonatomic, assign) CGSize inputSize;

@end

@implementation MKGPUImageTextureOutput

- (instancetype)initWithContext:(MKGPUImageContext *)context
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    _context = context;
    
    runMSynchronouslyOnContextQueue(context, ^{
        [context useAsCurrentContext];
        dataProgram = [context programForVertexShaderString:kMKGPUImageVertexShaderString fragmentShaderString:kMKGPUImagePassthroughFragmentShaderString];
        
        if (!dataProgram.initialized)
        {
            if (![dataProgram link])
            {
                NSString *progLog = [dataProgram programLog];
                NSLog(@"Program link log: %@", progLog);
                NSString *fragLog = [dataProgram fragmentShaderLog];
                NSLog(@"Fragment shader compile log: %@", fragLog);
                NSString *vertLog = [dataProgram vertexShaderLog];
                NSLog(@"Vertex shader compile log: %@", vertLog);
                dataProgram = nil;
            }
        }
        
        dataPositionAttribute = [dataProgram attributeIndex:@"position"];
        dataTextureCoordinateAttribute = [dataProgram attributeIndex:@"inputTextureCoordinate"];
        dataInputTextureUniform = [dataProgram uniformIndex:@"inputImageTexture"];
    });
    
    return self;
}

#pragma mark -
#pragma mark Data access

- (void)renderAtInternalSize;
{
    [self.context useAsCurrentContext];
    [dataProgram use];
    
    glBindFramebuffer(GL_FRAMEBUFFER, framebuffer);
    glViewport(0, 0, _textureWidth, _textureHeight);
    
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    static const GLfloat squareVertices[] = {
        -1.0f, -1.0f,
        1.0f, -1.0f,
        -1.0f,  1.0f,
        1.0f,  1.0f,
    };
    
    glActiveTexture(GL_TEXTURE4);
    glBindTexture(GL_TEXTURE_2D, [firstInputFramebuffer texture]);
    glUniform1i(dataInputTextureUniform, 4);
    
    glVertexAttribPointer(dataPositionAttribute, 2, GL_FLOAT, 0, 0, squareVertices);
    glVertexAttribPointer(dataTextureCoordinateAttribute, 2, GL_FLOAT, 0, 0, [MKGPUImageFilter textureCoordinatesForRotation:self.rotateMode]);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    [firstInputFramebuffer unlock];
}

- (void)setOutputWithBGRATexture:(GLint)texture width:(int)width height:(int)height{
    _texture = texture;
    _textureWidth = width;
    _textureHeight = height;
    
    runMSynchronouslyOnContextQueue(self.context, ^{
        [self.context useAsCurrentContext];
        
        if (!framebuffer){
            glGenFramebuffers(1, &framebuffer);
        }
        glBindFramebuffer(GL_FRAMEBUFFER, framebuffer);
        
        glBindTexture(GL_TEXTURE_2D, _texture);
        
        //glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, _textureWidth, _textureHeight, 0, GL_BGRA, GL_UNSIGNED_BYTE, 0);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _texture, 0);
        
        glBindTexture(GL_TEXTURE_2D, 0);
        
    });
}

-(void)dealloc{
    runMSynchronouslyOnContextQueue(self.context, ^{
        [self.context useAsCurrentContext];
        
        if (framebuffer){
            glDeleteFramebuffers(1, &framebuffer);
            framebuffer = 0;
        }
    });
    
}


#pragma mark -
#pragma mark GPUImageInput protocol

- (void)setInputSize:(CGSize)newSize;
{
    
}

- (void)setInputFramebuffer:(MKGPUImageFramebuffer *)newInputFramebuffer atIndex:(NSInteger)textureIndex;
{
    firstInputFramebuffer = newInputFramebuffer;
    [firstInputFramebuffer lock];
}

- (void)newFrameReadyIndex:(NSInteger)textureIndex;
{
    runMSynchronouslyOnContextQueue(self.context, ^{
        [self.context useAsCurrentContext];
        
        [self renderAtInternalSize];
    });
}

@end
