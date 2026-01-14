//////////////////////////////////////////////////////////////////////////////
//
// This file is part of the Corona game engine.
// For overview and more information on licensing please refer to README.md
// Home page: https://github.com/coronalabs/corona
// Contact: support@coronalabs.com
//
//////////////////////////////////////////////////////////////////////////////

#ifndef Rtt_MacGLView_H
#define Rtt_MacGLView_H

#import <AppKit/AppKit.h>

#ifdef Rtt_MetalANGLE
    #import <MetalANGLE/MGLKit.h>

    // MetalANGLE base class (MGLKView inherits from NSView on macOS)
    #define Rtt_GLViewBaseClass MGLKView

    typedef MGLContext Rtt_GLContext;
    typedef MGLLayer Rtt_GLLayer;

    #define Rtt_GLDepthFormat24 MGLDrawableDepthFormat24
    #define Rtt_GLMultisample4X MGLDrawableMultisample4X
    #define Rtt_GLMultisampleNone MGLDrawableMultisampleNone

#else
    #import <OpenGL/gl.h>
    #import <AppKit/NSOpenGL.h>
    #import <AppKit/NSOpenGLView.h>

    // OpenGL base class
    #define Rtt_GLViewBaseClass NSOpenGLView

    typedef NSOpenGLContext Rtt_GLContext;
    typedef CALayer Rtt_GLLayer; // NSOpenGLView uses regular CALayer

    // These are not directly comparable, just for compatibility
    #define Rtt_GLDepthFormat24 16  // NSOpenGLPFADepthSize value
    #define Rtt_GLMultisample4X 4
    #define Rtt_GLMultisampleNone 0

#endif

// ----------------------------------------------------------------------------

#endif // Rtt_MacGLView_H
