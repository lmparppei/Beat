//
//  BeatAppDelegate+Backups.h
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 21.10.2025.
//  Copyright © 2025 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatAppDelegate.h"

NS_ASSUME_NONNULL_BEGIN

@interface BeatAppDelegate (Backups)

/// Adds backup menu items and management actions to given menu
- (void)addBackupMenuItemsTo:(NSMenu*)menu;


@end

NS_ASSUME_NONNULL_END
