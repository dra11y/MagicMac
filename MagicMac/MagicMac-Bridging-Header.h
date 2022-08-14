#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

// UniversalAccess.framework
// /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/System/Library/PrivateFrameworks/UniversalAccess.framework/Versions/Current/UniversalAccess.tbd

bool UAWhiteOnBlackIsEnabled();
bool UAWhiteOnBlackSetEnabled(bool);
// _UAHoverTextIsEnabled

// Skylight.framework
// /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/System/Library/PrivateFrameworks/Skylight.framework/Versions/Current/Skylight.tbd

bool SLSGetAppearanceThemeLegacy();
void SLSSetAppearanceThemeLegacy(bool);

// https://github.com/rxhanson/Rectangle/blob/master/Rectangle/Rectangle-Bridging-Header.h

AXError _AXUIElementGetWindow(AXUIElementRef element, uint32_t *wid);


// https://github.com/koekeishiya/yabai/blob/master/src/misc/extern.h

extern int SLSMainConnectionID(void);
extern bool SLSManagedDisplayIsAnimating(int cid, CFStringRef uuid);
extern CGError SLSMoveWindow(int cid, uint32_t wid, CGPoint *point);
extern CGError SLSGetWindowBounds(int cid, uint32_t wid, CGRect *frame);
extern CGError SLSGetRevealedMenuBarBounds(CGRect *rect, int cid, uint64_t sid);
