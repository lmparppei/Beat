//
//  FountainPaginator.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 18.5.2020.
//  Copyright © 2020 KAPITAN!. All rights reserved.
//

/*
 
 WORK IN PROGRESS.
 A pagination class for removing the FNElement layer altogether.
 This is very loosely based on the original FNPaginator code, with heavy
 modifications to the whole logic behind it, and rewritten to use the
 Line class driving ContinuousFountainParser. The implementation (still in use)
 leans on converting Line to FNElement.
 
 To get this into production app still needs rewriting FNHTMLScript to support Beat.
 
 Original Fountain repository pagination code was totally convoluted and had
 many obvious bugs and stuff that really didn't work in many places.
 I went out of my way to make my own pagination engine, just to end up with
 something almost as convoluted.
 
 Maybe it was an important journey - I learned how this actually works and
 got to spend a nice day coding in my bathrobe. I had two feature scripts that
 required my attention, but yeah. This is duct-taped together to give somewhat
 acceptable pagination results when using European page sizes, and now also
 splits paragraphs into parts.
 
 It doesn't matter - I have the chance to spend my days doing something I'm
 intrigued by, and probably it makes it less likely that I'll get dementia or
 other memory-related illness later in life. I don't know.
 
 The current iteration has live pagination stuff built in. The idea is to have
 the class be retained, and to only paginate from changed indices. I've made
 some experiments to allow that, but for now it does not work at all.
 
 This might have been pretty unhelpful for anyone stumbling upon this file some day.
 Try to make something out of it.

 
 "Remember the flight
 the bird is mortal"
 (Forough Farrokhzad)
 
 */

#import "FountainPaginator.h"
#import "Line.h"
#import "RegExCategories.h"

#define LINE_HEIGHT 13

@interface FountainPaginator ()

@property (weak, nonatomic) NSDocument *document;
@property (strong, nonatomic) NSArray *script;

// WIP
@property (nonatomic) bool livePagination;

@end

@implementation FountainPaginator

- (id)initWithScript:(NSArray *)elements
{
	self = [super init];
	if (self) {
		_pages = [[NSMutableArray alloc] init];
		_script = elements;
	}
	return self;
}
- (id)initWithScript:(NSArray *)elements document:(NSDocument*)document
{
	self = [super init];
	if (self) {
		_pages = [[NSMutableArray alloc] init];
		_script = elements;
		_document = document;
	}
	return self;
}
- (id)initForLivePagination:(NSArray *)elements paperSize:(CGSize)paperSize {
	self = [super init];
	if (self) {
		_pages = [NSMutableArray array];
		_script = elements;
		_paperSize = paperSize;
		_livePagination = YES;
		_pageBreaks = [NSMutableArray array];
	}
	return self;
}
- (id)initWithScript:(NSArray *)elements paperSize:(CGSize)paperSize
{
	self = [super init];
	if (self) {
		_pages = [[NSMutableArray alloc] init];
		_script = elements;
		_paperSize = paperSize;
	}
	return self;
}

