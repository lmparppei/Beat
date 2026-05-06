//
//  BeatTextView+SelectionEvents.h
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 24.8.2025.
//  Copyright © 2025 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatTextView.h"

NS_ASSUME_NONNULL_BEGIN

@interface BeatTextView (SelectionEvents)

/// Sets up main selection events (review + future metadata navigation)
- (void)setupSelectionEvents;

/// 
- (void)didChangeSelection:(NSNotification *)notification;

/// Register an event performed when selection changes. Please note that this is different from the main editor selection event. I don't really know why.
- (void)registerSelectionEvent:(void (^ _Nonnull)(NSRange))event;

@end

NS_ASSUME_NONNULL_END
