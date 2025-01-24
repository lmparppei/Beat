//
//  BeatDocumentViewController+TextEvents.h
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 20.1.2025.
//  Copyright © 2025 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatDocumentViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface BeatDocumentViewController (TextEvents) <UITextViewDelegate>

/// Restores caret position from document settings
- (void)restoreCaret;
- (void)handleTabPress;

@end

NS_ASSUME_NONNULL_END