// NOTE NOTE NOTE: NOT WORKING
- (void)livePaginationFor:(NSArray*)script fromIndex:(NSInteger)index {
	@synchronized (self) {
		self.script = script;
		[self paginateFromIndex:0 currentPage:nil];
	}
	
	/*
	 
	if (index == 0 || self.pages.count == 0) {
		@synchronized (self) {
			[self paginateFromIndex:0 currentPage:nil];
			return;
		}
	}
	
	_livePagination = YES;
	
	NSInteger startIndex = -1;
	
	NSMutableArray *currentPage = [NSMutableArray array];
	NSMutableArray *nonEditedPages = [NSMutableArray array];
	
	Line *editedLine;
	
	// See which pages are unedited
	for (NSArray *page in self.pages) {
		Line *lastLine = page.lastObject;

		// This page has not been edited
		if (index > lastLine.position + lastLine.string.length) {
			[nonEditedPages addObject:page];
		} else {
			// We have found the page the changed index is on
			NSUInteger lineIndex = -1;
			bool indexFound = NO;
			for (Line* line in page) {
				lineIndex++;
				NSLog(@" %lu ---- %lu/%lu --- %@", index, line.position, line.position+line.string.length, line.string);

				if (index >= line.position && index <= line.position + line.string.length + 1) {
					NSLog(@"in range: %@", line.string);
					editedLine = line;
					break;
				} else {
					[currentPage addObject:line];
				}
			}
			
			if (indexFound) startIndex = lineIndex;
			break;
		}
	}
	
	NSInteger indexOfLine = -1;
	for (Line * line in script) {
		if (index >= line.position && index <= line.position + line.string.length) {
			indexOfLine = [script indexOfObject:line];
		}
	}
	
	@synchronized (self) {
		self.script = script;
		self.pages = nonEditedPages;
		
		if (indexOfLine >= 0 && self.pages.count > 0) [self paginateFromIndex:indexOfLine currentPage:currentPage];
		else [self paginateFromIndex:0 currentPage:nil];
	}
	*/
}

- (NSArray *)pageAtIndex:(NSUInteger)index
{
	// Make sure some kind of pagination has been run before you try to return a value.
	if ([self.pages count] == 0) {
		[self paginate];
	}
	
	// Make sure we don't try and access an index that doesn't exist
	if ([self.pages count] == 0 || (index > [self.pages count] - 1)) {
		return @[];
	}
	
	return self.pages[index];
}

- (NSUInteger)numberOfPages
{
	// Make sure some kind of pagination has been run before you try to return a value.
	if ([self.pages count] == 0) {
		[self paginate];
	}
	return [self.pages count];
}

/*
You, who shall resurface following the flood
In which we have perished,
Contemplate —
When you speak of our weaknesses,
Also the dark time
That you have escaped.
*/


