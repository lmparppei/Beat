//
//  BeatPaginationElements.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 11.12.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatPaginationElements.h"
#import "BeatFonts.h"

@protocol BeatPageDelegate <NSObject>
@property (nonatomic, readonly) BeatFonts *fonts;
@end

@interface BeatPaginationView ()
@property (nonatomic) id<BeatPageDelegate> delegate;
@property (nonatomic) CGFloat maxHeight;
@property (nonatomic) NSMutableArray<BeatPaginationBlock*>* blocks;
@end

@implementation BeatPaginationView

@end
