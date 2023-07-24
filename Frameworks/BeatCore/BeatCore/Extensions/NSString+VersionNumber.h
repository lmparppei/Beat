//
//  NSString+VersionNumber.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 27.11.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSString (VersionNumber)
- (NSString *)shortenedVersionNumberString;
- (bool)isNewerVersionThan:(NSString*)old;
@end

NS_ASSUME_NONNULL_END
