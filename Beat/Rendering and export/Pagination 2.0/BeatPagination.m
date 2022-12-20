//
//  BeatPagination.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 11.12.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//
/**
 
 This is an Objective C port of native pagination / rendering code.
 In this iteration, pages won't return an `NSTextView`, only an attributed string, to
 make the class more easily compatible with the upcoming iOS version.
 
 */

#import "BeatPagination.h"
#import "BeatFonts.h"
#import "Beat-Swift.h"
#import "BeatPaginationBlock.h"
#import "BeatPaginationBlockGroup.h"
#import "BeatPageBreak.h"


@interface BeatPagination() <BeatPageDelegate>
@property (nonatomic) NSArray<Line*>* lines;

@property (nonatomic) NSMutableArray<Line*>* lineQueue;
@property (nonatomic) BeatFonts* fonts;
@property (nonatomic) Styles* styles;
@property (nonatomic) NSInteger location;

@property (nonatomic) NSMutableDictionary<NSNumber*, NSDictionary*>* lineTypeAttributes;

@property (nonatomic) bool livePagination;

@property (weak, nonatomic) id<BeatPaginationDelegate> delegate;
@property (nonatomic) BeatPaginationPage* currentPage;

@property (nonatomic) NSArray<BeatPaginationPage*>* cachedPages;
@end

@implementation BeatPagination

+ (CGFloat) lineHeight; {
	return 12.0;
}

+ (BeatPagination*)newPaginationWithScreenplay:(BeatScreenplay*)screenplay delegate:(id<BeatPaginationDelegate>)delegate {
	return [BeatPagination.alloc initWithDelegate:delegate screenplay:screenplay settings:delegate.settings livePagination:false changeAt:0 cachedPages:nil];
}
+ (BeatPagination*)newLivePaginationWithScreenplay:(BeatScreenplay*)screenplay changeAt:(NSInteger)location delegate:(id<BeatPaginationDelegate>)delegate {
	return [BeatPagination.alloc initWithDelegate:delegate screenplay:screenplay settings:delegate.settings livePagination:true changeAt:location cachedPages:nil];
}
- (instancetype)initWithDelegate:(id<BeatPaginationDelegate>)delegate screenplay:(BeatScreenplay*)screenplay settings:(BeatExportSettings*)settings livePagination:(bool)livePagination changeAt:(NSInteger)changeAt cachedPages:(NSArray<BeatPaginationPage*>* __nullable)cachedPages {
	self = [super init];
	
	if (self) {
		_delegate = delegate;
		
		_fonts = BeatFonts.sharedFonts;
		_styles = Styles.shared;
		
		_lines = (screenplay.lines != nil) ? screenplay.lines : @[];
		_livePagination = livePagination;
		_location = changeAt;
		_cachedPages = cachedPages;
		_settings = settings;
		_pages = NSMutableArray.new;
		_lineTypeAttributes = NSMutableDictionary.new;
		
		_startTime = NSDate.new;
	}
	
	return self;
}

#pragma mark - Convenience stuff

/// A method for backwards compatibility with the old pagination code
- (NSInteger)numberOfPages {
	if (self.pages.count == 0) {
		[self paginate];
	}
	
	return self.pages.count;
}

- (void)paginationFinished {
	[self.delegate paginationFinished:self];
}


#pragma mark - Running pagination

- (void)paginate {
	if (_livePagination) {
		// Do live pagination magic here
	}
	
	self.success = [self paginateFromIndex:self.location];
	[self paginationFinished];
}

