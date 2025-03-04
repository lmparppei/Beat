//
//  ParsingRule.h
//  BeatParsing
//
//  Created by Lauri-Matti Parppei on 22.12.2024.
//

#import <Foundation/Foundation.h>
#import <BeatParsing/Line.h>

@interface ParsingRule : NSObject

@property (nonatomic, assign) LineType resultingType;
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
@property (nonatomic, strong) NSIndexSet *previousTypes;

@property (nonatomic, assign) NSInteger minimumLength;
@property (nonatomic, assign) NSInteger minimumLengthAtInput;

+ (instancetype)ruleWithResultingType:(LineType)resultingType
                        minimumLength:(NSInteger)minimumLength
                 minimumLengthAtInput:(NSInteger)minimumLengthAtInput
                      previousIsEmpty:(BOOL)previousIsEmpty
                        previousTypes:(NSArray<NSNumber*>*)previousTypes
              allCapsUntilParentheses:(BOOL)allCapsUntilParentheses
                         exactMatches:(NSArray<NSString*>*)exactMatches
                           beginsWith:(NSArray<NSString*>*)beginsWith
                             endsWith:(NSArray<NSString*>*)endsWith
                  requiredAfterPrefix:(NSArray<NSString*>*)requiredAfterPrefix
                  excludedAfterPrefix:(NSArray<NSString*>*)excludedAfterPrefix
                               length:(NSInteger)length
                    allowedWhiteSpace:(NSInteger)allowedWhiteSpace
                            titlePage:(BOOL)titlePage;

+ (instancetype)ruleWithResultingType:(LineType)resultingType
                         exactMatches:(NSArray<NSString*>*)exactMatches;

+ (instancetype)ruleWithResultingType:(LineType)resultingType
                               length:(NSInteger)length
                    allowedWhiteSpace:(NSInteger)allowedWhiteSpace;

+ (instancetype)ruleWithResultingType:(LineType)resultingType
                      previousIsEmpty:(BOOL)previousIsEmpty
                        previousTypes:(NSArray<NSNumber *> *)previousTypes
              allCapsUntilParentheses:(BOOL)allCapsUntilParentheses;

+ (instancetype)ruleWithResultingType:(LineType)resultingType
                        minimumLength:(NSInteger)minimumLength
                 minimumLengthAtInput:(NSInteger)minimumLengthAtInput
                      previousIsEmpty:(BOOL)previousIsEmpty
                        previousTypes:(NSArray<NSNumber *> *)previousTypes
              allCapsUntilParentheses:(BOOL)allCapsUntilParentheses;

+ (instancetype)ruleWithResultingType:(LineType)resultingType
                      previousIsEmpty:(BOOL)previousIsEmpty
                         previousTypes:(NSArray<NSNumber *> *)previousTypes
                allCapsUntilParentheses:(BOOL)allCapsUntilParentheses
                            beginsWith:(NSArray<NSString *> *)beginsWith
                              endsWith:(NSArray<NSString *> *)endsWith
                   requiredAfterPrefix:(NSArray<NSString *> *)requiredAfterPrefix
                  excludedAfterPrefix:(NSArray<NSString *> *)excludedAfterPrefix;

+ (instancetype)ruleWithResultingType:(LineType)resultingType
                      previousIsEmpty:(BOOL)previousIsEmpty
                         previousTypes:(NSArray<NSNumber *> *)previousTypes
                allCapsUntilParentheses:(BOOL)allCapsUntilParentheses
                            beginsWith:(NSArray<NSString *> *)beginsWith
                             endsWith:(NSArray<NSString *> *)endsWith;

- (BOOL)validate:(Line*)line previousLine:(Line*)previousLine;

@end
