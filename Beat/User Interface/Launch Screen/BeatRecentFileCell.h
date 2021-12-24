//
//  BeatRecentFileCell.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 22.12.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface BeatRecentFileCell : NSTableCellView
@property (weak) IBOutlet NSTextField *filename;
@property (weak) IBOutlet NSTextField *date;
@end

NS_ASSUME_NONNULL_END
