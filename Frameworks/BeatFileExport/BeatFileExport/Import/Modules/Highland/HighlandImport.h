//
//  HighlandImport.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 18.11.2020.
//  Copyright © 2020 Lauri-Matti Parppei. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface HighlandImport : NSObject
@property (nonatomic) NSString *script;
- (id)initWithURL:(NSURL*)url;
@end

NS_ASSUME_NONNULL_END
