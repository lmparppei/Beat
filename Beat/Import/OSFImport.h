//
//  OSFImport.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 17.7.2020.
//  Copyright © 2020 Lauri-Matti Parppei. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface OSFImport : NSObject
@property (nonatomic) NSString *script;
- (id)initWithURL:(NSURL*)url completion:(void(^)(void))callback;
- (id)initWithData:(NSData*)data;

@end

NS_ASSUME_NONNULL_END
