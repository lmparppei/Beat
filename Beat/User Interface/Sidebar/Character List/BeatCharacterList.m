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

@interface BeatCharacter : NSObject
@property (nonatomic) NSString *name;
@property (nonatomic) NSString *gender;
@property (nonatomic) NSInteger lines;
@property (nonatomic) NSMutableSet * scenes;
@end
@implementation BeatCharacter
@end

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

@interface BeatCharacterList ()
@property (nonatomic, weak) IBOutlet NSTabView *masterTabView;
@property (nonatomic, weak) IBOutlet BeatPieGraph *graphView;
@property (nonatomic) NSDictionary<NSString*, BeatCharacter*> *characterNames;
@property (nonatomic) NSTimer *reloadTimer;
@property (nonatomic) NSInteger mostLines;
@property (nonatomic) NSPopover *popover;
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

-(void)reloadView {
	NSInteger selectedRow = self.selectedRow;
	NSArray *lines = self.editorDelegate.parser.lines.copy;
	NSMutableDictionary *charactersAndLines = NSMutableDictionary.dictionary;
	
	NSMutableArray *genders = NSMutableArray.new;
	
	// Proces in a background thread
	// (This is pretty light, but still
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND,0), ^{
		Line *scene;
		
		for (Line* line in lines) { @autoreleasepool {
			// WIP: We need to get the actual OutlineScene here
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
				
				NSString *gender;
				if (self.editorDelegate.characterGenders[character.name]) gender = self.editorDelegate.characterGenders[character.name];
				else gender = @"unspecified";
				
				[genders addObject:gender];
				character.gender = gender.copy;
				
				if (scene) [character.scenes addObject:scene];
				if (character.lines > self.mostLines) self.mostLines = character.lines;
			}
		} }
		
		self.characterNames = charactersAndLines;
		
		// Reload data in main thread
		dispatch_async(dispatch_get_main_queue(), ^(void) {
			[self reloadData];
			[self.graphView pieChartForData:genders];
			
			if (selectedRow < self.numberOfRows) {
				NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:selectedRow];
				[self selectRowIndexes:indexSet byExtendingSelection:NO];
			}
		});
	});
}

-(void)reloadInBackground {
	if (_reloadTimer.valid) [_reloadTimer invalidate];
	
	_reloadTimer = [NSTimer scheduledTimerWithTimeInterval:.5 repeats:NO block:^(NSTimer * _Nonnull timer) {
		[self reloadView];
	}];
}

- (NSArray*)sortCharactersByLines {
	NSArray *sortedKeys = [_characterNames keysSortedByValueUsingComparator: ^(BeatCharacter* obj1, BeatCharacter* obj2) {
		 return (NSComparisonResult)[@(obj2.lines) compare:@(obj1.lines)];;
	}];
	return sortedKeys;
}

-(void)didClick:(id)sender {
	if (self.clickedRow == _previouslySelected) {
		[_popover close];
		[self deselectAll:nil];
		_previouslySelected = -1;
	} else {
		_previouslySelected = self.clickedRow;
	}
}

