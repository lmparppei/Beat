//
//  BeatTimeline.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 3.9.2020.
//  Copyright © 2020 KAPITAN!. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface BeatTimeline : NSView

@property (nonatomic) NSArray* outline;
- (void)reload:(NSArray*)scenes;

@end

NS_ASSUME_NONNULL_END
