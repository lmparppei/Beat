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


@interface BeatPagination() <BeatPageDelegate>
@property (nonatomic) NSArray<Line*>* lines;
@property (nonatomic) NSArray<Line*>* lineQueue;
@property (nonatomic) BeatFonts* fonts;
@property (nonatomic) BeatExportSettings* settings;
@property (nonatomic) Styles* styles;
@property (nonatomic) NSInteger location;

@property (nonatomic) bool livePagination;
@property (nonatomic) bool canceled;
@property (nonatomic) bool success;

@property (weak, nonatomic) id<BeatPaginationDelegate> delegate;

@property (nonatomic) NSMutableArray<Line*>* queue;
@property (nonatomic) NSArray<BeatPaginationPage*>* cachedPages;
@property (nonatomic) BeatPaginationPage* currentPage;

@property (nonatomic) NSMutableArray<BeatPaginationPage*>* pages;

@property (nonatomic) NSDate* startTime;
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
		_lines = (screenplay.lines != nil) ? screenplay.lines : @[];
		_livePagination = livePagination;
		_location = changeAt;
		_cachedPages = cachedPages;
		_settings = settings;
		_pages = NSMutableArray.new;
		
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
	_startTime = NSDate.new;
	
	// Reset queue
	_queue = NSMutableArray.new;
	_lineQueue = [NSMutableArray arrayWithArray:self.lines];
	
	if (index == 0) {
		_pages = NSMutableArray.new;
		_currentPage = [BeatPaginationPage.alloc initWithDelegate:self];
	}
	
	for (NSInteger i=index; i<_lineQueue.count; i++) {
		// Do nothing if this operation is canceled
		if (_canceled) { return false; }
		
		Line* line = _lineQueue[i];
		
		// Catch wrong parsing (just in case)
		if (line.string.length == 0) continue;
		
		if ([_queue containsObject:line]) { continue; }
		else if (line.isInvisible && !(_settings.printNotes && line.note)) continue;
		
		// catch forced page breaks first
		if (line.type == pageBreak) {
			BeatPageBreak *pageBreak = [BeatPageBreak.alloc initWithY:-1 element:line reason:@"Forced page break"];
			
			[self addPage:@[line] pageBreak:pageBreak];
			//addPage(currentPage!, onCurrentPage: [line], onNextPage: [], pageBreak: pageBreak)
			continue;
		}
		
		// Add initial page break when needed
		if (self.pages.count == 0 && _currentPage.blocks.count == 0) {
			NSLog(@"Adding initial page break: %@", line);
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
			
		}
	}
	
	return true;
}

/**
Returns "blocks" for the given line.
- note: A block is usually any paragraph or a full dialogue block, but for the pagination to make sense, some blocks are grouped together.
That's why we are returning `[ [Line], [Line], ... ]`, and converting those blocks into actual screenplay layout blocks later.

The layout blocks (`BeatPageBlock`)
won't contain anything else than the rendered block, which can also mean a full dual-dialogue block.
*/
- (NSArray<NSArray<Line*>*>*)blocksForLineAt:(NSInteger)idx {
	Line* line = self.lineQueue[idx];
	NSMutableArray<Line*>* block = [NSMutableArray arrayWithObject:line];
	
	if (line.isAnyCharacter) {
		return [self dialogueBlockForLineAt:idx];
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
- (NSArray*)dialogueBlockForLineAt:(NSInteger)idx {
	Line *line = _lineQueue[idx];
	NSMutableArray<Line*>* block = NSMutableArray.new;
	[block addObject:line];
	
	bool waitForDualDialogue = line.nextElementIsDualDialogue;
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

- (void)addPage:(NSArray<Line*>*)elements pageBreak:(BeatPageBreak*)pageBreak {
	BeatPaginationBlock *block = [BeatPaginationBlock withLines:elements delegate:self];
	[_currentPage addBlock:block];
	[_pages addObject:_currentPage];
	
	_currentPage = [BeatPaginationPage.alloc initWithDelegate:self];
	_currentPage.pageBreak = pageBreak;
}

/*
	
	
	 // catch forced page breaks first
	 if (line.type == .pageBreak) {
		 let pageBreak = BeatPageBreak(y: -1, element: line, reason: "Forced page break")
		 addPage(currentPage!, onCurrentPage: [line], onNextPage: [], pageBreak: pageBreak)
		 continue
	 }
	 
	 // Add initial page break when needed
	 if self.pages.count == 0 && currentPage!.blocks.count == 0 {
		 print("Adding initial page break: ", line)
		 currentPage?.pageBreak = BeatPageBreak(y: 0, element: line)
	 }
	 
	 autoreleasepool {
		 let blocks = blocksFor(lineAtIndex: i)
		 addBlocks(blocks: blocks, currentPage: currentPage!)
	 }
 }
 
 // The loop has ended.
 pages.append(currentPage!)
 
 return true
}
 */


#pragma mark - Line lookup

/// Returns page index based on line position
- (NSInteger)findPageIndexAt:(NSInteger)position {
	NSLog(@"findPageIndexAt: not implemented");
	for (NSInteger i=0; i<self.pages.count; i++) {
		BeatPaginationPage *page = _pages[i];
		// get page.representedRange etc
	}
	
	return NSNotFound;
}
/*
 /// Returns page index based on line position
 func findPageIndex(position:Int, pages:[BeatPageView]) -> Int {
	 var i = 0
	 while i < pages.count {
		 let p = pages[i]
		 if p.representedRange.location > position {
			 if i > 0 {
				 // Return PREVIOUS page
				 return i - 1
			 } else {
				 return 0
			 }
		 }
		 i += 1
	 }
	 
	 for p in 0..<pages.count {
		 let page = pages[p]
		 
		 let lines = page.lines
		 for i in 0..<lines.count {
			 let line = lines[i]
			 
			 if NSMaxRange(line.range()) >= line.position {
				 return p
			 }
		 }
	 }
	 
	 return NSNotFound
 }
 */

#pragma mark - CONT'D and (MORE)

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