- (bool)paginateFromIndex:(NSInteger)index {
	_startTime = [NSDate date];
	
	// Reset queue
	_lineQueue = [NSMutableArray arrayWithArray:[self.lines subarrayWithRange:NSMakeRange(index, self.lines.count - index)]];
	
	if (index == 0) {
		_pages = NSMutableArray.new;
		_currentPage = [BeatPaginationPage.alloc initWithDelegate:self];
	}
	
	while (_lineQueue.count > 0) {
	//for (NSInteger i=index; i<_lineQueue.count; i++) {
		// Do nothing if this operation is canceled
		if (_canceled) { return false; }
		
		// Get the first object in the queue array until no lines are left
		Line* line = _lineQueue[0];
		
		// Catch wrong parsing (just in case)
		if (line.string.length == 0 ||
			line.isTitlePage ||
			(line.isInvisible && !(_settings.printNotes && line.note))) {
			[_lineQueue removeObjectAtIndex:0];
			continue;
		}
				
		// catch forced page breaks first
		if (line.type == pageBreak) {
			[_lineQueue removeObjectAtIndex:0];
			
			BeatPageBreak *pageBreak = [BeatPageBreak.alloc initWithY:-1 element:line reason:@"Forced page break"];
			[self addPage:@[line] toQueue:@[] pageBreak:pageBreak];
			continue;
		}
		
		// Add initial page break when needed
		if (self.pages.count == 0 && _currentPage.blocks.count == 0) {
			_currentPage.pageBreak = [BeatPageBreak.alloc initWithY:0 element:line reason:@"Initial page break"];
		}
		
		/**
		 Get the block for current line and add it to temp element queue.
		 A block is something that has to be handled as one when paginating, such as:
		 • a single paragraph or transition
		 • dialogue block, or a dual dialogue block
		 • a heading or a shot, followed by another block
		*/
		@autoreleasepool {
			NSArray *blocks = [self blocksForLineAt:0];
			[self addBlocks:blocks];
		}
	}
	
	[_pages addObject:_currentPage];
	
	return true;
}

- (void)addBlocks:(NSArray<NSArray<Line*>*>*)blocks {
	NSMutableArray<BeatPaginationBlock*>* pageBlocks = NSMutableArray.new;
		
	for (NSArray<Line*>* block in blocks) {
		BeatPaginationBlock *pageBlock = [BeatPaginationBlock withLines:block delegate:self];
		[pageBlocks addObject:pageBlock];
		
		[_lineQueue removeObjectsInRange:NSMakeRange(0, block.count)];
	}
	
	BeatPaginationBlockGroup *group = [BeatPaginationBlockGroup withBlocks:pageBlocks];
	
	if (_currentPage.remainingSpace >= group.height) {
		// Add blocks on current page
		for (BeatPaginationBlock *pageBlock in pageBlocks) {
			[_currentPage addBlock:pageBlock];
		}
		return;
	}
	
	// Nothing fit, let's break it apart
	CGFloat remainingSpace = _currentPage.remainingSpace;
	
	// If remaining space is less than 1 line, just roll on to next page
	if (remainingSpace < BeatPagination.lineHeight) {
		BeatPageBreak *pageBreak = [BeatPageBreak.alloc initWithY:0 element:group.blocks.firstObject.lines.firstObject reason:@"Nothing fit"];
		[self addPage:@[] toQueue:group.lines pageBreak:pageBreak];
	}
	else if (group.blocks.count > 0) {
		NSArray* split = [group breakGroupWithRemainingSpace:remainingSpace];
		[self addPage:split[0] toQueue:split[1] pageBreak:split[2]];
	}
	else {
		BeatPaginationBlock *pageBlock = group.blocks.firstObject;
		NSArray* split = [pageBlock breakBlockWithRemainingSpace:remainingSpace];
		[self addPage:split[0] toQueue:split[1] pageBreak:split[2]];
	}
}


