//
//  FDXElement.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 21.3.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import "FDXElement.h"
#import <BeatCore/BeatCore.h>
#import <BeatCore/BeatCore-Swift.h>

@implementation FDXNote
- (instancetype)initWithRange:(NSRange)range
{
	self = [super init];
	if (self) {
		self.range = range;
		self.elements = NSMutableArray.new;
	}
	return self;
}

- (NSString*)noteString
{
	NSMutableString* string = NSMutableString.new;
	[string appendString:@" [["];
	if (self.color != nil) [string appendFormat:@"%@: ", self.color];
	
	for (FDXElement* el in self.elements) {
		[string appendString:el.string];
	}
	
	[string appendString:@"]]"];
		return string;
}

@end

@implementation FDXElement

-(instancetype)initWithText:(NSString*)text type:(NSString*)type
{
	self = [super init];
	_text = [[NSMutableAttributedString alloc] initWithString:(text) ? text : @""];
	_type = (type != nil) ? type : @"";
	return self;
}

-(instancetype)initWithAttributedText:(NSAttributedString*)text type:(NSString*)type
{
	self = [super init];
	_text = [[NSMutableAttributedString alloc] initWithAttributedString:(text) ? text : NSAttributedString.new];
	_type = (type != nil) ? type : @"";
	return self;
}

+ (FDXElement*)lineBreak
{
	return [[FDXElement alloc] initWithText:@"" type:@"empty"];
}
+ (FDXElement*)withText:(NSString*)string type:(NSString*)type
{
	return [[FDXElement alloc] initWithText:string type:type];
}
+ (FDXElement*)withAttributedText:(NSAttributedString*)string type:(NSString*)type
{
	return [[FDXElement alloc] initWithAttributedText:string type:type];
}

- (NSString*)string
{
	if (self.text.string == nil) return @"";
	else return self.text.string;
}

- (void)setString:(NSString*)string
{
    [self.text setAttributedString:ToAttributedString(string)];
}

- (void)append:(NSString *)string
{
    [_text appendAttributedString:ToAttributedString(string)];
}

- (void)insertAtBeginning:(NSString*)string
{
	[_text insertAttributedString:ToAttributedString(string) atIndex:0];
}

- (void)insertAtEnd:(NSString*)string
{
	[_text appendAttributedString:ToAttributedString(string)];
}

- (void)addAttribute:(NSAttributedStringKey)name value:(id)value range:(NSRange)range
{
    [_text addAttribute:name value:value range:range];
}

- (void)makeUppercase
{
	if (_text.length > 0) {
		NSDictionary *attributes = [self.text attributesAtIndex:0 longestEffectiveRange:nil inRange:(NSRange){0, self.text.length}];
		[_text replaceCharactersInRange:(NSRange){0, _text.length} withString:self.string.uppercaseString];
		[_text addAttributes:attributes range:(NSRange){0, _text.length}];
	}
}

- (void)addStyle:(NSString *)style to:(NSRange)range
{
	[self.text addAttribute:@"Style" value:style range:range];
}

- (NSInteger)length
{
	return self.text.length;
}

- (NSString*)fountainString
{
    NSAttributedString* str = self.attributedFountainString;
    return str.string;
}

- (NSAttributedString*)attributedFountainString
{
	NSMutableAttributedString *attrResult = NSMutableAttributedString.new;
	
	// Enumerate string attributes, find previously set stylization and convert it to Fountain
	[self.text enumerateAttributesInRange:(NSRange){0, self.text.length} options:0 usingBlock:^(NSDictionary<NSAttributedStringKey,id> * _Nonnull attrs, NSRange range, BOOL * _Nonnull stop) {
		NSString *open = @"";
		NSString *close = @"";
		NSString *openClose = @"";

		NSAttributedString *attrStr = [self.text attributedSubstringFromRange:range];
        bool allCaps = false;
        
		if (attrs[@"Style"]) {
			NSArray *styles = [(NSString*)attrs[@"Style"] componentsSeparatedByString:@","];
			for (NSString *style in styles) {
				if ([self style:style matches:@"Italic"]) {
					openClose = [openClose stringByAppendingString:@"*"];
				}
				else if ([self style:style matches:@"Bold"]) {
					openClose = [openClose stringByAppendingString:@"**"];
				}
				else if ([self style:style matches:@"Underline"]) {
					openClose = [openClose stringByAppendingString:@"_"];
				}
				else if ([self style:style matches:@"Strikeout"]) {
					open = [open stringByAppendingString:@"{{"];
					close = [close stringByAppendingString:@"}}"];
				}
                else if ([self style:style matches:@"AllCaps"]) {
                    allCaps = true;
                }
			}
		}
		
        if (allCaps) {
            attrStr = attrStr.uppercased;
        }
        
        [attrResult appendString:open];
        [attrResult appendString:openClose];
        
		[attrResult appendAttributedString:attrStr];
        
        [attrResult appendString:openClose];
        [attrResult appendString:close];
	}];
	
	return attrResult;
}

- (bool)style:(NSString*)style matches:(NSString*)match
{
    return ([style.trim isEqualToString:match]);
}

+ (NSString*)colorNameFor16bitHex:(NSString*)hex
{
	static NSMutableDictionary* colors;
	
	if (colors == nil) {
		colors = NSMutableDictionary.new;
		
		[colors addEntriesFromDictionary:@{
			@"#E2E29898DDDD": @"pink",
			@"#EBEB62627B7B": @"red",
			@"#EFEFA4A46262": @"orange",
			@"#E5E5CBCB6C6C": @"yellow",
			@"#929290900000": @"olive",
			@"#8F8FC3C36A6A": @"green",
			@"#8888CACAB8B8": @"mint",
			@"#6363A7A7EFEF": @"blue",
			@"#9A9AAEAEDBDB": @"violet",
			@"#AFAF9393E8E8": @"purple",
			@"#B2B27C7C7373": @"brown",
			@"#C0C0C0C0C0C0": @"gray"
		}];
		
		for (NSString* key in BeatColors.colors.allKeys) {
			NSString* hx = [NSString stringWithFormat:@"#%@", [BeatColors colorWith16bitHex:key]];
			colors[hx] = key;
		}
	}
	
	return colors[hex];
}

@end
