//
//  BeatiOSFormatting.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 14.5.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <BeatCore/BeatEditorDelegate.h>

NS_ASSUME_NONNULL_BEGIN

@interface BeatiOSFormatting : NSObject
+ (CGFloat)editorLineHeight;

@property (nonatomic) id<BeatEditorDelegate> delegate;

- (void)formatLine:(Line*)line;
- (void)formatLine:(Line*)line firstTime:(bool)firstTime;
- (void)renderBackgroundForLine:(Line*)line clearFirst:(bool)clear;
- (UITextRange*)getTextRangeFor:(NSRange)range;
@end

NS_ASSUME_NONNULL_END
