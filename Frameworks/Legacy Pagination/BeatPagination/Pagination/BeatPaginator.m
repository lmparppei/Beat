//
//  FountainPaginator.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 18.5.2020.
//  Copyright © 2020 Lauri-Matti Parppei. All rights reserved.
//

/*
 
 WORK IN PROGRESS.

 This is very, very loosely based on the original FNPaginator code, rewritten
 to use the Line class driving ContinuousFountainParser.
  
 Original Fountain repository pagination code was totally convoluted and had
 many obvious bugs and stuff that really didn't work in many places.
 I went out of my way to make my own pagination engine, just to end up with
 something almost as convoluted.
 
 Maybe it was an important journey - I learned how this actually works and
 got to spend a nice day coding in my bathrobe. I had two feature scripts that
 required my attention, but yeah. This is duct-taped together to give somewhat
 acceptable pagination results.
 
 It doesn't matter - I have the chance to spend my days doing something I'm
 intrigued by, and probably it makes it less likely that I'll get dementia or
 other memory-related illness later in life. I don't know.
 
 I have found the fixed values with goold old trial & error. As we are using a
 WKWebView to render the HTML file, the pixel coordinates do not match AT ALL.
 There is a boolean value to check whether we're paginating on a US Letter or
 on the only real paper size, used by the rest of the world (A4).
 
 This might have been pretty unhelpful for anyone stumbling upon this file some day.
 Try to make something out of it.
 
 NOTE:
 At the moment, this class only takes care of dispatching pagination operations.
 Actual pagination happens in BeatPaginationOperation.
 
 Remember the flight
 the bird may die
 (Forough Farrokhzad)
 
 

 */

#import <TargetConditionals.h>
#import <BeatParsing/BeatParsing.h>
#import <BeatCore/BeatFonts.h>
#import <BeatCore/BeatCore-Swift.h>

#import "BeatPaginator.h"
#import "BeatPaginationOperation.h"


#if TARGET_OS_IOS
	#define BXDocument UIDocument
	#define BXPrintInfo UIPrintInfo
#else
	#define BXDocument NSDocument
	#define BXPrintInfo NSPrintInfo
#endif

#define LINE_HEIGHT 12.5

@interface BeatPaginator ()

@property (atomic) NSString *textCache;
@property (atomic) CGSize printableArea; // for iOS

@property (nonatomic) NSMutableArray<NSThread*>* runningThreads;
@property (nonatomic) NSMutableArray<BeatPaginationOperation*>* queue;

@property (atomic) NSMutableArray <NSArray<Line*>*>*pageCache;
@property (atomic) NSMutableArray <NSArray<Line*>*>*pageBreakCache;

@property (atomic) BeatPaginationOperation *finishedOperation;

@end

@implementation BeatPaginator

- (id)initWithScript:(NSArray *)elements settings:(BeatExportSettings*)settings {
	return [self initWithDocument:nil elements:elements settings:settings printInfo:nil livePagination:NO];
}

- (id)initForLivePagination:(BXDocument*)document {
	return [self initForLivePagination:document withElements:nil];
}

- (id)initForLivePagination:(BXDocument*)document withElements:(NSArray*)elements {
	return [self initWithDocument:document elements:elements settings:nil printInfo:nil livePagination:YES];
}

- (id)initWithScript:(NSArray *)elements printInfo:(BXPrintInfo*)printInfo
{
	return [self initWithDocument:nil elements:elements settings:nil printInfo:printInfo livePagination:NO];
}

- (id)initWithDocument:(BXDocument*)document elements:(NSArray*)elements settings:(BeatExportSettings*)settings printInfo:(BXPrintInfo*)printInfo livePagination:(bool)livePagination {
	self = [super init];
	if (self) {
		// We have multiple ways of setting a document.
		// Live pagination uses document parameter, while export sends it via settings.
		if (document) _document = document;
		else if (settings.document) _document = settings.document;
		else _document = nil;
		
		self.settings = settings;
		self.printNotes = (settings) ? settings.printNotes : NO;
		self.livePagination = livePagination;
		self.font = [BeatFont fontWithName:@"Courier" size:12];

		if (self.livePagination) [self livePaginationFor:elements changeAt:0];
		else [self paginate:elements];
		
		/*
		 
		self.pages = NSMutableArray.new;
		self.script = (elements.count) ? elements : NSArray.new;
		self.printInfo = (printInfo) ? printInfo : nil;
		self.pageBreaks = NSMutableArray.new;
		self.livePagination = livePagination;
		
		 */
	}
	
	return self;
}

