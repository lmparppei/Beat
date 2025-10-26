//
//  BeatAppDelegate+Templates.h
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 21.10.2025.
//  Copyright © 2025 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatAppDelegate.h"

NS_ASSUME_NONNULL_BEGIN

@interface BeatAppDelegate (Templates)

/// Opens a template file with the given name
- (void)showTemplate:(NSString*)name;

@end

NS_ASSUME_NONNULL_END