- (void)paginate {
	[self paginateFromIndex:0 currentPage:nil];
}
- (void)paginateFromIndex:(NSInteger)fromIndex currentPage:(NSMutableArray*)currentPage
{
	// NSLog(@"paginating from %lu (with %lu elements on page)", fromIndex, currentPage.count);
	// Default pagination function for US Letter paper size (legacy of Fountain repository)
	if (_paperSize.height == 0) {
		if (self.document) {
			// Get paper size from the document
			_paperSize = CGSizeMake(self.document.printInfo.paperSize.width, self.document.printInfo.paperSize.height);
		} else {
			// US letter paper size is 8.5 x 11 (in pixels)
			_paperSize = CGSizeMake(612, 792);
		}
	}
	
	@autoreleasepool {
		bool debug = NO;
				
		NSInteger initialY = 0; // initial starting point on page
		NSInteger currentY = initialY;
		
		NSInteger oneInchBuffer = 72;
		NSInteger maxPageHeight = _paperSize.height - round(oneInchBuffer * 1.1);
		
		BeatFont *font = [BeatFont fontWithName:@"Courier" size:12];
		//NSInteger lineHeight = font.pointSize * 1.1;
		CGFloat lineHeight = LINE_HEIGHT;

		_pages = [NSMutableArray array];
		_pageBreaks = [NSMutableArray array];
		currentPage = [NSMutableArray array];

/*
		// For those who come after
		if (fromIndex == 0 || self.pages.count == 0) {
			_pages = [NSMutableArray array];
			_pageBreaks = [NSMutableArray array];
			currentPage = [NSMutableArray array];
		} else {
			// Retain the previous pages if we have a page index set
			// NOTE: This is something written for the very distant future, not at all usable now
			if (self.pages.count > 1) _pageBreaks = [NSMutableArray arrayWithArray:[self.pageBreaks subarrayWithRange:NSMakeRange(0, self.pages.count)]];
			else _pageBreaks = [NSMutableArray array];
			
			if (currentPage) {
				NSInteger i = 0;
				for (Line* line in currentPage) {
					if (i > 0) currentY += [FountainPaginator spaceBeforeForLine:line];
					currentY += [FountainPaginator elementHeight:line font:font lineHeight:LINE_HEIGHT];
					i++;
				}
			}
		}
*/
		
		CGFloat spaceBefore;
		CGFloat elementWidth;
				
		// create a tmp array that will hold elements to be added to the pages
		NSMutableArray *tmpElements = [NSMutableArray array];
		NSInteger maxElements = [self.script count];
		
		NSInteger previousDualDialogueBlockHeight = -1;

		// walk through the elements array
		for (NSInteger i = fromIndex; i < maxElements; i++) {
			// We need to copy this here, not to fuck anything
			Line *element  = (self.script)[i];
			
			// If we already handled this element, carry on
			if ([tmpElements containsObject:element]) {
				continue;
			} else [tmpElements removeAllObjects];
			
			// Skip invisible elements
			if (element.isInvisible || element.type == empty) continue;
			
			// If this is the FIRST page, add a break to mark for the end of title page and beginning of document
			if (_pageBreaks.count == 0) [self pageBreak:element position:0];
			
			// Reset Y if the page is empty
			if ([currentPage count] == 0) currentY = initialY;
			
			// catch page breaks immediately
			if (element.type == pageBreak) {
				// close the open page
				[currentPage addObject:element];
				[self.pages addObject:currentPage];

				[self pageBreak:element position:-1];
				
				// reset currentPage and the currentY value
				currentPage = [NSMutableArray array];
				currentY    = initialY;
				
				continue;
			}
			
			// Catch wrong parsing.
			// We SHOULD NOT have orphaned dialogue. This can happen with non-forced text.
			if (element.type == dialogue && element.string.length == 0) continue;
			
			// get spaceBefore, the leftMargin, and the elementWidth
			spaceBefore         = [FountainPaginator spaceBeforeForLine:element];
			elementWidth        = [FountainPaginator widthForElement:element];
			
			// get the height of the text
			NSInteger blockHeight    = [FountainPaginator heightForString:element.cleanedString font:font maxWidth:elementWidth lineHeight:lineHeight];
			
			// data integrity check
			if (blockHeight <= 0) {
				// height = lineHeight;
				continue;
			}
			NSInteger dialogueBlockHeight = 0;
			
			// only add the space before if we're not at the top of the current page
			if ([currentPage count] > 0) {
				blockHeight += spaceBefore;
			}
			
			// Fix to get styling to show up in PDFs. I have no idea.
			if (![element.cleanedString isMatch:RX(@" $")]) {
				element.string = [NSString stringWithFormat:@"%@%@", element.cleanedString, @""];
			}
			
			NSInteger fullHeight = blockHeight;
						
			// GOING THROUGH ELEMENTS
			
			// Reset dual dialogue
			if (element.type != dualDialogueCharacter) previousDualDialogueBlockHeight = -1;
			
			// Handle scene headings
			if (element.type == heading) {
				//NSInteger fullHeight = [FNPaginator widthForElement:element];
				[tmpElements addObject:element];

				NSInteger j = i+1;
				Line *nextElement;

				while (j < maxElements && ![nextElement.cleanedString length]) {
					nextElement = (self.script)[j];
					j++;
				}
				NSInteger height = [FountainPaginator elementHeight:nextElement font:font lineHeight:lineHeight];
				fullHeight += [FountainPaginator spaceBeforeForLine:nextElement] + height;
				
				if (nextElement) [tmpElements addObject:nextElement];
				//NSLog(@"/ full height: %lu", fullHeight);
			}
			
			// Handle character. Get whole block.
			else if ((element.type == character || element.type == dualDialogueCharacter) && [self elementExists:i + 1]) {				
				bool isDualDialogue = NO;
				if (element.type == dualDialogueCharacter) isDualDialogue = YES;
				
				Line *nextElement;
				NSInteger j = i; // Next item index
				
				nextElement = element;
				
				if ([currentPage count]) dialogueBlockHeight = spaceBefore; else dialogueBlockHeight = 0;
				
				// Catch elements in the dialogue block, single or dual
				do {
					dialogueBlockHeight += [FountainPaginator elementHeight:nextElement font:font lineHeight:lineHeight];
					[tmpElements addObject:nextElement];
					
					j++;
					if (j < maxElements) nextElement = (self.script)[j];
				} while (j < maxElements && (
					([nextElement isDialogueElement] && !isDualDialogue) ||
					([nextElement isDualDialogueElement] && isDualDialogue)
				));

				// Check if there is an upcoming dual dialogue block
				if (element.nextElementIsDualDialogue) {
					previousDualDialogueBlockHeight = dialogueBlockHeight;
				}
				// OR if the current block is the one we've been waiting for
				else if (element.type == dualDialogueCharacter) {
					// If the previous dialogue block was lower in height than the current one,
					// we'll substract to get the height difference and add it to the total page height later
					if (previousDualDialogueBlockHeight < dialogueBlockHeight) dialogueBlockHeight = dialogueBlockHeight - previousDualDialogueBlockHeight;
					else dialogueBlockHeight = 0;
				}
				else {
					previousDualDialogueBlockHeight = -1;
				}
				
				fullHeight = dialogueBlockHeight;
				
			} else {
				[tmpElements addObject:element];
			}
			
			
			// BREAKING ELEMENTS ONTO PAGES
			// Figure out which element went overboard
			if (currentY + fullHeight > maxPageHeight) {
				CGFloat overflow = maxPageHeight - (currentY + fullHeight);

				// How many rows remain on page
				//NSInteger rows = fabs(overflow) / 12;
				//if (rows == 0) rows = 1;
				
				// If it fits, just squeeze it on this page
				if (fabs(overflow) < lineHeight * 1.5) {
					[currentPage addObjectsFromArray:tmpElements];
					[_pages addObject:currentPage];
					
					// Add page break for live pagination (-1 means the break is AFTER the element)
					[self pageBreak:[tmpElements lastObject] position:-1];
					
					currentPage = [NSMutableArray array];
					currentY = 0;
					continue;
				}
				
				// Find out the spiller
				Line *spillerElement;
				
				bool handled = NO;
				
				#pragma mark Split scene heading & paragraph
				
				if (element.type == heading || element.type == action) {
					bool headingBlock = NO;

					if (element.type == heading) {
						headingBlock = YES;
						if ([self elementExists:i+1]) spillerElement = (self.script)[i+1];
						else spillerElement = element;
					} else {
						spillerElement = element;
					}
					
					// Some duct tape :----)
					if (headingBlock) {
						// Push to next page if it would be only 1 line or something
						if (fullHeight - fabs(overflow) < lineHeight * 3
							&& fabs(overflow) > lineHeight * 2) {
							handled = YES;
						}
					}
					
					// Split first paragraph scene into two if it's higher than one line
					NSInteger limit = lineHeight;
					NSInteger space = maxPageHeight - currentY;
					
					//if (headingBlock) limit = lineHeight + blockHeight;
					
					if (fabs(overflow) > limit && space > limit * 2 && !handled) {
						//if (debug) NSLog(@"split across pages (%f) %@", overflow, spillerElement.string);
						NSArray *words = [spillerElement.cleanedString componentsSeparatedByString:@" "];
						NSInteger space = maxPageHeight - currentY;
						
						if (headingBlock) space -= blockHeight;
						
						NSString *text = @"";
						NSString *retain = @"";
						NSString *split = @"";
						
						CGFloat breakPosition = 0;
						
						// Loop through words and count the height
						for (NSString *word in words) {
							text = [text stringByAppendingFormat:@" %@", word];
							// FNElement *tempElement = [FNElement elementOfType:@"Action" text:text];
							Line *tempElement = [[Line alloc] initWithString:text type:action];
							NSInteger h = [FountainPaginator elementHeight:tempElement font:font lineHeight:lineHeight];
							if (h < space) {
								breakPosition = h;
								retain = [retain stringByAppendingFormat:@" %@", word];
							} else {
								split = [split stringByAppendingFormat:@" %@", word];
							}
						}
						
						// Let's create character indexes for these virtual elements, too
						Line *prePageBreak = [Line withString:retain type:action];
						prePageBreak.position = spillerElement.position;
						Line *postPageBreak = [Line withString:split type:action];
						postPageBreak.position = prePageBreak.position + prePageBreak.string.length;
												
						// If it's a heading we need special rules
						if (headingBlock) {
							// We had something remain on the original page
							if ([retain length]) {
								[currentPage addObject:element];
								[currentPage addObject:prePageBreak];
								[_pages addObject:currentPage];
								
								// Add page break for live pagination
								[self pageBreak:spillerElement position:breakPosition];
								
								currentPage = [NSMutableArray array];
								[currentPage addObject:postPageBreak];
								currentY = [FountainPaginator elementHeight:postPageBreak font:font lineHeight:lineHeight];
							}
							// Nothing remained, move whole scene heading to next page
							else {
								[_pages addObject:currentPage];
								
								// Page break for live pagination
								[self pageBreak:element position:0];
								
								currentPage = [NSMutableArray array];
								[currentPage addObject:element];
								[currentPage addObject:postPageBreak];
								currentY = fullHeight - spaceBefore; // Remove space from beginning, because this is the first element
							}
						} else {
							[currentPage addObject:prePageBreak];
							[_pages addObject:currentPage];
							
							// Add page break info (for live pagination if in use)
							[self pageBreak:spillerElement position:breakPosition];
							
							currentPage = [NSMutableArray array];
							[currentPage addObject:postPageBreak];
							currentY = [FountainPaginator elementHeight:postPageBreak font:font lineHeight:lineHeight];
						}
												
						continue;
						
					} else {
						if (debug) NSLog(@"throw on next: %@", element.string);
												
						// Close page and reset
						[_pages addObject:currentPage];
						currentPage = [NSMutableArray array];

						// Add page break info (for live pagination if in use)
						[self pageBreak:element position:0];
					}
				}
				
				#pragma mark Split character
				else if (element.type == character) {
					// Figure out which element in dialogue block went over the page limit
					NSInteger dialogueHeight = 0;
					NSInteger blockIndex = -1;
				
					NSInteger remainingSpace = maxPageHeight - currentY;
	
					for (Line *dElement in tmpElements) {
						blockIndex++;
						NSInteger h = [FountainPaginator elementHeight:dElement font:font lineHeight:lineHeight];
						if (currentY + dialogueHeight + h > maxPageHeight) { spillerElement = dElement; break; }
						else { dialogueHeight += h; }
					}
					
					// If we got stuck in first parenthetical, throw the whole block on the next page
					if (spillerElement.type == parenthetical && blockIndex < 2) {
						[_pages addObject:currentPage];
						currentPage = [NSMutableArray array];
						
						// Add page break info
						[self pageBreak:element position:0];
					}
				
					// Squeeze this element on current page
					else if (fabs(overflow) <= lineHeight) {
						if (debug) NSLog(@" // squeeze");
						[currentPage addObjectsFromArray:tmpElements];
						[_pages addObject:currentPage];
						
						currentPage = [NSMutableArray array];
						currentY = 0;
						
						// Add page break info (for live pagination if in use)
						[self pageBreak:spillerElement position:-1];


						continue; // Don't let the loop take care of the tmp buffer here
					}
					else if (remainingSpace > lineHeight * 2) {
						if (spillerElement.type == dialogue) {
							// Break into sentences
							NSMutableArray *sentences = [NSMutableArray arrayWithArray:[spillerElement.cleanedString matches:RX(@"(.+?[\\.\\?\\!]+\\s*)")]];
							if (![sentences count] && [spillerElement.cleanedString length]) [sentences addObject:spillerElement.cleanedString];
							
							NSString *text = @"";
							NSString *retain = @"";
							NSString *split = @"";
							CGFloat breakPosition = 0;
							
							for (NSString *sentence in sentences) {
								text = [text stringByAppendingFormat:@" %@", sentence];
								Line *tempElement = [[Line alloc] initWithString:text type:dialogue];
								
								NSInteger h = [FountainPaginator elementHeight:tempElement font:font lineHeight:lineHeight];
								
								// We need to substract other dialogue block heights from here
								NSInteger space = maxPageHeight - currentY - dialogueHeight;

								if (h < space) {
									breakPosition = h;
									retain = [retain stringByAppendingFormat:@" %@", sentence];
								} else {
									split = [split stringByAppendingFormat:@" %@", sentence];
								}
							}
							
							// If we have something to retain, do it, otherwise just break to next page
							if ([retain length] > 0) {
								for (NSInteger d = 0; d < blockIndex; d++) {
									Line *preBreak = [Line withString:[tmpElements[d] cleanedString] type:[(Line*)tmpElements[d] type]];
									[currentPage addObject:preBreak];
								}
								
								// Add on the previous page
								Line *preDialogue = [[Line alloc] initWithString:retain type:dialogue];
								Line *preMore = [[Line alloc] initWithString:@"(MORE)" type:more];
								
								// These are the same, to inform live pagination where we are in the document
								preDialogue.position = spillerElement.position;
								preMore.position = spillerElement.position;
								
								[currentPage addObject:preDialogue];
								[currentPage addObject:preMore];
								[self.pages addObject:currentPage];

								// Add page break
								[self pageBreak:spillerElement position:breakPosition];
								
								currentPage = [NSMutableArray array];

								// Add the remaining stuff on the next page
								Line *postCue = [Line withString:[element.cleanedString stringByAppendingString:@" (CONT'D)"] type:character];
								Line *postDialogue = [Line withString:split type:dialogue];
								// Position indexes for live pagination
								postCue.position = preDialogue.position + preDialogue.string.length;
								postDialogue.position = postCue.position;
								
								[currentPage addObject:postCue];
								[currentPage addObject:postDialogue];
								
								currentY = 0;
								currentY += [FountainPaginator elementHeight:postCue font:font lineHeight:lineHeight];
								currentY += [FountainPaginator elementHeight:postDialogue font:font lineHeight:lineHeight];

								// Add possible remaining dialogue elements
								if (blockIndex + 1 > [tmpElements count]) continue;
								NSInteger position = postDialogue.position + postDialogue.string.length;
								for (NSInteger d = blockIndex + 1; d < [tmpElements count]; d++) {
									Line *postBreak = [[Line alloc] initWithString:[tmpElements[d] cleanedString] type:[(Line*)tmpElements[d] type]];
									postBreak.position = position; // String index from file
									position += postBreak.string.length;
									currentY += [FountainPaginator elementHeight:postBreak font:font lineHeight:lineHeight];
									
									[currentPage addObject:postBreak];
									
								}
							
								// Don't let this loop handle the buffer
								continue;
							} else {
								// Nothing to retain, move whole block on next page
								[_pages addObject:currentPage];
								currentPage = [NSMutableArray array];
								[self pageBreak:element position:0];
							}

						} else {
							// Parenthetical spills, but it's not SECOND element, rather than somewhere else in the block
							if (spillerElement.type == parenthetical && blockIndex > 1) {
								// Add the preceeding elements
								for (NSInteger d = 0; d < blockIndex; d++) {
									Line *dElement = tmpElements[d];
									[currentPage addObject:dElement];
								}
																
								// Add (more) after the dialogue
								[currentPage addObject:[Line withString:@"(MORE)" type:more]];
								[_pages addObject:currentPage];
								currentPage = [NSMutableArray array];
								
								Line* postCue = [[Line alloc] initWithString:[element.cleanedString stringByAppendingString:@" (CONT'D)"] type:character];
								[currentPage addObject:postCue];
								[currentPage addObject:spillerElement];
								
								// Count heights
								currentY = 0;
								currentY += [FountainPaginator elementHeight:postCue font:font lineHeight:lineHeight];
								currentY += [FountainPaginator elementHeight:spillerElement font:font lineHeight:lineHeight];
								
								// Add the rest of the stuff
								for (NSInteger d = blockIndex + 1; d < tmpElements.count; d++) {
									Line *dElement = tmpElements[d];
									currentY += [FountainPaginator elementHeight:dElement font:font lineHeight:lineHeight];
									[currentPage addObject:dElement];
								}
								
								// Add page break for live pagination
								[self pageBreak:spillerElement position:0];
								
								// Don't let the loop take care of the buffered elements
								continue;
							}
						}
						
					// Otherwise push it on the next page
					} else {
					
						[_pages addObject:currentPage];
						currentPage = [NSMutableArray array];
						
						[self pageBreak:spillerElement position:0];
					}
				}
				else if (element.type == action) {
					[_pages addObject:currentPage];
					currentPage = [NSMutableArray array];
					
					[self pageBreak:spillerElement position:-1];

				} else {
					// Whatever, let's just push this element on the next page
					[_pages addObject:currentPage];
					currentPage = [NSMutableArray array];
					
					[self pageBreak:spillerElement position:0];
				}
				
				currentY = 0;
			}
			
			// Add remaining elements
			for (Line *el in tmpElements) {
				NSInteger h = [FountainPaginator elementHeight:el font:font lineHeight:lineHeight];
				
				if (previousDualDialogueBlockHeight < 0) {
					currentY += h;
					if ([currentPage count] > 0) { currentY += [FountainPaginator spaceBeforeForLine:el]; }
				} else {
					// If this is double dialogue, let's add dialogue block height.
					// If this one was higher, its height difference is added on top of the previous
					currentY += dialogueBlockHeight;
				}
				
				[currentPage addObject:el];
			}
		}
		
		[_pages addObject:currentPage];
	}
}


