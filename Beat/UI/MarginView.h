//
//  MarginView.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 15.5.2020.
//  Copyright © 2020 KAPITAN!. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "DynamicColor.h"

NS_ASSUME_NONNULL_BEGIN

@interface MarginView : NSView
@property (nonatomic) DynamicColor *backgroundColor;
@property (nonatomic) DynamicColor *marginColor;
@property (nonatomic) CGFloat insetWidth;
@property (nonatomic) CGFloat magnificationLevel;
@end

NS_ASSUME_NONNULL_END