-(BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row {
	return YES;
}

- (IBAction)showCharacterInfo:(id)sender {
	if (!self.popover) {
		// Load popover into memory only when used for the first time
		[self setupCharacterPopup];
	}
	
	NSRect rowFrame = [self frameOfCellAtColumn:1 row:self.selectedRow];
	
	BeatCharacter *character = _characterNames[[self sortCharactersByLines][self.selectedRow]];
	NSString *infoString = [NSString stringWithFormat:@"%@\n%@: %lu\n%@: %lu",
							character.name,
							NSLocalizedString(@"statistics.lines", nil),
							character.lines,
							NSLocalizedString(@"statistics.scenes", nil),
							character.scenes.count];
	_infoTextView.string = infoString;
	
	NSString *gender = character.gender.lowercaseString;
	
	if (gender) {
		if ([gender isEqualToString:@"woman"] || [gender isEqualToString:@"female"]) _radioWoman.state = NSOnState;
		else if ([gender isEqualToString:@"man"] || [gender isEqualToString:@"male"]) _radioMan.state = NSOnState;
		else if ([gender isEqualToString:@"other"]) _radioOther.state = NSOnState;
		else _radioUnspecified.state = NSOnState;
	} else {
		_radioOther.state = NSOnState;
	}
		
	[self.popover showRelativeToRect:rowFrame ofView:self preferredEdge:NSMaxXEdge];
}

- (void)setupCharacterPopup {
	self.popover = [[NSPopover alloc] init];
	if (@available(macOS 10.14, *)) self.popover.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];

	NSView *contentView = [[NSView alloc] initWithFrame:NSZeroRect];
	NSViewController *contentViewController = [[NSViewController alloc] init];
	[contentViewController setView:contentView];
	
	NSRect frame = NSMakeRect(0, 0, 200, 150);
	[self.popover setContentSize:NSMakeSize(NSWidth(frame), NSHeight(frame))];
	
	_infoTextView = [NSTextView.alloc initWithFrame:frame];
	[_infoTextView setEditable:NO];
	[_infoTextView setDrawsBackground:NO];
	[_infoTextView setRichText:NO];
	[_infoTextView setUsesRuler:NO];
	[_infoTextView setSelectable:NO];
	[_infoTextView setTextContainerInset:NSMakeSize(8, 8)];
	_infoTextView.font = [NSFont systemFontOfSize:NSFont.systemFontSize];
	
	NSView *infoContentView = [NSView.alloc initWithFrame:NSZeroRect];
	[infoContentView addSubview:_infoTextView];
	NSViewController *infoViewController = [[NSViewController alloc] init];
	[infoViewController setView:infoContentView];
	
	self.popover.contentViewController = infoViewController;
	
	NSButton *buttonUp = [NSButton buttonWithTitle:@"▲" target:self action:@selector(prevLine)];
	NSButton *buttonDown = [NSButton buttonWithTitle:@"▼" target:self action:@selector(nextLine)];
	
	NSRect upFrame = buttonUp.frame;
	NSRect downFrame = buttonDown.frame;
	
	buttonUp.bezelStyle = NSBezelStyleCircular;
	buttonUp.bordered = NO;
	buttonDown.bezelStyle = NSBezelStyleCircular;
	buttonDown.bordered = NO;
	
	upFrame.origin.x = _popover.contentSize.width - upFrame.size.width;
	upFrame.origin.y = _popover.contentSize.height - upFrame.size.height;
	buttonUp.frame = upFrame;
	
	downFrame.origin.x = downFrame.origin.x = _popover.contentSize.width - downFrame.size.width;
	downFrame.origin.y = 0;
	buttonDown.frame = downFrame;
	
	[self.popover.contentViewController.view addSubview:buttonUp];
	[self.popover.contentViewController.view addSubview:buttonDown];

	NSView *genderStack = [[NSView alloc] initWithFrame:(NSRect){0, 4, 150, 80}];
	
	NSArray *radioButtons = [self buttonsForGenders];
	for (NSButton *btn in radioButtons) {
		[genderStack addSubview:btn];
	}
	
	[self.popover.contentViewController.view addSubview:genderStack];
}

- (NSArray<NSButton*>*)buttonsForGenders {
	NSArray *genders = @[NSLocalizedString(@"gender.unspecified", nil), NSLocalizedString(@"gender.woman", nil), NSLocalizedString(@"gender.man", nil), NSLocalizedString(@"gender.other", nil)];
	NSMutableArray *buttons = [NSMutableArray array];
	
	CGFloat y = genders.count * 35;
	NSInteger i = 0;
	
	for (NSString *gender in genders) {
		NSButton *button = [[NSButton alloc] initWithFrame:(NSRect){ 8, 0, 150, y - i * 35 }];
		[button setButtonType:NSRadioButton];
		button.title = gender;
		[buttons addObject:button];
		
		//button.target = self;
		button.action = @selector(selectGender:);
		
		if ([gender isEqualToString:NSLocalizedString(@"gender.unspecified", nil)]) _radioUnspecified = button;
		else if ([gender isEqualToString:NSLocalizedString(@"gender.woman", nil)]) _radioWoman = button;
		else if ([gender isEqualToString:NSLocalizedString(@"gender.man", nil)]) _radioMan = button;
		else _radioOther = button;
		
		i++;
	}
	
	return buttons;
}
- (IBAction)selectGender:(id)sender {
	NSString *gender;
	if (sender == _radioOther) gender = @"other";
	else if (sender == _radioWoman) gender = @"woman";
	else if (sender == _radioMan) gender = @"man";
	else gender = @"unspecified";
	
	BeatCharacter *character = _characterNames[[self sortCharactersByLines][self.selectedRow]];
	
	if (gender.length && character.name.length) {
		// Set gender
		NSMutableDictionary* genders = _editorDelegate.characterGenders.mutableCopy;
		genders[character.name] = gender;
		_editorDelegate.characterGenders = genders;
		
		[self reloadView];
	}
}

- (void)prevLine {
	NSArray *lines = self.editorDelegate.parser.lines;
	Line *currentLine = [_editorDelegate.parser lineAtPosition:_editorDelegate.selectedRange.location];
	if (!currentLine) return;
	
	BeatCharacter *chr = _characterNames[[self sortCharactersByLines][self.selectedRow]];
	
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
- (void)nextLine {
	NSArray *lines = self.editorDelegate.parser.lines;
	Line *currentLine = [_editorDelegate.parser lineAtPosition:_editorDelegate.selectedRange.location];
	if (!currentLine) return;
	
	BeatCharacter *chr = _characterNames[[self sortCharactersByLines][self.selectedRow]];

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

-(BOOL)resignFirstResponder {
	[self.popover close];
	return YES;
}

-(void)tableViewSelectionDidChange:(NSNotification *)notification {
	// Hide popover when deselected
	if (self.selectedRow == -1) [self.popover close];
	else if (self.selectedRow != NSNotFound) {
		[self showCharacterInfo:nil];
	}
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
