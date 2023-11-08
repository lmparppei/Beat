//
//  ThemeEditor.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 17.1.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import <BeatThemes/BeatThemes.h>
#import <Cocoa/Cocoa.h>
#import "ThemeEditor.h"
#import "Beat-Swift.h"

@interface ThemeEditor ()
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

@property (nonatomic, weak) IBOutlet NSColorWell *outlineSectionLight;
@property (nonatomic, weak) IBOutlet NSColorWell *outlineSectionDark;

@property (nonatomic, weak) IBOutlet NSColorWell *outlineSceneNumberLight;
@property (nonatomic, weak) IBOutlet NSColorWell *outlineSceneNumberDark;

@property (nonatomic, weak) IBOutlet NSColorWell *outlineItemLight;
@property (nonatomic, weak) IBOutlet NSColorWell *outlineItemDark;

@property (nonatomic, weak) IBOutlet NSColorWell *outlineItemOmittedLight;
@property (nonatomic, weak) IBOutlet NSColorWell *outlineItemOmittedDark;

@property (nonatomic, weak) IBOutlet NSColorWell *outlineSynopsisLight;
@property (nonatomic, weak) IBOutlet NSColorWell *outlineSynopsisDark;

@property (nonatomic, weak) IBOutlet NSColorWell *genderWoman;
@property (nonatomic, weak) IBOutlet NSColorWell *genderMan;
@property (nonatomic, weak) IBOutlet NSColorWell *genderOther;
@property (nonatomic, weak) IBOutlet NSColorWell *genderUnspecified;

@property (nonatomic) NSTimer* updateTimer;

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
	
	
	
	[self loadTheme:ThemeManager.sharedManager.theme];
	
}

- (IBAction)cancel:(id)sender {
	[ThemeManager.sharedManager revertToSaved];
	[NSNotificationCenter.defaultCenter postNotification:[NSNotification notificationWithName:@"Reset theme" object:nil]];
	
	[self.window close];
}

- (IBAction)resetToDefault:(id)sender {
	[self loadDefaults];
}

- (void)loadDefaults {
	[ThemeManager.sharedManager resetToDefault];
	[ThemeManager.sharedManager loadThemeForAllDocuments];
	
	[NSNotificationCenter.defaultCenter postNotification:[NSNotification notificationWithName:@"Reset theme" object:nil]];
}
- (void)loadTheme:(BeatTheme*)theme {
	[_backgroundLight setColor:theme.backgroundColor.lightColor];
	[_backgroundDark setColor:theme.backgroundColor.darkColor];
	[_textLight setColor:theme.textColor.lightColor];
	[_textDark setColor:theme.textColor.darkColor];
	[_marginLight setColor:theme.marginColor.lightColor];
	[_marginDark setColor:theme.marginColor.darkColor];
	[_selectionLight setColor:theme.selectionColor.lightColor];
	[_selectionDark setColor:theme.selectionColor.darkColor];
	[_invisibleTextLight setColor:theme.invisibleTextColor.lightColor];
	[_invisibleTextDark setColor:theme.invisibleTextColor.darkColor];
	[_commentLight setColor:theme.commentColor.lightColor];
	[_commentDark setColor:theme.commentColor.darkColor];
	[_pageNumberLight setColor:theme.pageNumberColor.lightColor];
	[_pageNumberDark setColor:theme.pageNumberColor.darkColor];
	[_caretLight setColor:theme.caretColor.lightColor];
	[_caretDark setColor:theme.caretColor.darkColor];
	[_synopsisLight setColor:theme.synopsisTextColor.lightColor];
	[_synopsisDark setColor:theme.synopsisTextColor.darkColor];
	[_sectionLight setColor:theme.sectionTextColor.lightColor];
	[_sectionDark setColor:theme.sectionTextColor.darkColor];
	
	[_outlineBackgroundLight setColor:theme.outlineBackground.lightColor];
	[_outlineBackgroundDark setColor:theme.outlineBackground.darkColor];
	[_outlineHighlightLight setColor:theme.outlineHighlight.lightColor];
	[_outlineHighlightDark setColor:theme.outlineHighlight.darkColor];

	[_outlineSceneNumberLight setColor:theme.outlineSceneNumber.lightColor];
	[_outlineSceneNumberDark setColor:theme.outlineSceneNumber.darkColor];
	
	[_outlineItemLight setColor:theme.outlineItem.lightColor];
	[_outlineItemDark setColor:theme.outlineItem.darkColor];
	
	[_outlineItemOmittedLight setColor:theme.outlineItemOmitted.lightColor];
	[_outlineItemOmittedDark setColor:theme.outlineItemOmitted.darkColor];
	
	[_outlineSectionLight setColor:theme.outlineSection.lightColor];
	[_outlineSectionDark setColor:theme.outlineSection.darkColor];
	
	[_outlineSynopsisLight setColor:theme.outlineSynopsis.lightColor];
	[_outlineSynopsisDark setColor:theme.outlineSynopsis.darkColor];
		
	[_genderWoman setColor:theme.genderWomanColor.lightColor];
	[_genderMan setColor:theme.genderManColor.lightColor];
	[_genderOther setColor:theme.genderOtherColor.lightColor];
	[_genderUnspecified setColor:theme.genderUnspecifiedColor.lightColor];
}

