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

@property (nonatomic) FDXNote* openNote;
@property (nonatomic) NSMutableArray<FDXNote*>* notes;

@property (nonatomic) NSString* sceneColor;

@property (nonatomic) FDXSectionType section;

@property (nonatomic) bool importNotes;

@end

@implementation FDXImport

- (id)initWithURL:(NSURL*)url importNotes:(bool)importNotes completion:(void(^)(void))callback
{
	self = [super init];
	if (self) {
		_importNotes = importNotes;
		
		[self setup];

		// Thank you, RIPtutorial
		// Fetch xml data
		NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
		
		NSURLSessionDataTask *task = [session dataTaskWithRequest:[NSURLRequest requestWithURL:url] completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
			[self parse:data callback:callback];
		}];
			
		[task resume];
		
	}
	return self;
}

- (id)initWithData:(NSData*)data importNotes:(bool)importNotes completion:(void(^)(void))callback
{
	self = [super init];
	if (self) {
		_importNotes = importNotes;
		[self parse:data callback:callback];
	}
	
	return self;
}

- (void)setup
{
	_elementText = NSMutableString.new;
	_attrText = NSMutableAttributedString.new;
	_script = NSMutableArray.new;
	_titlePage = NO;
	_dualDialogue = -1;
	_attrContents = NSMutableAttributedString.new;
	_notes = NSMutableArray.new;

}

