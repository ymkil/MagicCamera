//
//  MKGPUImageTextureInput.m
//  MagicCamera
//
//  Created by mkil on 2019/9/4.
//  Copyright © 2019 黎宁康. All rights reserved.
//

#import "MKGPUImageTextureInput.h"
#import "MKGPUImageFilter.h"

@interface MKGPUImageTextureInput()
{
    MKGLProgram *dataProgram;
    
    GLint dataPositionAttribute;
    GLint dataTextureCoordinateAttribute;
    
    GLint dataInputTextureUniform;
}

@end


@implementation MKGPUImageTextureInput

- (instancetype)initWithContext:(MKGPUImageContext *)context
{
    if (!(self = [super initWithContext:context])){
        return nil;
    }
    
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

- (void)processWithBGRATexture:(GLint)texture width:(int)width height:(int)height{
    runMSynchronouslyOnContextQueue(self.context, ^{
        [self.context useAsCurrentContext];
        [dataProgram use];
        
        if ([MKGPUImageFilter needExchangeWidthAndHeightWithRotation:self.rotateMode]) {
            outputFramebuffer = [[self.context framebufferCache] fetchFramebufferForSize:CGSizeMake(height, width) textureOptions:self.outputTextureOptions missCVPixelBuffer:YES];
        } else {
            outputFramebuffer = [[self.context framebufferCache] fetchFramebufferForSize:CGSizeMake(width, height) textureOptions:self.outputTextureOptions missCVPixelBuffer:YES];
        }
        [outputFramebuffer activateFramebuffer];
        
        glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        
        static const GLfloat squareVertices[] = {
            -1.0f, -1.0f,
            1.0f, -1.0f,
            -1.0f,  1.0f,
            1.0f,  1.0f,
        };
        
        
        glActiveTexture(GL_TEXTURE1);
        glBindTexture(GL_TEXTURE_2D, texture);
        glUniform1i(dataInputTextureUniform, 1);
        
        glVertexAttribPointer(dataPositionAttribute, 2, GL_FLOAT, 0, 0, squareVertices);
        glVertexAttribPointer(dataTextureCoordinateAttribute, 2, GL_FLOAT, 0, 0, [MKGPUImageFilter textureCoordinatesForRotation:self.rotateMode]);
        
        
        glEnableVertexAttribArray(dataPositionAttribute);
        glEnableVertexAttribArray(dataTextureCoordinateAttribute);
        
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
        
        for (id<MKGPUImageInput> currentTarget in targets)
        {
            if ([MKGPUImageFilter needExchangeWidthAndHeightWithRotation:self.rotateMode]) {
                [currentTarget setInputSize:CGSizeMake(height, width)];
            } else {
                [currentTarget setInputSize:CGSizeMake(width, height)];
            }
            NSInteger indexOfObject = [targets indexOfObject:currentTarget];
            [currentTarget setInputFramebuffer:outputFramebuffer atIndex:indexOfObject];
            [currentTarget newFrameReadyIndex:indexOfObject];
        }
        
        [outputFramebuffer unlock];
    });
    
}

@end
