//
//  BeatModalItem.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 7.8.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import <TargetConditionals.h>

#if !TARGET_OS_IOS
#import <Cocoa/Cocoa.h>
// macOS
@interface BeatModalAccessoryView : NSView
@property (nonatomic) NSMutableDictionary *fields;
- (void)addView:(NSView *)view;
- (void)addField:(NSDictionary*)item;
- (CGFloat)heightForItems;
- (NSDictionary*)valuesForFields;
@end

#else
#import <UIKit/UIKit.h>
// iOS
@interface BeatModalAccessoryView : UIView
@end

#endif

