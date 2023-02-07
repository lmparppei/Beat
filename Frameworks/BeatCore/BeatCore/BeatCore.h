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

#import "BeatColors.h"

#import "BeatAttributes.h"

#import "BeatRevisionItem.h"
#import "BeatRevisions.h"

#import "BeatLocalization.h"

#import "BeatTagging.h"
#import "BeatTag.h"

#import "NSString+Levenshtein.h"

#import "BeatUserDefaults.h"
