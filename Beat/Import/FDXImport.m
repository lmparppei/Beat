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


#import "FDXImport.h"
#import "BeatRevisionItem.h"
#import "FDXElement.h"
#import "BeatDocumentSettings.h"
#import "BeatRevisions.h"

@interface FDXImport () <NSXMLParserDelegate>
@property(nonatomic, strong) NSXMLParser *xmlParser;

@property (nonatomic) NSMutableAttributedString *attrContents;

@property (nonatomic) bool contentFound;
@property (nonatomic) bool titlePage;
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
			if([self.xmlParser parse]){
				callback();
		}
			
		}];
			
		[task resume];
		
	}
	return self;
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(nullable NSString *)namespaceURI qualifiedName:(nullable NSString *)qName attributes:(NSDictionary<NSString *, NSString *> *)attributeDict{
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
		_activeElement = attributeDict[@"Type"];
		_alignment = attributeDict[@"Alignment"];
				
		// Create new element
		_element = [FDXElement withText:@""];
	}
	else if ([elementName isEqualToString:@"Text"]) {
		_didFinishText = NO;
		_lastFoundString = @"";
		_textStyle = attributeDict[@"Style"];
		_revisionID = attributeDict[@"RevisionID"];
	}
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string{
	if (_contentFound && !_titlePage && !_didFinishText) {
		// Clear line breaks
		string = [string stringByTrimmingCharactersInSet:NSCharacterSet.newlineCharacterSet];
		
		if ([_lastFoundElement isEqualToString:@"Text"]) {
			//if (![self isLastCharacterSpace:_elementText]) _elementText = [NSMutableString stringWithString:[_elementText stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]];
			[_element append:string];
		}
		
		else {
			NSString *trimmedString = [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
			[_element append:trimmedString];
		}
				
		// Save the string for later use
		if (!_didFinishText) {
			_lastFoundString = [_lastFoundString stringByAppendingString:string];
		}
		
	}
}

- (NSAttributedString*)attrStrFrom:(NSString*)string {
	return [[NSAttributedString alloc] initWithString:string];
}

- (bool)isFirstCharacterSpace:(NSString*)string {
	if (string.length > 0) {
		if ([[string substringWithRange:NSMakeRange(0, 1)] isEqualToString:@" "]) return YES;
		else return NO;
	} else {
		return NO;
	}
}
- (bool)isLastCharacterSpace:(NSString*)string {
	if (string.length > 1) {
		if ([[string substringWithRange:NSMakeRange(string.length - 1, 1)] isEqualToString:@" "]) return YES;
		else return NO;
	} else {
		if ([string isEqualToString:@" "]) return YES;
		else return NO;
	}
}
- (NSString*)trim:(NSString*)string {
	return [string stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
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
	else if ([elementName isEqualToString:@"Paragraph"]) {
		// Add empty rows before required elements.
		if ([_script count] > 0) {
			FDXElement *previousLine = [_script lastObject];
			
			if (previousLine.length > 0 && _element.length > 0) {
				if ([_activeElement isEqualToString:@"Character"] ||
					[_activeElement isEqualToString:@"Scene Heading"] ||
					[_activeElement isEqualToString:@"Action"]) {
					[_script addObject:[FDXElement lineBreak]];
				}
			}
		}
		
		// Format contents
		//result = [self fountainString:_attrText];
		
		if ([_activeElement isEqualToString:@"Scene Heading"]) {
			// Set to uppercase
			[_element setString:_element.string.uppercaseString];
			
			// Force scene prefix if needed
			if ([_element.string rangeOfString:@"INT."].location == NSNotFound &&
				[_element.string rangeOfString:@"EXT."].location == NSNotFound &&
				[_element.string rangeOfString:@"I./E."].location == NSNotFound
			) {
				[_element insertAtBeginning:@"."];
			}
		}
		else if ([_activeElement isEqualToString:@"Lyrics"]) {
			[_element insertAtBeginning:@"~"];
		}
		else if ([_activeElement isEqualToString:@"Character"]) {
			if (_dualDialogue > 0) _dualDialogue++;
			if (_dualDialogue == 3) {
				[_element insertAtEnd:@" ^"];
				_dualDialogue = -1;
			}
			else [_element makeUppercase];
		}
		else if ([_activeElement isEqualToString:@"Transition"]) {
			[_element makeUppercase];
			[_element insertAtBeginning:@"> "];
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

@end
