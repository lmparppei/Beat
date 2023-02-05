//
//  BeatHTMLScript.m
//	Modified for Beat from FNHTMLScript
//
//  Copyright © 2019-2020 Lauri-Matti Parppei / Lauri-Matti Parppei
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy 
//  of this software and associated documentation files (the "Software"), to 
//  deal in the Software without restriction, including without limitation the 
//  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or 
//  sell copies of the Software, and to permit persons to whom the Software is 
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in 
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING 
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS 
//  IN THE SOFTWARE.
//

/*
 
 This piece of code outputs the screenplay as HTML. It is based on FNHTMLScript.m.
 It now natively uses the Beat data structure (Line) and the Continuous Fountain Parser
 instead of the old, open source Fountain stuff. It's now about 10 times faster and
 more reliable.
  
 Note that HTML output links to either screen or print CSS depending on the target format.
 Print & PDF versions rely on ScreenplayStyles.css and preview mode add PreviewStyles.css
 on top of that.
 
 Pagination is a bit messy, but generally speaking, it inherits print settings
 and page size either from the original Document class or defaults to A4.
 
 The old open source stuff was very, very dated, and in late 2019 I ran into pretty
 big problems, which had to do with computer architecture stuff. I was ill prepared
 for my little programming project requiring any understanding of that. The code
 used a library called RegexKitLite and I had to rewrite everything referring to it.
 
 I saved the rant below from those days, because it's fairly funny and touching:
 
 - As I'm writing this, some functions in RegexKitLite.h have been deprecated in
   macOS 10.12+. Fair enough - it was apparently last updated in 2010.
 
   Back then, I hadn't made any films. In 2010, I was young, madly in love and
   had dreams and aspirations. I had just recently started my studies in a film school.
   In 9 years, I figured back then, I'd be making films that really communicated the
   pain I had gone through. My films would reach out to other lonely people, confined
   in their gloomy tomb, assured of their doom.
 
   Well.
 
   Instead, I'm reading about fucking C enumerators and OS spin locks to be able to
   build my own fucking software, which - mind you - ran just fine a few weeks ago.
 
   Hence, I tried to replace the deprecated spin locks of RegexKitLite.h with modern ones.
   It was about to destroy my inner child. I just wanted to write nice films, I wasn't
   planning on fucking learning any motherfucking C!!!!!!
 
   SO, if you are reading this: Beat now relies on a customized RegexKitLite, which might
   work or not. It could crash systems all around the world. It could consume your
   computer's soul and kill any glimpse of hope.
 
   I could have spent these hours with my dear friends, my lover or just watching flowers
   grow and maybe talking to them. Or even writing my film. I didn't. Here I am, typing
   this message to some random fucker who, for whatever reason, decides to take a look at
   my horrible code sometime in the future.
 
   Probably it's me, though.
 
   What can I say. STOP WASTING YOUR LIFE AND GO FUCK YOURSELF.

 ---
 
 UPDATE 21th Jan 2020:
 References to RegexKitLite have been removed. Totally.
 It has resulted in some pretty strange solutions, and self-customizing a Regex library,
 but for now it works - also on modern systems.
 
 UPDATE 17th May 2020:
 This could be rewritten to conform with our Line* class instead of FNElement / FNScript.
 I also stumbled upon the message written above, and omg past me, I'd send you some hugs and kisses
 if I could, but I'm writing this amidst the COVID-19 pandemic so I have to keep my distance.
 
 UPDATE 4th September 2020:
 I implemented the idea presented above. It now works like a charm and is a lot faster.
 At first, it was used only for the previews, but now every single reference to the old
 Fountain stuff has been removed!
 
 UPDATE sometime in November 2020:
 The code has been cleaned up a bit.
 
*/

#import "BeatHTMLScript.h"
#import <BeatParsing/BeatParsing.h>
#import <BeatDefaults/BeatDefaults.h>

#define PRINT_CSS @"ScreenplayStyles"
#define PREVIEW_CSS @"PreviewStyles"
#define PREVIEW_IOS @"PreviewStyles-iOS"

