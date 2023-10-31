//
//  BeatHTMLRenderer.h
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 21.4.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//

#import <Foundation/Foundation.h>
@class BeatPagination;
@class BeatScreenplay;
@class BeatPaginationPage;
@class BeatExportSettings;
@class Line;

@interface BeatHTMLRenderer : NSObject

@property (strong, nonatomic) BeatScreenplay *screenplay;
@property (strong, nonatomic) NSMutableArray *titlePage;
@property (strong, nonatomic) NSNumber *customPage;
@property (strong, nonatomic) NSNumber *forRendering;
@property (copy, nonatomic) NSString *bodyText;
@property (nonatomic) BeatPagination *pagination;
@property (nonatomic) NSArray* renderedPages;
@property (nonatomic) NSArray<BeatPaginationPage*>* pages;

- (instancetype)initWithPagination:(BeatPagination*)pagination settings:(BeatExportSettings*)settings;
- (instancetype)initWithLines:(NSArray<Line*>*)lines settings:(BeatExportSettings*)settings;


//- (NSInteger)pages;
- (NSString *)html;
- (NSString *)htmlBody;
- (NSString *)content; // Returns only the ARTICLE part
- (NSString *)htmlHeader;
- (NSString *)htmlFooter;

@end

