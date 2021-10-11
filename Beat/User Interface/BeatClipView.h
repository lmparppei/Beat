//
//  BeatClipView.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 9.10.2021.
//  Copyright © 2021 KAPITAN!. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "BeatEditorDelegate.h"

NS_ASSUME_NONNULL_BEGIN

@interface BeatClipView : NSClipView
@property (nonatomic, weak) IBOutlet id<BeatEditorDelegate> editorDelegate;
@end

NS_ASSUME_NONNULL_END
