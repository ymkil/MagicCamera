//
//  MKGLProgram.h
//  MagicCamera
//
//  Created by mkil on 2019/9/4.
//  Copyright © 2019 黎宁康. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>

NS_ASSUME_NONNULL_BEGIN

@interface MKGLProgram : NSObject
{
    NSMutableArray  *attributes;
    NSMutableArray  *uniforms;
    GLuint          program,
    vertShader,
    fragShader;
}

@property(readwrite, nonatomic) BOOL initialized;
@property(readwrite, copy, nonatomic) NSString *vertexShaderLog;
@property(readwrite, copy, nonatomic) NSString *fragmentShaderLog;
@property(readwrite, copy, nonatomic) NSString *programLog;

- (id)initWithVertexShaderString:(NSString *)vShaderString
            fragmentShaderString:(NSString *)fShaderString;

- (GLuint)attributeIndex:(NSString *)attributeName;
- (GLuint)uniformIndex:(NSString *)uniformName;
- (BOOL)link;
- (void)use;
@end

NS_ASSUME_NONNULL_END
