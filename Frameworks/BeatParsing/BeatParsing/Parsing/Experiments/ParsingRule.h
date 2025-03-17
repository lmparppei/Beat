//
//  ParsingRule.h
//  BeatParsing
//
//  Created by Lauri-Matti Parppei on 22.12.2024.
//

#import <Foundation/Foundation.h>
#import <BeatParsing/Line.h>

@interface ParsingRule : NSObject

typedef NS_OPTIONS(NSUInteger, ParsingOptions) {
    PreviousIsEmpty          = 1 << 1,
    NextIsEmpty              = 1 << 2,
    AllCapsUntilParentheses  = 1 << 3,
    AllowsLeadingWhitespace  = 1 << 4,
    BelongsToTitlePage       = 1 << 5
};

@property (nonatomic, assign) LineType resultingType;
@property (nonatomic) ParsingOptions options;

@property (nonatomic, assign) BOOL allCapsUntilParentheses;
@property (nonatomic, assign) BOOL previousIsEmpty;
@property (nonatomic, assign) BOOL titlePage;
@property (nonatomic, strong) NSArray<NSString *> *beginsWith;
@property (nonatomic, strong) NSArray<NSString *> *endsWith;
@property (nonatomic, strong) NSArray<NSString *> *requiredAfterPrefix;
@property (nonatomic, strong) NSArray<NSString *> *excludedAfterPrefix;
@property (nonatomic, strong) NSArray<NSString *> *exactMatches;
@property (nonatomic, assign) BOOL forcedType;
@property (nonatomic, assign) NSInteger length;
@property (nonatomic, assign) NSInteger allowedWhiteSpace;
@property (nonatomic, assign) bool allowsLeadingWhitespace;
@property (nonatomic, strong) NSIndexSet *previousTypes;

@property (nonatomic, assign) NSInteger minimumLength;
@property (nonatomic, assign) NSInteger minimumLengthAtInput;

+ (instancetype)type:(LineType)resultingType
             options:(ParsingOptions)options
       previousTypes:(NSArray<NSNumber *> *)previousTypes;

+ (instancetype)type:(LineType)resultingType
             options:(ParsingOptions)options
       minimumLength:(NSInteger)minimumLength
       previousTypes:(NSArray<NSNumber *> *)previousTypes;

+ (instancetype)type:(LineType)resultingType
              length:(NSInteger)length
   allowedWhiteSpace:(NSInteger)allowedWhiteSpace;

+ (instancetype)type:(LineType)resultingType
        exactMatches:(NSArray<NSString*>*)exactMatches;

+ (instancetype)type:(LineType)resultingType
             options:(ParsingOptions)options
       minimumLength:(NSInteger)minimumLength
minimumLengthAtInput:(NSInteger)minimumLengthAtInput
       previousTypes:(NSArray<NSNumber *> *)previousTypes;

+ (instancetype)type:(LineType)resultingType
             options:(ParsingOptions)options
       previousTypes:(NSArray<NSNumber *> *)previousTypes
          beginsWith:(NSArray<NSString *> *)beginsWith
            endsWith:(NSArray<NSString *> *)endsWith
 requiredAfterPrefix:(NSArray<NSString *> *)requiredAfterPrefix
 excludedAfterPrefix:(NSArray<NSString *> *)excludedAfterPrefix;

+ (instancetype)type:(LineType)resultingType
             options:(ParsingOptions)options
       previousTypes:(NSArray<NSNumber *> *)previousTypes
          beginsWith:(NSArray<NSString *> *)beginsWith
            endsWith:(NSArray<NSString *> *)endsWith;

+ (instancetype)type:(LineType)resultingType
             options:(ParsingOptions)options
       minimumLength:(NSInteger)minimumLength
minimumLengthAtInput:(NSInteger)minimumLengthAtInput
       previousTypes:(NSArray<NSNumber*>*)previousTypes
        exactMatches:(NSArray<NSString*>*)exactMatches
          beginsWith:(NSArray<NSString*>*)beginsWith
            endsWith:(NSArray<NSString*>*)endsWith
 requiredAfterPrefix:(NSArray<NSString*>*)requiredAfterPrefix
 excludedAfterPrefix:(NSArray<NSString*>*)excludedAfterPrefix
              length:(NSInteger)length
   allowedWhiteSpace:(NSInteger)allowedWhiteSpace;

- (BOOL)validate:(Line*)line previousLine:(Line*)previousLine;

@end
