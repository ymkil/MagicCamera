//
//  MKGPUImageConstants.h
//  MagicCamera
//
//  Created by mkil on 2019/9/4.
//  Copyright © 2019 黎宁康. All rights reserved.
//

#ifndef MKGPUImageConstants_h
#define MKGPUImageConstants_h

#import <OpenGLES/ES2/gl.h>
#import <Foundation/Foundation.h>

#define MKGPUImageRotationSwapsWidthAndHeight(rotation) ((rotation) == kMKGPUImageRotateLeft || (rotation) == kMKGPUImageRotateRight || (rotation) == kMKGPUImageRotateRightFlipVertical || (rotation) == kMKGPUImageRotateRightFlipHorizontal)

typedef struct MKGPUTextureOptions {
    GLenum minFilter;
    GLenum magFilter;
    GLenum wrapS;
    GLenum wrapT;
    GLenum internalFormat;
    GLenum format;
    GLenum type;
} MKGPUTextureOptions;

typedef struct MKGPUVector4 {
    GLfloat one;
    GLfloat two;
    GLfloat three;
    GLfloat four;
} MKGPUVector4;

typedef struct MKGPUVector3 {
    GLfloat one;
    GLfloat two;
    GLfloat three;
} MKGPUVector3;

typedef struct MKGPUMatrix4x4 {
    MKGPUVector4 one;
    MKGPUVector4 two;
    MKGPUVector4 three;
    MKGPUVector4 four;
} MKGPUMatrix4x4;

typedef struct MKGPUMatrix3x3 {
    MKGPUVector3 one;
    MKGPUVector3 two;
    MKGPUVector3 three;
} MKGPUMatrix3x3;

typedef NS_ENUM(NSUInteger, MKGPUImageRotationMode) {
    kMKGPUImageNoRotation,
    kMKGPUImageRotateLeft,
    kMKGPUImageRotateRight,
    kMKGPUImageFlipVertical,
    kMKGPUImageFlipHorizonal,
    kMKGPUImageRotateRightFlipVertical,
    kMKGPUImageRotateRightFlipHorizontal,
    kMKGPUImageRotate180
};

#endif /* MKGPUImageConstants_h */
