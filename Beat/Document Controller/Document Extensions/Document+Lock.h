//
//  Document+Lock.h
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 25.4.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//

#import "Document.h"

NS_ASSUME_NONNULL_BEGIN

@interface Document (Lock)

- (void)showLockStatus;
- (bool)contentLocked;
- (void)lock;
- (void)unlock;
- (void)toggleLock;

@end

NS_ASSUME_NONNULL_END
