//
//  BeatCore.h
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 2.2.2023.
//

/*
 
 This is a framework for shared core editor stuff between macOS and iOS versions.
 
 */

#import <Foundation/Foundation.h>

//! Project version number for BeatCore.
FOUNDATION_EXPORT double BeatCoreVersionNumber;

//! Project version string for BeatCore.
FOUNDATION_EXPORT const unsigned char BeatCoreVersionString[];

#define FORWARD_TO( CLASS, TYPE, METHOD ) \
- (TYPE)METHOD { [CLASS METHOD]; }

#import <BeatCore/BeatColors.h>
#import <BeatCore/BeatAttributes.h>
#import <BeatCore/BeatRevisionItem.h>
#import <BeatCore/BeatRevisions.h>
#import <BeatCore/BeatLocalization.h>
#import <BeatCore/BeatTagging.h>
#import <BeatCore/BeatTag.h>
#import <BeatCore/BeatTagItem.h>
#import <BeatCore/NSString+Levenshtein.h>
#import <BeatCore/BeatUserDefaults.h>
#import <BeatCore/BeatLayoutManager.h>
#import <BeatCore/BeatTextIO.h>
//#import <BeatCore/BeatFonts.h>
#import <BeatCore/BeatFontSet.h>
#import <BeatCore/BeatTranslation.h>
#import <BeatCore/BeatAutocomplete.h>
#import <BeatCore/BeatEditorFormattingActions.h>
#import <BeatCore/BeatMeasure.h>
#import <BeatCore/BeatDocument.h>
#import <BeatCore/NSArray+JSON.h>
#import <BeatCore/NSString+VersionNumber.h>
#import <BeatCore/BeatCompatibility.h>
#import <BeatCore/BeatEditorFormatting.h>
#import <BeatCore/OutlineViewItem.h>
#import <BeatCore/OutlineItemProvider.h>

#import <BeatCore/BeatDocumentBaseController.h>
#import <BeatCore/BeatDocumentBaseController+RegisteredViewsAndObservers.h>

#import <BeatCore/BeatNotificationDelegate.h>
#import <BeatCore/NSTextView+UX.h>
#import <BeatCore/BeatNotepad.h>

#import <BeatCore/DiffMatchPatch.h>
#import <BeatCore/NSString+Compression.h>

#import <BeatCore/BeatVersionControl.h>

