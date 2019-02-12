//
//  WriterFDXTests.m
//  Writer
//
//  Created by Hendrik Noeller on 07.04.16.
//  Copyright © 2016 Hendrik Noeller. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "ContinousFountainParser.h"
#import "FDXInterface.h"

@interface WriterFDXTests : XCTestCase

@end

@implementation WriterFDXTests

- (void)testEmptyFile
{
    NSString* fdxString = [FDXInterface fdxFromString:@""];
    NSArray* lines = [fdxString componentsSeparatedByString:@"\n"];
    int i = 0;
    XCTAssertEqualObjects(lines[i], @"<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\" ?>"); i++;
    XCTAssertEqualObjects(lines[i], @"<FinalDraft DocumentType=\"Script\" Template=\"No\" Version=\"1\">"); i++;
    XCTAssertEqualObjects(lines[i], @""); i++;
    XCTAssertEqualObjects(lines[i], @"  <Content>"); i++;
    XCTAssertEqualObjects(lines[i], @"  </Content>"); i++;
    XCTAssertEqualObjects(lines[i], @"</FinalDraft>"); i++;
}

- (void)testFDXExport
{
    NSString* fdxString = [FDXInterface fdxFromString:fdxScript];
    NSArray* lines = [fdxString componentsSeparatedByString:@"\n"];
    
    int i = 0;
    XCTAssertEqualObjects(lines[i], @"<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\" ?>"); i++;
    XCTAssertEqualObjects(lines[i], @"<FinalDraft DocumentType=\"Script\" Template=\"No\" Version=\"1\">"); i++;
    XCTAssertEqualObjects(lines[i], @""); i++;
    XCTAssertEqualObjects(lines[i], @"  <Content>"); i++;
    
    XCTAssertEqualObjects(lines[i], @"    <Paragraph Type=\"Scene Heading\">"); i++;
    XCTAssertEqualObjects(lines[i], @"      <Text>INT. DAY - APPARTMENT</Text>"); i++;
    XCTAssertEqualObjects(lines[i], @"    </Paragraph>"); i++;
    
    XCTAssertEqualObjects(lines[i], @"    <Paragraph Type=\"Action\">"); i++;
    XCTAssertEqualObjects(lines[i], @"      <Text>Ted, Marshall and Lilly are sitting on the couch</Text>"); i++;
    XCTAssertEqualObjects(lines[i], @"    </Paragraph>"); i++;
    
    XCTAssertEqualObjects(lines[i], @"    <Paragraph>"); i++;
    XCTAssertEqualObjects(lines[i], @"      <DualDialogue>"); i++;
    
    XCTAssertEqualObjects(lines[i], @"    <Paragraph Type=\"Character\">"); i++;
    XCTAssertEqualObjects(lines[i], @"      <Text>TED</Text>"); i++;
    XCTAssertEqualObjects(lines[i], @"    </Paragraph>"); i++;
    
    XCTAssertEqualObjects(lines[i], @"    <Paragraph Type=\"Parenthetical\">"); i++;
    XCTAssertEqualObjects(lines[i], @"      <Text>(parenthetical)</Text>"); i++;
    XCTAssertEqualObjects(lines[i], @"    </Paragraph>"); i++;
    
    XCTAssertEqualObjects(lines[i], @"    <Paragraph Type=\"Dialogue\">"); i++;
    XCTAssertEqualObjects(lines[i], @"      <Text>Wanna head down to the bar?</Text>"); i++;
    XCTAssertEqualObjects(lines[i], @"    </Paragraph>"); i++;
    
    XCTAssertEqualObjects(lines[i], @"    <Paragraph Type=\"Character\">"); i++;
    XCTAssertEqualObjects(lines[i], @"      <Text>MARSHALL</Text>"); i++;
    XCTAssertEqualObjects(lines[i], @"    </Paragraph>"); i++;
    
    XCTAssertEqualObjects(lines[i], @"    <Paragraph Type=\"Parenthetical\">"); i++;
    XCTAssertEqualObjects(lines[i], @"      <Text>(happy)</Text>"); i++;
    XCTAssertEqualObjects(lines[i], @"    </Paragraph>"); i++;
    
    XCTAssertEqualObjects(lines[i], @"    <Paragraph Type=\"Dialogue\">"); i++;
    XCTAssertEqualObjects(lines[i], @"      <Text>Sure, let&#x27;s go!</Text>"); i++;
    XCTAssertEqualObjects(lines[i], @"    </Paragraph>"); i++;
    
    XCTAssertEqualObjects(lines[i], @"      </DualDialogue>"); i++;
    XCTAssertEqualObjects(lines[i], @"    </Paragraph>"); i++;
    
    XCTAssertEqualObjects(lines[i], @"    <Paragraph Type=\"Transition\">"); i++;
    XCTAssertEqualObjects(lines[i], @"      <Text>FADE TO:</Text>"); i++;
    XCTAssertEqualObjects(lines[i], @"    </Paragraph>"); i++;
    
    XCTAssertEqualObjects(lines[i], @"    <Paragraph Type=\"Scene Heading\">"); i++;
    XCTAssertEqualObjects(lines[i], @"      <Text>INT. DAY - THE BAR</Text>"); i++;
    XCTAssertEqualObjects(lines[i], @"    </Paragraph>"); i++;
    
    XCTAssertEqualObjects(lines[i], @"    <Paragraph Type=\"Action\">"); i++;
    XCTAssertEqualObjects(lines[i], @"      <Text>The jukebox is playing</Text>"); i++;
    XCTAssertEqualObjects(lines[i], @"    </Paragraph>"); i++;
    
    XCTAssertEqualObjects(lines[i], @"    <Paragraph Type=\"Lyrics\">"); i++;
    XCTAssertEqualObjects(lines[i], @"      <Text>1 o&#x27;clock, 2 o&#x27;clock, 3&#x27;o clock rock!</Text>"); i++;
    XCTAssertEqualObjects(lines[i], @"    </Paragraph>"); i++;
    
    XCTAssertEqualObjects(lines[i], @"    <Paragraph Alignment=\"Center\" Type=\"Action\">"); i++;
    XCTAssertEqualObjects(lines[i], @"      <Text> The song is the bomb! </Text>"); i++;
    XCTAssertEqualObjects(lines[i], @"    </Paragraph>"); i++;
    
    XCTAssertEqualObjects(lines[i], @"  </Content>"); i++;
    
    
    XCTAssertEqualObjects(lines[i], @"  <TitlePage>"); i++;
    XCTAssertEqualObjects(lines[i], @"    <Content>"); i++;
    
    for (int j = 0; j < 18; j++) {
        XCTAssertEqualObjects(lines[i], @"      <Paragraph>"); i++;
        XCTAssertEqualObjects(lines[i], @"        <Text></Text>"); i++;
        XCTAssertEqualObjects(lines[i], @"      </Paragraph>"); i++;
    }
    
    XCTAssertEqualObjects(lines[i], @"      <Paragraph Alignment=\"Center\">"); i++;
    XCTAssertEqualObjects(lines[i], @"        <Text>Any generic HIMYM Script</Text>"); i++;
    XCTAssertEqualObjects(lines[i], @"      </Paragraph>"); i++;
    
    XCTAssertEqualObjects(lines[i], @"      <Paragraph Alignment=\"Center\">"); i++;
    XCTAssertEqualObjects(lines[i], @"        <Text></Text>"); i++;
    XCTAssertEqualObjects(lines[i], @"      </Paragraph>"); i++;
    
    XCTAssertEqualObjects(lines[i], @"      <Paragraph Alignment=\"Center\">"); i++;
    XCTAssertEqualObjects(lines[i], @"        <Text></Text>"); i++;
    XCTAssertEqualObjects(lines[i], @"      </Paragraph>"); i++;
    
    XCTAssertEqualObjects(lines[i], @"      <Paragraph Alignment=\"Center\">"); i++;
    XCTAssertEqualObjects(lines[i], @"        <Text>40$</Text>"); i++;
    XCTAssertEqualObjects(lines[i], @"      </Paragraph>"); i++;
    
    XCTAssertEqualObjects(lines[i], @"      <Paragraph Alignment=\"Center\">"); i++;
    XCTAssertEqualObjects(lines[i], @"        <Text></Text>"); i++;
    XCTAssertEqualObjects(lines[i], @"      </Paragraph>"); i++;
    
    XCTAssertEqualObjects(lines[i], @"      <Paragraph Alignment=\"Center\">"); i++;
    XCTAssertEqualObjects(lines[i], @"        <Text>Carter Thomas and Craig Bays</Text>"); i++;
    XCTAssertEqualObjects(lines[i], @"      </Paragraph>"); i++;
    
    XCTAssertEqualObjects(lines[i], @"      <Paragraph Alignment=\"Center\">"); i++;
    XCTAssertEqualObjects(lines[i], @"        <Text></Text>"); i++;
    XCTAssertEqualObjects(lines[i], @"      </Paragraph>"); i++;
    
    XCTAssertEqualObjects(lines[i], @"      <Paragraph Alignment=\"Center\">"); i++;
    XCTAssertEqualObjects(lines[i], @"        <Text></Text>"); i++;
    XCTAssertEqualObjects(lines[i], @"      </Paragraph>"); i++;
    
    XCTAssertEqualObjects(lines[i], @"      <Paragraph Alignment=\"Center\">"); i++;
    XCTAssertEqualObjects(lines[i], @"        <Text>The top of my mind</Text>"); i++;
    XCTAssertEqualObjects(lines[i], @"      </Paragraph>"); i++;
    
    for (int j = 0; j < 20; j++) {
        XCTAssertEqualObjects(lines[i], @"      <Paragraph>"); i++;
        XCTAssertEqualObjects(lines[i], @"        <Text></Text>"); i++;
        XCTAssertEqualObjects(lines[i], @"      </Paragraph>"); i++;
    }
    
    XCTAssertEqualObjects(lines[i], @"      <Paragraph>"); i++;
    XCTAssertEqualObjects(lines[i], @"        <Text>some day in the future</Text>"); i++;
    XCTAssertEqualObjects(lines[i], @"      </Paragraph>"); i++;
    
    XCTAssertEqualObjects(lines[i], @"      <Paragraph>"); i++;
    XCTAssertEqualObjects(lines[i], @"        <Text>mail@internet.cat</Text>"); i++;
    XCTAssertEqualObjects(lines[i], @"      </Paragraph>"); i++;
    
    XCTAssertEqualObjects(lines[i], @"    </Content>"); i++;
    XCTAssertEqualObjects(lines[i], @"  </TitlePage>"); i++;
    
    XCTAssertEqualObjects(lines[i], @"</FinalDraft>"); i++;
}

