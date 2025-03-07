//
//  BeatImportModule.h
//  BeatFileExport
//
//  Created by Lauri-Matti Parppei on 14.11.2024.
//

#import <Foundation/Foundation.h>

/// Types for possible options for import module
typedef enum : NSUInteger {
    BeatFileImportModuleOptionTypeBool = 0,
    BeatFileImportModuleOptionTypeInteger,
    BeatFileImportModuleOptionTypeString
} BeatFileImportModuleOptionType;

@protocol BeatFileImportModule <NSObject>

@property (nonatomic, readonly) NSString* _Nullable fountain;
@property (nonatomic, copy, nullable) void (^callback)(NSString* _Nullable);

+ (NSArray<NSString*>* _Nonnull)formats;
+ (NSArray<NSString*>* _Nullable)UTIs;

- (id _Nonnull)initWithURL:(NSURL* _Nonnull)url options:(NSDictionary* _Nullable)options completion:(void(^ _Nullable)(NSString* _Nullable))callback;

@optional

/// Return `true` if this module can't provide the text synchronously and has to wait for the results
+ (bool)asynchronous;
/**
 WIP: Options for file import, as dictionary:
 ```
 { "optionName": { "title": "Option Description", "type": BeatFileImportModuleOptionType } }
 ```
 */
+ (NSDictionary<NSString*,NSDictionary*>* _Nullable)options;

+ (NSString* _Nullable)infoTitle;
+ (NSString* _Nullable)infoMessage;

@end
