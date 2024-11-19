//
//  BeatImportModule.h
//  BeatFileExport
//
//  Created by Lauri-Matti Parppei on 14.11.2024.
//

#import <Foundation/Foundation.h>

@protocol BeatFileImportModule <NSObject>

@property (nonatomic, readonly) NSString* _Nullable fountain;
@property (nonatomic, copy, nullable) void (^callback)(id _Nullable);

- (id _Nonnull)initWithURL:(NSURL* _Nonnull)url options:(NSDictionary* _Nullable)options completion:(void(^ _Nullable)(id _Nullable))callback;

@optional

@property (nonatomic) bool asynchronous;
- (NSString* _Nullable)infoTitle;
- (NSString* _Nullable)infoMessage;

@end