#define BOLD_OPEN @"<b>"
#define BOLD_CLOSE @"</b>"
#define ITALIC_OPEN @"<i>"
#define ITALIC_CLOSE @"</i>"
#define UNDERLINE_OPEN @"<u>"
#define UNDERLINE_CLOSE @"</u>"
#define STRIKEOUT_OPEN @"<del>"
#define STRIKEOUT_CLOSE @"</del>"
#define NOTE_OPEN @"<span class='note'>"
#define NOTE_CLOSE @"</span>"

@interface BeatHTMLScript ()

@property (readonly, copy, nonatomic) NSString *cssText;
@property (nonatomic) NSInteger numberOfPages;
@property (nonatomic) NSArray* htmlPages;
@property (atomic) NSArray* paginatedContent;
@property (nonatomic) BeatExportSettings *settings;

@end

@implementation BeatHTMLScript

static bool boldedHeading;
static bool underlinedHeading;

- (id)initWithLines:(NSArray*)lines {
	// This method is here for our studio party
	self = [super init];
	_script = lines;
	_settings = [BeatExportSettings operation:ForPreview document:nil header:@"" printSceneNumbers:false];
	
	return self;
}

- (id)initWithScript:(BeatScreenplay*)script settings:(BeatExportSettings*)settings {
	self = [super init];
	
	if (settings) {
		_script = script.lines;
		_titlePage = script.titlePage;
		
		_settings = settings;
		if (settings.header.length == 0) settings.header = @""; // Double check that header is ""
						
		// Styles
		boldedHeading = [BeatUserDefaults.sharedDefaults getBool:BeatSettingHeadingStyleBold];
		underlinedHeading = [BeatUserDefaults.sharedDefaults getBool:BeatSettingHeadingStyleUnderlined];
	}
	
	return self;
}

// Init with pre-paginated content
- (id)initWithPages:(NSArray*)pages titlePage:(NSArray*)titlePage settings:(BeatExportSettings*)settings {
	self = [super init];
	
	if (settings) {
		_titlePage = titlePage;
		_paginatedContent = pages;
		_settings = settings;
		
		if (settings.header.length == 0) settings.header = @""; // Double check that header is ""
						
		// Styles
		boldedHeading = [BeatUserDefaults.sharedDefaults getBool:BeatSettingHeadingStyleBold];
		underlinedHeading = [BeatUserDefaults.sharedDefaults getBool:BeatSettingHeadingStyleUnderlined];
	}
	
	return self;
}

- (id)initForQuickLook:(BeatScreenplay*)script {
	BeatExportSettings *settings = [BeatExportSettings operation:ForQuickLook document:nil header:@"" printSceneNumbers:YES];
	settings.paperSize = BeatA4;
	return [self initWithScript:script settings:settings];
}


#pragma mark - HTML content

- (NSInteger)pages {
	return _numberOfPages + 1;
}

- (NSString *)html
{
	NSMutableString *html = NSMutableString.new;
	[html appendString:[self htmlHeader]];
	[html appendString:[self content]];
	[html appendString:[self htmlFooter]];

	return html;
}


- (NSString*)htmlHeader {
	NSURL* templateUrl = [NSBundle.mainBundle URLForResource:@"HeaderTemplate" withExtension:@"html"];
	NSString* template = [NSString stringWithContentsOfURL:templateUrl encoding:NSUTF8StringEncoding error:nil];
	
	NSString *bodyClasses = @"";
	
	// Append body classes
	if (_settings.operation == ForQuickLook) bodyClasses = [bodyClasses stringByAppendingString:@" quickLook"];

	// Paper size body class
	if (_settings.paperSize == BeatUSLetter) bodyClasses = [bodyClasses stringByAppendingString:@" us-letter"];
	else bodyClasses = [bodyClasses stringByAppendingString:@" a4"];
	
	template = [template stringByReplacingOccurrencesOfString:@"#CSS#" withString:self.css];
	template = [template stringByReplacingOccurrencesOfString:@"#BODYCLASSES#" withString:bodyClasses];
	
	return template;
}

- (NSString*)htmlFooter {
	NSURL *templateUrl = [NSBundle.mainBundle URLForResource:@"FooterTemplate" withExtension:@"html"];
	NSString *template = [NSString stringWithContentsOfURL:templateUrl encoding:NSUTF8StringEncoding error:nil];
	
	return template;
}

