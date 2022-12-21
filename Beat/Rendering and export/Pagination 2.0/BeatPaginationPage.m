//
//  BeatPaginationPage.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 12.12.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//
/*
 
NOTE: iOS can't use this code.
 
 */
#import <BeatParsing/BeatParsing.h>
#import "BeatPaginationPage.h"
#import "BeatPaginationBlock.h"
#import "BeatPageBreak.h"
#import "Beat-Swift.h"

@interface BeatPaginationPage()
@property (nonatomic, weak) id<BeatPageDelegate> delegate;
@property (nonatomic) NSMutableArray<Line*>* lines;

@end

@implementation BeatPaginationPage

-(instancetype)initWithDelegate:(id<BeatPageDelegate>)delegate {
	self = [super init];
	
	if (self) {
		self.delegate = delegate;
		self.blocks = NSMutableArray.new;
		
		NSSize size = [BeatPaperSizing sizeFor:delegate.settings.paperSize];
		RenderStyle* style = delegate.styles.page;
		
		// Max height for page content is formed by subtracting margins and the page header from page height
		self.maxHeight = size.height - style.marginTop - style.marginBottom - BeatPagination.lineHeight * 2;
	}
	
	return self;
}

/**
 This method returns page content as `NSAttributedString`. To get it working, you'll need to hook up a `BeatRendererDelegate` instance to the paginator. macOS and iOS require their own respective classes which comply to the protocol.
 */
-(NSAttributedString*)attributedString {
	if (self.delegate.renderer == nil) {
		NSLog(@"WARNING: No renderer set for paginator");
		return NSAttributedString.new;
	}
	
	NSInteger pageNumber = [self.delegate.pages indexOfObject:self];
	if (pageNumber == NSNotFound) pageNumber = self.delegate.pages.count - 1;
	
	NSMutableAttributedString* string = NSMutableAttributedString.new;
	
	// Add page number header
	NSAttributedString* header = [self.delegate.renderer pageNumberBlockForPageNumber:pageNumber + 1];
	[string appendAttributedString:header];
	
	for (BeatPaginationBlock* block in self.blocks) {
		bool firstElement = (block == self.blocks.firstObject) ? true : false;
		NSAttributedString* renderedBlock = [self.delegate.renderer renderBlock:block firstElementOnPage:firstElement];
		[string appendAttributedString:renderedBlock];
	}
	
	return string;
}


-(NSArray*)lines {
	NSMutableArray* lines = NSMutableArray.new;
	for (BeatPaginationBlock* block in self.blocks) {
		[lines addObjectsFromArray:block.lines];
	}
	return lines;
}

-(CGFloat)remainingSpace {
	CGFloat height = 0.0;
	for (BeatPaginationBlock *block in self.blocks) {
		height += block.height;
		
		// Remove top margin for the first object
		if (block == self.blocks.firstObject) {
			height -= block.topMargin;
		}
	}
	
	return _maxHeight - height;
}

-(NSRange)representedRange {
	NSInteger begin = NSNotFound;
	NSInteger end = NSNotFound;
	NSArray<Line*>* lines = self.lines;
	
	for (Line* line in lines) {
		if (!line.unsafeForPageBreak) {
			begin = line.position;
			break;
		}
	}
	
	NSInteger i = lines.count - 1;
	while (i >= 0) {
		Line *line = lines[i];
		if (!line.unsafeForPageBreak) {
			end = NSMaxRange(line.range);
		}
	}
	
	if (begin == NSNotFound || end == NSNotFound)
		return NSMakeRange(NSNotFound, 0);
	else
		return NSMakeRange(begin, end - begin);
}

-(void)addBlock:(BeatPaginationBlock*)block {
	[self.blocks addObject:block];
}


@end
