//
//  TouchBarTimeline.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 15.5.2020.
//  Copyright © 2020 KAPITAN!. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface TouchBarTimeline : NSScrubber <NSScrubberDataSource>

@property (nonatomic) NSArray *scenes;

- (void)reload:(NSString*)json;

@end

NS_ASSUME_NONNULL_END
