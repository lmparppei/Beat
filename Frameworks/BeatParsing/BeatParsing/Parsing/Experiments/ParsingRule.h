//
//  ParsingRule.h
//  BeatParsing
//
//  Created by Lauri-Matti Parppei on 22.12.2024.
//

#import <Foundation/Foundation.h>
#import <BeatParsing/Line.h>

@protocol ContinuousFountainParserDelegate;

@interface ParsingRule : NSObject

typedef NS_OPTIONS(NSUInteger, ParsingOptions) {
    PreviousIsEmpty          = 1 << 1,
    PreviousIsNotEmpty       = 1 << 2,
    NextIsEmpty              = 1 << 3,
    AllCapsUntilParentheses  = 1 << 4,
    AllowsLeadingWhitespace  = 1 << 5,
    AllowsTrailingWhitespace = 1 << 6,
    RequiresTwoEmptyLines    = 1 << 7,
    BelongsToTitlePage       = 1 << 8
};

@property (nonatomic, assign) LineType resultingType;
@property (nonatomic) ParsingOptions options;

@property (nonatomic, assign) BOOL allCapsUntilParentheses;
@property (nonatomic, assign) BOOL previousIsEmpty;
@property (nonatomic, assign) BOOL nextIsEmpty;
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

@property (nonatomic, assign) unichar allowedSymbol;

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
        exactMatches:(NSArray<NSString*>*)exactMatches
   allowedWhitespace:(NSInteger)allowedWhitespace;

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
       allowedSymbol:(unichar)allowedSymbol;

+ (instancetype)type:(LineType)resultingType
             options:(ParsingOptions)options
       minimumLength:(NSInteger)minimumLength
minimumLengthAtInput:(NSInteger)minimumLengthAtInput
       previousTypes:(NSArray<NSNumber*>* _Nullable)previousTypes
        exactMatches:(NSArray<NSString*>* _Nullable)exactMatches
          beginsWith:(NSArray<NSString*>* _Nullable)beginsWith
            endsWith:(NSArray<NSString*>* _Nullable)endsWith
 requiredAfterPrefix:(NSArray<NSString*>* _Nullable)requiredAfterPrefix
 excludedAfterPrefix:(NSArray<NSString*>* _Nullable)excludedAfterPrefix
              length:(NSInteger)length
   allowedWhiteSpace:(NSInteger)allowedWhiteSpace
   onlyAllowedSymbol:(unichar)allowedSymbol;

- (BOOL)validate:(Line* _Nonnull)line previousLine:(Line* _Nullable)previousLine nextLine:(Line* _Nullable)nextLine delegate:(id<ContinuousFountainParserDelegate> _Nullable)delegate;

@end
