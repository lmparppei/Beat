//
//  WriterParserTests.m
//  WriterTests
//
//  Created by Hendrik Noeller on 05.10.14.
//  Copyright (c) 2016 Hendrik Noeller. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>

#import "ContinousFountainParser.h"

@interface WriterParserTests : XCTestCase

@end

@implementation WriterParserTests

- (void)testAccessors
{
    ContinousFountainParser *parser = [[ContinousFountainParser alloc] initWithString:miniScript];
    XCTAssertEqual([parser.lines count], 8);
    
    //Check string and position at line
    int i = 0;
    int count = 0;
    for (NSString* s in [miniScript componentsSeparatedByString:@"\n"]) {
        XCTAssertEqualObjects([parser stringAtLine:i], s);
        XCTAssertEqual([parser positionAtLine:i], count);
        i++;
        count += [s length] + 1; //+1 for the newline char that is omited in this representation
    }
    
    //Check description
    NSString* toString = [parser description];
    XCTAssertEqualObjects(toString, miniScriptExpectedToString);
    
    //Break test string at line, type at line and pos at line
    XCTAssertEqualObjects([parser stringAtLine:-1], @"");
    XCTAssertEqualObjects([parser stringAtLine:20], @"");
    XCTAssertEqual([parser typeAtLine:-1], NSNotFound);
    XCTAssertEqual([parser typeAtLine:20], NSNotFound);
    XCTAssertEqual([parser positionAtLine:-1], NSNotFound);
    XCTAssertEqual([parser positionAtLine:20], NSNotFound);
}

