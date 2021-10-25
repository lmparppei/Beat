//
//  BeatCharacterList.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 22.10.2021.
//  Copyright © 2021 KAPITAN!. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "BeatEditorDelegate.h"
#import "BeatSidebarTabView.h"

NS_ASSUME_NONNULL_BEGIN

@interface BeatCharacterList : NSTableView <NSTableViewDataSource, NSTableViewDelegate, BeatReloadableView>

@property (nonatomic, weak) IBOutlet id<BeatEditorDelegate> editorDelegate;
-(void)reloadInBackground;
-(bool)visibleInTab;
@end

NS_ASSUME_NONNULL_END
