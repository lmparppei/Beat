//
//  BeatSegmentedControl.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 21.10.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface BeatSegmentedControl : NSSegmentedControl <NSAnimationDelegate, NSTabViewDelegate>
@property (nonatomic, weak) IBOutlet NSTabView *tabView;
@end

NS_ASSUME_NONNULL_END
