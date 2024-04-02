//
//  BeatTextView+FocusMode.h
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 1.4.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatTextView.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, BeatFocusModeType) {
	BeatFocusModeOff,
	BeatFocusModeSentence,
	BeatFocusModeBlock
};

@interface BeatTextView (FocusMode) <BeatSelectionObserver>
- (void)setupFocusMode;
- (IBAction)toggleFocusMode:(id)sender;
- (BOOL)validateFocusMode:(NSMenuItem*)menuItem;
@end

NS_ASSUME_NONNULL_END