- (NSString *)content {
	// N.B. this method can be called alone by itself to return pure content,
	// as can htmlBody. Dont' include anything that could break that functionality.
	
	if (!self.bodyText) {
		self.bodyText = [self htmlBody];
	}
	
	NSMutableString *html = [NSMutableString string];
	[html appendString:@"<article>\n"];
	[html appendString:self.bodyText];
	[html appendString:@"</article>\n"];
	
	return html;
}

- (NSArray*)singlePages {
	if (self.htmlPages == nil) self.htmlPages = [self paginateAndCreateHTML];
	
	NSMutableArray *everyPageAsDocument = NSMutableArray.new;
	
	for (NSString *page in self.htmlPages) {
		NSMutableString *html = [NSMutableString string];
		[html appendString:[self htmlHeader]];
		[html appendString:@"<article>\n"];
		[html appendString:page];
		[html appendString:@"</article>\n"];
		[html appendString:[self htmlFooter]];
		[everyPageAsDocument addObject:html];
	}
	
	return everyPageAsDocument;
}


- (NSString *)css
{
	NSString * css = [NSString stringWithContentsOfURL:[NSBundle.mainBundle URLForResource:PRINT_CSS withExtension:@"css"]
											  encoding:NSUTF8StringEncoding
												 error:nil];
	if (css == nil) css = @"";
	
	NSString * previewCss = [NSString stringWithContentsOfURL:[NSBundle.mainBundle URLForResource:PREVIEW_CSS withExtension:@"css"]
													 encoding:NSUTF8StringEncoding
														error:nil];
	
#if TARGET_OS_IOS
	// Additional styles for iOS WebKit rendering
	NSString *iosCss = [NSString stringWithContentsOfURL: [NSBundle.mainBundle URLForResource:PREVIEW_IOS withExtension:@"css"] encoding:NSUTF8StringEncoding error:nil];
	previewCss = [previewCss stringByAppendingString:iosCss];
#endif
	
	// Include additional preview styles and add some line breaks just in case
	if (_settings.operation != ForPrint) {
		css = [css stringByAppendingString:@"\n\n"];
		css = [css stringByAppendingString:previewCss];
	}
	
	// Print settings included custom CSS styles, add them in
	if (_settings.customCSS.length) {
		css = [css stringByAppendingString:@"\n\n"];
		css = [css stringByAppendingString:_settings.customCSS];
	}
	
	// Preprocess CSS
	NSInteger spacingBeforeHeading = [BeatUserDefaults.sharedDefaults getInteger:@"sceneHeadingSpacing"];
	css = [css stringByReplacingOccurrencesOfString:@"#sceneHeadingSpacing#" withString:[NSString stringWithFormat:@"%lu", spacingBeforeHeading]];
	
    return css;
}

