//
//  BeatAppDelegate+AdditionalViews.h
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 21.10.2025.
//  Copyright © 2025 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatAppDelegate.h"

NS_ASSUME_NONNULL_BEGIN

@interface BeatAppDelegate (AdditionalViews)

/// Displays the basic launch screen
-(void)showLaunchScreen;

/// Displays templates in the main launch screen
-(void)showTemplates;

/// Sets up notifications for showing the launch screen
-(void)setupDocumentOpenListener;


@end

NS_ASSUME_NONNULL_END
