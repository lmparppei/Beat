//
//  BeatEditorFormattingActions.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 9.6.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <BeatParsing/BeatParsing.h>
#import <TargetConditionals.h>

#if TARGET_OS_IOS
#define BXResponder UIResponder
#else
#define BXResponder NSResponder
#endif

@protocol BeatEditorDelegate;

typedef NS_ENUM(NSUInteger, BeatFormatting) {
	Block = 0,
	Bold,
	Italic,
	Underline,
	Note,
    Centered
};

@interface BeatEditorFormattingActions : BXResponder
@property (nonatomic, weak) IBOutlet id<BeatEditorDelegate> delegate;
- (instancetype)initWithDelegate:(id<BeatEditorDelegate>)delegate;
- (void)forceElement:(LineType)lineType;

- (void)addCue;

- (IBAction)addTitlePage:(id)sender;
- (IBAction)lockSceneNumbers:(id)sender;
- (IBAction)unlockSceneNumbers:(id)sender;

- (IBAction)makeBold:(id)sender;
- (IBAction)makeItalic:(id)sender;
- (IBAction)makeUnderlined:(id)sender;
- (IBAction)makeNote:(id)sender;
- (IBAction)makeOmitted:(id)sender;
- (IBAction)omitScene:(id)sender;
- (IBAction)makeSceneNonNumbered:(id)sender;
- (IBAction)makeCentered:(id)sender;

- (IBAction)forceHeading:(id)sender;
- (IBAction)forceAction:(id)sender;
- (IBAction)forceCharacter:(id)sender;
- (IBAction)forceTransition:(id)sender;
- (IBAction)forceLyrics:(id)sender;

@end

