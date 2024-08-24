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

@interface BeatNotepadView : BeatNotepad <BeatNotepadExports, BeatTextChangeObservable>
@end

NS_ASSUME_NONNULL_END
