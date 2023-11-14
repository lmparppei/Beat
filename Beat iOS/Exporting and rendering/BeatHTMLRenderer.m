//
//  BeatHTMLRenderer.m
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 21.4.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatHTMLRenderer.h"

#import <BeatCore/BeatCore.h>
#import <BeatPagination2/BeatPagination2.h>
#import <BeatParsing/BeatParsing.h>

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

@interface BeatHTMLRenderer()

@property (nonatomic) NSString* css;
@property (nonatomic) BeatExportSettings* settings;

@end

@implementation BeatHTMLRenderer

//static bool boldedHeading;
//static bool underlinedHeading;

/// Returns a renderer with pre-paginated content
- (instancetype)initWithPagination:(BeatPagination*)pagination settings:(BeatExportSettings*)settings
{
	self = [super init];
	if (self) {
		self.pages = pagination.pages;
		self.pagination = pagination;
		self.settings = settings;
	}
	return self;
}

/// Returns a renderer with a screenplay object. Contents are paginated first.
- (instancetype)initWithScreenplay:(BeatScreenplay*)screenplay settings:(BeatExportSettings*)settings
{
	self = [super init];
	
	if (self) {
		BeatPaginationManager* pm = [BeatPaginationManager.alloc initWithSettings:settings delegate:nil renderer:nil livePagination:false];
		[pm newPaginationWithScreenplay:screenplay settings:settings forEditor:false changeAt:0];
		
		self.pagination = pm.finishedPagination;
	}
	
	return self;
}

/// Returns a renderer with just the line content
- (instancetype)initWithLines:(NSArray<Line*>*)lines settings:(BeatExportSettings*)settings
{
	BeatScreenplay* screenplay = BeatScreenplay.new;
	screenplay.lines = lines;
	screenplay.titlePageContent = @[];
	
	return [BeatHTMLRenderer.alloc initWithScreenplay:screenplay settings:settings];
}


- (void)reloadStyles {
	[(BeatStylesheet*)self.settings.styles reload];
}

- (NSString *)html
{
	NSMutableString *html = NSMutableString.new;
	[html appendString:[self htmlHeader]];
	[html appendString:[self content]];
	[html appendString:[self htmlFooter]];

	return html;
}

#pragma mark - Heading settings

- (BOOL)boldedHeading {
	return [BeatUserDefaults.sharedDefaults getBool:BeatSettingHeadingStyleBold];
}
- (BOOL)underlinedHeading {
	return [BeatUserDefaults.sharedDefaults getBool:BeatSettingHeadingStyleUnderlined];
}

#pragma mark - HTML sections

