//
//  BeatNotepad.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 21.10.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatNotepad.h"
#import "BeatColors.h"
#import "BeatDocumentSettings.h"
#import "ThemeManager.h"
#import <QuartzCore/QuartzCore.h>
#import "ColorCheckbox.h"

@interface BeatNotepad ()
@property (nonatomic) NSString *currentColorName;
@property (nonatomic) NSColor *currentColor;

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
@end
@implementation BeatNotepad

-(instancetype)initWithCoder:(NSCoder *)coder {
	self = [super initWithCoder:coder];
	
	if (self) {
		self.wantsLayer = YES;
		self.layer.cornerRadius = 10.0;
		self.layer.backgroundColor = [NSColor.darkGrayColor colorWithAlphaComponent:0.3].CGColor;
		self.textColor = ThemeManager.sharedManager.textColor.darkAquaColor;
		
		[self setTextContainerInset:(NSSize){ 5, 5 }];
	}
	
	return self;
}
-(void)awakeFromNib {
	self.buttons = @[self.buttonDefault, self.buttonRed, self.buttonGreen, self.buttonBlue, self.buttonPink, self.buttonOrange, self.buttonBrown, self.buttonCyan, self.buttonMagenta];
	
	self.buttonDefault.state = NSOnState;
	self.currentColorName = @"lightGray";
	self.currentColor = [BeatColors color:_currentColorName];
	
	[self.textStorage setAttributedString:[self coloredRanges:self.string]];
	
	[self setTypingAttributes:@{
		NSForegroundColorAttributeName: _currentColor
	}];
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
}

-(IBAction)setInputColor:(id)sender {
	ColorCheckbox *box = sender;
	_currentColorName = box.colorName;
	
	if ([_currentColorName isEqualToString:@"lightGray"]) _currentColor = ThemeManager.sharedManager.textColor.darkAquaColor;
	else _currentColor = [BeatColors color:_currentColorName];
	
	for (ColorCheckbox *button in _buttons) {
		if ([button.colorName isEqualToString:_currentColorName]) button.state = NSOnState;
		else button.state = NSControlStateValueOff;
	}
	
	if (self.selectedRange.length) {
		// If a range was selected when color was changed, save it to document
		NSRange range = self.selectedRange;
		NSAttributedString *attrStr = [self.attributedString attributedSubstringFromRange:range];
		[self.textStorage addAttribute:NSForegroundColorAttributeName value:_currentColor range:range];
		
		[self.undoManager registerUndoWithTarget:self handler:^(id  _Nonnull target) {
			[self.textStorage replaceCharactersInRange:range withAttributedString:attrStr];
		}];
		[self saveToDocument];
	}
	
	[self setTypingAttributes:@{
		NSForegroundColorAttributeName: _currentColor
	}];
	
	self.selectedRange = (NSRange){ self.selectedRange.location + self.selectedRange.length, 0 };
}

-(void)loadString:(NSString*)string {
	[self.textStorage setAttributedString:[self coloredRanges:string]];
}

-(void)didChangeText {
	// Save contents into document settings
	[self saveToDocument];
	[super didChangeText];
}

- (NSAttributedString*)coloredRanges:(NSString*)fullString
{
	NSUInteger length = fullString.length;
	unichar string[length];
	[fullString getCharacters:string];

	NSMutableAttributedString *attrStr = [[NSMutableAttributedString alloc] init];
	
	NSArray *colors = BeatColors.colors.allKeys;
	
	NSInteger rangeBegin = -1; //Set to -1 when no range is currently inspected, or the the index of a detected beginning
	NSString *currentMatch = @"";
	for (NSInteger i = 0; i < length; i++) {
		if (rangeBegin == -1 && string[i] == '<') {
			// Opening tag
			for (NSString *color in colors) {
				if (i + color.length + 1 < length) {
					NSRange tagRange = (NSRange){ i, color.length + 2 };
					NSString *test = [fullString substringWithRange:tagRange];
					NSString *colorTag = [NSString stringWithFormat:@"<%@>", color];
					if ([test isEqualToString:colorTag]) {
						currentMatch = color;
						rangeBegin = i + color.length + 2;
						i += color.length + 1;
						
						break;
					}
				}
			}
			if (currentMatch.length) continue;
		}
		else if (rangeBegin >= 0) {
			if (i + 3 + currentMatch.length <= length ) {
				if (string[i] == '<' && string [i+1] == '/' && string[i+2+currentMatch.length] == '>') {
					NSRange tagRange = (NSRange){ i + 2, currentMatch.length };
					NSString *test = [fullString substringWithRange:tagRange];
					if ([test isEqualToString:currentMatch]) {
						i += currentMatch.length + 2;
						currentMatch = @"";
						rangeBegin = -1;
						continue;
					}
				}
			}
		}
		
		// append character
		[attrStr appendAttributedString:
		 [NSAttributedString.alloc initWithString: [NSString stringWithFormat:@"%c", string[i] ]]
		];
		if (currentMatch.length) {
			[attrStr addAttribute:NSForegroundColorAttributeName value:[BeatColors color:currentMatch] range:(NSRange){ attrStr.length - 1, 1 }];
		} else {
			[attrStr addAttribute:NSForegroundColorAttributeName value:ThemeManager.sharedManager.textColor.darkAquaColor range:(NSRange){ attrStr.length - 1, 1 }];
		}
	
	}
	
	return attrStr;
}

- (void)saveToDocument {
	[self.editorDelegate.documentSettings set:@"Notes" as:[self stringForSaving]];
	NSLog(@".... %@", [self.editorDelegate.documentSettings get:@"Notes"]);
}

- (NSString*)stringForSaving {
	NSMutableString *result = [NSMutableString.alloc initWithString:@""];
	
	[self.attributedString enumerateAttribute:NSForegroundColorAttributeName inRange:(NSRange){0,self.string.length} options:0 usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
		NSString *colorTag;
		for (NSString *colorName in BeatColors.colors.allKeys) {
			if (BeatColors.colors[colorName] == value) {
				colorTag = colorName;
				break;
			}
		}
		
		if (colorTag && ![colorTag.lowercaseString isEqualToString:@"lightgray"]) {
			[result appendFormat:@"<%@>", colorTag];
			[result appendString:[self.string substringWithRange:range]];
			[result appendFormat:@"</%@>", colorTag];
		} else {
			[result appendString:[self.string substringWithRange:range]];
		}
	}];
		
	return result;
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
