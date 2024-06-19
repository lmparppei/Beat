//
//  BeatNotepad.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 21.10.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <BeatCore/BeatCore.h>
#import <JavaScriptCore/JavaScriptCore.h>

NS_ASSUME_NONNULL_BEGIN

@protocol BeatNotepadExports <JSExport>
@property (nonatomic) NSString* string;
JSExportAs(replaceRange, - (void)replaceRange:(NSInteger)position length:(NSInteger)length string:(NSString*)string color:(NSString*)colorName);
@end

@interface BeatNotepad : NSTextView <BeatNotepadExports, BeatTextChangeObservable>
@property (weak, nonatomic) IBOutlet id<BeatEditorDelegate> editorDelegate;
- (void)setup;
- (void)loadString:(NSString*)string;
@end

NS_ASSUME_NONNULL_END
