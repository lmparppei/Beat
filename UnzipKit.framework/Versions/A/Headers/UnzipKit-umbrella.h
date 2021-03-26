#ifdef __OBJC__
#import <Cocoa/Cocoa.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "UnzipKit.h"
#import "UZKArchive.h"
#import "UZKFileInfo.h"

FOUNDATION_EXPORT double UnzipKitVersionNumber;
FOUNDATION_EXPORT const unsigned char UnzipKitVersionString[];

