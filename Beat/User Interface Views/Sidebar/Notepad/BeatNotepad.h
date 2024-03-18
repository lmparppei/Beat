//
//  BeatNotepad.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 21.10.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <BeatCore/BeatCore.h>

NS_ASSUME_NONNULL_BEGIN

@interface BeatNotepad : NSTextView
@property (weak, nonatomic) IBOutlet id<BeatEditorDelegate> editorDelegate;
-(void)loadString:(NSString*)string;
@end

NS_ASSUME_NONNULL_END
