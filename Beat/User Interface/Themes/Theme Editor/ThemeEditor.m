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
@property (nonatomic, weak) IBOutlet NSColorWell *pageNumberLight;
@property (nonatomic, weak) IBOutlet NSColorWell *pageNumberDark;
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

+ (instancetype)sharedEditor {
	static ThemeEditor* sharedEditor;
	if (!sharedEditor) {
		sharedEditor = [[ThemeEditor alloc] init];
	}
	return sharedEditor;
}

- (instancetype)init {
	return [super initWithWindowNibName:@"ThemeEditor" owner:self];
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
	_themeManager = [ThemeManager sharedManager];
	[self loadTheme:_themeManager.theme];
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
	[self.themeManager resetToDefault];
	[self.themeManager loadThemeForAllDocuments];
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
	[_pageNumberLight setColor:theme.pageNumberColor.aquaColor];
	[_pageNumberDark setColor:theme.pageNumberColor.darkAquaColor];
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
	
	//[self.themeManager resetToDefault];
	//[self.themeManager loadThemeForAllDocuments];
}

-(IBAction)changeColor:(NSColorWell*)sender {
	Theme *theme = _themeManager.theme;
	if (sender == _backgroundLight) theme.backgroundColor.aquaColor = sender.color;
	if (sender == _backgroundDark) theme.backgroundColor.darkAquaColor = sender.color;
	if (sender == _textLight) theme.textColor.aquaColor = sender.color;
	if (sender == _textDark) theme.textColor.darkAquaColor = sender.color;
	if (sender == _marginLight) theme.marginColor.aquaColor = sender.color;
	if (sender == _marginDark) theme.marginColor.darkAquaColor = sender.color;
	if (sender == _selectionLight) theme.selectionColor.aquaColor = sender.color;
	if (sender == _selectionDark) theme.selectionColor.darkAquaColor = sender.color;
	if (sender == _invisibleTextLight) theme.invisibleTextColor.aquaColor = sender.color;
	if (sender == _invisibleTextDark) theme.invisibleTextColor.darkAquaColor = sender.color;
	if (sender == _commentLight) theme.commentColor.aquaColor = sender.color;
	if (sender == _commentDark) theme.commentColor.darkAquaColor = sender.color;
	if (sender == _caretLight) theme.caretColor.aquaColor = sender.color;
	if (sender == _caretDark) theme.caretColor.darkAquaColor = sender.color;
	if (sender == _pageNumberLight) theme.pageNumberColor.aquaColor = sender.color;
	if (sender == _pageNumberDark) theme.pageNumberColor.darkAquaColor = sender.color;
	if (sender == _synopsisLight) theme.synopsisTextColor.aquaColor = sender.color;
	if (sender == _synopsisDark) theme.synopsisTextColor.darkAquaColor = sender.color;
	if (sender == _sectionLight) theme.sectionTextColor.aquaColor = sender.color;
	if (sender == _sectionDark) theme.sectionTextColor.darkAquaColor = sender.color;
	
	if (sender == _outlineHighlightLight) theme.outlineHighlight.aquaColor = sender.color;
	if (sender == _outlineHighlightDark) theme.outlineHighlight.darkAquaColor = sender.color;
	if (sender == _outlineBackgroundLight) theme.outlineBackground.aquaColor = sender.color;
	if (sender == _outlineBackgroundDark) theme.outlineBackground.darkAquaColor = sender.color;
	
	[self.themeManager loadThemeForAllDocuments];
}

- (IBAction)apply:(id)sender {
	[_themeManager saveTheme];
	[self.window close];
}

@end
