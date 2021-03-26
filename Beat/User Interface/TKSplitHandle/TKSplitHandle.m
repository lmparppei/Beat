//
//  TKSplitHandle.m
//  TKSplitHandle
//
//  Created by Antoine Duchateau on 16/06/15.
//  Copyright (c) 2015 Taktik SA. All rights reserved.
//  Parts Copyright © 2020 Lauri-Matti Parppei
//

#import "TKSplitHandle.h"
#import "NSArray+Additions.h"

@interface TKSplitHandle ()
@property NSImage *handleImage;
@property NSMutableArray *leftConstraints;
@property NSMutableArray *rightConstraints;
@end
@implementation TKSplitHandle

- (void)awakeFromNib {
	[super awakeFromNib];
	_handleImage = self.image;
	
	NSTrackingArea *trackingArea = [[NSTrackingArea alloc] initWithRect:self.frame options:(NSTrackingMouseMoved | NSTrackingActiveAlways | NSTrackingInVisibleRect) owner:self userInfo:nil];
	[self.window setAcceptsMouseMovedEvents:YES];
	[self addTrackingArea:trackingArea];
}

- (float) totalSpan { return self.isVertical ? self.superview.frame.size.height : self.superview.frame.size.width; }
- (float) handleSpan { return self.isVertical ? self.frame.size.height : self.frame.size.width; }
- (float) topOrRightViewSpan { return self.isVertical ? self.topOrRightView.frame.size.height : self.topOrRightView.frame.size.width; }
- (float) bottomOrLeftViewSpan { return self.isVertical ? self.bottomOrLeftView.frame.size.height : self.bottomOrLeftView.frame.size.width; }
- (float) safeMinConstraint { return MAX(self.bottomOrLeftMinSize?:50.0, 20.0); }
- (float) safeMaxConstraint { return self.totalSpan - self.handleSpan - MAX(self.topOrRightMinSize?:50.0, 20.0); }

- (BOOL) isVertical {
    return self.frame.size.width > self.frame.size.height;
}

- (float) oppositeConstraint:(float) initialConstraint {
    return self.totalSpan - self.handleSpan - initialConstraint;
}

- (float) handlePosition {
    return self.mainConstraint.constant;
}

- (void) setHandlePosition:(float) position {
    // Let's not collapse anything for now
	if (position < self.safeMinConstraint) {
        // if (self.topOrRightViewIsCollapsed) { [self restoreTopOrRightView]; }
        // [self collapseBottomOrLeftView];
    } else if (position>self.safeMaxConstraint) {
        // if (self.bottomOrLeftViewIsCollapsed) { [self restoreBottomOrLeftView]; }
        // [self collapseTopOrRightView];
    } else {
        self.mainConstraint.constant = position;
        [self restoreTopOrRightView];
        [self restoreBottomOrLeftView];
		
		// Inform the master view that we resized its subviews
		[self.delegate splitViewDidResize];
    }
}

- (BOOL) topOrRightViewIsCollapsed {
    return self.topOrRightView.superview == nil;
}

- (BOOL) bottomOrLeftViewIsCollapsed {
    return self.bottomOrLeftView.superview == nil;
}

- (void) collapseTopOrRightView {
    if (!self.topOrRightViewIsCollapsed) {
        if (self.bottomOrLeftViewIsCollapsed) { [self restoreBottomOrLeftView]; }
        [self.topOrRightView removeFromSuperview];
        self.mainConstraint.constant = self.totalSpan - self.handleSpan;
    }
}

- (void) collapseBottomOrLeftView {
    if (!self.bottomOrLeftViewIsCollapsed) {
        if (self.topOrRightViewIsCollapsed) { [self restoreTopOrRightView]; }
		
		//[self saveLeftConstraints];
		[self.bottomOrLeftView removeFromSuperview];
        self.mainConstraint.constant = 0;
		self.image = nil;
	}
}

