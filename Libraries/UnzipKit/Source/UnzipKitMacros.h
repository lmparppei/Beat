//
//  UnzipKitMacros.h
//  UnzipKit
//
//  Created by Dov Frankel on 7/10/17.
//  Copyright © 2017 Abbey Code. All rights reserved.
//

#ifndef UnzipKitMacros_h
#define UnzipKitMacros_h

#import "TargetConditionals.h"

//#import "Availability.h"
//#import "AvailabilityInternal.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundef"
#pragma clang diagnostic ignored "-Wgnu-zero-variadic-macro-arguments"


#if TARGET_OS_IPHONE
#define SDK_10_13_MAJOR 11
#define SDK_10_13_MINOR 0
#else
#define SDK_10_13_MAJOR 10
#define SDK_10_13_MINOR 13
#endif

// iOS 10, macOS 10.12, tvOS 10.0, watchOS 3.0
#define UNIFIED_LOGGING_SUPPORTED \
    __IPHONE_OS_VERSION_MIN_REQUIRED >= 100000 \
    || __MAC_OS_X_VERSION_MIN_REQUIRED >= 101200 \
    || __TV_OS_VERSION_MIN_REQUIRED >= 100000 \
    || __WATCH_OS_VERSION_MIN_REQUIRED >= 30000

#if UNIFIED_LOGGING_SUPPORTED
@import os.log;
@import os.activity;

// Called from +[UnzipKit initialize] and +[UZKArchiveTestCase setUp]
extern os_log_t unzipkit_log; // Declared in UZKArchive.m
extern BOOL unzipkitIsAtLeast10_13SDK; // Declared in UZKArchive.m
#define UZKLogInit() unzipkit_log = os_log_create("com.abbey-code.UnzipKit", "General"); \
    \
    NSOperatingSystemVersion minVersion; \
    minVersion.majorVersion = SDK_10_13_MAJOR; \
    minVersion.minorVersion = SDK_10_13_MINOR; \
    minVersion.patchVersion = 0; \
    unzipkitIsAtLeast10_13SDK = [[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:minVersion]; \
    UZKLogDebug("Is >= 10.13 (or iOS 11): %@", unzipkitIsAtLeast10_13SDK ? @"YES" : @"NO");

#define UZKLog(format, ...)      os_log(unzipkit_log, format, ##__VA_ARGS__);
#define UZKLogInfo(format, ...)  os_log_info(unzipkit_log, format, ##__VA_ARGS__);
#define UZKLogDebug(format, ...) os_log_debug(unzipkit_log, format, ##__VA_ARGS__);


#define UZKLogError(format, ...) \
    if (unzipkitIsAtLeast10_13SDK) os_log_error(unzipkit_log, format, ##__VA_ARGS__); \
    else os_log_with_type(unzipkit_log, OS_LOG_TYPE_ERROR, format, ##__VA_ARGS__);

#define UZKLogFault(format, ...) \
    if (unzipkitIsAtLeast10_13SDK) os_log_fault(unzipkit_log, format, ##__VA_ARGS__); \
    else os_log_with_type(unzipkit_log, OS_LOG_TYPE_FAULT, format, ##__VA_ARGS__);


#define UZKCreateActivity(name) \
    os_activity_t activity = os_activity_create(name, OS_ACTIVITY_CURRENT, OS_ACTIVITY_FLAG_DEFAULT); \
    os_activity_scope(activity);


#else // Fall back to regular NSLog

// No-op, as nothing needs to be initialized
#define UZKLogInit() (void)0


// Only used below
#define _removeLogFormatTokens(format) [[[@format \
    stringByReplacingOccurrencesOfString:@"{public}" withString:@""] \
    stringByReplacingOccurrencesOfString:@"{time_t}" withString:@""] \
    stringByReplacingOccurrencesOfString:@"{iec-bytes}" withString:@""]
#define _stringify(a) #a
#define _nsLogWithoutWarnings(format, ...) \
    _Pragma( _stringify( clang diagnostic push ) ) \
    _Pragma( _stringify( clang diagnostic ignored "-Wformat-nonliteral" ) ) \
    _Pragma( _stringify( clang diagnostic ignored "-Wformat-security" ) ) \
    NSLog(_removeLogFormatTokens(format), ##__VA_ARGS__); \
    _Pragma( _stringify( clang diagnostic pop ) )

// All levels do the same thing
#define UZKLog(format, ...)      _nsLogWithoutWarnings(format, ##__VA_ARGS__);
#define UZKLogInfo(format, ...)  _nsLogWithoutWarnings(format, ##__VA_ARGS__);
#define UZKLogDebug(format, ...) _nsLogWithoutWarnings(format, ##__VA_ARGS__);
#define UZKLogError(format, ...) _nsLogWithoutWarnings(format, ##__VA_ARGS__);
#define UZKLogFault(format, ...) _nsLogWithoutWarnings(format, ##__VA_ARGS__);

// No-op, as no equivalent to Activities exists
#define UZKCreateActivity(name) (void)0

#endif


#pragma clang diagnostic pop

#endif /* UnzipKitMacros_h */
