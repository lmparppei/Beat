//
//  TrelbyImport.h
//  BeatFileExport
//
//  Created by Lauri-Matti Parppei on 3.9.2024.
//

#import <Foundation/Foundation.h>
#import <BeatFileExport/BeatImportModule.h>

NS_ASSUME_NONNULL_BEGIN

@interface TrelbyImport : NSObject <BeatFileImportModule>
@property (nonatomic) NSString *script;
@property (nonatomic) NSString *fountain;
@property (nonatomic, copy, nullable) void (^callback)(id _Nullable);
- (id)initWithURL:(NSURL *)url options:(NSDictionary * _Nullable)options completion:(void (^ _Nullable)(id _Nullable))callback;

@end

NS_ASSUME_NONNULL_END
