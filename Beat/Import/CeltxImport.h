//
//  CeltxImport.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 16.11.2020.
//  Copyright © 2020 Lauri-Matti Parppei. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface CeltxImport : NSObject {
	NSMutableString *element;
	NSMutableString *content;
}
@property (nonatomic) NSString *script;
- (instancetype)initWithURL:(NSURL*)url;
@end

NS_ASSUME_NONNULL_END