-(IBAction)changeColor:(id)sender {
	if (![sender isKindOfClass:BeatThemeColorWell.class]) return;
	
	BeatThemeColorWell* colorWell = sender;
	NSColor* color = [colorWell.color colorUsingColorSpaceName:NSCalibratedRGBColorSpace device:nil];

	NSString* key = colorWell.themeKey;
	if (key.length == 0) return;
	
	BeatTheme* theme = ThemeManager.sharedManager.theme;
	DynamicColor* themeColor = [theme valueForKey:key];
	
	if (colorWell.commonColor) {
		// Set color for both styles
		themeColor.darkColor = color;
		themeColor.lightColor = color;
	}
	else if (colorWell.darkColor) {
		themeColor.darkColor = color;
	} else {
		themeColor.lightColor = color;
	}
	
	// Update changes after 0.5 seconds
	[self scheduleUpdate];
}

- (void)scheduleUpdate {
	[self.updateTimer invalidate];
	self.updateTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 repeats:false block:^(NSTimer * _Nonnull timer) {
		[ThemeManager.sharedManager loadThemeForAllDocuments];
	}];
}


- (IBAction)apply:(id)sender {
	[ThemeManager.sharedManager saveTheme];
	[self.window close];
}

@end
/*
 
 in the night
 I took outside
 with a steaming cup of tea
 feeling happy but restless
 
 haven't written a poem in a long time
 last year fewer than ever
 i made promises
 couldn't keep
 and time---
 let's not think about time right now
 
 the snow covers the house
 snow covers my car
 snow covers the road away from here
 and until thursday i'm confined here
 but everything is fine
 i have food
 i have wood
 i'll wake up at 9.00--
 let's not think about time, but
 then the sun is rising
 make some coffee
 looking outside, straight into the brightness
 of the fresh snow
 
 the wind is howling
 it's harded and harder to enjoy things, i think
 making songs is hard
 making love feels numb
 can't remember my home anymore
 is life different when I get back
 not sure when---
 let's not think about time now

 i had a lover
 their grandfather chopped so much wood
 that when he'd die, his wife wouldn't
 need to worry about firewood ever again
 he died, because it happens
 and the grandmother had to move into a home
 but the firewood was still there
 enough for the future generations
 to spend their summers in the house
 
 i was once there too
 fucking their grandchild from behind in the night
 in their old, creaky bed
 and later that person
 abused me
 assaulted me
 mishandled me
 and almost destroyed me
 well
 let's think about time now
 i've lived longer than i anticipated
 i've lived a better life i could have imagined
 i'll think about time now
 it stretches in front of me
 crashes over me
 i'll let it take me
 towards new sorrows
 new joys
 new waters
 new ages
 new hopes. 
 
 */
