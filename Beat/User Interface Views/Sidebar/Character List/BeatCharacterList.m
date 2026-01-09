//
//  BeatCharacterList.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 22.10.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import <BeatParsing/BeatParsing.h>
#import <BeatThemes/BeatThemes.h>
#import <BeatCore/BeatColors.h>
#import <BeatCore/BeatCore-Swift.h>
#import "BeatCharacterList.h"
#import "BeatPieGraph.h"
#import "Beat-Swift.h"

#define POPOVER_WIDTH 150

@interface BeatLinesBarRowView : NSTableCellView
@property (nonatomic) CGFloat barWidth;
@property (nonatomic, weak) BeatCharacter *character;
@property (nonatomic, weak) IBOutlet NSTextField* numberOfLines;
@end

@implementation BeatLinesBarRowView

-(void)drawRect:(NSRect)dirtyRect
{
	[super drawRect:dirtyRect];

	static NSDictionary *colorForGender;
	if (colorForGender == nil) colorForGender = @{
		@"woman": ThemeManager.sharedManager.genderWomanColor,
		@"man": ThemeManager.sharedManager.genderManColor,
		@"other": ThemeManager.sharedManager.genderOtherColor,
		@"unspecified": ThemeManager.sharedManager.genderUnspecifiedColor
	};

	NSColor *color = colorForGender[_character.gender];
	CGFloat alpha = _barWidth * 1.0;
	
	if (self.character.highlightColor.length > 0) {
		NSColor* cc = [BeatColors color:self.character.highlightColor];
		if (cc != nil) color = cc;
	}

	if (alpha > 1.0) alpha = 1.0;
	if (alpha < 0.2) alpha = .2;
	color = [color colorWithAlphaComponent:alpha];
	[color setFill];
		
	CGFloat width = (self.frame.size.width - self.numberOfLines.frame.size.width - 5.0) * _barWidth;
	CGFloat height = self.frame.size.height * .6;
	if (width < 2.0) width = 2.0;
	
	// Paint a rounded rect
	NSRect rect = (NSRect){ 0, (self.frame.size.height - height) / 2, width, height };
	NSBezierPath *path = [[NSBezierPath alloc] init];
	[path appendBezierPathWithRoundedRect:rect xRadius:2 yRadius:2];
	[path fill];
}

@end

@interface BeatCharacterList () <NSPopoverDelegate, BeatCharacterListDelegate> {
	bool awoken;
}
@property (nonatomic, weak) IBOutlet NSTabView *masterTabView;
@property (nonatomic, weak) IBOutlet BeatPieGraph *graphView;
@property (nonatomic) NSDictionary<NSString*, BeatCharacter*> *characters;
@property (nonatomic) NSTimer *reloadTimer;
@property (nonatomic) NSInteger mostLines;
@property (nonatomic) NSPopover *popover;
@property (nonatomic) BeatCharacterEditorPopoverManager *popoverManager;
@property (nonatomic) NSTextView *infoTextView;

@property (nonatomic) NSButton *radioUnspecified;
@property (nonatomic) NSButton *radioWoman;
@property (nonatomic) NSButton *radioMan;
@property (nonatomic) NSButton *radioOther;

@property (nonatomic) NSArray* characterNameList;

@end

@implementation BeatCharacterList

-(instancetype)initWithCoder:(NSCoder *)coder {
	self = [super initWithCoder:coder];
	self.dataSource = self;
	self.delegate = self;
	self.target = self;
	
	[self setDoubleAction:@selector(showCharacterInfo:)];
		
	return self;
}

-(void)awakeFromNib {
	[super awakeFromNib];
	if (awoken) return;
	
	[self.editorDelegate registerEditorView:self];
	awoken = true;
}

#pragma mark - Drawing

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
}

-(void)viewWillDraw {
	// Reload (in sync) on draw
	if (!_characters) [self reloadView];
}

-(bool)visible {
	return (_masterTabView.selectedTabViewItem.view == self.enclosingScrollView.superview);
}


#pragma mark - Character editor callbacks

- (void)editorDidCloseFor:(BeatCharacter*)character
{
	// Deselect if this view is no longer active
	if (self.window.firstResponder != self) [self deselectAll:nil];
}



#pragma mark - Table data source

