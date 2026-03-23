//////////////////////////////////////////////////////////////////////////////
//
// This file is part of the Corona game engine.
// For overview and more information on licensing please refer to README.md
// Home page: https://github.com/coronalabs/corona
// Contact: support@coronalabs.com
//
//////////////////////////////////////////////////////////////////////////////

#import <Cocoa/Cocoa.h>
#include <unistd.h>

int main(int argc, char *argv[])
{
    @autoreleasepool {
        // Dual-binary renderer selection: the app bundle contains two executables —
        // "Corona Simulator" (OpenGL) and "Corona Simulator-Metal" (MetalANGLE).
        // Check the user preference and execv() the correct binary if needed.
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        BOOL wantsMetal = [defaults boolForKey:@"useMetalANGLE"];

        NSString *execPath = [[NSBundle mainBundle] executablePath];
        BOOL isMetal = [execPath hasSuffix:@"-Metal"];

        if (wantsMetal != isMetal) {
            NSString *bundleMacOS = [[[NSBundle mainBundle] bundlePath]
                stringByAppendingPathComponent:@"Contents/MacOS"];
            NSString *targetBinary = wantsMetal
                ? [bundleMacOS stringByAppendingPathComponent:@"Corona Simulator-Metal"]
                : [bundleMacOS stringByAppendingPathComponent:@"Corona Simulator"];

            if ([[NSFileManager defaultManager] isExecutableFileAtPath:targetBinary]) {
                execv([targetBinary fileSystemRepresentation], argv);
                // execv() only returns on failure — fall through to launch current binary
            }
        }
    }
    return NSApplicationMain(argc, (const char **)argv);
}
