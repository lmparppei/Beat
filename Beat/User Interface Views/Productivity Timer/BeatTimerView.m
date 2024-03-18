//
//  BeatTimerView.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 11.7.2020.
//  Copyright © 2020 Lauri-Matti Parppei. All rights reserved.
//

#import <BeatThemes/BeatThemes.h>
#import <QuartzCore/QuartzCore.h>
#import <BeatCore/BeatColors.h>

#import "BeatTimerView.h"
#import "ScrollView.h"

@interface BeatTimerView ()
@property (nonatomic, weak) IBOutlet ScrollView *parentView;
@property (nonatomic) bool mouseOver;
@property (nonatomic) CAShapeLayer *shapeLayer;

@end
@implementation BeatTimerView

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
}

-(void)update {
	if (!_shapeLayer) {
		//NSAffineTransform *transform =  [NSAffineTransform transform];
		_shapeLayer = [CAShapeLayer layer];
		CGRect rect = CGRectMake(3, 3, self.frame.size.width - 6, self.frame.size.height - 6);
		CGPathRef path = CGPathCreateWithEllipseInRect(rect, nil);
		
		CGAffineTransform transform = _shapeLayer.affineTransform;
		[_shapeLayer setAffineTransform:CGAffineTransformRotate(transform, 90)];
		
		_shapeLayer.lineWidth = 3;
		_shapeLayer.strokeColor = [[BeatColors color:@"blue"] CGColor];
		_shapeLayer.fillColor = nil;
		_shapeLayer.path = path;
		self.layer = _shapeLayer;
		CGPathRelease(path);
	}
	
	if (!_finished) {
		_shapeLayer.strokeStart = 0;
		_shapeLayer.strokeEnd = _progress;
	} else {
		_shapeLayer.strokeStart = 0;
		_shapeLayer.strokeEnd = 1;
		_shapeLayer.strokeColor = [[BeatColors color:@"blue"] CGColor];
		
		CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"opacity"];
		animation.duration = 0.5;
		animation.fromValue = [NSNumber numberWithFloat:1.0];
		animation.toValue = [NSNumber numberWithFloat:0.0];
		animation.repeatCount = 10.0;
		animation.autoreverses = YES;
		
		[_shapeLayer addAnimation:animation forKey:@"fillColor"];
	}
}
-(void)start {
	_shapeLayer.strokeEnd = 0.0;
	_shapeLayer.strokeStart = 1;
	_progress = 1;
	[_shapeLayer removeAllAnimations];
	[_parentView timerDidStart];
}
-(void)finish {
	// Show even if hidden
	[self.animator setAlphaValue:1.0];

	_finished = YES;
	[self update];
}
-(void)reset {
	_finished = NO;
	_progress = 0;
	_shapeLayer.strokeEnd = 0.0;
	_shapeLayer.strokeStart = 0.0;
	[_shapeLayer removeAllAnimations];
	[self setNeedsDisplay:YES];
}

-(void)mouseDown:(NSEvent *)event {
	[self.delegate showTimer];
}
-(void)mouseEntered:(NSEvent *)event {
	_mouseOver = YES;
}
-(void)mouseExited:(NSEvent *)event {
	_mouseOver = NO;
}

@end