- (void)testInitialParse
{
    ContinousFountainParser *parser = [[ContinousFountainParser alloc] initWithString:script];
    
    NSUInteger i = 0; //User a counter and add "i++" after each line to prevent changing all numbers on every insertion
    XCTAssertEqual([parser typeAtLine:i], titlePageTitle);
    XCTAssertEqual([parser positionAtLine:i], 0); i++;
    XCTAssertEqual([parser typeAtLine:i], titlePageAuthor);
    XCTAssertEqual([parser positionAtLine:i], 14); i++;
    XCTAssertEqual([parser typeAtLine:i], titlePageCredit);
    XCTAssertEqual([parser positionAtLine:i], 36); i++;
    XCTAssertEqual([parser typeAtLine:i], titlePageSource); i++;
    XCTAssertEqual([parser typeAtLine:i], titlePageDraftDate); i++;
    XCTAssertEqual([parser typeAtLine:i], titlePageContact); i++;
    XCTAssertEqual([parser typeAtLine:i], titlePageContact); i++;
    XCTAssertEqual([parser typeAtLine:i], titlePageContact); i++;
    XCTAssertEqual([parser typeAtLine:i], titlePageUnknown); i++;
    XCTAssertEqual([parser typeAtLine:i], empty); i++;
    XCTAssertEqual([parser typeAtLine:i], heading); i++;
    XCTAssertEqualObjects([parser sceneNumberAtLine:i-1], @"1");
    XCTAssertEqual([parser typeAtLine:i], action); i++;
    XCTAssertEqual([parser typeAtLine:i], empty); i++;
    XCTAssertEqual([parser typeAtLine:i], heading); i++;
    XCTAssertNil([parser sceneNumberAtLine:i-1]);
    XCTAssertEqual([parser typeAtLine:i], action); i++;
    XCTAssertEqual([parser typeAtLine:i], empty); i++;
    XCTAssertEqual([parser typeAtLine:i], character); i++;
    XCTAssertEqual([parser typeAtLine:i], dialogue); i++;
    XCTAssertEqual([parser typeAtLine:i], dialogue); i++;
    XCTAssertEqual([parser typeAtLine:i], empty); i++;
    XCTAssertEqual([parser typeAtLine:i], doubleDialogueCharacter); i++;
    XCTAssertEqual([parser typeAtLine:i], doubleDialogue); i++;
    XCTAssertEqual([parser typeAtLine:i], empty); i++;
    XCTAssertEqual([parser typeAtLine:i], character); i++;
    XCTAssertEqual([parser typeAtLine:i], parenthetical); i++;
    XCTAssertEqual([parser typeAtLine:i], dialogue); i++;
    XCTAssertEqual([parser typeAtLine:i], dialogue); i++;
    XCTAssertEqual([parser typeAtLine:i], parenthetical); i++;
    XCTAssertEqual([parser typeAtLine:i], empty); i++;
    XCTAssertEqual([parser typeAtLine:i], doubleDialogueCharacter); i++;
    XCTAssertEqual([parser typeAtLine:i], doubleDialogueParenthetical); i++;
    XCTAssertEqual([parser typeAtLine:i], doubleDialogue); i++;
    XCTAssertEqual([parser typeAtLine:i], doubleDialogue); i++;
    XCTAssertEqual([parser typeAtLine:i], doubleDialogue); i++;
    XCTAssertEqual([parser typeAtLine:i], empty); i++;
    XCTAssertEqual([parser typeAtLine:i], action); i++;
    XCTAssertEqual([parser typeAtLine:i], action); i++;
    XCTAssertEqual([parser typeAtLine:i], transition); i++;
    XCTAssertEqual([parser typeAtLine:i], heading); i++;
    XCTAssertNil([parser sceneNumberAtLine:i-1]);
    XCTAssertEqual([parser typeAtLine:i], action); i++;
    XCTAssertEqual([parser typeAtLine:i], lyrics); i++;
    XCTAssertEqual([parser typeAtLine:i], transition); i++;
    XCTAssertEqual([parser typeAtLine:i], empty); i++;
    XCTAssertEqual([parser typeAtLine:i], action); i++;
    XCTAssertEqual([parser typeAtLine:i], centered); i++;
    XCTAssertEqual([parser typeAtLine:i], pageBreak); i++;
    XCTAssertEqual([parser typeAtLine:i], pageBreak); i++;
    XCTAssertEqual([parser typeAtLine:i], action); i++;
    XCTAssertEqual([parser typeAtLine:i], section); i++;
    XCTAssertEqual([parser typeAtLine:i], section); i++;
    XCTAssertEqual([parser typeAtLine:i], synopse); i++;
    XCTAssertEqual([parser typeAtLine:i], character); i++;
    XCTAssertEqual([parser typeAtLine:i], dialogue); i++;
    XCTAssertEqual([parser typeAtLine:i], empty); i++;
    XCTAssertEqual([parser typeAtLine:i], heading); i++;
    XCTAssertNil([parser sceneNumberAtLine:i-1]);
    XCTAssertEqual([parser typeAtLine:i], empty); i++;
    XCTAssertEqual([parser typeAtLine:i], heading); i++;
    XCTAssertNil([parser sceneNumberAtLine:i-1]);
    XCTAssertEqual([parser typeAtLine:i], empty); i++;
    XCTAssertEqual([parser typeAtLine:i], heading); i++;
    XCTAssertNil([parser sceneNumberAtLine:i-1]);
    XCTAssertEqual([parser typeAtLine:i], empty); i++;
    XCTAssertEqual([parser typeAtLine:i], heading); i++;
    XCTAssertNil([parser sceneNumberAtLine:i-1]);
}

