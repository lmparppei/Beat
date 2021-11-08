//
//  TouchTimelinePopover.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 28.5.2020.
//  Copyright © 2020 Lauri-Matti Parppei. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN
@protocol TouchPopoverDelegate <NSObject>
- (void)touchPopoverDidShow;
- (void)touchPopoverDidHide;
@end
@interface TouchTimelinePopover : NSPopoverTouchBarItem
@property (weak) id <TouchPopoverDelegate> delegate;
@end

NS_ASSUME_NONNULL_END