#pragma mark - Pagination

- (void)paginate:(NSArray*)lines {
	[self paginateLines:lines];
}

- (void)paginateLines:(NSArray *)lines {
	[self cancelAllOperations];
	
	BeatPaginationOperation *operation = [BeatPaginationOperation.alloc initWithElements:lines paginator:self];
	[self runOperation:operation];
}

- (void)livePaginationFor:(NSArray *)script changeAt:(NSUInteger)location {
	BeatPaginationOperation *operation = [BeatPaginationOperation.alloc initWithElements:script livePagination:true paginator:self cachedPages:self.pages.copy cachedPageBreaks:self.pageBreaks.copy changeAt:location];
	
	[self runOperation:operation];
}

- (void)runOperation:(BeatPaginationOperation*)operation {
	// Cancel all previous operations
	[self cancelAllOperations];
	
	if (_queue == nil) _queue = NSMutableArray.new;
	[_queue addObject:operation];
	
	// If the pagination queue is empty, run it immediately
	if (_queue.count == 1) {
		if (operation.livePagination) [operation paginateForEditor];
		else [operation paginate];
	}
}

- (void)cancelAllOperations {
	for (BeatPaginationOperation* operation in _queue) {
		[operation cancel];
	}
}

- (void)paginationFinished:(BeatPaginationOperation*)operation {
	// Pagination was finished. Remove this pagination from queue.
	[_queue removeObject:operation];
		
	@synchronized (self) {
		// Only accept newest results. If an old operation took its time to finish, we'll just ignore it.
		NSTimeInterval timeDiff = [operation.startTime timeIntervalSinceDate:_finishedOperation.startTime];

		if (operation.success && (timeDiff > 0 || self.finishedOperation == nil)) {
			// Store successful results
			self.finishedOperation = operation;
			
			self.pages = operation.pages;
			self.pageBreaks = operation.pageBreaks;
			self.lastPageHeight = operation.lastPageHeight;
			
			[self.delegate paginationDidFinish:operation.pages pageBreaks:operation.pageBreaks];
		}
	}
	
	// Once finished, cancel everything else but the very last queued operation
	BeatPaginationOperation *lastOperation = _queue.lastObject;
	if (lastOperation) {
		[self runOperation:lastOperation];
	}
}


#pragma mark - Results

- (NSInteger)pageNumberFor:(NSInteger)location {
	NSInteger pageNumber = 1;
	for (NSArray *page in self.pages) {
		Line *firstElement = page.firstObject;
		Line *lastElement = page.lastObject;
		if (location >= firstElement.position && location <= lastElement.position + lastElement.string.length) {
			return pageNumber;
		}
		pageNumber++;
	}
	return 0;
}

- (NSArray *)pageAtIndex:(NSUInteger)index
{
	@synchronized (self) {
		// Make sure we don't try and access an index that doesn't exist
		if (self.pages.count == 0 || (index > self.pages.count - 1)) {
			return @[];
		}
		
		return self.pages[index];
	}
}


#pragma mark - Paper sizing

- (void)setPageSize:(BeatPaperSize)pageSize {
#if TARGET_OS_IOS
	_paperSize = [BeatPaperSizing printableAreaFor:pageSize];
#else
	_printInfo = [BeatPaperSizing printInfoFor:pageSize];
#endif
}


#pragma mark - More / Cont'd items

- (NSString*)contdString {
    return BeatScreenplayElements.shared.contd;
}

- (NSString*)moreString {
    return BeatScreenplayElements.shared.more;
}

