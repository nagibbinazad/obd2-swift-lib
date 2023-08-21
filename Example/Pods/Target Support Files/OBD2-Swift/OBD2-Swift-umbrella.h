#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "OBD2Swift.h"

FOUNDATION_EXPORT double OBD2VersionNumber;
FOUNDATION_EXPORT const unsigned char OBD2VersionString[];

