//
//  BeatPreview.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 17.5.2020.
//  Copyright © 2020 Lauri-Matti Parppei. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "OutlineScene.h"
#import "BeatDocumentSettings.h"
#import "BeatEditorDelegate.h"

typedef NS_ENUM(NSUInteger, BeatPreviewType) {
	BeatPrintPreview = 0,
	BeatQuickLookPreview,
	BeatComparisonPreview
};

@protocol BeatPreviewDelegate
@property (atomic) BeatDocumentSettings *documentSettings;
@property (nonatomic) bool printSceneNumbers;
@property (nonatomic, readonly, weak) OutlineScene *currentScene;
@property (readonly) NSAttributedString *attrTextCache;
- (NSString*)text;

@end

@interface BeatPreview : NSObject
@property (nonatomic, weak) id<BeatPreviewDelegate, BeatEditorDelegate> delegate;
- (id) initWithDocument:(id)document;
- (NSString*) createPreview;
- (NSString*) createPreviewFor:(NSString*)rawScript type:(BeatPreviewType)previewType;
@end
