//
//  BeatDocument.h
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 20.2.2023.
//

#import <Foundation/Foundation.h>
#import <BeatParsing/BeatParsing.h>

@class BeatRevisions;


@protocol BeatDocumentViewDelegate
//- (NSAttributedString* _Nullable)attributedString;
@end


NS_ASSUME_NONNULL_BEGIN

@interface BeatDocument : NSObject

@property (nonatomic) NSURL* _Nullable url;
@property (nonatomic) BeatDocumentSettings* _Nullable settings;
@property (nonatomic) ContinuousFountainParser* parser;

- (instancetype)initWithURL:(NSURL*)url;


@end

NS_ASSUME_NONNULL_END
