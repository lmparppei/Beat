//
//  BeatMarkerScroller.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 11.10.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <BeatCore/BeatCore.h>

NS_ASSUME_NONNULL_BEGIN

@interface BeatMarkerScroller : NSScroller
@property (nonatomic, weak) IBOutlet id<BeatEditorDelegate> editorDelegate;
@end

NS_ASSUME_NONNULL_END
