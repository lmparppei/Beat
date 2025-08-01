//
//  BeatDocumentDelegate.h
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 6.6.2023.
//
/**
 
 Please move a ton of stuff from `BeatEditorDelegate` to here so we can have a lighter version of the delegate.
 
 */

#import <BeatParsing/BeatParsing.h>

#ifndef BeatDocumentDelegate_h
#define BeatDocumentDelegate_h

@class ContinuousFountainParser;
@class Line;
@class OutlineScene;
@class BeatDocumentSettings;

@protocol BeatDocumentDelegate <NSObject>

#pragma mark - Base document stuff

@property (nonatomic, readonly) NSURL* _Nullable fileURL;

/// Create a document file
- (NSString* _Nullable)createDocumentFileWithAdditionalSettings:(NSDictionary* _Nullable)additionalSettings excludingSettings:(NSArray<NSString*>* _Nullable)excludedKeys;


#pragma mark - Parser

/// Fountain parser associated with the document
@property (readonly) ContinuousFountainParser* _Nonnull parser;
@property (nonatomic, readonly) BeatDocumentSettings* _Nonnull documentSettings;

- (NSString* _Nonnull)text;
- (NSUUID* _Nonnull)uuid;

#pragma mark - Export options

@property (nonatomic) BeatPaperSize pageSize;
@property (nonatomic, readonly) BeatExportSettings* _Nonnull exportSettings;


@end

#endif /* BeatDocumentDelegate_h */
