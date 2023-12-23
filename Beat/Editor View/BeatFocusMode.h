//
//  BeatFocusMode.h
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 23.12.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <BeatCore/BeatEditorDelegate.h>

NS_ASSUME_NONNULL_BEGIN

@interface BeatFocusMode : NSObject
- (instancetype)initWithDelegate:(id<BeatEditorDelegate>)delegate;
- (void)toggle;
@end

NS_ASSUME_NONNULL_END
