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
#import "BeatCharacterList.h"
#import "BeatPieGraph.h"
#import "Beat-Swift.h"

@interface BeatLinesBarRowView : NSTableCellView
@property (nonatomic) CGFloat barWidth;
@property (nonatomic, weak) BeatCharacter *character;
@end

@implementation BeatLinesBarRowView

#define POPOVER_WIDTH 150

-(void)drawRect:(NSRect)dirtyRect {
	[super drawRect:dirtyRect];

	
	NSDictionary *colorForGender = @{
		@"woman": ThemeManager.sharedManager.genderWomanColor,
		@"man": ThemeManager.sharedManager.genderManColor,
		@"other": ThemeManager.sharedManager.genderOtherColor,
		@"unspecified": ThemeManager.sharedManager.genderUnspecifiedColor
	};

	NSColor *color = colorForGender[_character.gender];
	CGFloat alpha = _barWidth * 1.0;

	
	if (alpha > 1.0) alpha = 1.0;
	if (alpha < 0.2) alpha = .2;
	color = [color colorWithAlphaComponent:alpha];
	[color setFill];
	
	CGFloat width = (self.frame.size.width - self.textField.frame.size.width * 1.2)  * _barWidth;
	CGFloat height = self.frame.size.height * .6;
	if (width < 2.0) width = 2.0;
	
	// Paint a rounded rect
	NSRect rect = (NSRect){ 0, (self.frame.size.height - height) / 2, width, height };
	NSBezierPath *path = [[NSBezierPath alloc] init];
	[path appendBezierPathWithRoundedRect:rect xRadius:2 yRadius:2];
	[path fill];
	
	//NSRectFillUsingOperation(rect, NSCompositingOperationSourceOver);
}

@end

@interface BeatCharacterList () <NSPopoverDelegate, BeatCharacterListDelegate>
@property (nonatomic, weak) IBOutlet NSTabView *masterTabView;
@property (nonatomic, weak) IBOutlet BeatPieGraph *graphView;
@property (nonatomic) NSDictionary<NSString*, BeatCharacter*> *characterNames;
@property (nonatomic) NSTimer *reloadTimer;
@property (nonatomic) NSInteger mostLines;
@property (nonatomic) NSPopover *popover;
@property (nonatomic) BeatCharacterEditorPopoverManager *popoverManager;
@property (nonatomic) NSTextView *infoTextView;

@property (nonatomic) NSButton *radioUnspecified;
@property (nonatomic) NSButton *radioWoman;
@property (nonatomic) NSButton *radioMan;
@property (nonatomic) NSButton *radioOther;

@property (nonatomic) NSUInteger previouslySelected;

@end

@implementation BeatCharacterList

-(instancetype)initWithCoder:(NSCoder *)coder {
	self = [super initWithCoder:coder];
	self.dataSource = self;
	self.delegate = self;
	self.target = self;
	self.action = @selector(didClick:);
	self.previouslySelected = -1;
	
	[self setDoubleAction:@selector(showCharacterInfo:)];
		
	return self;
}

-(void)awakeFromNib {
	[self.editorDelegate registerEditorView:self];
}

#pragma mark - Drawing

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    // Drawing code here.
}

-(void)viewWillDraw {
	// Reload (in sync) on draw
	if (!_characterNames) [self reloadView];
}

-(bool)visible {
	if (_masterTabView.selectedTabViewItem.view == self.enclosingScrollView.superview) {
		return YES;
	} else {
		return NO;
	}
}

#pragma mark - Table data source

-(NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {

	return _characterNames.count;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
	NSString *key = [self sortCharactersByLines][row];
	return _characterNames[key];
}

-(NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
	BeatCharacter *character = [tableView.dataSource tableView:tableView objectValueForTableColumn:tableColumn row:row];
	
	if (tableColumn == tableView.tableColumns[1]) {
		BeatLinesBarRowView *linesRow = [tableView makeViewWithIdentifier:@"LinesBarView" owner:nil];
		linesRow.character = character;
		linesRow.barWidth = (CGFloat)character.lines / (CGFloat)_mostLines;
		linesRow.textField.stringValue = [NSString stringWithFormat:@"%lu", character.lines];
		return linesRow;
	} else {
		NSTableCellView *row = [tableView makeViewWithIdentifier:@"CharacterName" owner:nil];
		row.textField.stringValue = character.name;
		return row;
	}
}

-(void)didClick:(id)sender
{
	if (self.clickedRow == _previouslySelected) {
		//[_popover close];
		[self deselectAll:nil];
		_previouslySelected = -1;
	} else {
		_previouslySelected = self.clickedRow;
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
	NSArray *lines = self.editorDelegate.parser.lines.copy;
	NSMutableDictionary *charactersAndLines = NSMutableDictionary.dictionary;
	
	NSMutableArray *genders = NSMutableArray.new;
	
	// Proces in a background thread
	// (This is pretty light, but still
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND,0), ^{
		Line *scene;
		
		NSDictionary* characterGenders = self.characterGenders;
		if (characterGenders == nil) characterGenders = @{};
		
		for (Line* line in lines) { @autoreleasepool {
			// WIP: We need to get the actual OutlineScene here (update: why though?)
			if (line.type == heading) scene = line;
			
			if (line.type == character || line.type == dualDialogueCharacter) {
				NSString *name = line.characterName;
				if (name.length == 0) continue;
				
				BeatCharacter *character;
				
				if (charactersAndLines[name]) {
					character = charactersAndLines[name];
					character.lines += 1;
				} else {
					character = BeatCharacter.alloc.init;
					character.name = name.copy;
					character.lines = 1;
					character.scenes = NSMutableSet.new;
					charactersAndLines[name] = character;
				}
				
				NSString *gender = characterGenders[character.name];
				if (gender == nil) gender = @"unspecified";
				
				[genders addObject:gender];
				character.gender = gender.copy;
				
				if (scene) [character.scenes addObject:scene];
				if (character.lines > self.mostLines) self.mostLines = character.lines;
			}
		} }
		
		self.characterNames = charactersAndLines;
		
		// Reload data in main thread
		dispatch_async(dispatch_get_main_queue(), ^(void) {
			self.popoverManager.popover.animates = false;
			[self reloadData];
			[self.graphView pieChartForData:genders];
			
			if (selectedRow < self.numberOfRows) {
				NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:selectedRow];
				[self selectRowIndexes:indexSet byExtendingSelection:NO];
			}
			self.popoverManager.popover.animates = true;
		});
	});
}