- (NSString *)snippet:(NSString*)string {
	if ([string length] > 25) {
		NSRange range = NSMakeRange(0,25);
		return [string substringWithRange:range];
	} else {
		return string;
	}
}

#pragma mark - Helper class methods
	
- (bool)elementExists:(NSInteger)i {
	if (i < self.script.count) return YES; else return NO;
}

+ (CGFloat)lineHeight {
	return LINE_HEIGHT;
}
+ (CGFloat)spaceBeforeForElement:(Line *)element
{
	CGFloat spaceBefore = 0;
	
	NSString *type  = element.typeAsFountainString;
	NSSet *set      = [NSSet setWithObjects:@"Action", @"General", @"Character", @"Transition", nil];
	
	if ([type isEqualToString:@"Scene Heading"]) {
		//spaceBefore = 3;
		spaceBefore = 33;
	}
	else if ([set containsObject:type]) {
		//spaceBefore = 1.1;
		spaceBefore = LINE_HEIGHT;
	}
	
	return spaceBefore;
}

+ (CGFloat)elementHeight:(Line *)element font:(BeatFont*)font lineHeight:(CGFloat)lineHeight {
	return [FountainPaginator heightForString:element.cleanedString font:font maxWidth:[FountainPaginator widthForElement:element] lineHeight:lineHeight];
}