- (void)testFormattingExport
{
    NSString* fdxString = [FDXInterface fdxFromString:@"**bold**\n**bold** normal *italic* _underline_ _**boldline**_ _*underitalic*_ ***boldit***\na\n*i*\n**"];
    NSArray* lines = [fdxString componentsSeparatedByString:@"\n"];
    
    int i = 0;
    XCTAssertEqualObjects(lines[i], @"<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\" ?>"); i++;
    XCTAssertEqualObjects(lines[i], @"<FinalDraft DocumentType=\"Script\" Template=\"No\" Version=\"1\">"); i++;
    XCTAssertEqualObjects(lines[i], @""); i++;
    XCTAssertEqualObjects(lines[i], @"  <Content>"); i++;
    
    XCTAssertEqualObjects(lines[i], @"    <Paragraph Type=\"Action\">"); i++;
    XCTAssertEqualObjects(lines[i], @"      <Text Style=\"Bold\">bold</Text>"); i++;
    XCTAssertEqualObjects(lines[i], @"    </Paragraph>"); i++;
    
    XCTAssertEqualObjects(lines[i], @"    <Paragraph Type=\"Action\">"); i++;
    XCTAssertEqualObjects(lines[i], @"      <Text Style=\"Bold\">bold</Text>"); i++;
    XCTAssertEqualObjects(lines[i], @"      <Text> normal </Text>"); i++;
    XCTAssertEqualObjects(lines[i], @"      <Text Style=\"Italic\">italic</Text>"); i++;
    XCTAssertEqualObjects(lines[i], @"      <Text> </Text>"); i++;
    XCTAssertEqualObjects(lines[i], @"      <Text Style=\"Underline\">underline</Text>"); i++;
    XCTAssertEqualObjects(lines[i], @"      <Text> </Text>"); i++;
    XCTAssertEqualObjects(lines[i], @"      <Text Style=\"Bold+Underline\">boldline</Text>"); i++;
    XCTAssertEqualObjects(lines[i], @"      <Text> </Text>"); i++;
    XCTAssertEqualObjects(lines[i], @"      <Text Style=\"Italic+Underline\">underitalic</Text>"); i++;
    XCTAssertEqualObjects(lines[i], @"      <Text> </Text>"); i++;
    XCTAssertEqualObjects(lines[i], @"      <Text Style=\"Bold+Italic\">boldit</Text>"); i++;
    XCTAssertEqualObjects(lines[i], @"    </Paragraph>"); i++;
    
    XCTAssertEqualObjects(lines[i], @"    <Paragraph Type=\"Action\">"); i++;
    XCTAssertEqualObjects(lines[i], @"      <Text>a</Text>"); i++;
    XCTAssertEqualObjects(lines[i], @"    </Paragraph>"); i++;
    
    XCTAssertEqualObjects(lines[i], @"    <Paragraph Type=\"Action\">"); i++;
    XCTAssertEqualObjects(lines[i], @"      <Text Style=\"Italic\">i</Text>"); i++;
    XCTAssertEqualObjects(lines[i], @"    </Paragraph>"); i++;
    
    XCTAssertEqualObjects(lines[i], @"    <Paragraph Type=\"Action\">"); i++;
    XCTAssertEqualObjects(lines[i], @"    </Paragraph>"); i++;
    
    XCTAssertEqualObjects(lines[i], @"  </Content>"); i++;
    XCTAssertEqualObjects(lines[i], @"</FinalDraft>"); i++;
}