- (Line*)contdLineFor:(Line*)line {
    NSString *extension = [self contdString];
    
	NSString *cue = [line.stripFormatting stringByReplacingOccurrencesOfString:extension withString:@""];
	cue = [cue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
	
	NSString *contdString = [NSString stringWithFormat:@"%@%@", cue, extension];
	Line *contd = [Line.alloc initWithString:contdString type:character];
	contd.nextElementIsDualDialogue = line.nextElementIsDualDialogue;
	if (line.type == dualDialogueCharacter) contd.type = dualDialogueCharacter;
	
	return contd;
}

- (Line*)moreLineFor:(Line*)line {
	LineType type = (line.isDualDialogue) ? dualDialogueMore : more;
	Line *more = [Line.alloc initWithString:[self moreString] type:type];
	more.unsafeForPageBreak = YES;
	return more;
}

#pragma mark - Sizing helper methods

- (NSArray*)lengthInEights {
	// No pagination done
	if (self.pages.count == 0) return @[@0, @0];
	
	NSInteger pageCount = self.pages.count - 1;
	NSInteger eights = (NSInteger)round(_lastPageHeight / (1.0/8.0));
	
	// If the last page is almost full, just calculate it as one full page
	if (eights == 8) {
		pageCount++;
		eights = 0;
	}
	
	if (pageCount < 0) return nil;
	else return @[@(pageCount), @(eights)];
}

- (NSUInteger)numberOfPages {
	return self.pages.count;
}

- (CGFloat)spaceBeforeForLine:(Line*)line {
	if (line.isSplitParagraph) return 0;
	else if (line.type == heading) {
		// Get user default for scene heading spacing
        NSInteger spacingBeforeHeading = BeatScreenplayElements.shared.spaceBeforeHeading;
        if (spacingBeforeHeading == 0) spacingBeforeHeading = 2;
        
		return BeatPaginator.lineHeight * spacingBeforeHeading;
	}
	else if (line.type == character || line.type == dualDialogueCharacter) return BeatPaginator.lineHeight;
	else if (line.type == dialogue) return 0;
	else if (line.type == parenthetical) return 0;
	else if (line.type == dualDialogue) return 0;
	else if (line.type == dualDialogueParenthetical) return 0;
	else if (line.type == transitionLine) return BeatPaginator.lineHeight;
	else if (line.type == action) return BeatPaginator.lineHeight;
	else return BeatPaginator.lineHeight;
}

+ (CGFloat)heightForString:(NSString *)string font:(BeatFont *)font maxWidth:(NSInteger)maxWidth lineHeight:(CGFloat)lineHeight
{
	/*
	 This method MIGHT NOT work on iOS. For iOS you'll need to adjust the font size to 80% and use the NSString instance
	 method - (CGSize)sizeWithFont:constrainedToSize:lineBreakMode:
	 */
	
	if (string.length == 0) return lineHeight;
	if (font == nil) font = BeatFonts.sharedFonts.courier;
	
#if TARGET_OS_IOS
	// Set font size to 80% on iOS
	font = [font fontWithSize:font.pointSize * 0.8];
#endif
	
	// set up the layout manager
	NSTextStorage   *textStorage   = [[NSTextStorage alloc] initWithString:string attributes:@{NSFontAttributeName: font}];
	NSLayoutManager *layoutManager = NSLayoutManager.new;
	
	NSTextContainer *textContainer = NSTextContainer.new;
	[textContainer setSize:CGSizeMake(maxWidth, MAXFLOAT)];
	
	[layoutManager addTextContainer:textContainer];
	[textStorage addLayoutManager:layoutManager];
	[textContainer setLineFragmentPadding:0];
	[layoutManager glyphRangeForTextContainer:textContainer];
	
	// We'll get the number of lines rather than calculating exact size in NSTextField
	NSInteger numberOfLines;
	NSInteger index;
	NSInteger numberOfGlyphs = layoutManager.numberOfGlyphs;
	
	// Iterate through line fragments
	NSRange lineRange;
	for (numberOfLines = 0, index = 0; index < numberOfGlyphs; numberOfLines++){
		[layoutManager lineFragmentRectForGlyphAtIndex:index effectiveRange:&lineRange];
		index = NSMaxRange(lineRange);
	}
	
	return numberOfLines * lineHeight;
}

#pragma mark - Additional convenience methods

+ (CGFloat)lineHeight {
	return LINE_HEIGHT;
}


- (bool)boolForKey:(NSString*)key {
	id value = [self valueForKey:key];
	return [(NSNumber*)value boolValue];
}

@end

/*

on niin yksinkertaista
uskotella olevansa päivä joka ei milloinkaan laske
olla kaukaisten hailakkain vuorten takaa nouseva säteinen paiste
on niin vaikeaa
myöntää olevansa vain satunnainen kuiskaus
olla päivänkajo joka aina likempänä kuin aamua
  on hiipuvaa iltaa

*/
