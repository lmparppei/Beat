//
//  FountainReport.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 28/09/2019.
//  Copyright © 2019 Lauri-Matti Parppei. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <BeatCore/BeatEditorDelegate.h>

@class BeatEditorDelegate;

@interface FountainAnalysis : NSObject
@property (weak) id<BeatEditorDelegate> delegate;
- (instancetype)initWithDelegate:(id<BeatEditorDelegate>)delegate;
- (NSString*) getJSON;
- (NSMutableArray*) scenesWithCharacter:(NSString*)character onlyDialogue:(bool)onlyDialogue;
@end
