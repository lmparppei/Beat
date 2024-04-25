//
//  BeatTextView+ForceElement.h
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 8.3.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatTextView.h"

NS_ASSUME_NONNULL_BEGIN

@interface BeatTextView (ForceElement)

/// Displays force element menu
- (void)showForceElementMenu;
- (void)forceLineTypeWithName:(NSString*)string;

@end

NS_ASSUME_NONNULL_END
