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
