//
//  BeatCharacterView.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 22.10.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface BeatCharacterView : NSTableCellView
@property (nonatomic, weak) IBOutlet NSTextField *name;
@end

NS_ASSUME_NONNULL_END
