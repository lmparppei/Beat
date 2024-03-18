//
//  TimelineView.m
//  TouchBarTest
//
//  Created by Lauri-Matti Parppei for Beat on 27.5.2020.
//  Copyright © 2020 Lauri-Matti Parppei. All rights reserved.
//

/*
 
 A simple Touch Bar timeline view with playhead
 
*/

#import <BeatParsing/BeatParsing.h>
#import <BeatThemes/BeatThemes.h>
#import <BeatCore/BeatColors.h>
#import "TouchTimelineView.h"

//#import "DynamicColor.h"

@interface TouchTimelineView()
@property NSMutableArray *items;
@property CGFloat playheadPosition;
@property CGFloat scrollPosition;
@property CGFloat originalMagnification;
@property CGFloat originalScrollPosition;
@property CGFloat touchOrigin;
@property CGFloat panDelay;
@property bool isPanning;
@property NSTimer* timer;
@property NSMagnificationGestureRecognizer *gestures;
@end

@implementation TouchTimelineView

# pragma mark - Setup

- (void)awakeFromNib {
    _allowsMagnification = YES;
    _magnification = 1.0;
    _scrollPosition = 0;
	_playheadPosition = 0;
    _selectedItem = -1; // No item selected
	
/*
    // For future generations
    _gestures = [[NSMagnificationGestureRecognizer alloc] initWithTarget:self action:@selector(handleMagnification)];
    _gestures.delegate = self;
    
    [_gestures setAllowedTouchTypes:NSTouchTypeMaskDirect];
    [self addGestureRecognizer:_gestures];
    //_gestures.delegate = self;
*/
}

-(void)setDelegate:(id<BeatEditorDelegate>)delegate
{
	_delegate = delegate;
	[_delegate registerSceneOutlineView:self];
}

- (void)endGestureWithEvent:(NSEvent *)event {
 
}

# pragma mark - Setting data

- (void)setData:(NSMutableArray*)data {
     _items = [NSMutableArray array];
     for (OutlineScene *scene in data) {
		 NSMutableDictionary *item = [NSMutableDictionary dictionaryWithDictionary:@{
            @"name": scene.string,
            @"length": [NSNumber numberWithInteger:scene.length],
            @"type": scene.line.typeAsString
		 }];
		 
		 if (scene.color) {
			 NSColor *color = [BeatColors color:[scene.color lowercaseString]];
			 if (color) [item setValue:color forKey:@"color"];
			 else [item setValue:NSColor.grayColor forKey:@"color"];
		 }
		 else [item setValue:NSColor.grayColor forKey:@"color"];
		 
		 if (scene.omitted) [item setValue:@"YES" forKey:@"invisible"];
		 
		 [_items addObject:item];
     }
	
	[self setNeedsDisplay:YES];
}

