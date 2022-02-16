//
//  OSFImport.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 17.7.2020.
//  Copyright © 2020 Lauri-Matti Parppei. All rights reserved.
//

/*
 
 Simple import for Open Screenplay Format (XML) files.
 Could be (in theory) used to import Fade In screenplays.
 
 */

#import "OSFImport.h"

@interface OSFImport () <NSXMLParserDelegate>
@property(nonatomic, strong) NSXMLParser *xmlParser;
@property (nonatomic) bool paragraph;
@property (nonatomic) NSDictionary *paraProperties;

@property(nonatomic, strong) NSMutableArray *results;
@property (nonatomic, strong) NSMutableArray *titlePageElements;
@property(nonatomic, strong) NSMutableString *parsedString;
@property(nonatomic, strong) NSMutableString *resultScript;

@property(nonatomic) bool contentFound;
@property(nonatomic) bool titlePage;
@property(nonatomic, strong) NSString *lastFoundElement;
@property(nonatomic, strong) NSString *lastFoundString;
@property(nonatomic, strong) NSString *lastAddedLine;
@property(nonatomic, strong) NSString *style;
@property(nonatomic, strong) NSMutableString *elementText;
@property(nonatomic, strong) NSMutableArray *scriptLines;
@property(nonatomic) NSUInteger dualDialogue;
@end

@implementation OSFImport

- (id)initWithData:(NSData*)data {
	// Parsing with just data does not need a callback, we can do everything in sync
	self = [super init];
	if (self) {
		[self parse:data];
	}
	return self;
}

- (id)initWithURL:(NSURL*)url completion:(void(^)(void))callback
{
	// Parsing a URL request needs a completion callback
	
	self = [super init];
	if (self) {
		// Thank you, RIPtutorial
		// Fetch xml data
		NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
		
		NSURLSessionDataTask *task = [session dataTaskWithRequest:[NSURLRequest requestWithURL:url] completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
			// After the data has loaded, parse the file & return to callback
			[self parse:data];
			callback();
		}];
			
		[task resume];
	}
	return self;
}

