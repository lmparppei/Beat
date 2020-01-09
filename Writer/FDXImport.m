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

		// Thank you, RIPtutorial
		//Fetch xml data
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
    
	if ([elementName isEqualToString:@"Content"]) {
		_contentFound = YES;
	}
	if ([elementName isEqualToString:@"TitlePage"]) {
		_titlePage = YES;
	}
	if ([elementName isEqualToString:@"Paragraph"]) {
		_activeElement = attributeDict[@"Type"];
		_alignment = attributeDict[@"Alignment"];
		_style = attributeDict[@"Style"];
		[_elementText setString:@""];
	}
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string{
	if (_contentFound && !_titlePage) {
		[_elementText appendString:[string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
	}
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(nullable NSString *)namespaceURI qualifiedName:(nullable NSString *)qName{
    
	if([elementName isEqualToString:@"Paragraph"]) {
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
		if ([_activeElement isEqualToString:@"Lyrics"]) {
			result = [NSString stringWithFormat:@"~%@~", result];
		}
		if ([_activeElement isEqualToString:@"Character"]) {
			result = [result uppercaseString];
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
		[_script addObject:[NSString stringWithString:result]];
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