# pragma mark - Drawing
- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];

    if (_magnification < 1.0) {
        _magnification = 1.0;
        _scrollPosition = 0;
    }
    
    // beziering code here.
    NSGraphicsContext *context = [NSGraphicsContext currentContext];
    [context saveGraphicsState];
    
    NSInteger totalLength = 0;
	bool hasSections = NO;
    for (NSDictionary *item in self.items) {
		// Skip some elements
		if (item[@"invisible"]) continue;
		else if ([item[@"type"] isEqualToString:@"Synopse"]) continue;
		
		if ([item[@"type"] isEqualToString:@"Section"]) hasSections = YES;
        if ([item[@"type"] isEqualToString:@"Heading"]) totalLength += [item[@"length"] intValue];
    }
    
    // CGFloat width = _magnification * self.frame.size.width - self.items.count - 1;
    // CGFloat factor = width / totalLength;
	//CGFloat x = 0 - _scrollPosition;
	
	CGFloat width = self.frame.size.width - self.items.count;
	CGFloat factor = width / totalLength;
	CGFloat x = 0;
	
	// Make the scenes be centered in the touch bar if there are no sections
	CGFloat yPosition = 10;
	if (hasSections) yPosition = 0;
	
	
    NSMutableDictionary *previousItem = nil;
    
    for (NSMutableDictionary *item in self.items) {
		if (item[@"invisible"]) continue;
		
        if ([item[@"type"] isEqualToString:@"Heading"]) {
            CGFloat width = [item[@"length"] intValue] * factor;
            NSRect rect = NSMakeRect(x, yPosition / 2, width, self.frame.size.height - 10);
            
			NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:rect xRadius:0.5 yRadius:0.5];
			
			DynamicColor *color = item[@"color"];
			NSGradient *gradient = [[NSGradient alloc] initWithColors:@[color, [color colorWithAlphaComponent:0.9]]];
			[gradient drawInBezierPath:path angle:-90];
			
			//[color setFill];
            //NSRectFill(rect);
			//[path fill];
			
            [item setValue:[NSNumber numberWithFloat:x] forKey:@"start"];
            if (previousItem) [previousItem setValue:[NSNumber numberWithFloat:x - 1] forKey:@"end"];
            
            x += width + 1;
        }
        else if ([item[@"type"] isEqualToString:@"Section"]){
            NSRect rect = NSMakeRect(x, 0, 1, self.frame.size.height);
            NSColor *color = NSColor.lightGrayColor;
            [color setFill];
            NSRectFill(rect);
			[item setValue:[NSNumber numberWithFloat:x] forKey:@"start"];
			
            if (previousItem) [previousItem setValue:[NSNumber numberWithFloat:x - 1] forKey:@"end"];
            
            NSAttributedString *title = [[NSAttributedString alloc] initWithString:item[@"name"] attributes:@{
                NSFontAttributeName: [NSFont labelFontOfSize:7],
                NSForegroundColorAttributeName: NSColor.whiteColor
            }];
            [title drawAtPoint:CGPointMake(x + 2, self.frame.size.height - 8)];
            
            x += 2;
        }
        
        previousItem = item;
    }
    // Set end location for last item
    // (now known as previous, as the iteration has ended)
    [previousItem setValue:[NSNumber numberWithFloat:x] forKey:@"end"];
    
    if (_playheadPosition >= 0) {
        NSRect rect = NSMakeRect(_playheadPosition * _magnification - _scrollPosition, 0, 2, self.frame.size.height);
        NSColor *white = NSColor.whiteColor;
        [white setFill];
        NSRectFill(rect);
    }
    
    [context restoreGraphicsState];
}


# pragma mark - Touch controls + locating selected scene

- (void)touchesBeganWithEvent:(NSEvent *)event {
    [super touchesBeganWithEvent:event];
    
    NSTouch *touch = event.allTouches.anyObject;
    //_touchOrigin = [touch locationInView:self].x;
    _playheadPosition = [touch locationInView:self].x;
    [self setNeedsDisplay:YES];
}
- (void)touchesMovedWithEvent:(NSEvent *)event {
    [super touchesMovedWithEvent:event];
    /*
    if ([event.allTouches count] == 1) {
        if (_isPanning) {
            NSTouch *touch = event.allTouches.anyObject;
            _scrollPosition -= [touch locationInView:self].x - [touch previousLocationInView:self].x;
            CGFloat maxScroll = self.frame.size.width * _magnification - self.frame.size.width;
            if (_scrollPosition < 0) _scrollPosition = 0;
            if (_scrollPosition > maxScroll) _scrollPosition = maxScroll;
            
            [self setNeedsDisplay:YES];
        } else {
            _panDelay += 1;
            if (_panDelay > 3) {
                _isPanning = YES;
                _panDelay = 0;
            }
        }
    }
     */
    if ([event.allTouches count] == 1) {
        NSTouch *touch = event.allTouches.anyObject;
        //_touchOrigin = [touch locationInView:self].x;
        _playheadPosition = [touch locationInView:self].x;
        [self setNeedsDisplay:YES];
        [self locateScene];
    }
}

