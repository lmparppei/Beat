//
//  Line+Type.h
//  BeatParsing
//
//  Created by Lauri-Matti Parppei on 29.12.2024.
//

#import <BeatParsing/BeatParsing.h>
#import <JavaScriptCore/JavaScriptCore.h>

@protocol LineTypeExports <JSExport>
- (NSString*)typeAsString;
- (NSString*)typeName;
@end

@interface Line (Type) <LineTypeExports>

/// Returns a dictionary of all available types.
+ (NSDictionary*)typeDictionary;

/// Returns the type name for given string. Type names are basically `LineType`s in a string form, with no spaces. Use `typeAsString` to get a human-readable type string.
+ (NSString*)typeName:(LineType)type;

/// Returns type based on type _name_ (not `typeAsString` value)
+ (LineType)typeFromName:(NSString *)name;

/// Returns the line type in a human-readable form.
- (NSString*)typeAsString;

/// Returns the type name for this line. It's basically `LineType` as string, useful for variables, CSS styles etc. To get a human-readable version, use `typeAsString`.
- (NSString*)typeName;

@end