- (void)parse:(NSData*)data {
	_elementText = [NSMutableString string];
	_scriptLines = [NSMutableArray array];
	_titlePageElements = [NSMutableArray array];
	_titlePage = NO;
	_dualDialogue = -1;
	
	self.xmlParser = [[NSXMLParser alloc] initWithData:data];
	self.xmlParser.delegate = self;
	if ([self.xmlParser parse]) {
		self.script = [self scriptAsString];
	}
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(nullable NSString *)namespaceURI qualifiedName:(nullable NSString *)qName attributes:(NSDictionary<NSString *, NSString *> *)attributeDict{
	_lastFoundElement = elementName;
	
	// Fade In (sometimes) uses lower-case attribute & element names, while
	// OSF documentation explicitly specifies changing case, ie. "sceneNumber" vs "scenenumber".
	// So fuck everything, let's create a new dictionary out of the attributes
	// with lowercase counterparts. Style names are correctly capitalized, though.
	
	elementName = elementName.lowercaseString;
	NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
	
	for (id key in attributeDict) {
		[attributes setValue:[attributeDict objectForKey:key] forKey:[key lowercaseString]];
	}
	
	if ([elementName isEqualToString:@"paragraphs"]) {
		_contentFound = YES;
		_titlePage = NO;
	}
	else if ([elementName isEqualToString:@"titlepage"]) {
		_titlePage = YES;
	}
	else if ([elementName isEqualToString:@"para"]) {
		_paraProperties = attributes;
		_paragraph = YES;
		_elementText = [NSMutableString string];
	}
	else if ([elementName isEqualToString:@"style"]) {
		if (attributes[@"basestylename"]) _style = (NSString*)attributes[@"basestylename"];
		if (attributes[@"basestyle"]) _style = (NSString*)attributes[@"basestyle"];
		
		if (attributes[@"synopsis"]) {
			// Add synopsis to script
			[_scriptLines addObject:@""];
			[_scriptLines addObject:[NSString stringWithFormat:@"\n= %@", attributes[@"synopsis"]]];
		}
		
		if ([_style isEqualToString:@"Character"]) {
			if (_dualDialogue > 0) _dualDialogue += 1;
			if (_dualDialogue > 2) _dualDialogue = 0;
		}
		else if ([_style isEqualToString:@"Dialogue"]) {
			if (_dualDialogue == 2) _dualDialogue = 0;
		}
		
		if (attributes[@"dualdialogue"]) {
			// Start dual dialogue
			_dualDialogue = 1;
		}
	}
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string{
	if (_contentFound || _titlePage) {
		string = [string stringByTrimmingCharactersInSet:NSCharacterSet.newlineCharacterSet];
		
		if ([_lastFoundElement isEqualToString:@"text"]) {
			if (![self isLastCharacterSpace:_elementText]) _elementText = [NSMutableString stringWithString:[_elementText stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]];
			[_elementText appendString:string];
		}
		else [_elementText appendString:[string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
		
		// Save the string for later use
		_lastFoundString = string;
	}
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

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(nullable NSString *)namespaceURI qualifiedName:(nullable NSString *)qName{
	elementName = elementName.lowercaseString;
	
	if ([elementName isEqualToString:@"text"]) {
		_lastFoundElement = @"";
		[_elementText appendString:@" "];
	}
	else if ([elementName isEqualToString:@"para"]) {
		NSString *result = [NSString stringWithFormat:@"%@", _elementText];
		
		// Add empty rows before required elements.
		if (_scriptLines.count > 0) {
			NSString *previousLine = [_scriptLines lastObject];
			
			if (previousLine.length > 0 && _elementText.length > 0) {
				if ([_style isEqualToString:@"Character"] ||
					[_style isEqualToString:@"Scene Heading"] ||
					[_style isEqualToString:@"Action"]) {
					[_scriptLines addObject:@""];
				}
			}
		}
		
		if ([_style isEqualToString:@"Scene Heading"]) {
			result = [result uppercaseString];
			
			// Force scene prefix if there is none and the style is scene heading anyway
			if ([result rangeOfString:@"INT."].location == NSNotFound &&
				[result rangeOfString:@"EXT."].location == NSNotFound &&
				[result rangeOfString:@"I./E."].location == NSNotFound
			) {
				result = [NSString stringWithFormat:@".%@", result];
			}
			
			if (_paraProperties[@"scenenumber"]) {
				result = [NSString stringWithFormat:@"%@ #%@#", result, _paraProperties[@"scenenumber"]];
			}
		}
		else if ([_style isEqualToString:@"Lyrics"]) {
			result = [NSString stringWithFormat:@"~%@~", result];
		}
		if ([_style isEqualToString:@"Character"]) {
			if (_dualDialogue == 2) {
				result = [result stringByAppendingString:@" ^"];
				_dualDialogue = 0;
			}
			result = [result uppercaseString];
			
			// Force character if it's under 4 letters (like LI or PO)
			if (result.length < 4) result = [NSString stringWithFormat:@"@%@", result];
		}
		else if ([_style isEqualToString:@"Transition"]) {
			result = [NSString stringWithFormat:@"> %@", [result uppercaseString]];
		}
		else {
			result = [NSString stringWithFormat:@"%@", result];
		}
		
		if (_paraProperties[@"alignment"]) {
			if ([_paraProperties[@"alignment"] isEqualToString:@"right"]) {
				result = [NSString stringWithFormat:@"> %@", result];
			}
			else if ([_paraProperties[@"alignment"] isEqualToString:@"center"]) {
				result = [NSString stringWithFormat:@"> %@ <", result];
			}
		}
		
		// Add () for parentheticals
		if ([_style isEqualToString:@"Parenthetical"]) {
			result = [result stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
			result = [NSString stringWithFormat:@"(%@)", result];
		}
		
		// Add object
		if ([result isEqualToString:@""] && [_lastAddedLine isEqualToString:@""]) {
			// Do nothing for now
		} else {
			// For title pages we append the correct param name first
			if (_titlePage) {
				if (_paraProperties[@"bookmark"]) {
					NSString *bookmark = _paraProperties[@"bookmark"];
					NSString *prefix;
					if ([bookmark isEqualToString:@"Title"]) prefix = @"Title";
					else if ([bookmark isEqualToString:@"Author"]) prefix = @"Author";
					else if ([bookmark isEqualToString:@"Draft"]) prefix = @"Draft date";
					else if ([bookmark isEqualToString:@"Contact"]) prefix = @"Contact";
					
					// Only add KNOWN title page elements
					if (prefix.length && result.length) {
						result = [NSString stringWithFormat:@"%@: %@", prefix, result];
						[_titlePageElements addObject:[NSString stringWithString:result]];
					}
				}
			} else {
				[_scriptLines addObject:[NSString stringWithString:result]];
			}
			_lastAddedLine = result;
		}
		
		_elementText = [NSMutableString string];
	}
	
	// Start & end sections
	if ([elementName isEqualToString:@"titlepage"]) {
		// Add a separator line
		[_titlePageElements addObject:@""];
		_titlePage = NO;
	}
    if ([elementName isEqualToString:@"paragraphs"]) {
		_contentFound = NO;
    }
}

- (NSString*)scriptAsString {
	if (_scriptLines.count) {
		if (_titlePageElements.count) {
			_scriptLines = [NSMutableArray arrayWithArray:[_titlePageElements arrayByAddingObjectsFromArray:_scriptLines]];
		}
		
		return [_scriptLines componentsJoinedByString:@"\n"];
	}
	return @"";
}

@end
