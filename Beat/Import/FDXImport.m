//
//  FDXImport.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 8.1.2020.
//  Copyright © 2020 Lauri-Matti Parppei. All rights reserved.
//
/*
 
 Turns Final Draft files into Fountain. There are certain quirks
 and some elements are not supported yet.
 
 Usage:
 __block FDXImport *fdxImport;
 fdxImport = [[FDXImport alloc] initWithURL:fileName completion:(void)callback];
 
 Upon callback you can access the fdxImport.script array, which
 holds every line as string or just call [fdxImport scriptAsString];
 
 
 */


#import <BeatParsing/BeatParsing.h>
#import <BeatCore/BeatRevisions.h>
#import <BeatCore/BeatColors.h>
#import "FDXImport.h"
#import "FDXElement.h"


@interface FDXImport () <NSXMLParserDelegate>
@property(nonatomic, strong) NSXMLParser *xmlParser;

@property (nonatomic) NSMutableAttributedString *attrContents;

@property (nonatomic) bool contentFound;
@property (nonatomic) bool titlePage;
@property (nonatomic) bool insideParagraph;

@property (nonatomic) NSString *lastFoundElement;
@property (nonatomic) NSString *lastFoundString;
@property (nonatomic) FDXElement *lastAddedLine;
@property (nonatomic) NSString *activeElement;
@property (nonatomic) NSString *alignment;
@property (nonatomic) NSString *style;
@property (nonatomic) NSString *textStyle;
@property (nonatomic) NSMutableString *elementText;
@property (nonatomic) NSMutableAttributedString *attrText;
@property (nonatomic) NSString *revisionID;
@property (nonatomic) NSUInteger dualDialogue;
@property (nonatomic) bool didFinishText;
@property (nonatomic) FDXElement *element;

@property (nonatomic) NSString* sceneColor;

@end

@implementation FDXImport