- (NSString*)singlePage:(NSArray*)elementsOnPage pageNumber:(NSInteger)pageNumber {
	NSMutableString *body = NSMutableString.string;
	NSInteger dualDialogueCharacterCount = 0;
	NSSet *ignoringTypes = [NSSet setWithObjects:@"Boneyard", @"Comment", @"Synopse", @"Section", nil];
	
	NSString *pageClass = @"";
	
	// If we are coloring the revised pages, check for any changed lines here
	if (_settings.coloredPages && _settings.pageRevisionColor.length && _settings.operation == ForPrint) {
		bool revised = NO;
		for (Line* line in elementsOnPage) {
			if (line.changed) {
				revised = YES; break;
			}
		}
		
		if (revised) pageClass = [NSString stringWithFormat:@"revised %@", _settings.pageRevisionColor];
	}
	
	
	// Begin page
	[body appendFormat:@"<section class='%@'>", pageClass];
	
	int elementCount = 0;
	
	if (self.customPage != nil) {
		if (self.customPage.integerValue == 0) {
			[body appendFormat:@"<p class='page-break-render'><span class='header-top'>%@</span></p>\n", _settings.header];
		} else {
			// I don't understand this part. For some reason certain elements are cut off the page and have a random page number there when rendering. So, as a rational and solution-oriented person, I just removed the page number altogether if this happens.
			// - Lauri-Matti
			if (pageNumber < 3) [body appendFormat:@"<p class='page-break-render'><span class='header-top'>%@</span> %d.</p>\n", _settings.header, [self.customPage intValue]];
		}
	} else {
		// Only print page numbers after first page
		
		if (pageNumber > 1) [body appendFormat:@"<p class='page-break-render'><span class='header-top'>%@</span> %lu.</p>\n", _settings.header, pageNumber];
		else [body appendFormat:@"<p class='page-break-render'><span class='header-top'>%@</span> &nbsp;</p>\n", _settings.header];
	}
	
	// We need to catch lyrics not to make them fill up a paragraph
	LineType block = empty;
	
	for (Line *line in elementsOnPage) { @autoreleasepool {
		bool beginBlock = false;
		
		if ([ignoringTypes containsObject:line.typeAsString]) {
			// Close possible blocks
			if (block != empty) {
				// Close possible blocks
				[body appendFormat:@"</p>\n"];
				block = empty;
			}

			continue;
		}
		
		if (line.type == pageBreak) {
			if (block != empty) {
				// Close the block
				[body appendFormat:@"</p>\n"];
				block = empty;
			}
			 
			continue;
		}
		
		// Stop dual dialogue
		if ((dualDialogueCharacterCount == 2 && !line.isDualDialogueElement) ||
			(dualDialogueCharacterCount == 1 && line.type == character)) {
			[body appendString:@"</div></div>\n"];
			dualDialogueCharacterCount = 0;
		}
		
		// Catch dual dialogue
		if (line.type == character && line.nextElementIsDualDialogue) {
			dualDialogueCharacterCount++;
			[body appendString:@"<div class='dual-dialogue'>\n"];
			[body appendString:@"<div class='dual-dialogue-left'>\n"];
		}
		
		if (line.type == dualDialogueCharacter && dualDialogueCharacterCount == 1) {
			dualDialogueCharacterCount++;
			[body appendString:@"</div>\n<div class='dual-dialogue-right'>\n"];
		}
		
		NSMutableString *text = NSMutableString.new;

		// Begin lyrics or centered block
		if (block != empty) {
			if (line.type != block) {
				// Close block
				[body appendFormat:@"</p>\n"];
				block = empty;
			}
			else if (line.type == block && line.beginsNewParagraph) {
				[body appendFormat:@"</p>\n"];
				beginBlock = true;
			}
		}
		else {
			if (line.type == lyrics || line.type == centered) {
				block = line.type;
				beginBlock = true;
			}
		}
		
		// Format string for HTML (if it's not a heading)
		[text setString:[self htmlStringFor:line]];
		
		// To avoid underlining heading tails, let's trim the text if needed
		if (line.type == heading && underlinedHeading) [text setString:[text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet]];
		
		// Preview shortcuts
		if (line.type == heading && _settings.operation == ForPreview) {
			[text setString:[NSString stringWithFormat:@"<a href='#' onclick='selectScene(this);' sceneIndex='%lu'>%@</a>", line.sceneIndex, text]];
		}

		NSMutableString *additionalClasses = [NSMutableString string];
		
		if (line.type == heading && line.sceneNumber) {
			// Add scene number ID to HTML, but don't print it if it's toggled off
			NSString *printedSceneNumber;
			if (_settings.printSceneNumbers) printedSceneNumber = line.sceneNumber;
			else printedSceneNumber = @"";
							
			NSString* sceneNumberLeft = [NSString stringWithFormat:@"<span id='scene-%@' class='scene-number-left'>%@</span>", line.sceneNumber, printedSceneNumber];
			NSString* sceneNumberRight = [NSString stringWithFormat:@"<span class='scene-number-right'>%@</span>", printedSceneNumber];
			
			[text setString:[NSString stringWithFormat:@"%@%@%@", sceneNumberLeft, text, sceneNumberRight]];
			
			if (boldedHeading) [additionalClasses appendString:@" bold"];
			if (underlinedHeading) [additionalClasses appendString:@" underline"];
		}
		
		if (![text isEqualToString:@""]) {
			if (line.type == centered) {
				[additionalClasses appendString:@" center"];
			}
			if (elementCount == 0) [additionalClasses appendString:@" first"];
			
			// Mark as changed, if comparing against another file or the line contains added/removed text
			if (line.changed || line.revisedRanges.count || line.removalSuggestionRanges.count) {
				[additionalClasses appendString:@" changed"];
				
				// Add revision color if available
				if (line.revisionColor.length > 0) {
					[additionalClasses appendFormat:@" %@", line.revisionColor.lowercaseString];
				}
			}
			
			// If this line isn't part of a larger block, output it as paragraph
			if (!beginBlock && block == empty) {
				[body appendFormat:@"<p class='%@%@' uuid='%@' paginatedHeight='%lu'>%@</p>\n", [self htmlClassForType:line.typeAsString], additionalClasses,line.uuid.UUIDString.lowercaseString,  line.heightInPaginator, text];
			} else {
				if (beginBlock) {
					// Begin new block
					[body appendFormat:@"<p class='%@%@' uuid='%@'>%@<br>", [self htmlClassForType:line.typeAsString], additionalClasses, line.uuid.UUIDString.lowercaseString, text];
				} else {
					// Continue the block
					// note: we can't use \n after the lines to make it more easy read, because we want to preserve the white space
					[body appendFormat:@"<span class='%@'>%@</span><br>", line.uuid.UUIDString.lowercaseString, text];
				}
			}
		} else {
			// Just in case
			if (block != empty) {
				// Close lyrics block
				[body appendFormat:@"</p>\n"];
				block = empty;
			}
		}
		
		elementCount++;
	} }
	
	[body appendString:@"</section>"];
	
	return body;
}

