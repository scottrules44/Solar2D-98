//////////////////////////////////////////////////////////////////////////////
//
// This file is part of the Corona game engine.
// For overview and more information on licensing please refer to README.md 
// Home page: https://github.com/coronalabs/corona
// Contact: support@coronalabs.com
//
//////////////////////////////////////////////////////////////////////////////

#include "Core/Rtt_Build.h"

#include "Rtt_MacViewCallback.h"

#include "Rtt_Runtime.h"
#include "Display/Rtt_Display.h"
#include "Display/Rtt_Scene.h"

#import <AppKit/NSView.h>

#ifdef Rtt_MetalANGLE
#import "GLView.h"
#endif

// ----------------------------------------------------------------------------

namespace Rtt
{

// ----------------------------------------------------------------------------

MacViewCallback::MacViewCallback( NSView *view )
:	fView( view ),
	fRuntime( NULL )
{
}

void
MacViewCallback::operator()()
{
	Rtt_ASSERT( fRuntime );
	(*fRuntime)();

#ifdef Rtt_MetalANGLE
	// For MGLKView, setNeedsDisplay:YES does not reliably trigger drawRect:.
	// Call display directly to force immediate rendering when the scene is dirty.
	if ( ! fRuntime->GetDisplay().GetScene().IsValid() )
	{
		[(GLView*)fView display];
	}
#else
	if ( ! fRuntime->GetDisplay().GetScene().IsValid() )
	{
		[fView setNeedsDisplay:YES];
	}
#endif
}

// ----------------------------------------------------------------------------

} // namespace Rtt

// ----------------------------------------------------------------------------