- (id)initWithURL:(NSURL*)url completion:(void(^)(void))callback
{
	self = [super init];
	if (self) {
		_elementText = [[NSMutableString alloc] init];
		_attrText = [[NSMutableAttributedString alloc] init];
		_script = [NSMutableArray array];
		_titlePage = NO;
		_dualDialogue = -1;
		_attrContents = [[NSMutableAttributedString alloc] init];

		// Thank you, RIPtutorial
		// Fetch xml data
		NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
		
		NSURLSessionDataTask *task = [session dataTaskWithRequest:[NSURLRequest requestWithURL:url] completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
			
			self.xmlParser = [[NSXMLParser alloc] initWithData:data];
			self.xmlParser.delegate = self;
			if ([self.xmlParser parse]){
				callback();
			} else {
				NSLog(@"ERROR: %@", self.xmlParser.parserError);
			}
			
		}];
			
		[task resume];
		
	}
	return self;
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(nullable NSString *)namespaceURI qualifiedName:(nullable NSString *)qName attributes:(NSDictionary<NSString *, NSString *> *)attributeDict
{
	_lastFoundElement = elementName;

	// Find different sections of the XML
	if ([elementName isEqualToString:@"Content"]) {
		_contentFound = YES;
	}
	else if ([elementName isEqualToString:@"DualDialogue"]) {
		_dualDialogue = 1;
	}
	else if ([elementName isEqualToString:@"TitlePage"]) {
		_titlePage = YES;
	}
	else if ([elementName isEqualToString:@"Paragraph"]) {
		// When exiting sub-node, the parser might think we are beginning this node again, with null attributes
		if (!_insideParagraph) {
			if (attributeDict[@"Type"] != nil) _activeElement = attributeDict[@"Type"];
			_alignment = attributeDict[@"Alignment"];
		}
		
		// Null the scene color when a new scene/outline element begins
		if ([attributeDict[@"Type"] isEqualToString:@"Scene Heading"] || [attributeDict[@"Type"] rangeOfString:@"Outline"].location != NSNotFound) {
			_sceneColor = nil;
		}
		
		// Create new element
		_element = [FDXElement withText:@""];
	}
	else if ([elementName isEqualToString:@"Text"]) {
		_didFinishText = NO;
		_lastFoundString = @"";
		_textStyle = attributeDict[@"Style"];
		_revisionID = attributeDict[@"RevisionID"];
	}
	else if ([elementName isEqualToString:@"SceneProperties"]) {
		// Read possible scene color
		_sceneColor = attributeDict[@"Color"];
	}
	
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string
{
	// Let's ignore title page and other non-content stuff
	if (!_contentFound || _titlePage || _didFinishText) return;

	// Clear line breaks
	string = [string stringByTrimmingCharactersInSet:NSCharacterSet.newlineCharacterSet];
	
	if ([_lastFoundElement isEqualToString:@"Text"]) {
		// If we're inside a text element, add the text to element
		[_element append:string];
	}
	else {
		// Otherwise, we need to trim the string. I think this is here for pre-FD12 compatibility?
		NSString *trimmedString = [string stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
		[_element append:trimmedString];
	}
	
	// Save the string for later use
	_lastFoundString = [_lastFoundString stringByAppendingString:string];
}

- (bool)isFirstCharacterSpace:(NSString*)string
{
	if (string.length == 0)	return NO;
	
	return ([string characterAtIndex:0] == ' ');
}

- (bool)isLastCharacterSpace:(NSString*)string
{
	if (string.length == 0) return NO;
	
	return ([string characterAtIndex:string.length - 1] == ' ');
}


- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(nullable NSString *)namespaceURI qualifiedName:(nullable NSString *)qName{
	
	if ([elementName isEqualToString:@"Text"] && !_titlePage) {
		// This was a text snippet
		_lastFoundElement = @"";
		_didFinishText = YES;
		
		if (_lastFoundString.length) {
			NSRange range = (NSRange){ _element.length - _lastFoundString.length, _lastFoundString.length };
			
			if (_textStyle) {
				[_element addStyle:_textStyle to:range];
			}
			if (_revisionID) {
				NSArray *colors = BeatRevisions.revisionColors;
				NSInteger index = [_revisionID integerValue];
				
				// 0 index in revision ID means original in Final Draft
				// We support up to 4 revision colors here
				if (index > 0) {
					index--;
					[_element addAttribute:@"Revision" value:[BeatRevisionItem type:RevisionAddition color:colors[index % 4]] range:range];
				}
			}
			
			// Build tagging support here some day.
			// Just read TagNumber=x, save it into an array and later parse TagCategories and TagDefinitions. Ez.
		}
	}
	
	// Reset dual dialogue
	else if ([elementName isEqualToString:@"DualDialogue"]) _dualDialogue = -1;
	// Go on
	else if ([elementName isEqualToString:@"Paragraph"] && _element.string.length > 0) {
		_insideParagraph = false;
		
		// Add empty rows before required elements.
		FDXElement *previousLine = _script.lastObject;
		
		if (previousLine.length > 0 && _element.length > 0) {
			if ([_activeElement isEqualToString:@"Character"] ||
				[_activeElement isEqualToString:@"Scene Heading"] ||
				[_activeElement isEqualToString:@"Action"] ||
				[_activeElement isEqualToString:@"Shot"]) {
				[_script addObject:[FDXElement lineBreak]];
			}
		}
				
		// Format according to line type
		if ([_activeElement isEqualToString:@"Scene Heading"]) {
			// Set to uppercase
			[_element makeUppercase];
			
			// Force scene prefix if needed
			if (
				[_element.string rangeOfString:@"INT."].location == NSNotFound &&
				[_element.string rangeOfString:@"EXT."].location == NSNotFound &&
				[_element.string rangeOfString:@"I./E."].location == NSNotFound
			) {
				[_element insertAtBeginning:@"."];
			}
			
			if (_sceneColor != nil) {
				NSString* colorString = [NSString stringWithFormat:@" [[%@]]", [self colorNameFor16bitHex:_sceneColor]];
				[_element append:colorString];
			}
		}
		else if ([_activeElement containsString:@"Outline"]) {
			NSInteger p = [_activeElement rangeOfString:@" "].location;
			NSInteger depth = 1;
			
			// Add space if needed
			if (_activeElement.length > 0 && [_element.string characterAtIndex:0] != ' ') {
				[_element insertAtBeginning:@" "];
			}
			
			if (p != NSNotFound && _activeElement.length > p) {
				depth = [_activeElement substringFromIndex:p + 1].integerValue;
			}

			for (NSInteger i=0; i<depth; i++) {
				[_element insertAtBeginning:@"#"];
			}
			
		}
		else if ([_activeElement isEqualToString:@"Lyrics"]) {
			[_element insertAtBeginning:@"~"];
		}
		else if ([_activeElement isEqualToString:@"Character"]) {
			[_element makeUppercase];

			if (_dualDialogue > 0) _dualDialogue++;
			if (_dualDialogue == 3) {
				[_element insertAtEnd:@" ^"];
				_dualDialogue = -1;
			}
		}
		else if ([_activeElement isEqualToString:@"Transition"]) {
			[_element makeUppercase];
			[_element insertAtBeginning:@"> "];
		}
		else if ([_activeElement isEqualToString:@"Shot"]) {
			[_element makeUppercase];
			[_element insertAtBeginning:@"!!"];
		}
		
		// Add object if both this and the previous line are not empty
		if (!([_element.string isEqualToString:@""] && [_lastAddedLine.string isEqualToString:@""])) {
			[_script addObject:_element];
			_lastAddedLine = _element;
		}
	}

	// Start & end sections
	if ([elementName isEqualToString:@"TitlePage"]) {
		_titlePage = NO;
	}
    if ([elementName isEqualToString:@"Content"]) {
		_contentFound = NO;
    }
}

- (NSString*)scriptAsString {
	if (_script.count < 1) return @"";
	
	NSMutableAttributedString *attributedScript = NSMutableAttributedString.new;
	
	for (FDXElement *element in _script) {
		[attributedScript appendAttributedString:element.attributedFountainString];
		[attributedScript appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n"]];
	}
	
	// Let's create a faux Beat document out of the FDX data
	BeatDocumentSettings *settings = [[BeatDocumentSettings alloc] init];
	NSDictionary *revisionRanges = [BeatRevisions rangesForSaving:attributedScript];
	[settings set:DocSettingRevisions as:revisionRanges];
	
	return [NSString stringWithFormat:@"%@\n%@", attributedScript.string, [settings getSettingsString]];
}

- (NSString*)colorNameFor16bitHex:(NSString*)hex {
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
