//
//  BeatDocumentDelegate.h
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 6.6.2023.
//

#import <BeatParsing/BeatParsing.h>

#ifndef BeatDocumentDelegate_h
#define BeatDocumentDelegate_h

@class ContinuousFountainParser;
@class Line;
@class OutlineScene;
@class BeatDocumentSettings;

@protocol BeatDocumentDelegate <NSObject>

#pragma mark - Parser

/// Fountain parser associated with the document
@property (readonly) ContinuousFountainParser* _Nonnull parser;
@property (nonatomic, readonly) BeatDocumentSettings* _Nonnull documentSettings;

- (NSString* _Nonnull)text;


#pragma mark - Export options

@property (nonatomic) BeatPaperSize pageSize;
@property (nonatomic, readonly) BeatExportSettings* _Nonnull exportSettings;


#pragma mark - Style getters

@property (nonatomic, readonly) bool headingStyleBold;
@property (nonatomic, readonly) bool headingStyleUnderline;


@end

#endif /* BeatDocumentDelegate_h */