- (NSString*)htmlBody {
	if (self.pagination != nil) {
		self.renderedPages = [self createHTMLWithPagination:self.pagination];
	}
	else {
		self.renderedPages = [self paginateAndCreateHTML];
	}
	return [self.renderedPages componentsJoinedByString:@"\n"];
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

- (NSArray*)singlePages {
	if (self.renderedPages == nil) self.renderedPages = [self paginateAndCreateHTML];
	
	NSMutableArray *everyPageAsDocument = NSMutableArray.new;
	
	for (NSString *page in self.renderedPages) {
		NSMutableString *html = NSMutableString.new;
		[html appendString:[self htmlHeader]];
		[html appendString:@"<article>\n"];
		[html appendString:page];
		[html appendString:@"</article>\n"];
		[html appendString:[self htmlFooter]];
		[everyPageAsDocument addObject:html];
	}
	
	return everyPageAsDocument;
}

/// Returns pure content, wrapped in `<article>` tags.
- (NSString *)content
{
	if (!self.bodyText) {
		self.bodyText = [self htmlBody];
	}
	
	NSMutableString *html = [NSMutableString string];
	[html appendString:@"<article>\n"];
	[html appendString:self.bodyText];
	[html appendString:@"</article>\n"];
	
	return html;
}

- (NSArray*)paginateAndCreateHTML
{
	// Pagination
	BeatPaginationManager* pm = [BeatPaginationManager.alloc initWithSettings:self.settings delegate:nil renderer:nil livePagination:false];
	[pm newPaginationWithScreenplay:self.screenplay settings:self.settings forEditor:false changeAt:0];
	self.pagination = pm.finishedPagination;

	return [self createHTMLWithPagination:self.pagination];
}

- (NSArray*)createHTMLWithPagination:(BeatPagination*)pagination
{
	NSMutableArray *pages = NSMutableArray.new;
		
	// Create title page
	NSString * titlePageString = [self createTitlePage];
	[pages addObject:titlePageString];
		
	// Header string (make sure it's not null)
	if (_settings.header == nil) _settings.header = @"";
	_settings.header = [_settings.header stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"];
	
	for (NSInteger pageIndex = 0; pageIndex < pagination.pages.count; pageIndex++) {
		NSString *pageAsString = [self singlePage:pagination.pages[pageIndex] pageNumber:pageIndex + 1];
		[pages addObject:pageAsString];
	}
	
	self.renderedPages = pages;
	return pages;
}


#pragma mark - Title page

- (NSMutableArray*)titlePage {
	if (_titlePage == nil) {
		_titlePage = self.pagination.titlePage.mutableCopy;
	}
	return _titlePage;
}

- (NSString*)createTitlePage {
	NSMutableString *body = [NSMutableString stringWithString:@""];
	
	if (self.titlePage.count > 0) {
		[body appendString:@"<section id='script-title' class='page'>"];
		[body appendFormat:@"<div class='mainTitle'>"];
		
		// Title
		Line* title = [self titlePageElementForKey:@"title"];
		if (title.string.length == 0) title.string = @"Untitled";
		[body appendString:[self htmlStringFor:title]];
			
		// Add Credit, Authors, Source (in this order)
		NSArray * credits = @[@"credit", @"authors", @"source"];
		for (NSString *credit in credits) {
			Line* line = [self titlePageElementForKey:credit];
			[body appendString:[self htmlStringFor:line]];
		}
				
		[body appendFormat:@"</div>"];
				
		// Draft date
		Line* draftDate = [self titlePageElementForKey:@"draft date"];
		[body appendFormat:@"<div class='versionInfo'><p>"];
		[body appendString:[self htmlStringFor:draftDate]];
		[body appendFormat:@"</p></div>"];
		
		// Left side block
		[body appendFormat:@"<div class='info'>"];
		Line* contact = [self titlePageElementForKey:@"contact"];
		Line* notes = [self titlePageElementForKey:@"notes"];
		[body appendString:[self htmlStringFor:contact]];
		[body appendString:[self htmlStringFor:notes]];
		
		// Append rest of the stuff
		while (self.titlePage.count > 0) {
			NSString * key = ((NSDictionary*)self.titlePage.firstObject).allKeys.firstObject;
			Line* line = [self titlePageElementForKey:key];
			[body appendString:[self htmlStringFor:line]];
		}
		
		[body appendFormat:@"</div>"];
		
		[body appendString:@"</section>"];
	}
	
	return body;
}


- (Line*)titlePageElementForKey:(NSString*)key {
	NSMutableArray<Line*>* lines = NSMutableArray.new;
	
	NSDictionary<NSString*, NSNumber*>* types = @{
		@"title": @(titlePageTitle),
		@"authors": @(titlePageAuthor),
		@"credit": @(titlePageCredit),
		@"source": @(titlePageSource),
		@"draft date": @(titlePageDraftDate),
		@"contact": @(titlePageContact)
	};
	
	LineType type = empty;
	if (types[key] != nil) type = (LineType)types[key].integerValue;
	else type = titlePageUnknown;
	
	for (NSInteger i=0; i<self.titlePage.count; i++) {
		NSDictionary* dict = self.titlePage[i];
		
		if (dict[key] != nil) {
			lines = dict[key];
			[self.titlePage removeObjectAtIndex:i];
			break;
		}
	}
	
	if (lines.count == 0) {
		return [Line withString:@"" type:type];
	}
	
	
	// Split first line
	Line* firstLine = lines.firstObject;
	firstLine = [firstLine splitAndFormatToFountainAt:firstLine.titlePageKey.length + 1][1];
	
	firstLine.type = type;
	
	for (NSInteger i=1; i<lines.count; i++) {
		[firstLine joinWithLine:lines[i]];
	}
	
	return firstLine;
}



#pragma mark - CSS

- (NSString *)css
{
	if (_css != nil) return _css;
	
	NSString * css = [NSString stringWithContentsOfURL:[NSBundle.mainBundle URLForResource:PRINT_CSS withExtension:@"css"]
											  encoding:NSUTF8StringEncoding
												 error:nil];
	if (css == nil) css = @"";
	
	NSString * previewCss = [NSString stringWithContentsOfURL:[NSBundle.mainBundle URLForResource:PREVIEW_CSS withExtension:@"css"]
													 encoding:NSUTF8StringEncoding
														error:nil];
	
#if TARGET_OS_IOS
	// Additional styles for iOS WebKit preview rendering
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
	
	_css = css;
	return css;
}

#pragma mark - Rendering

- (NSString*)singlePage:(BeatPaginationPage*)page pageNumber:(NSInteger)pageNumber {
	NSMutableString *body = NSMutableString.string;
	NSInteger dualDialogueCharacterCount = 0;
	//NSSet *ignoringTypes = [NSSet setWithObjects:@"Boneyard", @"Comment", @"Synopse", @"Section", nil];
	
	NSString *pageClass = @"";
	
	/*
	// If we are coloring the revised pages, check for any changed lines here
	if (_settings.coloredPages && _settings.pageRevisionColor.length && _settings.operation == ForPrint) {
		bool revised = NO;
		for (Line* line in page.lines) {
			if (line.changed) {
				revised = YES;
				break;
			}
		}
		
		if (revised) pageClass = [NSString stringWithFormat:@"revised %@", _settings.pageRevisionColor];
	}
	*/
	
	
	NSInteger elementCount = 0;
	
	// Begin page
	[body appendFormat:@"<section class='%@'>", pageClass];
		
	// First page doesn't have a page number.
	if (pageNumber > 1) [body appendFormat:@"<p class='page-break-render'><span class='header-top'>%@</span> %lu.</p>\n", _settings.header, pageNumber];
	else [body appendFormat:@"<p class='page-break-render'><span class='header-top'>%@</span> &nbsp;</p>\n", _settings.header];
	
	for (Line *line in page.lines) { @autoreleasepool {
		// Skip line break
		if (line.type == pageBreak) continue;
		
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
		
		NSString *element = [self htmlStringFor:line];

		if (element.length > 0) [body appendFormat:@"%@\n", element];
		
		elementCount++;
	} }
	
	[body appendString:@"</section>"];
	
	return body;
}

- (NSString*)format:(NSString*) string
{
	string = [RX(BOLD_ITALIC_UNDERLINE_FORMATTING_PATTERN) stringByReplacingMatchesInString:string options:0 range:NSMakeRange(0, string.length) withTemplate:@"<u><em><strong>$2</strong></em></u>"];
	string = [RX(BOLD_ITALIC_FORMATTING_PATTERN) stringByReplacingMatchesInString:string options:0 range:NSMakeRange(0, string.length) withTemplate:@"<strong><em>$2</em></strong>"];
	string = [RX(BOLD_UNDERLINE_FORMATTING_PATTERN) stringByReplacingMatchesInString:string options:0 range:NSMakeRange(0, string.length) withTemplate:@"<strong><u>$2</u></strong>"];
	string = [RX(ITALIC_UNDERLINE_FORMATTING_PATTERN) stringByReplacingMatchesInString:string options:0 range:NSMakeRange(0, string.length) withTemplate:@"<u><em>$2</em></u>"];
	string = [RX(BOLD_FORMATTING_PATTERN) stringByReplacingMatchesInString:string options:0 range:NSMakeRange(0, string.length) withTemplate:@"<strong>$2</strong>"];
	string = [RX(ITALIC_FORMATTING_PATTERN) stringByReplacingMatchesInString:string options:0 range:NSMakeRange(0, string.length) withTemplate:@"<em>$2</em>"];
	string = [RX(UNDERLINE_FORMATTING_PATTERN) stringByReplacingMatchesInString:string options:0 range:NSMakeRange(0, string.length) withTemplate:@"<u>$2</u>"];
	
	// Remove escape characters
	string = [string stringByReplacingOccurrencesOfString:@"\\*" withString:@"*"];
	string = [string stringByReplacingOccurrencesOfString:@"\\_" withString:@"_"];
	string = [string stringByReplacingOccurrencesOfString:@"\\@" withString:@"@"];
	string = [string stringByReplacingOccurrencesOfString:@"\\**" withString:@"**"];

	return string;
}
- (NSString*)htmlStringFor:(Line*)line {
	// We use the FDX attributed string to create a HTML representation of Line objects
	NSAttributedString *string = [line attributedStringForOutputWith:self.settings];
	
	// Ignore any formatting and only include CONTENT ranges
	NSMutableAttributedString *result = [NSMutableAttributedString.alloc initWithAttributedString:string];
		
	NSMutableString *htmlString = NSMutableString.string;
	
	// Get stylization in the current attribute range
	[result enumerateAttributesInRange:(NSRange){0, result.length} options:0 usingBlock:^(NSDictionary<NSAttributedStringKey,id> * _Nonnull attrs, NSRange range, BOOL * _Nonnull stop) {
		NSMutableString* text = [result.string substringWithRange:range].mutableCopy;
		// Opening and closing tags
		NSMutableString *open = NSMutableString.new;
		NSMutableString *close = NSMutableString.new;
		
		NSMutableSet* styles = attrs[@"Style"];

		// Append corresponding HTML tags to opening & closing strings, ie. open = "<b>", close = "</b>"
		if (styles.count > 0) {
			if ([styles containsObject:@"Bold"]) {
				[open appendString:BOLD_OPEN];
				[close appendString:BOLD_CLOSE];
			}
			if ([styles containsObject:@"Italic"]) {
				[open appendString:ITALIC_OPEN];
				[close appendString:ITALIC_CLOSE];
			}
			if ([styles containsObject:@"Underline"]) {
				[open appendString:UNDERLINE_OPEN];
				[close appendString:UNDERLINE_CLOSE];
			}
			if ([styles containsObject:@"Strikeout"]) {
				[open appendString:STRIKEOUT_OPEN];
				[close appendString:STRIKEOUT_CLOSE];
			}
			if ([styles containsObject:@"RemovalSuggestion"]) {
				[open appendString:STRIKEOUT_OPEN];
				[close appendString:STRIKEOUT_CLOSE];
			}
			if ([styles containsObject:@"Addition"]) {
				//open = [open stringByAppendingString:ADDITION_OPEN];
				//close = [close stringByAppendingString:ADDITION_OPEN];
			}
			if ([styles containsObject:@"Note"]) {
				[open appendString:NOTE_OPEN];
				[close appendString:NOTE_CLOSE];
			}
		}
		
		// Iterate through possible revisions baked into the line
		NSString* revision = attrs[BeatRevisions.attributeKey];
		if (revision.length > 0) {
			[open appendFormat:@"<span class='changedDetail %@'><a class='revisionMarker'></a>", revision];
			[close appendString:@"</span>"];
		}
		
		// Append snippet to paragraph
		[htmlString appendString:[NSString stringWithFormat:@"%@%@%@", open, [self escapeString:text], close]];
	}];
	
	// To avoid underlining heading tails, let's trim the text if needed
	if (line.type == heading && self.underlinedHeading) [htmlString setString:[htmlString stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet]];
	
	// Preview shortcuts
	if (line.type == heading && _settings.operation == ForPreview) {
		[htmlString setString:[NSString stringWithFormat:@"<a href='#' onclick='selectScene(this);' sceneIndex='%lu'>%@</a>", line.sceneIndex, htmlString]];
	}

	NSMutableString *additionalClasses = NSMutableString.string;
	
	if (line.type == heading && line.sceneNumber) {
		// Add scene number ID to HTML, but don't print it if it's toggled off
		NSString *printedSceneNumber;
		if (self.settings.printSceneNumbers) printedSceneNumber = line.sceneNumber;
		else printedSceneNumber = @"";
						
		NSString* sceneNumberLeft = [NSString stringWithFormat:@"<span id='scene-%@' class='scene-number-left'>%@</span>", line.sceneNumber, printedSceneNumber];
		NSString* sceneNumberRight = [NSString stringWithFormat:@"<span class='scene-number-right'>%@</span>", printedSceneNumber];
		
		[htmlString setString:[NSString stringWithFormat:@"%@%@%@", sceneNumberLeft, htmlString, sceneNumberRight]];
		
		if (self.boldedHeading) [additionalClasses appendString:@" bold"];
		if (self.underlinedHeading) [additionalClasses appendString:@" underline"];
	}
	
	// Centered
	if (line.type == centered) {
		[additionalClasses appendString:@" center"];
	}
	
	// Handlde split paragraphs
	if (line.canBeSplitParagraph && !line.beginsNewParagraph) {
		[additionalClasses appendString:@" splitParagraph"];
	}
	
	// Mark as changed, if comparing against another file or the line contains added/removed text
	if (line.changed || line.revisedRanges.count || line.removalSuggestionRanges.count) {
		[additionalClasses appendString:@" changed"];
		
		// Add revision color if available
		if (line.revisionColor.length > 0) {
			[additionalClasses appendFormat:@" %@", line.revisionColor.lowercaseString];
		}
	}

	[htmlString replaceOccurrencesOfString:@"\n" withString:@"<br>" options:0 range:(NSRange){0,htmlString.length}];
	
	if (htmlString.length > 0) {
		return [NSString stringWithFormat:@"<p class='%@%@' uuid='%@' paginatedHeight='%lu'>%@</p>\n", [self classNameForLine:line], additionalClasses,line.uuid.UUIDString.lowercaseString,  line.heightInPaginator, htmlString];
	} else {
		return @"";
	}
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


#pragma mark - Helper methods

- (NSString *)classNameForLine:(Line*)line
{
	return [line.typeName stringByReplacingOccurrencesOfString:@" " withString:@"-"];
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
 should.
 
 */
