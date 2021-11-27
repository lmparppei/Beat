//
//  BeatCheckboxCell.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 22.11.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface BeatCheckboxCell : NSTableCellView
@property (nonatomic,strong) IBOutlet NSButton * _Nonnull checkbox;
@property (nonatomic,strong) IBOutlet NSTextField * _Nonnull pluginName;
@property (nonatomic) bool available;
@property (nonatomic) bool updateAvailable;
@property (nonatomic) bool enabled;
@property (nonatomic) NSURL * _Nullable URL;
@property (nonatomic) NSURL * _Nullable localURL;
@property (nonatomic) NSString * _Nonnull name;
@property (nonatomic) bool selected;
- (void)downloadComplete;
- (void)setSize;
- (void)select;
- (void)deselect;
@end

NS_ASSUME_NONNULL_END
