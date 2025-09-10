//
//  BeatTextView+TypewriterMode.h
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 7.7.2025.
//  Copyright © 2025 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatTextView.h"

NS_ASSUME_NONNULL_BEGIN

@interface BeatTextView (TypewriterMode)

/// Updates the view with correct insets (this isn't the best way to do it but this is very, very legacy code, so whatever)
- (void)updateTypewriterView;
/// Scrolls text view to the current caret position
- (void)typewriterScroll;
/// Toggles the typewriter mode from menu
- (IBAction)toggleTypewriterMode:(id)sender;
 
@end

NS_ASSUME_NONNULL_END
