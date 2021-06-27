//
//  BDMCheckboxCell.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 18.4.2021.
//  Copyright © 2021 KAPITAN!. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface BDMCheckboxCell : NSTableCellView
@property (nonatomic,strong) IBOutlet NSButton * _Nonnull checkbox;
@property (nonatomic,strong) IBOutlet NSTextField * _Nonnull pluginName;
@property (nonatomic,strong) IBOutlet NSTextField * _Nonnull pluginText;
@property (nonatomic,strong) IBOutlet NSButton * _Nonnull downloadButton;
@property (nonatomic) bool available;
@property (nonatomic) bool updateAvailable;
@property (nonatomic) bool enabled;
@property (nonatomic) NSURL * _Nullable URL;
@property (nonatomic) NSURL * _Nullable localURL;
@property (nonatomic) NSString * _Nonnull name;
@property (nonatomic) NSString * _Nullable info;
@property (nonatomic) NSString * _Nullable copyright;
@property (nonatomic) NSString * _Nullable version;
@property (nonatomic) CGFloat rowHeight;
- (void)downloadComplete;
-(void)setSize;
@end