- (void)parse:(NSData*)data callback:(void(^)(void))callback
{
	self.xmlParser = [[NSXMLParser alloc] initWithData:data];
	self.xmlParser.delegate = self;
	if ([self.xmlParser parse]){
		callback();
	} else {
		NSLog(@"ERROR: %@", self.xmlParser.parserError);
	}
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(nullable NSString *)namespaceURI qualifiedName:(nullable NSString *)qName attributes:(NSDictionary<NSString *, NSString *> *)attributeDict
{
	_lastFoundElement = elementName;

	// Find different sections of the XML
	if ([elementName isEqualToString:@"Content"] && _section != FDXSectionTitlePage) {
		_section = FDXSectionContent;
		_contentFound = YES;
		return;
	}
	else if ([elementName isEqualToString:@"TitlePage"]) {
		_section = FDXSectionTitlePage;
		_titlePage = YES;
		return;
	}
	else if ([elementName isEqualToString:@"ScriptNotes"]) {
		_section = FDXSectionNotes;
		return;
	}
	else if ([elementName isEqualToString:@"ScriptNote"]) {
		NSString* rangeStr = attributeDict[@"Range"];
		NSArray<NSString*>* locLen = [rangeStr componentsSeparatedByString:@","];
		if (locLen.count < 2) return;
		
		NSInteger loc = locLen[0].integerValue;
		NSInteger len = locLen[1].integerValue - loc;
		
		_openNote = [FDXNote.alloc initWithRange:NSMakeRange(loc, len)];
		_openNote.color = [FDXElement colorNameFor16bitHex:attributeDict[@"Color"]];
		
		return;
	}
	
	// Handle content
	if ([elementName isEqualToString:@"DualDialogue"]) {
		_dualDialogue = 1;
	}
	else if ([elementName isEqualToString:@"Paragraph"]) {
		// When exiting sub-node, the parser might think we are beginning this node again, with null attributes
		if (!_insideParagraph) {
			if (attributeDict[@"Type"] != nil) _activeElement = attributeDict[@"Type"];
			_alignment = attributeDict[@"Alignment"];
		}
				
		// Create new element
		_element = [FDXElement withText:@"" type:_activeElement];
	}
	else if ([elementName isEqualToString:@"Text"]) {
		_didFinishText = NO;
		_lastFoundString = @"";
		_textStyle = attributeDict[@"Style"];
		_revisionID = attributeDict[@"RevisionID"];
	}
	else if ([elementName isEqualToString:@"SceneProperties"]) {
		// Read possible scene color
		_element.sceneColor = attributeDict[@"Color"];
	}
	
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string
{
	// Let's ignore title page and other non-content stuff
	if (_section == FDXSectionNone || _section == FDXSectionTitlePage) return;
	
	if (_section == FDXSectionContent || _section == FDXSectionNotes) {
		// Handle content
		string = [string stringByTrimmingCharactersInSet:NSCharacterSet.newlineCharacterSet]; // Clear line breaks to be safe
		
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
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(nullable NSString *)namespaceURI qualifiedName:(nullable NSString *)qName
{
	// End sections
	if ([elementName isEqualToString:@"TitlePage"]) {
		_titlePage = NO;
		_section = FDXSectionNone;
		return;
	}
	else if ([elementName isEqualToString:@"Content"]) {
		_contentFound = NO;
		_section = FDXSectionNone;
		return;
	}
	else if ([elementName isEqualToString:@"ScriptNotes"]) {
		_section = FDXSectionNone;
		return;
	}
	
		
	// Handle content
	if ([elementName isEqualToString:@"Text"]) {
		[self addTextFragment];
	}
	else if ([elementName isEqualToString:@"DualDialogue"]) {
		// Reset dual dialogue
		_dualDialogue = -1;
	}
	else if ([elementName isEqualToString:@"Paragraph"] && _element.string.length > 0) {
		[self addParagraph];
	}
	else if ([elementName isEqualToString:@"ScriptNote"] && _openNote != nil) {
		[_notes addObject:_openNote];
	}

}

- (void)addTextFragment
{
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

- (void)addParagraph
{
	// At the end of a paragraph we'll stylize the text and append it to content.
	_insideParagraph = false;
	
	// Let's store the original string for later use
	_element.originalString = _element.string.copy;
	
	// Add empty rows before required elements when needed
	FDXElement *previousLine = _script.lastObject;
	if (previousLine.length > 0 && _element.length > 0) {
		if ([_activeElement isEqualToString:@"Character"] ||
			[_activeElement isEqualToString:@"Scene Heading"] ||
			[_activeElement isEqualToString:@"Action"] ||
			[_activeElement isEqualToString:@"Shot"]) {
			[_script addObject:FDXElement.lineBreak];
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
		
		if (_element.sceneColor != nil) {
			NSString* colorString = [NSString stringWithFormat:@" [[%@]]", [FDXElement colorNameFor16bitHex:_element.sceneColor]];
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
		
		// Set outline element depth
		if (p != NSNotFound && _activeElement.length > p) {
			depth = [_activeElement substringFromIndex:p + 1].integerValue;
		}
		// Add as many #'s as needed
		for (NSInteger i=0; i<depth; i++) [_element insertAtBeginning:@"#"];
		
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
		
	// Add object only if both this and the previous line are not empty (avoids unnecessary empty lines)
	// if (_element.string.length == 0 && _lastAddedLine.string.length == 0) return;
	
	// Add section paragraphs to content
	if (_section == FDXSectionContent) {
		[_script addObject:_element];
		_lastAddedLine = _element;
	}
	else if (_section == FDXSectionNotes) {
		// Add to note
		[_openNote.elements addObject:_element];
		_lastAddedLine = _element;
	}
}

- (NSString*)scriptAsString
{
	if (_script.count < 1) return @"";
	
	NSMutableAttributedString *attributedScript = NSMutableAttributedString.new;
	
	// Create a index set of notes
	NSMutableIndexSet* noteIndices = NSMutableIndexSet.new;
	for (FDXNote* note in _notes) {
		if (note.range.length > 0) {
			[noteIndices addIndexesInRange:note.range];
		} else {
			[noteIndices addIndex:note.range.location];
		}
	}
	
	NSInteger pos = 0;
	for (FDXElement *element in _script) {
		NSInteger length = (element.originalString.length > 0) ? element.originalString.length + 1 : 0;
		NSRange lineRange = NSMakeRange(pos, length);
		
		// Insert notes
		if (_importNotes && [self range:lineRange containsAnyIndex:noteIndices]) {
			for (FDXNote* note in _notes) {
				if (!NSLocationInRange(note.range.location, lineRange)) continue;
				NSAttributedString* aNote = [NSAttributedString.alloc initWithString:note.noteString];
				[element.text insertAttributedString:aNote atIndex:element.length];
			}
		}
		
		[attributedScript appendAttributedString:element.attributedFountainString];
		[attributedScript appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n"]];
		pos += lineRange.length;
	}

		
	// Let's create a faux Beat document out of the FDX data
	BeatDocumentSettings *settings = BeatDocumentSettings.new;
	NSDictionary *revisionRanges = [BeatRevisions rangesForSaving:attributedScript];
	[settings set:DocSettingRevisions as:revisionRanges];
	
	return [NSString stringWithFormat:@"%@\n%@", attributedScript.string, [settings getSettingsString]];
}

- (bool)range:(NSRange)range containsAnyIndex:(NSIndexSet*)set
{
	for (NSInteger i=range.location; i<NSMaxRange(range); i++) {
		if ([set containsIndex:i]) return true;
	}
	return false;
}


@end
