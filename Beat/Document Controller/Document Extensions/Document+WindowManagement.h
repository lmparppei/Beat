//
//  Document+WindowManagement.h
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 18.3.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//

#import "Document.h"

NS_ASSUME_NONNULL_BEGIN

@interface Document (WindowManagement) <NSWindowDelegate>

- (void)setupWindow;
- (void)setMinimumWindowSize;
/// Registers an additional editor view/panel
- (void)registerWindow:(NSWindow*)window owner:(id)owner;
/// Restores sidebar status on launch
- (void)restoreSidebar;

@end

NS_ASSUME_NONNULL_END
