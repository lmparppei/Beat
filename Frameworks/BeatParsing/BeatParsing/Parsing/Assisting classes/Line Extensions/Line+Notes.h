//
//  Line+Notes.h
//  BeatParsing
//
//  Created by Lauri-Matti Parppei on 30.12.2024.
//

#import <BeatParsing/BeatParsing.h>
#import <JavaScriptCore/JavaScriptCore.h>

@protocol LineNoteExports <JSExport>
/// List of all notes (as note data objects) in this line
@property (nonatomic, readonly) NSArray<BeatNoteData*>* notes;
/// `true` if the line has no other content than a note
@property (readonly) bool note;

/// Returns a dictionary with the *actual range* (including brackets) as the key
- (NSMutableDictionary<NSNumber*, NSString*>*)noteContentsAndRanges;
/// Returns note content strings as an array
- (NSArray*)noteContents;
- (NSArray*)noteData;
/// Returns the **last** available range adn note with given prefix  (`[range, content]`)
- (NSArray*)contentAndRangeForLastNoteWithPrefix:(NSString*)string;
@end

@interface Line (Notes)

/// The line is filled by a note and has no other content
- (bool)isNote;
/// @warning DEPRECATED. Same as `isNote`.
- (bool)note;

/// Returns a dictionary with the *actual range* (including brackets) as the key
- (NSMutableDictionary<NSValue*, NSString*>*)noteContentsAndRanges;

/// Returns note content strings as an array
- (NSArray*)noteContents;

/// Returns `true` if the note is able to succesfully terminate a multi-line note block (contains `]]`)
- (bool)canTerminateNoteBlock;
/// Returns `true` if the note is able to succesfully terminate a multi-line note block (contains `]]`), and can also return the index of closing element
- (bool)canTerminateNoteBlockWithActualIndex:(NSInteger*)position;
/// Returns `true` if the line can begin a note block, and can also return the index of the possible opening element
- (bool)canBeginNoteBlockWithActualIndex:(NSInteger*)index;
/// Returns `true` if the line can begin a note block
- (bool)canBeginNoteBlock;

/// Returns an array (`[content, range]`) for the last note with given prefix.
- (NSArray*)contentAndRangeForLastNoteWithPrefix:(NSString*)string;

/// Returns JSON representations of all `BeatNoteData` objects on this line
- (NSArray<NSDictionary*>*)notesAsJSON;

@end

