//
//  BeatEditorFormatting.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 15.2.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BeatEditorDelegate.h"

NS_ASSUME_NONNULL_BEGIN

typedef enum {
	titlePageSubField = typeCount + 1,
	subSection
} ParagraphStyleType;

@interface BeatEditorFormatting : NSObject
+ (CGFloat)editorLineHeight;

@property (nonatomic) id<BeatEditorDelegate> delegate;

- (void)formatLine:(Line*)line;
- (void)formatLine:(Line*)line firstTime:(bool)firstTime;
- (void)renderBackgroundForLine:(Line*)line clearFirst:(bool)clear;
- (void)initialTextBackgroundRender;
//- (void)updateTypingAttributes;
@end

NS_ASSUME_NONNULL_END
