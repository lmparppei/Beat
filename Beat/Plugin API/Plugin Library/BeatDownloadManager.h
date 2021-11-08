//
//  BeatAboutScreen.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 9.1.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface BeatDownloadManager : NSWindowController
@property (nonatomic) IBOutlet NSOutlineView *pluginView;
- (void)show;
@end

NS_ASSUME_NONNULL_END
