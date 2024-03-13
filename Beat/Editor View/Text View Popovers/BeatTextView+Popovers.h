//
//  BeatTextView+Popovers.h
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 8.3.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatTextView.h"
#import "BeatTextView+ForceElement.h"
#import "BeatTextView+Tagging.h"

@interface BeatTextView (Popovers)

- (void)setupPopovers;
- (void)closePopovers;

- (void)showAutocompletions;

/// Inserts text from autocomplete popover
- (void)insertSelectedText;

/// Sets the tag selected from tag popover
- (void)setSelectedTag;

/// Shows selection info
- (IBAction)showInfo:(id)sender;

@end
