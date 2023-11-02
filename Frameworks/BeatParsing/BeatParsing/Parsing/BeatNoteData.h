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
    NoteTypeColor
};

@protocol BeatNoteDataExports<JSExport>
@property (nonatomic, readonly) NSString* content;
@property (nonatomic, readonly) NSString* color;
@property (nonatomic, readonly) NSRange range;
@property (nonatomic, readonly) bool multiline;
/// Returns a JSON representation of the note
- (NSDictionary*)json;
@end

@interface BeatNoteData : NSObject<BeatNoteDataExports>
@property (nonatomic, readonly) NSString* content;
@property (nonatomic) NSString* color;
@property (nonatomic, readonly) NSRange range;
@property (nonatomic, readonly) NoteType type;
@property (nonatomic) bool multiline;
+ (BeatNoteData*)withNote:(NSString*)text range:(NSRange)range;
@end

NS_ASSUME_NONNULL_END
