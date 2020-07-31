//
//  OSFImport.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 17.7.2020.
//  Copyright © 2020 KAPITAN!. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface OSFImport : NSObject

- (id)initWithURL:(NSURL*)url completion:(void(^)(void))callback;

@end

NS_ASSUME_NONNULL_END
