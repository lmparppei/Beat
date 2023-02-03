//
//  MarginView.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 15.5.2020.
//  Copyright © 2020 Lauri-Matti Parppei. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <BeatCore/BeatEditorDelegate.h>

NS_ASSUME_NONNULL_BEGIN

@class DynamicColor;
@interface MarginView : NSView
@property (nonatomic, weak) IBOutlet id<BeatEditorDelegate> editor;
@property (nonatomic, weak) DynamicColor *backgroundColor;
@property (nonatomic, weak) DynamicColor *marginColor;
- (void)updateBackground;
@end

NS_ASSUME_NONNULL_END
