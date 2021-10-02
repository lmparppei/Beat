//
//  BeatPreferencesPanel.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 12.9.2021.
//  Copyright © 2021 KAPITAN!. All rights reserved.
//

#import "BeatPreferencesPanel.h"
#import "ValidationItem.h"

@interface BeatPreferencesPanel ()
@property (nonatomic) NSArray* validationItems;

@property (nonatomic, weak) IBOutlet NSButton *hideFountainMarkup;
@property (nonatomic, weak) IBOutlet NSButton *showSceneNumbers;

@end

@implementation BeatPreferencesPanel

#define MATCH_PARENTHESES_KEY @"Match Parentheses"
#define SHOW_PAGENUMBERS_KEY @"Show Page Numbers"
#define SHOW_SCENE_LABELS_KEY @"Show Scene Number Labels"
#define AUTOMATIC_LINEBREAKS_KEY @"Automatic Line Breaks"
#define TYPERWITER_KEY @"Typewriter Mode"
#define FONT_STYLE_KEY @"Sans Serif"
#define HIDE_FOUNTAIN_MARKUP_KEY @"Hide Fountain Markup"
#define BOLDED_HEADINGS @"Bolded Headings"
#define UNDERLINED_HEADINGS @"Underlined Headings"

- (instancetype) init {
	return [super initWithWindowNibName:self.className owner:self];
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
	_validationItems = @[
		[ValidationItem newItem:@"hideFountainMarkup" setting:HIDE_FOUNTAIN_MARKUP_KEY target:NSUserDefaults.standardUserDefaults],
		[ValidationItem newItem:@"showSceneNumbers" setting:SHOW_SCENE_LABELS_KEY target:NSUserDefaults.standardUserDefaults],
		
		[ValidationItem newItem:@"boldedHeadings" setting:BOLDED_HEADINGS target:NSUserDefaults.standardUserDefaults]
	];
	
	for (ValidationItem *item in _validationItems) {
		[self setCheckBox:item.title value:[item validate]];
	}
}

- (void)setCheckBox:(NSString*)name value:(bool)value {
	NSButton *button = [self valueForKey:name];
	
	if (value) button.state = NSOnState;
	else button.state = NSOffState;
}

@end
