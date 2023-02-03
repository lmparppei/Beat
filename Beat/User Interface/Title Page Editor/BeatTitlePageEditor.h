//
//  BeatTitlePageEditor.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 21.5.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <BeatCore/BeatEditorDelegate.h>

NS_ASSUME_NONNULL_BEGIN

@interface BeatTitlePageEditor : NSWindowController <NSControlTextEditingDelegate>
@property (nonatomic) NSString *result;
- (instancetype)initWithDelegate:(id<BeatEditorDelegate>)delegate;
@end

NS_ASSUME_NONNULL_END
