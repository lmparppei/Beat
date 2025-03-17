//
//  BeatDocumentBaseController+VersionControl.m
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 20.2.2025.
//

#import "BeatDocumentBaseController+VersionControl.h"
#import "NSString+Compression.h"
#import <BeatCore/DiffMatchPatch.h>
#import <BeatCore/BeatVersionControl.h>

#define BeatVersionControlKey @"VersionControl"

@implementation BeatDocumentBaseController (VersionControl)

- (IBAction)beginVersionControl:(id)sender
{
    BeatVersionControl* vc = [BeatVersionControl.alloc initWithDelegate:(id<BeatEditorDelegate>)self];
    [vc createInitialCommit];
}

- (IBAction)addCommit:(id)sender
{
    BeatVersionControl* vc = [BeatVersionControl.alloc initWithDelegate:(id<BeatEditorDelegate>)self];
    [vc addCommit];
}

@end
