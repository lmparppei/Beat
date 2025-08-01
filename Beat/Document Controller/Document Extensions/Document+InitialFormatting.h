//
//  Document+InitialFormatting.h
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 30.7.2025.
//  Copyright © 2025 Lauri-Matti Parppei. All rights reserved.
//

#import "Document.h"

NS_ASSUME_NONNULL_BEGIN

@interface Document (InitialFormatting)

/// Render the newly opened document for editing
-(void)renderDocument;

/**
 Applies the initial formatting while document is loading. We'll create a temporary formatting object and attributed string to handle rendering off screen, and the text storage contents are put into text view after formatting is complete. This cuts the formatting time for longer documents to half.
 */
-(void)applyInitialFormatting;

/// Asynchronous formatting. Takes in an index and formats a bunch of parsed lines starting from that index, applying the formatting attributes to given attributed string. This avoids beach ball when opening a large document.
- (void)formatAllWithDelayFrom:(NSInteger)idx formattedString:(NSMutableAttributedString*)formattedString;


@end

NS_ASSUME_NONNULL_END