- (void) restoreTopOrRightView {
    if (self.topOrRightViewIsCollapsed) {
        if (self.mainConstraint.constant > self.safeMaxConstraint) {
            self.mainConstraint.constant = MAX(MIN(self.totalSpan - self.handleSpan - self.topOrRightViewSpan, self.safeMaxConstraint), self.safeMinConstraint);
        }
        
        NSView * sup = self.superview;
        NSView * torv = self.topOrRightView;
        NSView * split = self;
        
        [sup addSubview:self.topOrRightView];
		//[self.topOrRightView addConstraints:self.leftConstraints];
        
        NSDictionary * views = NSDictionaryOfVariableBindings(sup,torv,split);
        if (self.isVertical) {
            [sup addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[torv]|" options:0 metrics:nil views:views]];
            [sup addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[torv]-0-[split]" options:0 metrics:nil views:views]];
        } else {
            [sup addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[torv]|" options:0 metrics:nil views:views]];
            [sup addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:[split]-0-[torv]|" options:0 metrics:nil views:views]];
        }
    }
}

- (void) restoreBottomOrLeftView {
    if (self.bottomOrLeftViewIsCollapsed) {
		// Inform the delegate we did show the view
		// (customization for Beat)
		[self.delegate leftViewDidShow];
		
        if (self.mainConstraint.constant < self.safeMinConstraint) {
            self.mainConstraint.constant = MIN(MAX(self.bottomOrLeftViewSpan, self.safeMinConstraint), self.safeMaxConstraint);
        }
		
		// Show handle again
		[self setImage:_handleImage];
        
        NSView * sup = self.superview;
        NSView * bolv = self.bottomOrLeftView;
        NSView * split = self;
        
        [sup addSubview:self.bottomOrLeftView];
        
        NSDictionary * views = NSDictionaryOfVariableBindings(sup,bolv,split);
        if (self.isVertical) {
            [sup addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[bolv]|" options:0 metrics:nil views:views]];
            [sup addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[split]-0-[bolv]|" options:0 metrics:nil views:views]];
        } else {
            [sup addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[bolv]|" options:0 metrics:nil views:views]];
            [sup addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[bolv]-0-[split]" options:0 metrics:nil views:views]];
        }
	} else {
		//[self.delegate leftViewDidHide];
	}
}

- (void) collapseView:(NSView *) view {
    if (view == self.topOrRightView) {
        [self collapseTopOrRightView];
    } else if (view == self.bottomOrLeftView) {
        [self collapseBottomOrLeftView];
    }
}

- (void) restoreView:(NSView *) view {
    if (view == self.topOrRightView) {
        [self restoreTopOrRightView];
    } else if (view == self.bottomOrLeftView) {
        [self restoreBottomOrLeftView];
    }
}

- (IBAction) performDoubleClick:(id) sender {
    if (self.topOrRightViewIsCollapsed) {
        [self restoreTopOrRightView];
    } else {
        if (self.bottomOrLeftViewIsCollapsed) { [self restoreBottomOrLeftView]; }
        [self collapseTopOrRightView];
    }
    _timer = nil;
}

- (IBAction) performTripleClick:(id) sender {
    if (self.bottomOrLeftViewIsCollapsed) {
        [self restoreBottomOrLeftView];
    } else {
        if (self.topOrRightViewIsCollapsed) { [self restoreTopOrRightView]; }
        [self collapseBottomOrLeftView];
    }
    _timer = nil;
}

- (void) mouseDown: (NSEvent*) event {
    if (event.clickCount == 1) {
        [self setDragStartPoint:[event locationInWindow]];
        self.initialConstant = self.mainConstraint.constant;
		[[NSCursor resizeLeftRightCursor] set];
    }
	/*
	 
	// Nope. We don't want to allow this.
	else if (event.clickCount==2) {
        _timer = [NSTimer scheduledTimerWithTimeInterval:[NSEvent doubleClickInterval] target:self selector:(self.doubleClickCollapsesBottomOrLeft?@selector(performTripleClick:):@selector(performDoubleClick:)) userInfo:nil repeats:NO];
    } else if (event.clickCount==3) {
        [_timer invalidate];
        if (self.doubleClickCollapsesBottomOrLeft) {
            [self performDoubleClick:self];
        } else {
            [self performTripleClick:self];
        }
    }
	 */
}

- (void) mouseDragged: (NSEvent *) e {
    [self setHandlePosition:self.initialConstant - (self.isVertical?[self dragStartPoint].y - [e locationInWindow].y:[self dragStartPoint].x - [e locationInWindow].x)];
	[NSCursor.resizeLeftRightCursor set];
}

- (void) resetCursorRects {
    [super resetCursorRects];
    
    [self addCursorRect:self.bounds cursor:
     (self.isVertical?
      (self.topOrRightViewIsCollapsed ? [NSCursor resizeDownCursor]:self.bottomOrLeftViewIsCollapsed?[NSCursor resizeUpCursor]:[NSCursor resizeUpDownCursor]):
      (self.topOrRightViewIsCollapsed ? [NSCursor resizeRightCursor]:self.bottomOrLeftViewIsCollapsed?[NSCursor resizeLeftCursor]:[NSCursor resizeLeftRightCursor]))
     ];
}

-(void)mouseMoved:(NSEvent *)event {
	if (!self.bottomOrLeftViewIsCollapsed) {
		[NSCursor.resizeLeftRightCursor set];
	}
}
-(void)mouseExited:(NSEvent *)event {
	[NSCursor.arrowCursor set];
}

/*
-(void)saveLeftConstraints {
	self.leftConstraints = [NSMutableArray array];
	
	for (NSLayoutConstraint *constraint in self.bottomOrLeftView.constraints) {
		[_leftConstraints addObject:constraint];
	}
}

-(void)saveRightConstraints {
	self.rightConstraints = [NSMutableArray array];
	
	for (NSLayoutConstraint *constraint in self.topOrRightView.constraints) {
		[_rightConstraints addObject:constraint];
	}
}
 */

@end
