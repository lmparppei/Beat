//
//  TouchTimelinePopover.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 28.5.2020.
//  Copyright © 2020 Lauri-Matti Parppei. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "TouchTimelineView.h"

NS_ASSUME_NONNULL_BEGIN

@interface TouchTimelinePopover : NSPopoverTouchBarItem
@property (weak) IBOutlet TouchTimelineView* timeline;
@end

NS_ASSUME_NONNULL_END