- (void)testInsertions
{
    ContinousFountainParser *parser = [[ContinousFountainParser alloc] initWithString:@""];
    
    //Perform single insertions and deletions, including line breaks!
    [parser parseChangeInRange:NSMakeRange(0, 0) withString:@"INT. DAY - LIVING ROOM"];
    XCTAssertEqual([parser typeAtLine:0], heading);
    
    [parser parseChangeInRange:NSMakeRange(0, 0) withString:@"Title: Script\n\n"];
    XCTAssertEqual([parser typeAtLine:0], titlePageTitle);
    XCTAssertEqual([parser typeAtLine:1], empty);
    XCTAssertEqual([parser typeAtLine:2], heading);
    
    [parser parseChangeInRange:NSMakeRange(33, 0) withString:@"\n\n"];
    XCTAssertEqual([parser typeAtLine:0], titlePageTitle);
    XCTAssertEqual([parser typeAtLine:1], empty);
    XCTAssertEqual([parser typeAtLine:2], heading);
    XCTAssertEqual([parser typeAtLine:3], empty);
    XCTAssertEqual([parser typeAtLine:4], character);
    
    [parser parseChangeInRange:NSMakeRange(35, 4) withString:@"room\n"];
    XCTAssertEqual([parser typeAtLine:0], titlePageTitle);
    XCTAssertEqual([parser typeAtLine:1], empty);
    XCTAssertEqual([parser typeAtLine:2], heading);
    XCTAssertEqual([parser typeAtLine:3], empty);
    XCTAssertEqual([parser typeAtLine:4], action);
    
    [parser parseChangeInRange:NSMakeRange(40,0) withString:@"this will soon be dialogue"];
    XCTAssertEqual([parser typeAtLine:0], titlePageTitle);
    XCTAssertEqual([parser typeAtLine:1], empty);
    XCTAssertEqual([parser typeAtLine:2], heading);
    XCTAssertEqual([parser typeAtLine:3], empty);
    XCTAssertEqual([parser typeAtLine:4], action);
    XCTAssertEqual([parser typeAtLine:5], action);
    
    [parser parseChangeInRange:NSMakeRange(35, 4) withString:@"ROOM"];
    XCTAssertEqual([parser typeAtLine:0], titlePageTitle);
    XCTAssertEqual([parser typeAtLine:1], empty);
    XCTAssertEqual([parser typeAtLine:2], heading);
    XCTAssertEqual([parser typeAtLine:3], empty);
    XCTAssertEqual([parser typeAtLine:4], character);
    XCTAssertEqual([parser typeAtLine:5], dialogue);
    
    [parser parseChangeInRange:NSMakeRange(35, 5) withString:@""];
    XCTAssertEqual([parser typeAtLine:0], titlePageTitle);
    XCTAssertEqual([parser typeAtLine:1], empty);
    XCTAssertEqual([parser typeAtLine:2], heading);
    XCTAssertEqual([parser typeAtLine:3], empty);
    XCTAssertEqual([parser typeAtLine:4], action);
    
    [parser parseChangeInRange:NSMakeRange(61, 0) withString:@"\n"];
    XCTAssertEqual([parser typeAtLine:0], titlePageTitle);
    XCTAssertEqual([parser typeAtLine:1], empty);
    XCTAssertEqual([parser typeAtLine:2], heading);
    XCTAssertEqual([parser typeAtLine:3], empty);
    XCTAssertEqual([parser typeAtLine:4], action);
    XCTAssertEqual([parser typeAtLine:5], empty);
    
    [parser parseChangeInRange:NSMakeRange(62, 0) withString:@"I'm Phteven"];
    XCTAssertEqual([parser typeAtLine:0], titlePageTitle);
    XCTAssertEqual([parser typeAtLine:1], empty);
    XCTAssertEqual([parser typeAtLine:2], heading);
    XCTAssertEqual([parser typeAtLine:3], empty);
    XCTAssertEqual([parser typeAtLine:4], action);
    XCTAssertEqual([parser typeAtLine:5], action);
    
    [parser parseChangeInRange:NSMakeRange(62, 0) withString:@"(friendly)\n"];
    XCTAssertEqual([parser typeAtLine:0], titlePageTitle);
    XCTAssertEqual([parser typeAtLine:1], empty);
    XCTAssertEqual([parser typeAtLine:2], heading);
    XCTAssertEqual([parser typeAtLine:3], empty);
    XCTAssertEqual([parser typeAtLine:4], action);
    XCTAssertEqual([parser typeAtLine:5], action);
    XCTAssertEqual([parser typeAtLine:6], action);
    
    [parser parseChangeInRange:NSMakeRange(62, 0) withString:@"\nSTEVEN\n"];
    XCTAssertEqual([parser typeAtLine:0], titlePageTitle);
    XCTAssertEqual([parser typeAtLine:1], empty);
    XCTAssertEqual([parser typeAtLine:2], heading);
    XCTAssertEqual([parser typeAtLine:3], empty);
    XCTAssertEqual([parser typeAtLine:4], action);
    XCTAssertEqual([parser typeAtLine:5], empty);
    XCTAssertEqual([parser typeAtLine:6], character);
    XCTAssertEqual([parser typeAtLine:7], parenthetical);
    XCTAssertEqual([parser typeAtLine:8], dialogue);
    
    [parser parseChangeInRange:NSMakeRange(63, 6) withString:@"KAREN ^"];
    XCTAssertEqual([parser typeAtLine:0], titlePageTitle);
    XCTAssertEqual([parser typeAtLine:1], empty);
    XCTAssertEqual([parser typeAtLine:2], heading);
    XCTAssertEqual([parser typeAtLine:3], empty);
    XCTAssertEqual([parser typeAtLine:4], action);
    XCTAssertEqual([parser typeAtLine:5], empty);
    XCTAssertEqual([parser typeAtLine:6], doubleDialogueCharacter);
    XCTAssertEqual([parser typeAtLine:7], doubleDialogueParenthetical);
    XCTAssertEqual([parser typeAtLine:8], doubleDialogue);
    
    //Replace everything with a complete script
    Line* lastLine = [parser.lines lastObject];
    NSUInteger totalLength = lastLine.position + lastLine.string.length;
    [parser parseChangeInRange:NSMakeRange(0, totalLength) withString:script];
    NSUInteger i = 0; //User a counter and add "i++" after each line to prevent changing all numbers on every insertion
    XCTAssertEqual([parser typeAtLine:i], titlePageTitle);
    XCTAssertEqual([parser positionAtLine:i], 0); i++;
    XCTAssertEqual([parser typeAtLine:i], titlePageAuthor);
    XCTAssertEqual([parser positionAtLine:i], 14); i++;
    XCTAssertEqual([parser typeAtLine:i], titlePageCredit);
    XCTAssertEqual([parser positionAtLine:i], 36); i++;
    XCTAssertEqual([parser typeAtLine:i], titlePageSource); i++;
    XCTAssertEqual([parser typeAtLine:i], titlePageDraftDate); i++;
    XCTAssertEqual([parser typeAtLine:i], titlePageContact); i++;
    XCTAssertEqual([parser typeAtLine:i], titlePageContact); i++;
    XCTAssertEqual([parser typeAtLine:i], titlePageContact); i++;
    XCTAssertEqual([parser typeAtLine:i], titlePageUnknown); i++;
    XCTAssertEqual([parser typeAtLine:i], empty); i++;
    XCTAssertEqual([parser typeAtLine:i], heading); i++;
    XCTAssertEqualObjects([parser sceneNumberAtLine:i-1], @"1");
    XCTAssertEqual([parser typeAtLine:i], action); i++;
    XCTAssertEqual([parser typeAtLine:i], empty); i++;
    XCTAssertEqual([parser typeAtLine:i], heading); i++;
    XCTAssertNil([parser sceneNumberAtLine:i-1]);
    XCTAssertEqual([parser typeAtLine:i], action); i++;
    XCTAssertEqual([parser typeAtLine:i], empty); i++;
    XCTAssertEqual([parser typeAtLine:i], character); i++;
    XCTAssertEqual([parser typeAtLine:i], dialogue); i++;
    XCTAssertEqual([parser typeAtLine:i], dialogue); i++;
    XCTAssertEqual([parser typeAtLine:i], empty); i++;
    XCTAssertEqual([parser typeAtLine:i], doubleDialogueCharacter); i++;
    XCTAssertEqual([parser typeAtLine:i], doubleDialogue); i++;
    XCTAssertEqual([parser typeAtLine:i], empty); i++;
    XCTAssertEqual([parser typeAtLine:i], character); i++;
    XCTAssertEqual([parser typeAtLine:i], parenthetical); i++;
    XCTAssertEqual([parser typeAtLine:i], dialogue); i++;
    XCTAssertEqual([parser typeAtLine:i], dialogue); i++;
    XCTAssertEqual([parser typeAtLine:i], parenthetical); i++;
    XCTAssertEqual([parser typeAtLine:i], empty); i++;
    XCTAssertEqual([parser typeAtLine:i], doubleDialogueCharacter); i++;
    XCTAssertEqual([parser typeAtLine:i], doubleDialogueParenthetical); i++;
    XCTAssertEqual([parser typeAtLine:i], doubleDialogue); i++;
    XCTAssertEqual([parser typeAtLine:i], doubleDialogue); i++;
    XCTAssertEqual([parser typeAtLine:i], doubleDialogue); i++;
    XCTAssertEqual([parser typeAtLine:i], empty); i++;
    XCTAssertEqual([parser typeAtLine:i], action); i++;
    XCTAssertEqual([parser typeAtLine:i], action); i++;
    XCTAssertEqual([parser typeAtLine:i], transition); i++;
    XCTAssertEqual([parser typeAtLine:i], heading); i++;
    XCTAssertEqual([parser typeAtLine:i], action); i++;
    XCTAssertEqual([parser typeAtLine:i], lyrics); i++;
    XCTAssertEqual([parser typeAtLine:i], transition); i++;
    XCTAssertEqual([parser typeAtLine:i], empty); i++;
    XCTAssertEqual([parser typeAtLine:i], action); i++;
    XCTAssertEqual([parser typeAtLine:i], centered); i++;
    XCTAssertEqual([parser typeAtLine:i], pageBreak); i++;
    XCTAssertEqual([parser typeAtLine:i], pageBreak); i++;
    XCTAssertEqual([parser typeAtLine:i], action); i++;
    XCTAssertEqual([parser typeAtLine:i], section); i++;
    XCTAssertEqual([parser typeAtLine:i], section); i++;
    XCTAssertEqual([parser typeAtLine:i], synopse); i++;
    XCTAssertEqual([parser typeAtLine:i], character); i++;
    XCTAssertEqual([parser typeAtLine:i], dialogue); i++;
    XCTAssertEqual([parser typeAtLine:i], empty); i++;
    XCTAssertEqual([parser typeAtLine:i], heading); i++;
    XCTAssertEqual([parser typeAtLine:i], empty); i++;
    XCTAssertEqual([parser typeAtLine:i], heading); i++;
    XCTAssertEqual([parser typeAtLine:i], empty); i++;
    XCTAssertEqual([parser typeAtLine:i], heading); i++;
    XCTAssertEqual([parser typeAtLine:i], empty); i++;
    XCTAssertEqual([parser typeAtLine:i], heading); i++;
}

