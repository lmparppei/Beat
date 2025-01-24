//
//  BeatDocumentViewController+KeyboardEvents.h
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 23.1.2025.
//  Copyright © 2025 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatDocumentViewController.h"

@protocol KeyboardManagerDelegate;

@interface BeatDocumentViewController (KeyboardEvents) <KeyboardManagerDelegate>
- (void)setupKeyboardObserver;
@end