- (NSString*)htmlBody {
	if (_paginatedContent != nil) {
		_htmlPages = [self createHTMLWithPages:_paginatedContent];
	}
	else {
		_htmlPages = [self paginateAndCreateHTML];
	}
	return [_htmlPages componentsJoinedByString:@"\n"];
}

- (NSArray*)paginateAndCreateHTML
{
	// Pagination
	_paginator = [BeatPaginator.alloc initWithScript:_script settings:_settings];
	return [self createHTMLWithPages:_paginator.pages];
}

- (NSArray*)createHTMLWithPages:(NSArray*)paginatedContent
{
	_numberOfPages = paginatedContent.count;
	
	NSMutableArray *pages = NSMutableArray.new;
	NSMutableDictionary *titlePage = NSMutableDictionary.dictionary;
	
	// Put title page elements into a dictionary
	// (For some reason they maintain their order when done like this)
	for (NSDictionary *dict in self.titlePage) {
        [titlePage addEntriesFromDictionary:dict];
    }
	
	// Create title page
	NSString * titlePageString = [self createTitlePage:titlePage];
	[pages addObject:titlePageString];
    	
	// Header string (make sure it's not null)
	NSString *header = (_settings.header) ? _settings.header : @"";
	if (header.length) header = [header stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"];
	
	for (NSInteger pageIndex = 0; pageIndex < paginatedContent.count; pageIndex++) {
        NSArray *elementsOnPage = paginatedContent[pageIndex];
		NSString *pageAsString = [self singlePage:elementsOnPage pageNumber:pageIndex + 1];
		[pages addObject:pageAsString];
    }
	
	_htmlPages = pages;
	return pages;
}

- (NSString*)createTitlePage:(NSMutableDictionary*)titlePage {
	NSMutableString *body = [NSMutableString stringWithString:@""];;
	
	if (titlePage.count > 0) {
		[body appendString:@"<section id='script-title' class='page'>"];
		[body appendFormat:@"<div class='mainTitle'>"];
		
		// Title
		if (titlePage[@"title"] == nil) titlePage[@"title"] = @[@"Untitled"];
		[body appendString:[self titlePageElementForKey:@"title" titlePage:titlePage]];
	
		// Replace "author" with "authors"
		if (titlePage[@"author"] != nil) {
			titlePage[@"authors"] = titlePage[@"author"];
			[titlePage removeObjectForKey:@"author"];
		}
		
		// Add Credit, Authors, Source (in this order)
		NSArray * credits = @[@"credit", @"authors", @"source"];
		for (NSString *credit in credits) {
			[body appendString:[self titlePageElementForKey:credit titlePage:titlePage]];
		}
				
		[body appendFormat:@"</div>"];
				
		// Draft date
		[body appendFormat:@"<div class='versionInfo'><p>"];
		[body appendString:[self titlePageElementForKey:@"draft date" titlePage:titlePage]];
		[body appendFormat:@"</p></div>"];
		
		// Left side block
		[body appendFormat:@"<div class='info'>"];
		[body appendString:[self titlePageElementForKey:@"contact" titlePage:titlePage]];
		[body appendString:[self titlePageElementForKey:@"notes" titlePage:titlePage]];
		
		// Append rest of the stuff
		while (titlePage.count > 0) {
			NSString * key = titlePage.allKeys.firstObject;
			[body appendString:[self titlePageElementForKey:key titlePage:titlePage customKey:true]];
		}
		
		[body appendFormat:@"</div>"];
		
		[body appendString:@"</section>"];
	}
	
	return body;
}

- (NSString*)titlePageElementForKey:(NSString*)key titlePage:(NSMutableDictionary*)titlePage {
	return [self titlePageElementForKey:key titlePage:titlePage customKey:false];
}
- (NSString*)titlePageElementForKey:(NSString*)key titlePage:(NSMutableDictionary*)titlePage customKey:(bool)customKey {
	NSArray *values = titlePage[key];
	NSMutableString *element = NSMutableString.new;
	NSString *className = [key stringByReplacingOccurrencesOfString:@" " withString:@"-"];
	
	if (values == nil) {
		[element appendFormat:@"<p class='%@'>%@</p>", className, @""];
		return element;
	}
	
	NSMutableString *result = NSMutableString.new;
	for (NSString *val in values) {
		[result appendFormat:@"%@<br>", val];
	}
	
	// We won't set a class value based on the custom key, because it might conflict with existing css styles
	[element appendFormat:@"<p class='%@'>%@</p>", (customKey) ? @"" : className, [self format:result]];
	[titlePage removeObjectForKey:key];
	
	return element;
}

#pragma mark - Helper methods

- (NSString *)htmlClassForType:(NSString *)elementType
{
	return [elementType.lowercaseString stringByReplacingOccurrencesOfString:@" " withString:@"-"];
}

- (NSString*)format:(NSString*) string {
	string = [RX(BOLD_ITALIC_UNDERLINE_PATTERN) stringByReplacingMatchesInString:string options:0 range:NSMakeRange(0, string.length) withTemplate:@"<u><em><strong>$2</strong></em></u>"];
	string = [RX(BOLD_ITALIC_PATTERN) stringByReplacingMatchesInString:string options:0 range:NSMakeRange(0, string.length) withTemplate:@"<strong><em>$2</em></strong>"];
	string = [RX(BOLD_UNDERLINE_PATTERN) stringByReplacingMatchesInString:string options:0 range:NSMakeRange(0, string.length) withTemplate:@"<strong><u>$2</u></strong>"];
	string = [RX(ITALIC_UNDERLINE_PATTERN) stringByReplacingMatchesInString:string options:0 range:NSMakeRange(0, string.length) withTemplate:@"<u><em>$2</em></u>"];
	string = [RX(BOLD_PATTERN) stringByReplacingMatchesInString:string options:0 range:NSMakeRange(0, string.length) withTemplate:@"<strong>$2</strong>"];
	string = [RX(ITALIC_PATTERN) stringByReplacingMatchesInString:string options:0 range:NSMakeRange(0, string.length) withTemplate:@"<em>$2</em>"];
	string = [RX(UNDERLINE_PATTERN) stringByReplacingMatchesInString:string options:0 range:NSMakeRange(0, string.length) withTemplate:@"<u>$2</u>"];
	
	// Remove escape characters
	string = [string stringByReplacingOccurrencesOfString:@"\\*" withString:@"*"];
	string = [string stringByReplacingOccurrencesOfString:@"\\_" withString:@"_"];
	string = [string stringByReplacingOccurrencesOfString:@"\\@" withString:@"@"];
	string = [string stringByReplacingOccurrencesOfString:@"\\**" withString:@"**"];

	return string;
}
- (NSString*)htmlStringFor:(Line*)line {
	// We use the FDX attributed string to create a HTML representation of Line objects
	NSAttributedString *string = line.attributedStringForFDX;
	
	// Ignore any formatting and only include CONTENT ranges
	NSMutableAttributedString *result = NSMutableAttributedString.new;
	
	NSIndexSet *indices;
	if (!_settings.printNotes) indices = line.contentRanges;
	else {
		indices = line.contentRangesWithNotes;
	}
	
	[indices enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		[result appendAttributedString:[string attributedSubstringFromRange:range]];
	}];
		
	NSMutableString *htmlString = [NSMutableString string];
	
	// Get stylization in the current attribute range
	[result enumerateAttributesInRange:(NSRange){0, result.length} options:0 usingBlock:^(NSDictionary<NSAttributedStringKey,id> * _Nonnull attrs, NSRange range, BOOL * _Nonnull stop) {
		NSMutableString* text = [result.string substringWithRange:range].mutableCopy;
		// Opening and closing tags
		NSMutableString *open = NSMutableString.new;
		NSMutableString *close = NSMutableString.new;
		
		NSString *styleString = attrs[@"Style"];

		// Append corresponding HTML tags to opening & closing strings, ie. open = "<b>", close = "</b>"
		if (styleString.length) {
			NSMutableArray *styleArray = [styleString componentsSeparatedByString:@","].mutableCopy;
			[styleArray removeObject:@""];
						
			if ([styleArray containsObject:@"Bold"]) {
				[open appendString:BOLD_OPEN];
				[close appendString:BOLD_CLOSE];
			}
			if ([styleArray containsObject:@"Italic"]) {
				[open appendString:ITALIC_OPEN];
				[close appendString:ITALIC_CLOSE];
			}
			if ([styleArray containsObject:@"Underline"]) {
				[open appendString:UNDERLINE_OPEN];
				[close appendString:UNDERLINE_CLOSE];
			}
			if ([styleArray containsObject:@"Strikeout"]) {
				[open appendString:STRIKEOUT_OPEN];
				[close appendString:STRIKEOUT_CLOSE];
			}
			if ([styleArray containsObject:@"RemovalSuggestion"]) {
				[open appendString:STRIKEOUT_OPEN];
				[close appendString:STRIKEOUT_CLOSE];
			}
			if ([styleArray containsObject:@"Addition"]) {
				//open = [open stringByAppendingString:ADDITION_OPEN];
				//close = [close stringByAppendingString:ADDITION_OPEN];
			}
			if ([styleArray containsObject:@"Note"]) {
				[open appendString:NOTE_OPEN];
				[close appendString:NOTE_CLOSE];
			}
			
			// Iterate through possible revisions baked into the line
			for (NSString *key in styleArray.copy) {
				// A revision style attribute is formatted as "Revision:color"
				if ([key containsString:@"Revision:"]) {
					[styleArray removeObject:key];
					
					NSArray *revisionComponents = [key componentsSeparatedByString:@":"];
					if (revisionComponents.count < 2) continue;
					NSString *revColor = revisionComponents[1];
					
					[open appendFormat:@"<span class='changedDetail %@'><a class='revisionMarker'></a>", revColor];
					[close appendString:@"</span>"];
				}
			}
			
		}
		
		// Append snippet to paragraph
		[htmlString appendString:[NSString stringWithFormat:@"%@%@%@", open, [self escapeString:text], close]];
	}];
	
	// Create HTML line breaks
	[htmlString replaceOccurrencesOfString:@"\n" withString:@"<br>" options:0 range:(NSRange){0,htmlString.length}];
	
	return htmlString;
}

