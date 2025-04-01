//
//  BeatNotepad.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 21.10.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//
/**
 
 Saved notepad content format:
 <beatColorName>text</beatColorName>
 
 Notepad uses `BeatMarkdownTextStorage` which has a *very* bare-bones markdown parser and automatically stylizes text.
 
 */

#import <BeatParsing/BeatParsing.h>
#import <QuartzCore/QuartzCore.h>
#import <BeatThemes/BeatThemes.h>
#import <BeatPlugins/BeatPlugins.h>
#import <BeatCore/BeatCore-Swift.h>

#import "BeatNotepadView.h"
#import "Beat-Swift.h"
#import "ColorCheckbox.h"

@interface BeatNotepadView () <BeatEditorView>
@property (nonatomic) IBOutlet NSTabView* parentTabView;

@property (nonatomic) NSArray<ColorCheckbox*> *buttons;
@property (nonatomic, weak) IBOutlet ColorCheckbox *buttonDefault;
@property (nonatomic, weak) IBOutlet ColorCheckbox *buttonRed;
@property (nonatomic, weak) IBOutlet ColorCheckbox *buttonBlue;
@property (nonatomic, weak) IBOutlet ColorCheckbox *buttonBrown;
@property (nonatomic, weak) IBOutlet ColorCheckbox *buttonOrange;
@property (nonatomic, weak) IBOutlet ColorCheckbox *buttonGreen;
@property (nonatomic, weak) IBOutlet ColorCheckbox *buttonPink;
@property (nonatomic, weak) IBOutlet ColorCheckbox *buttonCyan;
@property (nonatomic, weak) IBOutlet ColorCheckbox *buttonMagenta;
//@property (nonatomic) DynamicColor* defaultColor;
@property (nonatomic) NSMutableArray* observers;

@property (nonatomic) CGFloat scaleFactor;
@property (nonatomic) CGFloat zoomLevel;

@end

@implementation BeatNotepadView

-(instancetype)initWithCoder:(NSCoder *)coder
{
	self = [super initWithCoder:coder];
	
	if (self) {
		// Create a default color
		self.defaultColor = [DynamicColor.alloc initWithLightColor:[NSColor colorWithWhite:0.1 alpha:1.0] darkColor:[NSColor colorWithWhite:0.9 alpha:1.0]];
		
		self.wantsLayer = YES;
		self.layer.cornerRadius = 10.0;
		self.layer.backgroundColor = [NSColor.darkGrayColor colorWithAlphaComponent:0.3].CGColor;
		self.textColor = self.defaultColor;
				
		[self setTextContainerInset:(NSSize){ 5, 5 }];
	}
	
	return self;
}

-(void)awakeFromNib
{
	[super awakeFromNib];

	self.buttons = @[self.buttonDefault, self.buttonRed, self.buttonGreen, self.buttonBlue, self.buttonPink, self.buttonOrange, self.buttonBrown, self.buttonCyan, self.buttonMagenta];
	self.buttonDefault.state = NSOnState;
	
	self.textColor = self.currentColor;
	self.buttonDefault.itemColor = self.defaultColor;
		
	[self.textStorage setAttributedString:[self coloredRanges:self.string]];
	
	[self setTypingAttributes:@{
		NSForegroundColorAttributeName: self.currentColor
	}];
	
	_scaleFactor = 1.0;
	_zoomLevel = [BeatUserDefaults.sharedDefaults getFloat:BeatSettingNotepadZoom];;
	[self setScale:_zoomLevel];
	
	[self updateLayout];
}

- (void)scrollWheel:(NSEvent *)event
{
	// For some reason we need to do this on macOS Sonoma.
	// No events are registered in the scroll view when another scroll view is earlier in responder chain in this window. No idea.
	if (@available(macOS 14.0, *)) {
		if (self.drawnOnScreen) {
			CGPoint p = [self convertPoint:event.locationInWindow fromView:nil];
			
			if ([self mouse:p inRect:self.bounds] && self.visibleRect.size.width > 0.0) {
				[self.enclosingScrollView scrollWheel:event];
				return;
			}
		}
	}
	
	[super scrollWheel:event];
}


#pragma mark - Text events and I/O

-(void)didChangeText
{
	// Save contents into document settings
	//[self saveToDocument];
	[self.editorDelegate addToChangeCount];
	[super didChangeText];
	[self notifyTextChange];
}

- (void)notifyTextChange
{
	if (self.observerDisabled) return;
	for (id<BeatTextChangeObserver>observer in self.observers) [observer observedTextDidChange:self];
}


#pragma mark - Zooming

- (void)setScale:(CGFloat)newScaleFactor
{
	if (_scaleFactor == newScaleFactor) return;
	
	CGSize curDocFrameSize, newDocBoundsSize;
	BXView* clipView = self.enclosingScrollView.documentView;

	CGFloat oldScaleFactor = _scaleFactor;
	
	curDocFrameSize = clipView.frame.size;
	newDocBoundsSize.width = curDocFrameSize.width;
	newDocBoundsSize.height = curDocFrameSize.height / newScaleFactor;
	
	CGRect newFrame = CGRectMake(0, 0, newDocBoundsSize.width, newDocBoundsSize.height);
	clipView.frame = newFrame;
	
	// Thank you, Mark Munz @ stackoverflow
	CGFloat scaler = newScaleFactor / oldScaleFactor;
	[self scaleUnitSquareToSize:NSMakeSize(scaler, scaler)];
	[self.layoutManager ensureLayoutForTextContainer:self.textContainer];
	_scaleFactor = newScaleFactor;
	
	[BeatUserDefaults.sharedDefaults saveFloat:_scaleFactor forKey:BeatSettingNotepadZoom];
	
	[self updateLayout];
}

