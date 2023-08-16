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

	[_outlineSceneNumberLight setColor:theme.outlineSceneNumber.aquaColor];
	[_outlineSceneNumberDark setColor:theme.outlineSceneNumber.darkAquaColor];
	
	[_outlineItemLight setColor:theme.outlineItem.aquaColor];
	[_outlineItemDark setColor:theme.outlineItem.darkAquaColor];
	
	[_outlineItemOmittedLight setColor:theme.outlineItemOmitted.aquaColor];
	[_outlineItemOmittedDark setColor:theme.outlineItemOmitted.darkAquaColor];
	
	[_outlineSectionLight setColor:theme.outlineSection.aquaColor];
	[_outlineSectionDark setColor:theme.outlineSection.darkAquaColor];
	
	[_outlineSynopsisLight setColor:theme.outlineSynopsis.aquaColor];
	[_outlineSynopsisDark setColor:theme.outlineSynopsis.darkAquaColor];
		
	[_genderWoman setColor:theme.genderWomanColor.aquaColor];
	[_genderMan setColor:theme.genderManColor.aquaColor];
	[_genderOther setColor:theme.genderOtherColor.aquaColor];
	[_genderUnspecified setColor:theme.genderUnspecifiedColor.aquaColor];
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
		themeColor.darkAquaColor = color;
		themeColor.aquaColor = color;
	}
	else if (colorWell.darkColor) {
		themeColor.darkAquaColor = color;
	} else {
		themeColor.aquaColor = color;
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
