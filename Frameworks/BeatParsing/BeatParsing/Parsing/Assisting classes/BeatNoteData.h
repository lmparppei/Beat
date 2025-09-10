//
//  BeatNoteData.h
//  BeatParsing
//
//  Created by Lauri-Matti Parppei on 1.4.2023.
//

#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, NoteType) {
    NoteTypeNormal = 0,
    NoteTypeMarker,
    NoteTypeBeat,
    NoteTypeColor,
    NoteTypePageNumber
};

@class Line;

@protocol BeatNoteDataExports<JSExport>
@property (nonatomic, readonly) NSString* content;
@property (nonatomic, readonly) NSString* color;
@property (nonatomic, readonly) NSRange range;
@property (nonatomic, readonly) bool multiline;
@property (nonatomic, readonly) NoteType type;
/// Returns a JSON representation of the note
- (NSDictionary*)json;
@end

@interface BeatNoteData : NSObject<BeatNoteDataExports>
@property (nonatomic, readonly) NoteType type;
@property (nonatomic, readonly) NSString* content;
@property (nonatomic) NSString* color;
@property (nonatomic, readonly) NSRange range;
@property (nonatomic) NSRange globalRange;
@property (nonatomic) bool multiline;
@property (nonatomic, weak) Line* line;
+ (BeatNoteData*)withNote:(NSString*)text range:(NSRange)range;
@end

NS_ASSUME_NONNULL_END