-(void)reloadInBackground
{
	if (_reloadTimer.valid) [_reloadTimer invalidate];
	
	_reloadTimer = [NSTimer scheduledTimerWithTimeInterval:.5 repeats:NO block:^(NSTimer * _Nonnull timer) {
		[self reloadView];
	}];
}


#pragma mark - Data getters and setters

- (NSDictionary*)characterGenders
{
	NSDictionary* genders = [_editorDelegate.documentSettings get:DocSettingCharacterGenders];
	return (genders) ? genders : @{};
}

- (void)saveCharacterGenders:(NSDictionary*)genders
{
	if (genders == nil) genders = @{};
	[_editorDelegate.documentSettings set:DocSettingCharacterGenders as:genders];
}


#pragma mark - Character data

- (NSArray*)sortCharactersByLines {
	NSArray *sortedKeys = [_characterNames keysSortedByValueUsingComparator: ^(BeatCharacter* obj1, BeatCharacter* obj2) {
		 return (NSComparisonResult)[@(obj2.lines) compare:@(obj1.lines)];;
	}];
	return sortedKeys;
}


- (IBAction)showCharacterInfo:(id)sender
{
	if (self.popoverManager) {
		[self.popoverManager.popover close];
		self.popoverManager = nil;
	}
	
	NSRect rowFrame = [self frameOfCellAtColumn:1 row:self.selectedRow];
	
	BeatCharacter *character = _characterNames[[self sortCharactersByLines][self.selectedRow]];
	
	_popoverManager = [BeatCharacterEditorPopoverManager.alloc initWithDelegate:self character:character];
	[_popoverManager.popover showRelativeToRect:rowFrame ofView:self preferredEdge:NSMaxXEdge];
}


- (IBAction)selectGender:(id)sender
{
	NSString *gender;
	if (sender == _radioOther) gender = @"other";
	else if (sender == _radioWoman) gender = @"woman";
	else if (sender == _radioMan) gender = @"man";
	else gender = @"unspecified";
	
	BeatCharacter *character = _characterNames[[self sortCharactersByLines][self.selectedRow]];
	
	if (gender.length && character.name.length) {
		// Set gender
		NSMutableDictionary* genders = self.characterGenders.mutableCopy;
		genders[character.name] = gender;
		[self saveCharacterGenders:genders];
		
		[self reloadView];
	}
}

- (void)prevLineFor:(BeatCharacter*)chr
{
	NSArray *lines = self.editorDelegate.parser.lines;
	Line *currentLine = [_editorDelegate.parser lineAtPosition:_editorDelegate.selectedRange.location];
	if (!currentLine) return;
	
	NSInteger idx = [lines indexOfObject:currentLine];
	
	for (NSInteger i=idx-1; i>=0; i--) {
		Line *line = lines[i];
		if (line.type != character && line.type != dualDialogueCharacter) continue;
		
		if ([line.characterName isEqualToString:chr.name]) {
			[_editorDelegate scrollToLine:line];
			break;
		}
	}
}
- (void)nextLineFor:(BeatCharacter*)chr
{
	NSArray *lines = self.editorDelegate.parser.lines;
	Line *currentLine = [_editorDelegate.parser lineAtPosition:_editorDelegate.selectedRange.location];
	if (!currentLine) return;
	
	NSInteger idx = [lines indexOfObject:currentLine];

	for (NSInteger i=idx+1; i<lines.count; i++) {
		Line *line = lines[i];
		if (line.type != character && line.type != dualDialogueCharacter) continue;
		
		if ([line.characterName isEqualToString:chr.name]) {
			[_editorDelegate scrollToLine:line];
			break;
		}
	}
}

-(void)tableViewSelectionDidChange:(NSNotification *)notification
{
	// Hide popover when deselected
	if (self.selectedRow == -1) [self.popover close];
	else if (self.selectedRow != NSNotFound) {
		[self showCharacterInfo:nil];
	}
}

-(void)setGenderWithName:(NSString *)name gender:(NSString *)gender
{
	if (gender.length && name.length) {
		// Set gender
		NSMutableDictionary* genders = self.characterGenders.mutableCopy;
		genders[name] = gender;
		[self saveCharacterGenders:genders];
		
		[self reloadView];
	}
}

-(NSString *)getGenderForName:(NSString *)name
{
	if (name.length == 0) return nil;
	return self.characterGenders[name];
}



@end
/*
 
 tänään aloitan laulamaan
 tänään soitellen sotaan
 soitellen sotaan
 jossa ei tarvitse ketään vahingoittaa
 
 jäähyväiset aseille joihin uskottiin
 jäähyväiset aseille joilla synnit sovitettiin
 jäähyväiset aseille joilla elämää suojellaan
 jäähyväiset aseille joilla elämä tuhotaan
 
 */
