//
//  ColorView.m
//  Beat
//
//  Copyright © 2019 Lauri-Matti Parppei. All rights reserved.
//

#import "ColorView.h"

@implementation ColorView

-(void)awakeFromNib {
	self.wantsLayer = YES;
	self.layer.backgroundColor = self.fillColor.CGColor;
}


@end