- (void)touchesEndedWithEvent:(NSEvent *)event {
    [super touchesEndedWithEvent:event];
    
    //if ([event.allTouches count] == 1 && !_isPanning) {
    if ([event.allTouches count] == 1) {
        NSTouch *touch = event.allTouches.anyObject;
        //_playheadPosition = _scrollPosition + [touch locationInView:self].x;
        _playheadPosition = [touch locationInView:self].x;
        [self setNeedsDisplay:YES];
        [self locateScene];
    }
    //_isPanning = NO;
}
- (void)locateScene {
    for (NSInteger i = 0; i < self.items.count; i++) {
        NSDictionary *item = [self.items objectAtIndex:i];
		if (item[@"invisible"] || [item[@"type"] isEqualToString:@"Synopse"]) continue;
		
		CGFloat start = [item[@"start"] floatValue];
        CGFloat end = [item[@"end"] floatValue] + 1;
        
        if (_playheadPosition >= start && _playheadPosition < end) {
            _selectedItem = i;
            _playheadPosition = start;
			[self didSelectItem:_selectedItem];
        
            [self setNeedsDisplay:YES];
            return;
        }
    }
    
    // See if we went over the area, then select last item
    NSDictionary *lastItem = [self.items lastObject];
    CGFloat end = [lastItem[@"end"] floatValue];
    if (_playheadPosition > end) {
        _selectedItem = [self.items indexOfObject:lastItem];
        _playheadPosition = [lastItem[@"start"] floatValue];

		[self didSelectItem:_selectedItem];
    }
    
    return;
}
- (void)selectItem:(NSInteger)index {
	if (index >= self.items.count) return;
	else if (index < 0) return;
	
    NSDictionary *item = [self.items objectAtIndex:index];
    if (item) {
        _playheadPosition = [item[@"start"] floatValue];
        [self setNeedsDisplay:YES];
    }
}
- (void)didSelectItem:(NSInteger)item {
	OutlineScene* scene = self.delegate.parser.outline[item];
	if (scene != nil) {
		[self.delegate setSelectedRange:scene.line.textRange];
		[self.delegate scrollToLine:scene.line];
		
	}
}
- (NSUInteger)getSelectedItem {
    [self locateScene];
    return _selectedItem;
}

// For future generations
- (void)handleMagnification {
    _magnification = _originalMagnification * _gestures.magnification;
    
    //_scrollPosition = _originalScrollPosition * _gestures.magnification;
    
    if (_magnification < 1.0) _magnification = 1.0;
//    CGFloat newWidth = self.frame.size.width * _magnification;
//    CGFloat factor = originalWidth / newWidth;
//
//    CGFloat pinchOrigin = _scrollPosition + _touchOrigin * _magnification;
//    NSLog(@"pinch: %f", _scrollPosition);
//
    CGFloat maxWidth = _magnification * self.frame.size.width;
//    _scrollPosition = (pinchOrigin / maxWidth) + (_touchOrigin * factor);


    if (_scrollPosition + self.frame.size.width > maxWidth) {
        _scrollPosition -= _scrollPosition + self.frame.size.width - maxWidth;
    }
    
    [self setNeedsDisplay:YES];
}

- (BOOL)gestureRecognizerShouldBegin:(NSGestureRecognizer *)gestureRecognizer {
    if (_isPanning) return NO;
    
    _originalScrollPosition = _scrollPosition;
    _originalMagnification = _magnification;
    return YES;
}

- (void)reloadInBackground {
	[self.timer invalidate];
	__weak __block TouchTimelineView* weakSelf = self;
	self.timer = [NSTimer scheduledTimerWithTimeInterval:2.0 repeats:NO block:^(NSTimer * _Nonnull timer) {
		[weakSelf reloadView];
		self.timer = nil;
	}];
}

- (void)reloadView {
	[self setData:self.delegate.parser.outline];
}


- (void)reloadWithChanges:(OutlineChanges *)changes {
	[self reloadView];
}


@end
/*
 
 kirjoitan tätä kun
 pandemia vyöryy maapallon yli
 ja ensimmäistä kertaa tunnen
 olevani turvassa
 olen kotona
 olen ainoa jolla on avaimet näihin oviin
 ja kaikkiin joihin luotan
 voin luottaa niin että antaisin niiden
 hoitaa kasvejani
 ampua omenan pääni päältä
 
 ja tänä kauniina kesäiltana
 suren kaikkia
 jotka eivät ole minä
 jotka eivät saa
 kaikkea tätä
 nähdä tätä
 kun lehdet ovat äkkiä
 puhjenneet kukkaan
 kun kaupunki herää eloon
 maailman vajotessa
 syvemmälle kaaokseen
 olen turvassa
 ensimmäistä kertaa.
 
*/