- (void)testFormattingParsing
{
    ContinousFountainParser *parser;
    Line* line;
    NSRange range;
    
    parser = [[ContinousFountainParser alloc] initWithString:@"**bold**"];
    line = parser.lines[0];
    range = NSMakeRange(0, 8);
    XCTAssertTrue([line.boldRanges containsIndexesInRange:range]);
    XCTAssertFalse([line.italicRanges containsIndexesInRange:range]);
    XCTAssertFalse([line.underlinedRanges containsIndexesInRange:range]);
    XCTAssertFalse([line.noteRanges containsIndexesInRange:range]);
    XCTAssertFalse([line.omitedRanges containsIndexesInRange:range]);
    
    parser = [[ContinousFountainParser alloc] initWithString:@"*itälic*"];
    line = parser.lines[0];
    range = NSMakeRange(0, 8);
    XCTAssertFalse([line.boldRanges containsIndexesInRange:range]);
    XCTAssertTrue([line.italicRanges containsIndexesInRange:range]);
    XCTAssertFalse([line.underlinedRanges containsIndexesInRange:range]);
    XCTAssertFalse([line.noteRanges containsIndexesInRange:range]);
    XCTAssertFalse([line.omitedRanges containsIndexesInRange:range]);
    
    parser = [[ContinousFountainParser alloc] initWithString:@"_ünderlined_"];
    line = parser.lines[0];
    range = NSMakeRange(0, 12);
    XCTAssertFalse([line.boldRanges containsIndexesInRange:range]);
    XCTAssertFalse([line.italicRanges containsIndexesInRange:range]);
    XCTAssertTrue([line.underlinedRanges containsIndexesInRange:range]);
    XCTAssertFalse([line.noteRanges containsIndexesInRange:range]);
    XCTAssertFalse([line.omitedRanges containsIndexesInRange:range]);
    
    parser = [[ContinousFountainParser alloc] initWithString:@"[[cómment]]"];
    line = parser.lines[0];
    range = NSMakeRange(0, 11);
    XCTAssertFalse([line.boldRanges containsIndexesInRange:range]);
    XCTAssertFalse([line.italicRanges containsIndexesInRange:range]);
    XCTAssertFalse([line.underlinedRanges containsIndexesInRange:range]);
    XCTAssertTrue([line.noteRanges containsIndexesInRange:range]);
    XCTAssertFalse([line.omitedRanges containsIndexesInRange:range]);
    
    parser = [[ContinousFountainParser alloc] initWithString:@"/*ömmited*/"];
    line = parser.lines[0];
    range = NSMakeRange(0, 11);
    XCTAssertFalse([line.boldRanges containsIndexesInRange:range]);
    XCTAssertFalse([line.italicRanges containsIndexesInRange:range]);
    XCTAssertFalse([line.underlinedRanges containsIndexesInRange:range]);
    XCTAssertFalse([line.noteRanges containsIndexesInRange:range]);
    XCTAssertTrue([line.omitedRanges containsIndexesInRange:range]);
    
    
    parser = [[ContinousFountainParser alloc] initWithString:@"**böld *böth* böld**"];
    line = parser.lines[0];
    range = NSMakeRange(0, 20);
    XCTAssertTrue([line.boldRanges containsIndexesInRange:range]);
    XCTAssertTrue([line.italicRanges containsIndexesInRange:NSMakeRange(7, 6)]);
    XCTAssertFalse([line.underlinedRanges containsIndexesInRange:range]);
    XCTAssertFalse([line.noteRanges containsIndexesInRange:range]);
    XCTAssertFalse([line.omitedRanges containsIndexesInRange:range]);
    
    parser = [[ContinousFountainParser alloc] initWithString:@"**böld *böldit _undérline [[nöte]] undèrline_ böldit* böld**"];
    line = parser.lines[0];
    XCTAssertTrue([line.boldRanges containsIndexesInRange:NSMakeRange(0, 60)]);
    XCTAssertTrue([line.italicRanges containsIndexesInRange:NSMakeRange(7, 46)]);
    XCTAssertTrue([line.underlinedRanges containsIndexesInRange:NSMakeRange(15, 30)]);
    XCTAssertTrue([line.noteRanges containsIndexesInRange:NSMakeRange(26, 8)]);
    XCTAssertFalse([line.omitedRanges containsIndexesInRange:NSMakeRange(0, 60)]);
    
    parser = [[ContinousFountainParser alloc] initWithString:@"**böld *böldit _undérline [[nö"];
    line = parser.lines[0];
    XCTAssertFalse([line.boldRanges containsIndexesInRange:NSMakeRange(0, 30)]);
    XCTAssertFalse([line.italicRanges containsIndexesInRange:NSMakeRange(7, 23)]);
    XCTAssertFalse([line.underlinedRanges containsIndexesInRange:NSMakeRange(15, 15)]);
    XCTAssertFalse([line.noteRanges containsIndexesInRange:NSMakeRange(26, 4)]);
    XCTAssertFalse([line.omitedRanges containsIndexesInRange:NSMakeRange(0, 30)]);
    
    parser = [[ContinousFountainParser alloc] initWithString:@"/* test\ntest*/ *italic*"];
    line = parser.lines[0];
    XCTAssertFalse([line.boldRanges containsIndexesInRange:NSMakeRange(0, 7)]);
    XCTAssertFalse([line.italicRanges containsIndexesInRange:NSMakeRange(0, 7)]);
    XCTAssertFalse([line.underlinedRanges containsIndexesInRange:NSMakeRange(0, 7)]);
    XCTAssertFalse([line.noteRanges containsIndexesInRange:NSMakeRange(0, 7)]);
    XCTAssertTrue([line.omitedRanges containsIndexesInRange:NSMakeRange(0, 7)]);
    line = parser.lines[1];
    XCTAssertFalse([line.boldRanges containsIndexesInRange:NSMakeRange(0, 15)]);
    XCTAssertFalse([line.italicRanges containsIndexesInRange:NSMakeRange(0, 7)]);
    XCTAssertTrue([line.italicRanges containsIndexesInRange:NSMakeRange(7, 8)]);
    XCTAssertFalse([line.underlinedRanges containsIndexesInRange:NSMakeRange(0, 15)]);
    XCTAssertFalse([line.noteRanges containsIndexesInRange:NSMakeRange(0, 15)]);
    XCTAssertTrue([line.omitedRanges containsIndexesInRange:NSMakeRange(0, 6)]);
    XCTAssertFalse([line.omitedRanges containsIndexesInRange:NSMakeRange(6, 9)]);
}

