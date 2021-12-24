//
//  NSImage+ProportionalScaling.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 23.12.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSImage (ProportionalScaling)
- (NSImage*)imageByScalingProportionallyToSize:(NSSize)targetSize;
@end

NS_ASSUME_NONNULL_END