-(NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {

	// When asked for number of rows, we'll create the list of names
	_characterNameList = [self sortCharactersByLines];
	return _characterNameList.count;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
	NSString *key = _characterNameList[row];
	return _characters[key];
}

-(NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
	BeatCharacter *character = [tableView.dataSource tableView:tableView objectValueForTableColumn:tableColumn row:row];
	
	if (tableColumn == tableView.tableColumns[1]) {
		BeatLinesBarRowView *linesRow = [tableView makeViewWithIdentifier:@"LinesBarView" owner:nil];
		linesRow.character = character;
		linesRow.numberOfLines.stringValue = [NSString stringWithFormat:@"%lu", character.lines];
		linesRow.barWidth = (CGFloat)character.lines / (CGFloat)_mostLines;
		return linesRow;
	} else {
		NSTableCellView *row = [tableView makeViewWithIdentifier:@"CharacterName" owner:nil];

		BXColor* color = [BeatColors color:character.highlightColor];
		if (color != nil) row.textField.textColor = color;
		else row.textField.textColor = BXColor.labelColor;
		
		row.textField.stringValue = character.name;
		return row;
	}
}

-(BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row
{
	return YES;
}


#pragma mark - Conform to Beat view protocol

-(void)reloadView
{
	NSInteger selectedRow = self.selectedRow;
	NSMutableArray *genders = NSMutableArray.new;
	
	__block BeatCharacterData* characterData = [BeatCharacterData.alloc initWithDelegate:self.editorDelegate];
	
	// Process in a background thread
	// (This is pretty light, but still)
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND,0), ^{
		// Safeguards for some rare thread issues
		if (self.editorDelegate == nil) return;
		NSArray* lines = self.editorDelegate.parser.safeLines;
		self.characters = [characterData charactersAndLinesWithLines:(lines != nil) ? lines : @[]];
		
		// Get the most amount of lines and add missing genders
		for (BeatCharacter* character in self.characters.allValues) {
			if (character.lines > self.mostLines) self.mostLines = character.lines;
			
			NSString* gender = (character.gender.length > 0) ? character.gender : @"unspecified";
			for (NSInteger i=0; i<character.lines; i++) [genders addObject:gender];
		}
		
		// Reload data in main thread
		dispatch_async(dispatch_get_main_queue(), ^(void) {
			[self reloadData];
			[self.graphView pieChartForData:genders];
			
			if (selectedRow < self.numberOfRows) {
				NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:selectedRow];
				[self selectRowIndexes:indexSet byExtendingSelection:NO];
			}

			// Remove reference (just in case)
			characterData = nil;
		});
	});
}

-(void)reloadInBackground
{
	[_reloadTimer invalidate];
	_reloadTimer = [NSTimer scheduledTimerWithTimeInterval:.5 repeats:NO block:^(NSTimer * _Nonnull timer) {
		[self reloadView];
	}];
}


#pragma mark - Character data

- (NSArray*)sortCharactersByLines {
	NSArray *sortedKeys = [_characters keysSortedByValueUsingComparator:^NSComparisonResult(BeatCharacter* _Nonnull obj1, BeatCharacter* _Nonnull obj2) {
		// For equal number of lines, we'll sort character names alphabetically
		if (obj2.lines == obj1.lines) return [obj1.name compare:obj2.name];
		// Otherwise let's just compare amount of lines
		return (obj2.lines > obj1.lines);
	}];

	return sortedKeys;
}


- (IBAction)showCharacterInfo:(id)sender
{
	// Remove existing popover manager
	if (self.popoverManager) {
		[self.popoverManager.popover close];
		self.popoverManager = nil;
	}
	
	NSRect rowFrame = [self frameOfCellAtColumn:1 row:self.selectedRow];
	
	NSString* name = _characterNameList[self.selectedRow];
	
	// We'll have to fetch a new value for this character, because it might be out of sync
	BeatCharacterData* data = [BeatCharacterData.alloc initWithDelegate:self.editorDelegate];
	BeatCharacter* character = [data charactersAndLinesWithLines:self.editorDelegate.parser.lines][name];
	
	// If the character exists, show popover
	if (character != nil) {
		_popoverManager = [BeatCharacterEditorPopoverManager.alloc initWithEditorDelegate:self.editorDelegate listView:self character:character characterData:data];
		[_popoverManager.popover showRelativeToRect:rowFrame ofView:self preferredEdge:NSMaxXEdge];
	}
}


NSInteger previouslySelected = NSNotFound;
-(void)tableViewSelectionDidChange:(NSNotification *)notification
{
	// Hide popover when deselected
	if (previouslySelected == self.selectedRow)
		return;
	else if (self.selectedRow == -1)
		[self.popover close];
	else if (self.selectedRow != NSNotFound)
		[self showCharacterInfo:nil];
	
	previouslySelected = self.selectedRow;
}


@end
/*
 
 tänään aloitan laulamaan
 tänään soitellen sotaan
 soitellen sotaan
 jossa ketään ei tarvitse vahingoittaa
 
 jäähyväiset aseille joihin uskottiin
 jäähyväiset aseille joilla synnit sovitettiin
 jäähyväiset aseille joilla elämää suojellaan
 jäähyväiset aseille joilla elämä tuhotaan
 
 */
