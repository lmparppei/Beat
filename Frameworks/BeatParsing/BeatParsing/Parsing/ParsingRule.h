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
    PreviousIsEmpty             = 1 << 1,
    //PreviousIsEffectivelyEmpty  = 1 << 2,
    PreviousIsNotEmpty          = 1 << 3,
    NextIsEmpty                 = 1 << 4,
    AllCapsUntilParentheses     = 1 << 5,
    AllowsLeadingWhitespace     = 1 << 6,
    AllowsTrailingWhitespace    = 1 << 7,
    RequiresTwoEmptyLines       = 1 << 8,
    BelongsToTitlePage          = 1 << 9
};

@property (nonatomic, assign) LineType resultingType;
@property (nonatomic) ParsingOptions options;

@property (nonatomic, assign) BOOL allCapsUntilParentheses;
@property (nonatomic, assign) BOOL previousIsEmpty;
/// Effectively empty means that the previous line doesn't exist as a printed element. Mainly it's something like `/*` or `*/`.
// @property (nonatomic, assign) BOOL previousIsEffectivelyEmpty;
@property (nonatomic, assign) BOOL nextIsEmpty;
@property (nonatomic, assign) BOOL titlePage;

@property (nonatomic, strong) NSArray<NSString *>* _Nullable beginsWith;
@property (nonatomic, strong) NSArray<NSString *>* _Nullable endsWith;
@property (nonatomic, strong) NSArray<NSString *>* _Nullable requiredAfterPrefix;
@property (nonatomic, strong) NSArray<NSString *>* _Nullable excludedAfterPrefix;
@property (nonatomic, strong) NSArray<NSString *>* _Nullable exactMatches;
@property (nonatomic, assign) BOOL forcedType;
@property (nonatomic, assign) NSInteger length;
@property (nonatomic, assign) NSInteger allowedWhiteSpace;
@property (nonatomic, assign) bool allowsLeadingWhitespace;
@property (nonatomic, strong) NSIndexSet* _Nullable previousTypes;

@property (nonatomic, assign) NSInteger minimumLength;
@property (nonatomic, assign) NSInteger minimumLengthAtInput;

@property (nonatomic, assign) unichar allowedSymbol;

+ (instancetype _Nonnull)type:(LineType)resultingType
             options:(ParsingOptions)options
       previousTypes:(NSArray<NSNumber *>* _Nullable)previousTypes;

+ (instancetype _Nonnull)type:(LineType)resultingType
             options:(ParsingOptions)options
       minimumLength:(NSInteger)minimumLength
       previousTypes:(NSArray<NSNumber *>* _Nullable)previousTypes;

+ (instancetype _Nonnull)type:(LineType)resultingType
              length:(NSInteger)length
   allowedWhiteSpace:(NSInteger)allowedWhiteSpace;

+ (instancetype _Nonnull)type:(LineType)resultingType
        exactMatches:(NSArray<NSString*>* _Nullable)exactMatches;

+ (instancetype _Nonnull)type:(LineType)resultingType
        exactMatches:(NSArray<NSString*>* _Nullable)exactMatches
   allowedWhitespace:(NSInteger)allowedWhitespace;

+ (instancetype _Nonnull)type:(LineType)resultingType
             options:(ParsingOptions)options
       minimumLength:(NSInteger)minimumLength
minimumLengthAtInput:(NSInteger)minimumLengthAtInput
       previousTypes:(NSArray<NSNumber*>* _Nullable)previousTypes;

+ (instancetype _Nonnull)type:(LineType)resultingType
             options:(ParsingOptions)options
       previousTypes:(NSArray<NSNumber*>* _Nullable)previousTypes
          beginsWith:(NSArray<NSString*>* _Nullable)beginsWith
            endsWith:(NSArray<NSString*>* _Nullable)endsWith
 requiredAfterPrefix:(NSArray<NSString*>* _Nullable)requiredAfterPrefix
 excludedAfterPrefix:(NSArray<NSString*>* _Nullable)excludedAfterPrefix;

+ (instancetype _Nonnull)type:(LineType)resultingType
             options:(ParsingOptions)options
       previousTypes:(NSArray<NSNumber*>* _Nullable)previousTypes
          beginsWith:(NSArray<NSString*>* _Nullable)beginsWith
            endsWith:(NSArray<NSString*>* _Nullable)endsWith;

+ (instancetype _Nonnull)type:(LineType)resultingType
             options:(ParsingOptions)options
       minimumLength:(NSInteger)minimumLength
minimumLengthAtInput:(NSInteger)minimumLengthAtInput
       allowedSymbol:(unichar)allowedSymbol;

+ (instancetype _Nonnull)type:(LineType)resultingType
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