/**
Returns "blocks" for the given line.
- note: A block is usually any paragraph or a full dialogue block, but for the pagination to make sense, some blocks are grouped together.
That's why we are returning `[ [Line], [Line], ... ]`, and converting those blocks into actual screenplay layout blocks later.

The layout blocks (`BeatPageBlock`) won't contain anything else than the rendered block, which can also mean a full dual-dialogue block.
*/
- (NSArray<NSArray<Line*>*>*)blocksForLineAt:(NSInteger)idx {
	Line* line = self.lineQueue[idx];
	NSMutableArray<Line*>* block = [NSMutableArray arrayWithObject:line];
	
	if (line.isAnyCharacter) {
		return @[[self dialogueBlockForLineAt:idx]];
	}
	else if (line == _lineQueue.lastObject) {
		return @[block];
	}
	else if (line.type != heading && line.type != lyrics && line.type != centered && line.type != shot) {
		return @[block];
	}
	
	NSInteger i = idx + 1;
	Line* nextLine = self.lineQueue[i];
	
	// If next line is a heading, this block ends there
	if (nextLine.type == heading) {
		return @[block];
	}
	
	// Headings and shots swallow up the whole next block
	if (line.type == heading || line.type == shot) {
		NSArray* followingBlocks = [self blocksForLineAt:i];
		NSMutableArray *blocks = [NSMutableArray arrayWithObject:block];
		[blocks addObjectsFromArray:followingBlocks];
		return blocks;
	}
	
	LineType expectedType;
	if (line.type == lyrics || line.type == centered) expectedType = line.type;
	else { expectedType = action; }
	
	//idx += 1
	while (idx < _lineQueue.count) {
		Line* l = _lineQueue[idx];
		idx += 1;
		
		// Skip empty lines, and break when the next line type is not the one we expected
		if (l.type == empty || l.string.length == 0) { continue; }
		if (l.type == expectedType) {
			if (l.beginsNewParagraph) { break; } // centered and lyric elements might begin a new block
			[block addObject:l];
		} else {
			break;
		}
	}
	
	return @[block];
}

/// Returns dialogue block for the given line index
- (NSArray<Line*>*)dialogueBlockForLineAt:(NSInteger)idx {
	Line *line = _lineQueue[idx];
	NSMutableArray<Line*>* block = NSMutableArray.new;
	[block addObject:line];
	
	bool hasBegunDualDialogue = false;
	
	for (NSInteger i=idx+1; i<_lineQueue.count; i++) {
		Line* l = _lineQueue[i];
		
		if (l.type == character) break;
		else if (!l.isDialogue && !l.isDualDialogue) break;
		else if (l.isDualDialogue) hasBegunDualDialogue = true;
		else if (hasBegunDualDialogue && (l.isDialogue || l.type == dualDialogueCharacter )) break;

		[block addObject:l];
	}
		
	return block;
}

- (void)addPage:(NSArray<Line*>*)elements toQueue:(NSArray<Line*>*)toQueue pageBreak:(BeatPageBreak*)pageBreak {
	BeatPaginationBlock *block = [BeatPaginationBlock withLines:elements delegate:self];
	[_currentPage addBlock:block];
	[_pages addObject:_currentPage];
	
	// Add objects to queue
	NSRange range = NSMakeRange(0, toQueue.count);
	NSIndexSet* indices = [NSIndexSet indexSetWithIndexesInRange:range];
	[_lineQueue insertObjects:toQueue atIndexes:indices];
	
	_currentPage = [BeatPaginationPage.alloc initWithDelegate:self];
	_currentPage.pageBreak = pageBreak;
}


#pragma mark - Line lookup

/// Returns page index based on line position
- (NSInteger)findPageIndexAt:(NSInteger)position {
	NSLog(@"findPageIndexAt: not implemented");
	for (NSInteger i=0; i<self.pages.count; i++) {
		BeatPaginationPage *page = _pages[i];
		NSRange range = page.representedRange;
		// get page.representedRange etc
		
		if (range.location > position) {
			// Return PREVIOUS page (as we've actually passed the position we've been looking for)
			if (i > 0) return i - 1;
			else return 0 ;
		}
	}
	
	return NSNotFound;
}

#pragma mark - Managing styles

- (RenderStyle*)styleForType:(LineType)type {
	return [self.styles forElement:[Line typeName:type]];
}