- (IBAction)zoomNotepadIn:(id)sender
{
	[self adjustZoom:0.1];
}
- (IBAction)zoomNotepadOut:(id)sender
{
	[self adjustZoom:-0.1];
}
- (void)adjustZoom:(CGFloat)value
{
	if (_zoomLevel + value < 1.0 || _zoomLevel + value > 1.7) return;
	
	_zoomLevel += value;
	[self setScale:_zoomLevel];
}

- (void)updateLayout
{
	[self setNeedsDisplay:YES];
	[self.enclosingScrollView setNeedsDisplay:YES];
	
	// For some reason, clip view might get the wrong height after magnifying. No idea what's going on.
	NSRect clipFrame = self.enclosingScrollView.contentView.frame;
	clipFrame.size.height = self.enclosingScrollView.contentView.superview.frame.size.height * _zoomLevel;
	self.enclosingScrollView.contentView.frame = clipFrame;
	
	self.needsUpdateConstraints = true;
	self.needsLayout = true;
	self.enclosingScrollView.needsUpdateConstraints = true;
	self.enclosingScrollView.needsLayout = true;
	self.enclosingScrollView.superview.needsUpdateConstraints = true;
	
	[self invalidateIntrinsicContentSize];
	self.textContainer.size = CGSizeMake(self.textContainer.size.width, CGFLOAT_MAX);
	self.textContainer.heightTracksTextView = false;
	
	[self setNeedsUpdateConstraints:true];
	
	[self.layoutManager invalidateLayoutForCharacterRange:NSMakeRange(0, self.text.length) actualCharacterRange:nil];
	[self.layoutManager ensureLayoutForTextContainer:self.textContainer];
	
	self.needsDisplay = true;
	self.needsLayout = true;
}


#pragma mark - Loading

- (void)loadString:(NSString *)string
{
	[super loadString:string];
	[self updateLayout];
}


#pragma mark - UI actions

-(IBAction)setInputColor:(id)sender
{
	ColorCheckbox *box = sender;
	[self setColor:box.colorName];
	
	for (ColorCheckbox *button in _buttons) {
		if ([button.colorName isEqualToString:self.currentColorName]) button.state = NSOnState;
		else button.state = NSControlStateValueOff;
	}
	
	if (self.selectedRange.length) {
		// If a range was selected when color was changed, save it to document
		NSRange range = self.selectedRange;
		NSAttributedString *attrStr = [self.attributedString attributedSubstringFromRange:range];
		[self.textStorage addAttribute:NSForegroundColorAttributeName value:self.currentColor range:range];
		
		[self.undoManager registerUndoWithTarget:self handler:^(id  _Nonnull target) {
			[self.textStorage replaceCharactersInRange:range withAttributedString:attrStr];
		}];
		[self saveToDocument];
	}
	
	[self setTypingAttributes:@{
		NSForegroundColorAttributeName:self.currentColor
	}];
	
	self.selectedRange = (NSRange){ self.selectedRange.location + self.selectedRange.length, 0 };
}

/// Cuts a piece of text from editor to notepad
- (IBAction)cutToNotepad:(id)sender
{
	NSRange range = self.editorDelegate.selectedRange;
	NSString* string = [self.editorDelegate.text substringWithRange:range];
	
	// Add line breaks if needed
	if (self.text.length > 1 && [self.text characterAtIndex:self.text.length - 1] != '\n') {
		string = [NSString stringWithFormat:@"\n\n%@", string];
	}
	
	[self replaceCharactersInRange:NSMakeRange(self.string.length, 0) withString:string];
	[self didChangeText];
	
	[self.editorDelegate.textActions replaceRange:range withString:@""];
	
	[self.undoManager registerUndoWithTarget:self handler:^(id  _Nonnull target) {
		[self replaceCharactersInRange:NSMakeRange(self.string.length - string.length, string.length) withString:@""];
	}];
}


#pragma mark - Make observable for plugins

- (void)addTextChangeObserver:(id<BeatTextChangeObserver>)observer
{
	if (_observers == nil) _observers = NSMutableArray.new;
	[self.observers addObject:observer];
}

- (void)removeTextChangeObserver:(id<BeatTextChangeObserver>)observer
{
	[self.observers removeObject:observer];
}


#pragma mark - Editor view conformance

- (void)reloadInBackground
{
	//[self reloadView];
}
- (void)reloadView
{
	// This is a hack to satisfy weird responder issues in macOS Sonoma (see scroll wheel events)
	//self.hidden = !self.visible;
	[self updateLayout];
}

-(bool)visible
{
	return (_parentTabView.selectedTabViewItem.view == self.enclosingScrollView.superview);
}

@end
/*
 
 lopulta unohdan yksityiskohdat
 mun rauhattomasta nuoruudesta
 silti muistan
 sinut tuollaisena
 selaamassa ydinräjähdysten kuvia
 vain niiden kauneuden takia
 
 */