- (void)testCharacterEscape
{
    NSString* testString;
    NSMutableString* mutableTestString;
    
    testString = @"this is a usual string äöü? $%è !";
    mutableTestString = [testString mutableCopy];
    [FDXInterface escapeString:mutableTestString];
    
    XCTAssertEqualObjects(mutableTestString, [testString mutableCopy]);
    
    testString = @"&";
    mutableTestString = [testString mutableCopy];
    [FDXInterface escapeString:mutableTestString];
    
    XCTAssertEqualObjects(mutableTestString, [@"&amp;" mutableCopy]);
    
    testString = @"\"";
    mutableTestString = [testString mutableCopy];
    [FDXInterface escapeString:mutableTestString];
    
    XCTAssertEqualObjects(mutableTestString, [@"&quot;" mutableCopy]);
    
    testString = @"'";
    mutableTestString = [testString mutableCopy];
    [FDXInterface escapeString:mutableTestString];
    
    XCTAssertEqualObjects(mutableTestString, [@"&#x27;" mutableCopy]);
    
    testString = @"<";
    mutableTestString = [testString mutableCopy];
    [FDXInterface escapeString:mutableTestString];
    
    XCTAssertEqualObjects(mutableTestString, [@"&lt;" mutableCopy]);
    
    testString = @">";
    mutableTestString = [testString mutableCopy];
    [FDXInterface escapeString:mutableTestString];
    
    XCTAssertEqualObjects(mutableTestString, [@"&gt;" mutableCopy]);
    
    testString = @"&\"'<>";
    mutableTestString = [testString mutableCopy];
    [FDXInterface escapeString:mutableTestString];
    
    XCTAssertEqualObjects(mutableTestString, [@"&amp;&quot;&#x27;&lt;&gt;" mutableCopy]);
}

NSString* fdxScript = @"Title: Any generic HIMYM Script\n"
@"Author: Carter Thomas and Craig Bays\n"
@"Credit: 40$\n"
@"Source: The top of my mind\n"
@"Draft date: some day in the future\n"
@"Contact: mail@internet.cat\n"
@"Legen-waitforit: dairy!\n"
@"\n"
@"#in the appartment \n"
@"= a bar going is initiiated\n"
@"\n"
@"INT. DAY - APPARTMENT\n"
@"\n"
@"Ted, Marshall and Lilly are sitting on the couch\n"
@"\n"
@"TED\n"
@"(parenthetical)\n"
@"Wanna head down to the bar?\n"
@"\n"
@"MARSHALL ^\n"
@"(happy)\n"
@"Sure, let's go!\n"
@"FADE TO:\n"
@"===\n"
@"\n"
@"INT. DAY - THE BAR\n"
@"The jukebox is playing\n"
@"~1 o'clock, 2 o'clock, 3'o clock rock!\n"
@"> The song is the bomb! <";


@end
