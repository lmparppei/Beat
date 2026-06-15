//
//  Line+Versions.h
//  BeatParsing
//
//  Created by Lauri-Matti Parppei on 28.5.2026.
//

#import <BeatParsing/BeatParsing.h>

NS_ASSUME_NONNULL_BEGIN

@protocol LineVersionDelegate <NSObject>
- (void)lineDidSwitchVersion:(Line*)line;
@end

@interface Line (Versions)

/// Returns the metadata for an alternative version of this line
/// - warning: This method **DOES NOT** replace anything, but instead returns the text and possible revisions of the line. You will need to handle the actual replacement yourself in editor.
- (NSDictionary*)stepVersion:(NSInteger)amount;

/// Switches to given version. Returns the metadata for an alternative version of this line
/// - warning: This method **DOES NOT** replace anything, but instead returns the text and possible revisions of the line. You will need to handle the actual replacement yourself in editor.
- (NSDictionary*)switchVersion:(NSInteger)index;

/// Stores the current version of this line
/// - note: You need to have baked the revisions in the text for this to work correctly (... Why? Fucking past me, please provide SOME FUCKING EXPLANATIONS OF STUFF YOU ARE DOING NOW AND THEN. I hate you for numerous other reasons as well. Self-forgiveness and mercy is hard, denial even harder, but we need to try. I'm not feeling good about myself right now, and this fucking mess isn't helping me.)
/// Anyway, here's the explanation: The parser is completely detached from the attributed text, so the line object doesn't know whether there are some attributes in its current string range. That's why only baked revisions are stored into the line version data.
- (void)storeVersion;

/// Reads possible line alternatives in the line `**ALTERNATIVES: ... *` and cleans that text up as well. This is kind of unnecessarily complex, but helps us keep compatibility with other Fountain editors, in semi-readable format.
- (void)readAlternativesAndCleanString;

/// Returns line versions ready to be serialized to JSON.
- (NSArray<NSDictionary*>*)versionsForSerialization;

/// Adds a new version of this text.
/// - note: You need to have baked the revisions in the text for this to work correctly
- (void)addVersion;

@end

NS_ASSUME_NONNULL_END
