//
//  BeatEditorFormattingActions.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 9.6.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <BeatParsing/BeatParsing.h>
#import <BeatCore/BeatCore.h>

#import "BeatModalInput.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, BeatFormatting) {
	Block = 0,
	Bold,
	Italic,
	Underline,
	Note
};

@interface BeatEditorFormattingActions : NSResponder
@property (nonatomic, weak) IBOutlet id<BeatEditorDelegate> delegate;
- (void)forceElement:(LineType)lineType;
@end

NS_ASSUME_NONNULL_END
