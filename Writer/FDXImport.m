//
//  FDXImport.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 8.1.2020.
//  Copyright © 2020 KAPITAN!. All rights reserved.
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

@interface FDXImport () <NSXMLParserDelegate>
@property(nonatomic, strong) NSXMLParser *xmlParser;
@end

@implementation FDXImport

- (id)initWithURL:(NSURL*)url completion:(void(^)(void))callback
{
	self = [super init];
	if (self) {
		_elementText = [[NSMutableString alloc] init];
		_script = [NSMutableArray array];
		_titlePage = NO;
		_dualDialogue = -1;

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
		_style = attributeDict[@"Style"];
		[_elementText setString:@""];
	}
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string{
	if (_contentFound && !_titlePage) {
		string = [string stringByTrimmingCharactersInSet:NSCharacterSet.newlineCharacterSet];
		
		// This is a trick by FD to kill FDX import/export from other apps, I guess?
		
		if ([_lastFoundElement isEqualToString:@"Text"]) {
			//if (![self isLastCharacterSpace:_elementText]) _elementText = [NSMutableString stringWithString:[_elementText stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]];
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
	
	// Reset last found element if needed
	if ([elementName isEqualToString:@"Text"]) _lastFoundElement = @"";
	// Reset dual dialogue
	else if ([elementName isEqualToString:@"DualDialogue"]) _dualDialogue = -1;
	// Go on
	else if ([elementName isEqualToString:@"Paragraph"]) {
		NSString *result = [NSString stringWithFormat:@"%@", _elementText];
		
		// Add empty rows before required elements.
		if ([_script count] > 0) {
			NSString *previousLine = [_script lastObject];
			
			if ([previousLine length] > 0 && [_elementText length] > 0) {
				if ([_activeElement isEqualToString:@"Character"] ||
					[_activeElement isEqualToString:@"Scene Heading"] ||
					[_activeElement isEqualToString:@"Action"]) {
					[_script addObject:@""];
				}
			}
		}
		
		if ([_activeElement isEqualToString:@"Scene Heading"]) {
			result = [result uppercaseString];
			
			// Force scene prefix if there is none and the style is scene heading anyway
			if ([result rangeOfString:@"INT."].location == NSNotFound &&
				[result rangeOfString:@"EXT."].location == NSNotFound &&
				[result rangeOfString:@"I./E."].location == NSNotFound
			) {
				result = [NSString stringWithFormat:@".%@", result];
			}
		}
		else if ([_activeElement isEqualToString:@"Lyrics"]) {
			result = [NSString stringWithFormat:@"~%@~", result];
		}
		if ([_activeElement isEqualToString:@"Character"]) {
			if (_dualDialogue > 0) _dualDialogue++;
			if (_dualDialogue == 3) {
				result = [result stringByAppendingString:@" ^"];
				_dualDialogue = -1;
			}
			else result = [result uppercaseString];
		}
		else if ([_activeElement isEqualToString:@"Transition"]) {
			result = [NSString stringWithFormat:@"> %@", [result uppercaseString]];
		}
		else if ([_activeElement isEqualToString:@"Transition"]) {
			result = [NSString stringWithFormat:@"> %@", [result uppercaseString]];
		}
		else {
			result = [NSString stringWithFormat:@"%@", result];
		}
		
		// Add object
		if ([result isEqualToString:@""] && [_lastAddedLine isEqualToString:@""]) {
			// Do nothing for now
		} else {
			[_script addObject:[NSString stringWithString:result]];
			_lastAddedLine = result;
		}
		_elementText = [NSMutableString string];
	}
	
	// Start & end sections
	if([elementName isEqualToString:@"TitlePage"]) {
		_titlePage = NO;
	}
    if([elementName isEqualToString:@"Content"]) {
		_contentFound = NO;
    }
}

- (NSString*)scriptAsString {
	if ([_script count]) {
		return [_script componentsJoinedByString:@"\n"];
	}
	return @"";
}

@end
