//
//  TrelbyImport.h
//  BeatFileExport
//
//  Created by Lauri-Matti Parppei on 3.9.2024.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TrelbyImport : NSObject
@property (nonatomic) NSString *script;
- (id)initWithURL:(NSURL*)url;
@end

NS_ASSUME_NONNULL_END
