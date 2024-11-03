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
	
	[self.editorDelegate replaceRange:range withString:@""];
	
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
