//
//  ThemeEditor.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 17.1.2021.
//  Copyright © 2021 KAPITAN!. All rights reserved.
//

#import "ThemeEditor.h"
#import "ThemeManager.h"

@interface ThemeEditor ()
@property (nonatomic) ThemeManager *themeManager;

@property (nonatomic, weak) IBOutlet NSColorWell *backgroundLight;
@property (nonatomic, weak) IBOutlet NSColorWell *backgroundDark;
@property (nonatomic, weak) IBOutlet NSColorWell *textLight;
@property (nonatomic, weak) IBOutlet NSColorWell *textDark;
@property (nonatomic, weak) IBOutlet NSColorWell *marginLight;
@property (nonatomic, weak) IBOutlet NSColorWell *marginDark;
@property (nonatomic, weak) IBOutlet NSColorWell *selectionLight;
@property (nonatomic, weak) IBOutlet NSColorWell *selectionDark;
@property (nonatomic, weak) IBOutlet NSColorWell *invisibleTextLight;
@property (nonatomic, weak) IBOutlet NSColorWell *invisibleTextDark;
@property (nonatomic, weak) IBOutlet NSColorWell *commentLight;
@property (nonatomic, weak) IBOutlet NSColorWell *commentDark;
@property (nonatomic, weak) IBOutlet NSColorWell *caretLight;
@property (nonatomic, weak) IBOutlet NSColorWell *caretDark;
@property (nonatomic, weak) IBOutlet NSColorWell *synopsisLight;
@property (nonatomic, weak) IBOutlet NSColorWell *synopsisDark;
@property (nonatomic, weak) IBOutlet NSColorWell *sectionLight;
@property (nonatomic, weak) IBOutlet NSColorWell *sectionDark;
@property (nonatomic, weak) IBOutlet NSColorWell *outlineBackgroundLight;
@property (nonatomic, weak) IBOutlet NSColorWell *outlineBackgroundDark;
@property (nonatomic, weak) IBOutlet NSColorWell *outlineHighlightLight;
@property (nonatomic, weak) IBOutlet NSColorWell *outlineHighlightDark;
@end

@implementation ThemeEditor

- (instancetype)init {
	return [super initWithWindowNibName:@"ThemeEditor" owner:self];
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
	_themeManager = [ThemeManager sharedManager];
	[self loadDefaults];
}
- (IBAction)cancel:(id)sender {
	[self.window close];
}
- (IBAction)resetToDefault:(id)sender {
	[self loadDefaults];
}

- (void)loadDefaults {
	Theme *defaultTheme = self.themeManager.defaultTheme;
	[self loadTheme:defaultTheme];
}
- (void)loadTheme:(Theme*)theme {
	[_backgroundLight setColor:theme.backgroundColor.aquaColor];
	[_backgroundDark setColor:theme.backgroundColor.darkAquaColor];
	[_textLight setColor:theme.textColor.aquaColor];
	[_textDark setColor:theme.textColor.darkAquaColor];
	[_marginLight setColor:theme.marginColor.aquaColor];
	[_marginDark setColor:theme.marginColor.darkAquaColor];
	[_selectionLight setColor:theme.selectionColor.aquaColor];
	[_selectionDark setColor:theme.selectionColor.darkAquaColor];
	[_invisibleTextLight setColor:theme.invisibleTextColor.aquaColor];
	[_invisibleTextDark setColor:theme.invisibleTextColor.darkAquaColor];
	[_commentLight setColor:theme.commentColor.aquaColor];
	[_commentDark setColor:theme.commentColor.darkAquaColor];
	[_caretLight setColor:theme.caretColor.aquaColor];
	[_caretDark setColor:theme.caretColor.darkAquaColor];
	[_synopsisLight setColor:theme.synopsisTextColor.aquaColor];
	[_synopsisDark setColor:theme.synopsisTextColor.darkAquaColor];
	[_sectionLight setColor:theme.sectionTextColor.aquaColor];
	[_sectionDark setColor:theme.sectionTextColor.darkAquaColor];
	[_outlineBackgroundLight setColor:theme.outlineBackground.aquaColor];
	[_outlineBackgroundDark setColor:theme.outlineBackground.darkAquaColor];
	[_outlineHighlightLight setColor:theme.outlineHighlight.aquaColor];
	[_outlineHighlightDark setColor:theme.outlineHighlight.darkAquaColor];
}

@end