- (NSDictionary*)attributesForLine:(Line*)line dualDialogue:(bool)isDualDialogue {
	LineType type = line.type;
	if (isDualDialogue) {
		if (line.type == character) type = dualDialogueCharacter;
		else if (line.type == parenthetical) type = dualDialogueParenthetical;
		else if (line.type == dialogue) type = dualDialogue;
		else if (line.type == more) type = dualDialogueMore;
	}
	
	NSNumber* n = [NSNumber numberWithInteger:type];
	
	if (_lineTypeAttributes[n] == nil) {
		RenderStyle *style = [self styleForType:type];
		
		NSMutableDictionary* styles = [NSMutableDictionary dictionaryWithDictionary:@{
			NSForegroundColorAttributeName: BXColor.blackColor
		}];
		
		if (style.italic && style.bold) styles[NSFontAttributeName] = self.fonts.boldItalicCourier;
		else if (style.italic) 			styles[NSFontAttributeName] = self.fonts.italicCourier;
		else if (style.bold) 			styles[NSFontAttributeName] = self.fonts.boldCourier;
		else 							styles[NSFontAttributeName] = self.fonts.courier;
		
		CGFloat width = (_settings.paperSize == BeatA4) ? style.widthA4 : style.widthLetter;
		CGFloat blockWidth = width + style.marginLeft;
		if (!isDualDialogue) blockWidth += self.styles.page.contentPadding;
		
		NSMutableParagraphStyle* pStyle = NSMutableParagraphStyle.new;
		pStyle.headIndent = style.marginLeft;
		pStyle.firstLineHeadIndent = style.marginLeft;
		pStyle.paragraphSpacingBefore = style.marginTop;
		pStyle.paragraphSpacing = style.marginBottom;
		pStyle.tailIndent = -1 * style.marginRight; // Negative value;
		
		pStyle.maximumLineHeight = BeatPagination.lineHeight;
		
		if (!isDualDialogue && !line.isTitlePage) {
			// Add content padding where needed
			pStyle.firstLineHeadIndent += self.styles.page.contentPadding;
			pStyle.headIndent += self.styles.page.contentPadding;
		} else if (!line.isTitlePage) {
			pStyle.firstLineHeadIndent = style.marginLeft;
			pStyle.headIndent = style.marginLeft;
		}
		
		// Create text block for non-title page elements to restrict horizontal size
		if (!line.isTitlePage) {
			NSTextBlock* textBlock = NSTextBlock.new;
			[textBlock setContentWidth:blockWidth type:NSTextBlockAbsoluteValueType];
			pStyle.textBlocks = @[textBlock];
		}
		
		// Text alignment
		if ([style.textAlign isEqualToString:@"center"]) pStyle.alignment = NSTextAlignmentCenter;
		else if ([style.textAlign isEqualToString:@"right"]) pStyle.alignment = NSTextAlignmentRight;
		
		// Special rules for some blocks
		if ((type == lyrics || type == centered) && !line.beginsNewParagraph) {
			pStyle.paragraphSpacingBefore = 0;
		}
		
		styles[NSParagraphStyleAttributeName] = pStyle;
		
		// Apply to existing styles
		_lineTypeAttributes[n] = [NSDictionary dictionaryWithDictionary:styles];
	}
	
	return _lineTypeAttributes[n];
}


#pragma mark - CONT'D and (MORE)

/// Returns a `Line` object with character cue followed by `(CONT'D)` extension for continuing dialogue block after a page break.
+ (Line*)contdLineFor:(Line*)line {
	NSString *extension = BeatPagination.contdString;
	NSString *cue = [line.stripFormatting stringByReplacingOccurrencesOfString:extension withString:@""];
	cue = [cue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
	
	NSString *contdString = [NSString stringWithFormat:@"%@%@", cue, extension];
	Line *contd = [Line.alloc initWithString:contdString type:character];
	contd.position = line.position;
	contd.nextElementIsDualDialogue = line.nextElementIsDualDialogue;
	if (line.type == dualDialogueCharacter) contd.type = dualDialogueCharacter;
	
	return contd;
}

/// Returns a `Line` object for the `(MORE)` at the bottom of a page when a dialogue block is broken across pages.
+ (Line*)moreLineFor:(Line*)line {
	LineType type = (line.isDualDialogue) ? dualDialogueMore : more;
	Line *more = [Line.alloc initWithString:[BeatPagination moreString] type:type];
	more.position = line.position;
	more.unsafeForPageBreak = YES;
	return more;
}

+ (NSString*)moreString {
	NSString *moreStr = [BeatUserDefaults.sharedDefaults get:@"screenplayItemMore"];
	return [NSString stringWithFormat:@"(%@)", moreStr];
}

+ (NSString*)contdString {
	NSString *contdStr = [BeatUserDefaults.sharedDefaults get:@"screenplayItemContd"];
	return [NSString stringWithFormat:@" (%@)", contdStr]; // Extra space here to be easily able to add this after a cue
}

@end