- (NSString*)escapeString:(NSString*)stringToEscape
{
	NSMutableString *string = [NSMutableString stringWithString:stringToEscape];
	[string replaceOccurrencesOfString:@"&"  withString:@"&amp;"  options:NSLiteralSearch range:NSMakeRange(0, [string length])];
	[string replaceOccurrencesOfString:@"\"" withString:@"&quot;" options:NSLiteralSearch range:NSMakeRange(0, [string length])];
	[string replaceOccurrencesOfString:@"'"  withString:@"&#x27;" options:NSLiteralSearch range:NSMakeRange(0, [string length])];
	[string replaceOccurrencesOfString:@">"  withString:@"&gt;"   options:NSLiteralSearch range:NSMakeRange(0, [string length])];
	[string replaceOccurrencesOfString:@"<"  withString:@"&lt;"   options:NSLiteralSearch range:NSMakeRange(0, [string length])];
	
	return string;
}

@end

/*
 
 Li Po crumbles his poems
 sets them on
 fire
 floats them down the
 river.
 
 'what have you done?' I
 ask him.
 
 Li passes the
 bottle: 'they are
 going to end
 no matter what
 happens...
 
 I drink to his knowledge
 pass the bottle back
 
 sit tightly upon my poems
 which I have
 jammed halfway up my crotch
 
 I help him burn
 some more of his poems
 
 it floats well
 down
 the river
 lighting up the night
 as good words
 shoul.
 
 */
