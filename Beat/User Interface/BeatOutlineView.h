//
//  BeatOutlineView.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 07/10/2019.
//  Copyright © 2019 KAPITAN!. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface BeatOutlineView : NSOutlineView
@property (nonatomic) NSInteger currentScene;
@property (weak) IBOutlet NSTouchBar *touchBar;
@end

NS_ASSUME_NONNULL_END
