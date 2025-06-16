//
//  BeatPieGraph.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 25.10.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatPieGraph.h"
#import <BeatCore/BeatColors.h>
#import <BeatCore/BeatCore-Swift.h>
#import <QuartzCore/QuartzCore.h>
#import <BeatThemes/BeatThemes.h>

@interface BeatPieGraph ()
@property (nonatomic, weak) IBOutlet NSTextField *textField;
@property (nonatomic) NSMutableArray<CAShapeLayer*> *graphLayers;
@property (nonatomic) NSDictionary<NSString*, NSColor*> *colors;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *heightConstraint;
@property (nonatomic) CGFloat fullHeight;
@property (nonatomic) bool expanded;
@end

@implementation BeatPieGraph

-(instancetype)initWithFrame:(NSRect)frameRect {
	self = [super initWithFrame:frameRect];
	[self setup];
	return self;
}
-(instancetype)initWithCoder:(NSCoder *)coder {
	self = [super initWithCoder:coder];
	[self setup];
	return self;
}

-(void)awakeFromNib {
	// Collapse by default
	_expanded = true;
	//_fullHeight = _heightConstraint.constant;
	//[_heightConstraint setConstant:0.0];
	self.wantsLayer = true;
}

- (void)setup {
	self.wantsLayer = YES;
	self.graphLayers = [NSMutableArray array];
	self.colors = @{
		@"woman": ThemeManager.sharedManager.genderWomanColor,
		@"man": ThemeManager.sharedManager.genderManColor,
		@"other": ThemeManager.sharedManager.genderOtherColor,
		@"unspecified": ThemeManager.sharedManager.genderUnspecifiedColor
	};

}

- (IBAction)show:(id)sender {
	/*
	_expanded = !_expanded;
	
	if (_expanded) {
		[_heightConstraint.animator setConstant:_fullHeight];
	} else {
		[_heightConstraint.animator setConstant:0.0];
	}
	 */
}

- (void)clearChart {
	for (CAShapeLayer *layer in _graphLayers) {
		[layer removeFromSuperlayer];
	}
	[_graphLayers removeAllObjects];
}

- (void)pieChartForData:(NSArray*)items {
	NSMutableDictionary *data = NSMutableDictionary.new;
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
	
	if (!data.count) {
		_textField.stringValue = @"No characters";
		[self clearChart];
		return;
	}
		
	NSArray *sortedValues = [data keysSortedByValueUsingComparator:^NSComparisonResult(id obj1, id obj2){
		return [obj2 compare:obj1];
	}];
	
	NSInteger i = 0;
	CGFloat offset = 0;
	
	CGFloat fullHeight = self.frame.size.height;
	CGFloat height = fullHeight * .7;
		
	NSMutableAttributedString *attrStr = NSMutableAttributedString.new;
	
	for (NSString * key in sortedValues) {
		CGFloat percentage = ((CGFloat)[(NSNumber*)data[key] integerValue] / (CGFloat)total);
		CAShapeLayer *graphLayer;
		
		if (i == _graphLayers.count) {
			graphLayer = CAShapeLayer.layer;
			
			CGRect rect = CGRectMake((fullHeight - height) / 2 + 8, (fullHeight - height) / 2, height, height);
			CGPathRef path = CGPathCreateWithEllipseInRect(rect, nil);
			
			graphLayer.lineWidth = 12.0;
			graphLayer.fillColor = nil;
			graphLayer.path = path;
			graphLayer.strokeStart = 0;
			
			[self.layer insertSublayer:graphLayer atIndex:0];
			[_graphLayers addObject:graphLayer];
			
			CGPathRelease(path);
		} else {
			graphLayer = _graphLayers[i];
		}
		
		graphLayer.strokeEnd = offset + percentage;
		graphLayer.strokeColor = _colors[key].CGColor;
		
		NSString *localizationKey = [NSString stringWithFormat:@"gender.%@", key];
		NSString *displayName = NSLocalizedString(localizationKey, nil);
		
		[attrStr appendAttributedString:[NSAttributedString.alloc initWithString:[NSString stringWithFormat:@"%@ %lu%%", displayName, (NSInteger)ceil(percentage * 100)] attributes:@{
			NSForegroundColorAttributeName: _colors[key]
		}]];
		
		if (key != sortedValues.lastObject) [attrStr appendString:@"\n"];
		
		offset += percentage;
		i++;
	}
	
	_textField.attributedStringValue = attrStr;
	
	if (i < _graphLayers.count - 1) {
		while (_graphLayers.count >= i && _graphLayers.count > 0) {
			CAShapeLayer *excessLayer = _graphLayers.lastObject;
			[excessLayer removeFromSuperlayer];
			[_graphLayers removeLastObject];
		}
	}
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
}

@end
/*
 
 Hur kan vi vara fridfulla nar vi skapar sån misär
 Hur kan vi vara kärleksfulla när vi kärleken förtär
 
 jag äter inte mina vänner för dom är en del av mig
 som jag kan leva med och växa med i all evighet
 
 */