+ (NSInteger)widthForElement:(Line *)element
{
	NSInteger width = 0;
	NSString *type  = element.typeAsFountainString;
	
	if ([type isEqualToString:@"Action"] || [type isEqualToString:@"General"] || [type isEqualToString:@"Scene Heading"] || [type isEqualToString:@"Transition"]) {
		width   = 430;
	}
	else if ([type isEqualToString:@"Character"]) {
		width   = 180;
	}
	else if ([type isEqualToString:@"Dialogue"]) {
		width   = 217;
	}
	else if ([type isEqualToString:@"Parenthetical"]) {
		width   = 210;
	}
	
	return width;
}

/*
 To get the height of a string we need to create a text layout box, and use that to calculate the number
 of lines of text we have, then multiply that by the line height. This is NOT the method Apple describes
 in their docs, but we have to do this because getting the size of the layout box (Apple's recommended
 method) doesn't take into account line height, so text won't display correctly when we try and print.
 */
+ (NSInteger)heightForString:(NSString *)string font:(BeatFont *)font maxWidth:(NSInteger)maxWidth lineHeight:(CGFloat)lineHeight
{
	/*
	 This method won't work on iOS. For iOS you'll need to adjust the font size to 80% and use the NSString instance
	 method - (CGSize)sizeWithFont:constrainedToSize:lineBreakMode:
	 */
	
	if ([string length] < 1) return lineHeight;
	
	// set up the layout manager
	NSTextStorage   *textStorage   = [[NSTextStorage alloc] initWithString:string attributes:@{NSFontAttributeName: font}];
	NSLayoutManager *layoutManager = [[NSLayoutManager alloc] init];
#if TARGET_OS_IPHONE
	NSTextContainer *textContainer = [[NSTextContainer alloc] init];
	[textContainer setSize:CGSizeMake(maxWidth, MAXFLOAT)];
#else
	NSTextContainer *textContainer = [[NSTextContainer alloc] initWithContainerSize:NSMakeSize(maxWidth, MAXFLOAT)];
#endif
	[layoutManager addTextContainer:textContainer];
	[textStorage addLayoutManager:layoutManager];
	[textContainer setLineFragmentPadding:0.0];
	
	[layoutManager glyphRangeForTextContainer:textContainer];
	
	// get the number of lines
	NSInteger numberOfLines;
	NSInteger index;
	NSInteger numberOfGlyphs = [layoutManager numberOfGlyphs];
	
	NSRange lineRange;
	for (numberOfLines = 0, index = 0; index < numberOfGlyphs; numberOfLines++){
		[layoutManager lineFragmentRectForGlyphAtIndex:index effectiveRange:&lineRange];
		index = NSMaxRange(lineRange);
	}
	
	// calculate the height
	return numberOfLines * lineHeight;
}
- (void)pageBreak:(Line*)line position:(CGFloat)position {
	if (!_livePagination) return; // Don't run this for non-live pagination

	NSNumber *value = [NSNumber numberWithFloat:position];

	if (value && line) {
		[_pageBreaks addObject:@{ @"line": line, @"position": value }];
	}
	else { NSLog(@"no value: %@", line); }
}

- (NSInteger)pageNumberFor:(NSInteger)location {
	NSInteger pageNumber = 1;
	for (NSArray *page in _pages) {
		Line *firstElement = [page firstObject];
		Line *lastElement = [page lastObject];
		if (location >= firstElement.position && location <= lastElement.position + lastElement.string.length) {
			return pageNumber;
		}
		pageNumber++;
	}
	return 0;
}

#pragma mark - Beat helper methods

+ (CGFloat)spaceBeforeForLine:(Line*)line {
	if (line.isSplitParagraph) return 0;
	else if (line.type == heading) return 33;
	else if (line.type == character || line.type == dualDialogueCharacter) return LINE_HEIGHT;
	else if (line.type == dialogue) return 0;
	else if (line.type == parenthetical) return 0;
	else if (line.type == dualDialogue) return 0;
	else if (line.type == dualDialogueParenthetical) return 0;
	else if (line.type == transitionLine) return LINE_HEIGHT;
	else if (line.type == action) return LINE_HEIGHT;
	else return LINE_HEIGHT;
}


@end
