//
//  WriterParserPerformance.m
//  Writer
//
//  Created by Hendrik Noeller on 03.04.16.
//  Copyright © 2016 Hendrik Noeller. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "ContinousFountainParser.h"
#import "FastFountainParser.h"
#import "FountainParser.h"

@interface WriterParserPerformance : XCTestCase

@end

@implementation WriterParserPerformance

- (void)testOwnPerformance {
    NSString* bigFish = [self bigFish];
    [self measureBlock:^{
        (void) [[ContinousFountainParser alloc] initWithString:bigFish];
    }];
}

- (void)testFountainFastPerformance {
    NSString* bigFish = [self bigFish];
    [self measureBlock:^{
        (void) [[FastFountainParser alloc] initWithString:bigFish];
    }];
}


- (void)testFountainPerformance {
    NSString* bigFish = [self bigFish];
    [self measureBlock:^{
        [FountainParser parseTitlePageOfString:bigFish];
        [FountainParser parseBodyOfString:bigFish];
    }];
}

- (void)testRemovePerformance {
    NSString* bigFish = [self bigFish];
    ContinousFountainParser *parser = [[ContinousFountainParser alloc] initWithString:bigFish];
    [self measureBlock:^{
        [parser parseChangeInRange:NSMakeRange(3545, 2) withString:@""];
        [parser parseChangeInRange:NSMakeRange(10, 2) withString:@""];
        [parser parseChangeInRange:NSMakeRange(3340, 2) withString:@""];
        [parser parseChangeInRange:NSMakeRange(330, 2) withString:@""];
        [parser parseChangeInRange:NSMakeRange(3230, 2) withString:@""];
        [parser parseChangeInRange:NSMakeRange(340, 2) withString:@""];
        [parser parseChangeInRange:NSMakeRange(3650, 2) withString:@""];
        [parser parseChangeInRange:NSMakeRange(3000, 2) withString:@""];
        [parser parseChangeInRange:NSMakeRange(300, 2) withString:@""];
        [parser parseChangeInRange:NSMakeRange(30, 2) withString:@""];
    }];
}

- (void)testInsertPerformance {
    NSString* bigFish = [self bigFish];
    ContinousFountainParser *parser = [[ContinousFountainParser alloc] initWithString:bigFish];
    [self measureBlock:^{
        [parser parseChangeInRange:NSMakeRange(30, 0) withString:@"baadsfasd/* sdfsdf _under_ **BOLD** */\nCHARACTER /*"];
    }];
}

- (NSString*)bigFish
{
    NSString* path = [[NSBundle mainBundle] pathForResource:@"Big-Fish"
                                                     ofType:@"fountain"];
    return [NSString stringWithContentsOfFile:path
                                     encoding:NSUTF8StringEncoding
                                        error:nil];
}

NSString* shortScript = @""
@"Title: Script\n"
@"Author: Florian Maier\n"
@"Credit: Thomas Maier\n"
@"source: somewhere\n"
@"DrAft Date: 42.23.23\n"
@"Contact: florian@maier.de\n"
@"\n"
@"INT. DAY - LIVING ROOM\n"
@"EXT. DAY - LIVING ROOM\n"
@"Pet@r sits somewhäre and doeß sométhing\n"
@"\n"
@"PETER\n"
@"I Like sitting here\n"
@"it makes me happy\n"
@"\n"
@"CHRIS ^\n"
@"i'm also a person!\n"
@"\n"
@"HARRAY\n"
@"(slightly irritated)\n"
@"Why do i have parentheses?\n"
@"They are weird!\n"
@"\n"
@"CHIRS ^\n"
@"(looking at harray)\n"
@"Why am i over here?\n"
@"  \n"
@"And I have holes in my text!\n"
@"\n"
@"He indeed looks very happy\n"
@"fade to:\n"
@".thisisaheading\n"
@"!THISISACTION\n"
@"~lyrics and stuff in this line\n"
@">transition\n"
@"      \n"
@"title: this is not the title page!\n"
@">center!<\n"
@"===\n"
@"======\n"
@"This is on a new page\n";

@end