- (void)testOmmitParsing
{
    ContinousFountainParser *parser;
    Line* line;
    
    parser = [[ContinousFountainParser alloc] initWithString:@"/*test*/"];
    line = parser.lines[0];
    XCTAssertTrue([line.omitedRanges containsIndexesInRange:NSMakeRange(0, 8)]);
    
    parser = [[ContinousFountainParser alloc] initWithString:@"/* test\n test*/"];
    line = parser.lines[0];
    XCTAssertTrue([line.omitedRanges containsIndexesInRange:NSMakeRange(0, 7)]);
    line = parser.lines[1];
    XCTAssertTrue([line.omitedRanges containsIndexesInRange:NSMakeRange(0, 7)]);
    
    parser = [[ContinousFountainParser alloc] initWithString:@"/* test\nstuff\nstuff\nstuff\ntest*/"];
    line = parser.lines[0];
    XCTAssertTrue([line.omitedRanges containsIndexesInRange:NSMakeRange(0, 7)]);
    line = parser.lines[1];
    XCTAssertTrue([line.omitedRanges containsIndexesInRange:NSMakeRange(0, 5)]);
    line = parser.lines[2];
    XCTAssertTrue([line.omitedRanges containsIndexesInRange:NSMakeRange(0, 5)]);
    line = parser.lines[3];
    XCTAssertTrue([line.omitedRanges containsIndexesInRange:NSMakeRange(0, 5)]);
    line = parser.lines[4];
    XCTAssertTrue([line.omitedRanges containsIndexesInRange:NSMakeRange(0, 6)]);
    
    [parser parseChangeInRange:NSMakeRange(0, 2) withString:@""];
    line = parser.lines[0];
    XCTAssertFalse([line.omitedRanges containsIndexesInRange:NSMakeRange(0, 5)]);
    line = parser.lines[1];
    XCTAssertFalse([line.omitedRanges containsIndexesInRange:NSMakeRange(0, 5)]);
    line = parser.lines[2];
    XCTAssertFalse([line.omitedRanges containsIndexesInRange:NSMakeRange(0, 5)]);
    line = parser.lines[3];
    XCTAssertFalse([line.omitedRanges containsIndexesInRange:NSMakeRange(0, 5)]);
    line = parser.lines[4];
    XCTAssertFalse([line.omitedRanges containsIndexesInRange:NSMakeRange(0, 6)]);
    
    [parser parseChangeInRange:NSMakeRange(0, 0) withString:@"*"];
    line = parser.lines[0];
    XCTAssertFalse([line.omitedRanges containsIndexesInRange:NSMakeRange(0, 6)]);
    line = parser.lines[1];
    XCTAssertFalse([line.omitedRanges containsIndexesInRange:NSMakeRange(0, 5)]);
    line = parser.lines[2];
    XCTAssertFalse([line.omitedRanges containsIndexesInRange:NSMakeRange(0, 5)]);
    line = parser.lines[3];
    XCTAssertFalse([line.omitedRanges containsIndexesInRange:NSMakeRange(0, 5)]);
    line = parser.lines[4];
    XCTAssertFalse([line.omitedRanges containsIndexesInRange:NSMakeRange(0, 6)]);
    
    [parser parseChangeInRange:NSMakeRange(0, 0) withString:@"/"];
    line = parser.lines[0];
    XCTAssertTrue([line.omitedRanges containsIndexesInRange:NSMakeRange(0, 7)]);
    line = parser.lines[1];
    XCTAssertTrue([line.omitedRanges containsIndexesInRange:NSMakeRange(0, 5)]);
    line = parser.lines[2];
    XCTAssertTrue([line.omitedRanges containsIndexesInRange:NSMakeRange(0, 5)]);
    line = parser.lines[3];
    XCTAssertTrue([line.omitedRanges containsIndexesInRange:NSMakeRange(0, 5)]);
    line = parser.lines[4];
    XCTAssertTrue([line.omitedRanges containsIndexesInRange:NSMakeRange(0, 6)]);
    
    [parser parseChangeInRange:NSMakeRange(0, 0) withString:@"test\n"];
    line = parser.lines[0];
    XCTAssertFalse([line.omitedRanges containsIndexesInRange:NSMakeRange(0, 4)]);
    line = parser.lines[1];
    XCTAssertTrue([line.omitedRanges containsIndexesInRange:NSMakeRange(0, 7)]);
    line = parser.lines[2];
    XCTAssertTrue([line.omitedRanges containsIndexesInRange:NSMakeRange(0, 5)]);
    line = parser.lines[3];
    XCTAssertTrue([line.omitedRanges containsIndexesInRange:NSMakeRange(0, 5)]);
    line = parser.lines[4];
    XCTAssertTrue([line.omitedRanges containsIndexesInRange:NSMakeRange(0, 5)]);
    line = parser.lines[5];
    XCTAssertTrue([line.omitedRanges containsIndexesInRange:NSMakeRange(0, 6)]);
    
}

