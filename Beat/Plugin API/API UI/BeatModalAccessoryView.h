//
//  BeatModalItem.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 7.8.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface BeatModalAccessoryView : NSView
@property (nonatomic) NSMutableDictionary *fields;
- (void)addView:(NSView *)view;
- (void)addField:(NSDictionary*)item;
- (CGFloat)heightForItems;
- (NSDictionary*)valuesForFields;
@end

NS_ASSUME_NONNULL_END
