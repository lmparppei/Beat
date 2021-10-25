//
//  BeatPieGraph.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 25.10.2021.
//  Copyright © 2021 KAPITAN!. All rights reserved.
//

#import "BeatPieGraph.h"
#import "BeatColors.h"
#import <QuartzCore/QuartzCore.h>

@interface BeatPieGraph ()
@property (nonatomic) CAShapeLayer *pieLayer;
@end

@implementation BeatPieGraph

-(instancetype)initWithCoder:(NSCoder *)coder {
	self = [super initWithCoder:coder];
	
	if (self) {
		self.wantsLayer = YES;
		_pieLayer = [CAShapeLayer layer];
		CGRect rect = CGRectMake(3, 3, self.frame.size.width - 6, self.frame.size.height - 6);
		CGPathRef path = CGPathCreateWithEllipseInRect(rect, nil);
		
		CGAffineTransform transform = _pieLayer.affineTransform;
		[_pieLayer setAffineTransform:CGAffineTransformRotate(transform, 90)];
		
		_pieLayer.lineWidth = 3;
		_pieLayer.strokeColor = [BeatColors color:@"blue"].CGColor;
		_pieLayer.fillColor = nil;
		_pieLayer.path = path;
		self.layer = _pieLayer;
		CGPathRelease(path);
	}
	
	return self;
}

- (void)pieChartForData:(NSArray*)items {
	NSMutableDictionary *data = [NSMutableDictionary dictionary];
	NSInteger total = items.count;
	
	for (NSString *item in items) {
		if (data[item]) {
			NSInteger val = [(NSNumber*)data[item] integerValue];
			val++;
			data[item] = @(val);
		} else {
			data[item] = [NSNumber numberWithInteger:1];
		}
	}
	
	for (NSString* key in data.allKeys) {
		NSLog(@"%@ : %f", key, ((CGFloat)[(NSNumber*)data[key] integerValue] / (CGFloat)total));
	}
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    // Drawing code here.
}

@end
