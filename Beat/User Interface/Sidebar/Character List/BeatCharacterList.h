//
//  BeatCharacterList.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 22.10.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <BeatCore/BeatEditorDelegate.h>
#import "BeatSidebarTabView.h"

NS_ASSUME_NONNULL_BEGIN

@interface BeatCharacterList : NSTableView <NSTableViewDataSource, NSTableViewDelegate, BeatEditorView>

@property (nonatomic, weak) IBOutlet id<BeatEditorDelegate> editorDelegate;

@end

NS_ASSUME_NONNULL_END