NSString* miniScript = @"INT. DAY - APPARTMENT\n"
@"Ted, Marshall and Lilly are sitting on the couch\n"
@"\n"
@"TED\n"
@"Wanna head down to the bar?\n"
@"\n"
@"MARSHALL\n"
@"Sure, let's go!";

NSString* miniScriptExpectedToString = @"0 Heading: \"INT. DAY - APPARTMENT\"\n"
@"1 Action: \"Ted, Marshall and Lilly are sitting on the couch\"\n"
@"2 Empty: \"\"\n"
@"3 Character: \"TED\"\n"
@"4 Dialogue: \"Wanna head down to the bar?\"\n"
@"5 Empty: \"\"\n"
@"6 Character: \"MARSHALL\"\n"
@"7 Dialogue: \"Sure, let's go!\"";

NSString* script = @""
@"Title: Script\n"
@"Author: Florian Maier\n"
@"Credit: Thomas Maier\n"
@"source: somewhere\n"
@"DrAft Date: 42.23.23\n"
@"Contact: florian@maier.de\n"
@"   noeller@me.com\n"
@"\ttest@abc.\nde"
@"Key: value\n"
@"\n"
@"INT. DAY - LIVING ROOM #1# \n"
@"EXT. DAY - LIVING ROOM\n"
@"\n"
@"EXT. DAY - LIVING ROOM\n"
@"Peter sités somewhere and does something\n"
@"\n"
@"PETER\n"
@"I Liké sitting here\n"
@"it mäkes me happy\n"
@"\n"
@"CHRIS ^\n"
@"i'm alßo a person!\n"
@"\n"
@"HARRAY\n"
@"(slightly irritated)\n"
@"Why do i have parentheses?\n"
@"They are weird!\n"
@"(still slightly irritated)\n"
@"\n"
@"CHIRS ^\n"
@"(looking at harray)\n"
@"Why am i over here?\n"
@"  \n"
@"And I have holes in my text!\n"
@"\n"
@"§$!%\n"
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
@"This is on a new page\n"
@"#section a\n"
@"###section c\n"
@"=synopse\n"
@"@tom\n"
@"dialogue\n"
@"\n"
@"INT./EXT stuff\n"
@"\n"
@"INT/EXT other things\n"
@"\n"
@"I/E things\n"
@"\n"
@"EST things\n";

@end
