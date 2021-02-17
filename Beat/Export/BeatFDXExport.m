//
//  BeatFDXExport.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 8.2.2021.
//  Copyright © 2021 KAPITAN!. All rights reserved.
//
//  Based on FDXInterface by Hendrik Noeller,
//  originally translated to Objective C from: https://github.com/vilcans/screenplain/blob/master/screenplain/export/fdx.py

/*
 
 TODO:
 - Remove forced scene numbers
 
 
 This implementation relies on a semi-clever hack. I'm converting style ranges (bold, italic, underline)
 created by the parser into custom attributes (ie. "Style": "Bold"). That attributed string can be
 requested from Line objects, along with ranges which contain Fountain markup, and we can use that data
 to create FDX compatible XML tags.
 
 This system also allows us to use FDX tagging, which requires some more weird hacking. It's a bit
 convoluted system right now, and baking tags into Line objects requires the original attributed
 string from the editor.

 As I'm writing this, screenplay tagging is very, very close to working. It requires some tweaking.
 The logic behind
 
 Production tag data is wrapped in <TagData>, followed by <TagCategories>, <TagDefinitions> and <Tags>.
 
 FDX tag category IDs seem to be hard-coded, so we use them here with no remorse.
 (To be user-friendly, we should create 16bit (12-digit) hexes for colors.)
 
	 <TagCategories>
		 <TagCategory Color="#000000000000" Id="8e5e75c2-713b-47df-a75f-f12648b98ded" Name="Synopsis" Number="1" Style="Bold"/>
		 <TagCategory Color="#00003600B700" Id="01fc9642-84ff-4366-b37c-a3068dee57e8" Name="Cast Members" Number="2" Style="Bold"/>
		 <TagCategory Color="#94AA11150000" Id="028a4e2b-b507-4d09-88ab-90e3edae9071" Name="Background Actors" Number="3" Style="Bold"/>
		 <TagCategory Color="#94AA11150000" Id="0377dbe6-77a3-41af-bda8-86eb2468fdbf" Name="Stunts" Number="4" Style="Bold"/>
		 <TagCategory Color="#94AA11150000" Id="04721a56-f54b-49c8-80ad-d53887d6b851" Name="Vehicles" Number="5" Style="Bold"/>
		 <TagCategory Color="#94AA11150000" Id="05c556eb-6bc1-4a3a-b09f-f8b5ba1b6afa" Name="Props" Number="6" Style="Bold"/>
		 <TagCategory Color="#94AA11150000" Id="47b02ff1-5161-4137-b736-f36eebba7643" Name="Camera" Number="7" Style="Bold"/>
		 <TagCategory Color="#94AA11150000" Id="069e18b8-2109-4f3d-94e7-d802027a60a8" Name="Special Effects" Number="8" Style="Bold"/>
		 <TagCategory Color="#94AA11150000" Id="0726fa85-1e65-4ab8-87de-bf21d09b01f0" Name="Wardrobe" Number="9" Style="Bold"/>
		 <TagCategory Color="#94AA11150000" Id="08ae1eef-32ce-415f-9a9b-0982d2453ec4" Name="Makeup/Hair" Number="10" Style="Bold"/>
		 <TagCategory Color="#94AA11150000" Id="09cb0d1c-ce01-4f22-bb64-b5f2e6c491c6" Name="Animals" Number="11" Style="Bold"/>
		 <TagCategory Color="#94AA11150000" Id="0ae40617-cc7c-48e6-ae2b-5aaecc09986f" Name="Animal Wrangler" Number="12" Style="Bold"/>
		 <TagCategory Color="#94AA11150000" Id="0b0b44c9-aa4b-4c40-88b1-d94472ad7a26" Name="Music" Number="13" Style="Bold"/>
		 <TagCategory Color="#94AA11150000" Id="0ce7d308-096d-4603-8fe8-349f72cd89ff" Name="Sound" Number="15" Style="Bold"/>
		 <TagCategory Color="#94AA11150000" Id="c86eae40-3b01-41c3-a7de-6859e6ec971d" Name="Art Department" Number="16" Style="Bold"/>
		 <TagCategory Color="#94AA11150000" Id="0debb71b-5743-4c53-80cc-e17e841ce645" Name="Set Dressing" Number="17" Style="Bold"/>
		 <TagCategory Color="#94AA11150000" Id="0e7a8fc5-5441-4bad-a9bf-5ddd3fe51c69" Name="Greenery" Number="18" Style="Bold"/>
		 <TagCategory Color="#94AA11150000" Id="0ff5cda4-4d43-4cfe-940f-91380c46fdad" Name="Special Equipment" Number="19" Style="Bold"/>
		 <TagCategory Color="#94AA11150000" Id="109d0eaa-0334-4823-ac0c-b44d3f209dc4" Name="Security" Number="20" Style="Bold"/>
		 <TagCategory Color="#94AA11150000" Id="1179a4b1-70ee-4011-b4a2-809a0af09e92" Name="Additional Labor" Number="21" Style="Bold"/>
		 <TagCategory Color="#94AA11150000" Id="12ab0932-e3b9-4b4a-bcd0-3da1b4e61d5e" Name="Visual Effects" Number="23" Style="Bold"/>
		 <TagCategory Color="#94AA11150000" Id="135cc9d1-c4d5-4d00-83d9-571f584ea9cd" Name="Mechanical Effects" Number="24" Style="Bold"/>
		 <TagCategory Color="#94AA11150000" Id="ce04f547-f7ee-40c9-ab66-d95a0c98034e" Name="Miscellaneous" Number="25" Style="Bold"/>
		 <TagCategory Color="#94AA11150000" Id="15b6f4fd-4e74-4ad8-9971-b239d88c2997" Name="Notes" Number="26" Style="Bold"/>
		 <TagCategory Color="#94AA11150000" Id="63c140da-ef2b-491a-b416-b46f461abb89" Name="Script Day" Number="27" Style="Bold"/>
		 <TagCategory Color="#94AA11150000" Id="849f1ebf-5507-4f33-bff6-3a5b4d73be14" Name="Unit" Number="28" Style="Bold"/>
		 <TagCategory Color="#94AA11150000" Id="70877d87-30ef-45b6-be46-c6fa94b83a71" Name="Sequence" Number="29" Style="Bold"/>
		 <TagCategory Color="#94AA11150000" Id="c5e89e4d-f83e-4c28-950c-92a63f1b5f26" Name="Location" Number="30" Style="Bold"/>
		 <TagCategory Color="#94AA11150000" Id="216f33fd-fc42-4269-be01-b05b18f815a0" Name="Comments" Number="31" Style="Bold"/>
	</TagCategories>
 
 Tag definitions have a running number, a reference to their category and a cross-reference to individual Tags.
	 <TagDefinitions>
		   <TagDefinition CatId="0b0b44c9-aa4b-4c40-88b1-d94472ad7a26" Id="058dcea8-0d67-4991-ba6e-673e521a56b8" Label="some nice music" Number="1"/>
	 </TagDefinitions>
 
 Tags themselves have the number as an attribute and contain <DefId> which refers to the definition.
 I'm a bit weirded out by this, to be honest.
	 <Tags>
		<Tag Number="1">
			 <DefId>058dcea8-0d67-4991-ba6e-673e521a56b8</DefId>
		</Tag>
	 </Tags>
 </TagData>
 
 
 For the individual tag IDs we need to create a random hex number. It doesn't seem to have any logic to it,
 just needs to be formatted like this: ########-####-####-####-############
 
 Tags can then be attached to the screenplay using <Text TagNumber="1">some nice music</Text>
 
 Because the tagging system in Beat doesn't have literal definitions other than what's in the script,
 we'll just create a definition for each of the tags, UNLESS they are the same.
 
 */

#import "BeatFDXExport.h"
#import "ContinousFountainParser.h"
#import "BeatTagging.h"
#define format(s, ...) [NSString stringWithFormat:s, ##__VA_ARGS__]

static NSDictionary *fdxIds;

@interface BeatFDXExport ()
@property (nonatomic) ContinousFountainParser *parser;
@property (nonatomic) NSArray *tags;
@property (nonatomic) NSMutableString *result;

@property (nonatomic) NSMutableDictionary *tagData;

@property (nonatomic) NSMutableString *tagDefinitions;
@property (nonatomic) NSMutableString *tagIds;
@property (nonatomic) NSMutableString *tagsStr;
@property (nonatomic) NSInteger tagNumber;

@property (nonatomic) bool inDualDialogue;
@end

@implementation BeatFDXExport

- (instancetype)initWithString:(NSString*)string tags:(NSArray*)tags attributedString:(NSAttributedString*)attrString
{
	self = [super init];
	
	// Init static tag id data
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		fdxIds = @{
			// Map Beat tags to FDX tag identifiers.
			// These contain dual instances for plural forms, just in case
			@"Synopsis":	 	@{ @"number": @1, @"id": @"8e5e75c2-713b-47df-a75f-f12648b98ded" },
			@"Cast":	 		@{ @"number": @2, @"id": @"01fc9642-84ff-4366-b37c-a3068dee57e8" },
			@"Extras": 			@{ @"number": @3, @"id": @"028a4e2b-b507-4d09-88ab-90e3edae9071" },
			@"Stunt": 			@{ @"number": @4, @"id": @"0377dbe6-77a3-41af-bda8-86eb2468fdbf" }, @"Stunts": @{ @"number": @4, @"id": @"0377dbe6-77a3-41af-bda8-86eb2468fdbf" },
			@"Vehicle": 		@{ @"number": @5, @"id": @"04721a56-f54b-49c8-80ad-d53887d6b851" }, @"Vehicles": @{ @"number": @5, @"id": @"04721a56-f54b-49c8-80ad-d53887d6b851" },
			@"Prop": 			@{ @"number": @6, @"id": @"05c556eb-6bc1-4a3a-b09f-f8b5ba1b6afa" }, @"Props": @{ @"number": @6, @"id": @"05c556eb-6bc1-4a3a-b09f-f8b5ba1b6afa" },
			@"Camera": 			@{ @"number": @7, @"id": @"47b02ff1-5161-4137-b736-f36eebba7643" },
			@"Special Effect":  @{ @"number": @8, @"id": @"069e18b8-2109-4f3d-94e7-d802027a60a8" }, @"Special Effects": @{ @"number": @8, @"id": @"069e18b8-2109-4f3d-94e7-d802027a60a8" },
			
			@"Costume":			@{ @"number": @9, @"id": @"0726fa85-1e65-4ab8-87de-bf21d09b01f0" },
			
			@"Makeup": 			@{ @"number": @10, @"id": @"08ae1eef-32ce-415f-9a9b-0982d2453ec4" },
			@"Makeup & hair": 	@{ @"number": @10, @"id": @"08ae1eef-32ce-415f-9a9b-0982d2453ec4" },
			
			@"Animal": 			@{ @"number": @11, @"id": @"09cb0d1c-ce01-4f22-bb64-b5f2e6c491c6" }, @"Animals": @{ @"number": @11, @"id": @"09cb0d1c-ce01-4f22-bb64-b5f2e6c491c6" },
			@"Music": 			@{ @"number": @13, @"id": @"0b0b44c9-aa4b-4c40-88b1-d94472ad7a26" },
			@"Sound": 			@{ @"number": @15, @"id": @"0ce7d308-096d-4603-8fe8-349f72cd89ff" },
			@"Art": 			@{ @"number": @16, @"id": @"c86eae40-3b01-41c3-a7de-6859e6ec971d" },
			@"Scenography": 	@{ @"number": @17, @"id": @"0debb71b-5743-4c53-80cc-e17e841ce645" },
			@"Special Equipment": @{ @"number": @19, @"id": @"0ff5cda4-4d43-4cfe-940f-91380c46fdad" },
			@"Security": 		@{ @"number": @20, @"id": @"109d0eaa-0334-4823-ac0c-b44d3f209dc4" },
			@"Additional Work": @{ @"number": @21, @"id": @"1179a4b1-70ee-4011-b4a2-809a0af09e92" },
			@"VFX": 			@{ @"number": @23, @"id": @"12ab0932-e3b9-4b4a-bcd0-3da1b4e61d5e" },
			@"Practical FX": 	@{ @"number": @24, @"id": @"135cc9d1-c4d5-4d00-83d9-571f584ea9cd" },
			@"Other":			@{ @"number": @25, @"id": @"ce04f547-f7ee-40c9-ab66-d95a0c98034e" },
			@"Notes":			@{ @"number": @26, @"id": @"15b6f4fd-4e74-4ad8-9971-b239d88c2997" },
			@"Script Day":		@{ @"number": @27, @"id": @"63c140da-ef2b-491a-b416-b46f461abb89" },
			@"Unit":			@{ @"number": @28, @"id": @"849f1ebf-5507-4f33-bff6-3a5b4d73be14" },
			//@"Sequence":		@{ @"number": @29, @"id": @"70877d87-30ef-45b6-be46-c6fa94b83a71" },
			@"Location":		@{ @"number": @30, @"id": @"c5e89e4d-f83e-4c28-950c-92a63f1b5f26" }
		};
	});
	
	self.parser = [[ContinousFountainParser alloc] initWithString:string];
	if (attrString && tags.count) [BeatTagging bakeTags:tags inString:attrString toLines:self.parser.lines];
	
	self.tagNumber = 0;
	self.tags = [NSArray arrayWithArray:tags];
	self.tagData = [NSMutableDictionary dictionary];
	
	self.tagDefinitions = [NSMutableString string];
	self.tagIds = [NSMutableString string];
	self.tagsStr = [NSMutableString string];
	
	[self createFDX];
	
	return self;
}

- (NSString*)fdxString {
	return self.result;
}

- (NSString*)createFDX {

	if (self.parser.lines.count == 0) return @"";

	_result = [@"<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\" ?>\n"
			   @"<FinalDraft DocumentType=\"Script\" Template=\"No\" Version=\"1\">\n"
			   @"\n"
			   @"  <Content>\n" mutableCopy];
	
	_inDualDialogue = NO;
		
	for (int i = 0; i < _parser.lines.count; i++) {
		[self appendLineAtIndex:i];
		//inDualDialogue = [self appendLineAtIndex:i fromLines:parser.lines toString:result inDualDialogue:inDualDialogue tags:tags];
	}
	
	[_result appendString:@"  </Content>\n"];
	[self appendTitlePage];
	
	if (_tags) {
		[_result appendString:@"  <TagData>\n"];
		[_result appendString:@"    <TagCategories>\n"];
		[_result appendString:@"      <TagCategory Color=\"#00003600B700\" Id=\"01fc9642-84ff-4366-b37c-a3068dee57e8\" Name=\"Cast Members\" Number=\"2\" Style=\"Bold\"/>\n"
							  @"      <TagCategory Color=\"#94AA11150000\" Id=\"028a4e2b-b507-4d09-88ab-90e3edae9071\" Name=\"Background Actors\" Number=\"3\" Style=\"Bold\"/>\n"
							  @"      <TagCategory Color=\"#94AA11150000\" Id=\"0377dbe6-77a3-41af-bda8-86eb2468fdbf\" Name=\"Stunts\" Number=\"4\" Style=\"Bold\"/>\n"
							  @"      <TagCategory Color=\"#94AA11150000\" Id=\"04721a56-f54b-49c8-80ad-d53887d6b851\" Name=\"Vehicles\" Number=\"5\" Style=\"Bold\"/>\n"
							  @"      <TagCategory Color=\"#94AA11150000\" Id=\"05c556eb-6bc1-4a3a-b09f-f8b5ba1b6afa\" Name=\"Props\" Number=\"6\" Style=\"Bold\"/>\n"
							  @"      <TagCategory Color=\"#94AA11150000\" Id=\"069e18b8-2109-4f3d-94e7-d802027a60a8\" Name=\"Special Effects\" Number=\"8\" Style=\"Bold\"/>\n"
							  @"      <TagCategory Color=\"#94AA11150000\" Id=\"0726fa85-1e65-4ab8-87de-bf21d09b01f0\" Name=\"Wardrobe\" Number=\"9\" Style=\"Bold\"/>\n"
							  @"      <TagCategory Color=\"#94AA11150000\" Id=\"08ae1eef-32ce-415f-9a9b-0982d2453ec4\" Name=\"Makeup/Hair\" Number=\"10\" Style=\"Bold\"/>\n"
							  @"      <TagCategory Color=\"#94AA11150000\" Id=\"09cb0d1c-ce01-4f22-bb64-b5f2e6c491c6\" Name=\"Animals\" Number=\"11\" Style=\"Bold\"/>\n"
							  @"      <TagCategory Color=\"#94AA11150000\" Id=\"0ae40617-cc7c-48e6-ae2b-5aaecc09986f\" Name=\"Animal Wrangler\" Number=\"12\" Style=\"Bold\"/>\n"
							  @"      <TagCategory Color=\"#94AA11150000\" Id=\"0b0b44c9-aa4b-4c40-88b1-d94472ad7a26\" Name=\"Music\" Number=\"13\" Style=\"Bold\"/>\n"
							  @"      <TagCategory Color=\"#94AA11150000\" Id=\"0ce7d308-096d-4603-8fe8-349f72cd89ff\" Name=\"Sound\" Number=\"15\" Style=\"Bold\"/>\n"
							  @"      <TagCategory Color=\"#94AA11150000\" Id=\"0debb71b-5743-4c53-80cc-e17e841ce645\" Name=\"Set Dressing\" Number=\"17\" Style=\"Bold\"/>\n"
					          @"      <TagCategory Color=\"#94AA11150000\" Id=\"0e7a8fc5-5441-4bad-a9bf-5ddd3fe51c69\" Name=\"Greenery\" Number=\"18\" Style=\"Bold\"/>\n"
					          @"      <TagCategory Color=\"#94AA11150000\" Id=\"0ff5cda4-4d43-4cfe-940f-91380c46fdad\" Name=\"Special Equipment\" Number=\"19\" Style=\"Bold\"/>\n"
					          @"      <TagCategory Color=\"#94AA11150000\" Id=\"109d0eaa-0334-4823-ac0c-b44d3f209dc4\" Name=\"Security\" Number=\"20\" Style=\"Bold\"/>\n"
					          @"      <TagCategory Color=\"#94AA11150000\" Id=\"1179a4b1-70ee-4011-b4a2-809a0af09e92\" Name=\"Additional Labor\" Number=\"21\" Style=\"Bold\"/>\n"
					          @"      <TagCategory Color=\"#94AA11150000\" Id=\"12ab0932-e3b9-4b4a-bcd0-3da1b4e61d5e\" Name=\"Visual Effects\" Number=\"23\" Style=\"Bold\"/>\n"
					          @"      <TagCategory Color=\"#94AA11150000\" Id=\"135cc9d1-c4d5-4d00-83d9-571f584ea9cd\" Name=\"Mechanical Effects\" Number=\"24\" Style=\"Bold\"/>\n"
					          @"      <TagCategory Color=\"#94AA11150000\" Id=\"15b6f4fd-4e74-4ad8-9971-b239d88c2997\" Name=\"Notes\" Number=\"26\" Style=\"Bold\"/>\n"
					          @"      <TagCategory Color=\"#94AA11150000\" Id=\"216f33fd-fc42-4269-be01-b05b18f815a0\" Name=\"Comments\" Number=\"31\" Style=\"Bold\"/>\n"
					          @"      <TagCategory Color=\"#94AA11150000\" Id=\"47b02ff1-5161-4137-b736-f36eebba7643\" Name=\"Camera\" Number=\"7\" Style=\"Bold\"/>\n"
					          @"      <TagCategory Color=\"#94AA11150000\" Id=\"63c140da-ef2b-491a-b416-b46f461abb89\" Name=\"Script Day\" Number=\"27\" Style=\"Bold\"/>\n"
					          @"      <TagCategory Color=\"#94AA11150000\" Id=\"70877d87-30ef-45b6-be46-c6fa94b83a71\" Name=\"Sequence\" Number=\"29\" Style=\"Bold\"/>\n"
					          @"      <TagCategory Color=\"#94AA11150000\" Id=\"849f1ebf-5507-4f33-bff6-3a5b4d73be14\" Name=\"Unit\" Number=\"28\" Style=\"Bold\"/>\n"
					          @"      <TagCategory Color=\"#000000000000\" Id=\"8e5e75c2-713b-47df-a75f-f12648b98ded\" Name=\"Synopsis\" Number=\"1\" Style=\"Bold\"/>\n"
					          @"      <TagCategory Color=\"#94AA11150000\" Id=\"c5e89e4d-f83e-4c28-950c-92a63f1b5f26\" Name=\"Location\" Number=\"30\" Style=\"Bold\"/>\n"
					          @"      <TagCategory Color=\"#94AA11150000\" Id=\"c86eae40-3b01-41c3-a7de-6859e6ec971d\" Name=\"Art Department\" Number=\"16\" Style=\"Bold\"/>\n"
							  @"      <TagCategory Color=\"#94AA11150000\" Id=\"ce04f547-f7ee-40c9-ab66-d95a0c98034e\" Name=\"Miscellaneous\" Number=\"25\" Style=\"Bold\"/>"
							  @"    </TagCategories>\n"
							 ];
		[_result appendString:@"    <TagDefinitions>\n"];
		[_result appendString:_tagDefinitions];
		[_result appendString:@"    </TagDefinitions>\n"];
		[_result appendString:@"    <Tags>\n"];
		[_result appendString:_tagsStr];
		[_result appendString:@"    </Tags>\n"];
		[_result appendString:@"  </TagData>\n"];
	}
	
	[_result appendString:@"</FinalDraft>\n"];
	
	return _result;
}

- (void)appendLineAtIndex:(NSUInteger)index
{
	Line* line = self.parser.lines[index];
	NSArray *lines = self.parser.lines;
	
	// Skip omited lines
	if (line.omited) return;
	
	NSString* paragraphType = [self typeAsFDXString:line.type];
	if (paragraphType.length == 0) {
		//Ignore if no type is known
		return;
	}
		
	//If no double dialogue is currently in action, and a dialogue should be printed, check if it is followed by double dialogue so both can be wrapped in a double dialogue
	if (!_inDualDialogue && line.type == character) {
		for (NSUInteger i = index + 1; i < [lines count]; i++) {
			Line* futureLine = lines[i];
			if (futureLine.type == parenthetical ||
				futureLine.type == dialogue ||
				futureLine.type == empty) {
				continue;
			}
			if (futureLine.type == dualDialogueCharacter) {
				_inDualDialogue = YES;
			}
			break;
		}
		if (_inDualDialogue) {
			[_result appendString:@"    <Paragraph>\n"];
			[_result appendString:@"      <DualDialogue>\n"];
		}
	}
	
	
	
	//Append Open Paragraph Tag
	if (line.type == centered) {
		[_result appendFormat:@"    <Paragraph Alignment=\"Center\" Type=\"%@\">\n", paragraphType];
	} else {
		// Add scene number if it's a heading
		if (line.type == heading) {
			// Strip possible scene number
			if (line.sceneNumber) line.string = [line.string stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"#%@#", line.sceneNumber] withString:@""];
			[_result appendFormat:@"    <Paragraph Number=\"%@\" Type=\"%@\">\n", line.sceneNumber, paragraphType];
		} else {
			[_result appendFormat:@"    <Paragraph Type=\"%@\">\n", paragraphType];
		}
	}
	
	//Append content
	[self appendLineContents:line];
	
	//Apend close paragraph
	[_result appendString:@"    </Paragraph>\n"];
	
	//If a double dialogue is currently in action, check wether it needs to be closed after this
	if (_inDualDialogue) {
		if (index < [lines count] - 1) {
			//If the following line doesn't have anything to do with dialogue, end double dialogue
			Line* nextLine = lines[index+1];
			if (nextLine.type != empty &&
				nextLine.type != character &&
				nextLine.type != parenthetical &&
				nextLine.type != dialogue &&
				nextLine.type != dualDialogueCharacter &&
				nextLine.type != dualDialogueParenthetical &
				nextLine.type != dualDialogue) {
				_inDualDialogue = NO;
				[_result appendString:@"      </DualDialogue>\n"];
				[_result appendString:@"    </Paragraph>\n"];
			}
		} else {
			//If the line is the last line, it's also time to close the dual dialogue tag
			_inDualDialogue = NO;
			[_result appendString:@"      </DualDialogue>\n"];
			[_result appendString:@"    </Paragraph>\n"];
		}
	}
}

#define BOLD_PATTERN_LENGTH 2
#define ITALIC_UNDERLINE_PATTERN_LENGTH 1

- (void)appendLineContents:(Line*)line
{
	NSString *string = [self lineToXML:line];
	if (string.length) [_result appendString:string];
}

// These are no longer used because the attributes a
#define BOLD_STYLE @"Bold"
#define ITALIC_STYLE @"Italic"
#define UNDERLINE_STYLE @"Underline"

- (void)escapeString:(NSMutableString*)string
{
	[string replaceOccurrencesOfString:@"&"  withString:@"&amp;"  options:NSLiteralSearch range:NSMakeRange(0, [string length])];
	[string replaceOccurrencesOfString:@"\"" withString:@"&quot;" options:NSLiteralSearch range:NSMakeRange(0, [string length])];
	[string replaceOccurrencesOfString:@"'"  withString:@"&#x27;" options:NSLiteralSearch range:NSMakeRange(0, [string length])];
	[string replaceOccurrencesOfString:@">"  withString:@"&gt;"   options:NSLiteralSearch range:NSMakeRange(0, [string length])];
	[string replaceOccurrencesOfString:@"<"  withString:@"&lt;"   options:NSLiteralSearch range:NSMakeRange(0, [string length])];
}

- (NSString*)typeAsFDXString:(LineType)type
{
	switch (type) {
		case empty:
			return @"";
		case section:
			return @"";
		case synopse:
			return @"";
		case titlePageTitle:
			return @"";
		case titlePageAuthor:
			return @"";
		case titlePageCredit:
			return @"";
		case titlePageSource:
			return @"";
		case titlePageContact:
			return @"";
		case titlePageDraftDate:
			return @"";
		case titlePageUnknown:
			return @"";
		case heading:
			return @"Scene Heading";
		case action:
			return @"Action";
		case character:
			return @"Character";
		case parenthetical:
			return @"Parenthetical";
		case dialogue:
			return @"Dialogue";
		case dualDialogueCharacter:
			return @"Character";
		case dualDialogueParenthetical:
			return @"Parenthetical";
		case dualDialogue:
			return @"Dialogue";
		case transitionLine:
			return @"Transition";
		case lyrics:
			return @"Lyrics";
		case pageBreak:
			return @"";
		case centered:
			return @"Action";
		case more:
			return @"More";
	}
}

#define LINES_PER_PAGE 46
#define LINES_BEFORE_CENTER 18
#define LINES_BEFORE_CREDIT 2
#define LINES_BEFORE_AUTHOR 1
#define LINES_BEFORE_SOURCE 2

- (void)appendTitlePage
{
	/*
	 
	 Rewrite this to support the new static Title Page parsing
	 
	 */
	
	bool hasTitlePage = NO;
	
	Line* firstLine = _parser.lines[0];
	if (firstLine.type == titlePageTitle ||
		firstLine.type == titlePageAuthor ||
		firstLine.type == titlePageCredit ||
		firstLine.type == titlePageSource ||
		firstLine.type == titlePageDraftDate ||
		firstLine.type == titlePageContact) {
		hasTitlePage = YES;
	}
	
	if (!hasTitlePage) return;
	
	NSMutableString* title = [[self stringByRemovingKey:@"title:" fromString:[self firstStringForLineType:titlePageTitle]] mutableCopy];
	NSMutableString* credit = [[self stringByRemovingKey:@"credit:" fromString:[self firstStringForLineType:titlePageCredit]] mutableCopy];
	NSMutableString* author = [[self stringByRemovingKey:@"author:" fromString:[self firstStringForLineType:titlePageAuthor]] mutableCopy];
	NSMutableString* source = [[self stringByRemovingKey:@"source:" fromString:[self firstStringForLineType:titlePageSource]] mutableCopy];
	NSMutableString* draftDate = [[self stringByRemovingKey:@"draft date:" fromString:[self firstStringForLineType:titlePageDraftDate]] mutableCopy];
	NSMutableString* contact = [[self stringByRemovingKey:@"contact:" fromString:[self firstStringForLineType:titlePageContact]] mutableCopy];
	
	[self escapeString:title];
	[self escapeString:credit];
	[self escapeString:author];
	[self escapeString:source];
	[self escapeString:draftDate];
	[self escapeString:contact];
	
	[_result appendString:@"  <TitlePage>\n"];
	[_result appendString:@"    <Content>\n"];
	
	NSUInteger lineCount = 0;
	
	for (int i = 0; i < LINES_BEFORE_CENTER; i++) {
		[self appendTitlePageLineWithString:@"" center:NO];
		lineCount++;
	}
	
	if (title) {
		[self appendTitlePageLineWithString:title center:YES];
		lineCount++;
	}
	
	if (credit) {
		for (int i = 0; i < LINES_BEFORE_CREDIT; i++) {
			[self appendTitlePageLineWithString:@"" center:YES];
			lineCount++;
		}
		[self appendTitlePageLineWithString:credit center:YES];
	}
	
	if (author) {
		for (int i = 0; i < LINES_BEFORE_AUTHOR; i++) {
			[self appendTitlePageLineWithString:@"" center:YES];
			lineCount++;
		}
		[self appendTitlePageLineWithString:author center:YES];
	}
	
	if (source) {
		for (int i = 0; i < LINES_BEFORE_SOURCE; i++) {
			[self appendTitlePageLineWithString:@"" center:YES];
			lineCount++;
		}
		[self appendTitlePageLineWithString:source center:YES];
	}
	
	while (lineCount < LINES_PER_PAGE - 2) {
		[self appendTitlePageLineWithString:@"" center:NO];
		lineCount++;
	}
	
	if (draftDate) {
		[self appendTitlePageLineWithString:draftDate center:NO];
	}
	
	if (contact) {
		[self appendTitlePageLineWithString:contact center:NO];
	}
	
	[_result appendString:@"    </Content>\n"];
	[_result appendString:@"  </TitlePage>\n"];
}

- (void)appendTitlePageLineWithString:(NSString*)string center:(bool)center
{
	if (center) {
		[_result appendString:@"      <Paragraph Alignment=\"Center\">\n"];
	} else {
		[_result appendString:@"      <Paragraph>\n"];
	}
	
	[_result appendFormat:@"        <Text>%@</Text>\n", string];
	[_result appendString:@"      </Paragraph>\n"];
}

- (NSString*)firstStringForLineType:(LineType)type
{
	for (Line* line in _parser.lines) {
		if (line.type == type) {
			return line.string;
		}
	}
	return nil;
}

- (NSString*)stringByRemovingKey:(NSString*)key fromString:(NSString*)string
{
	if (string) {
		if ([[[string substringToIndex:key.length] lowercaseString] isEqualToString:key]) {
			string = [string stringByReplacingCharactersInRange:NSMakeRange(0, key.length) withString:@""];
		}
		while (string.length > 0 && [string characterAtIndex:0] == ' ') {
			string = [string stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:@""];
		}
	}
	return string;
}

- (NSString*)lineToXML:(Line*)line {
	NSAttributedString *string = line.attributedStringForFDX;
	NSMutableAttributedString *result = [[NSMutableAttributedString alloc] init];
	[line.contentRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		[result appendAttributedString:[string attributedSubstringFromRange:range]];
	}];
	
	NSMutableString *xmlString = [NSMutableString string];
	
	[result enumerateAttributesInRange:(NSRange){0, result.length} options:0 usingBlock:^(NSDictionary<NSAttributedStringKey,id> * _Nonnull attrs, NSRange range, BOOL * _Nonnull stop) {
		NSMutableString* text = [[result.string substringWithRange:range] mutableCopy];
		
		// Get stylization in the current attribute range
		NSString *styles = @"";
		NSString *styleString = attrs[@"Style"];
		
		if (styleString.length) {
			NSMutableArray *styleArray = [NSMutableArray arrayWithArray:[styleString componentsSeparatedByString:@","]];
			[styleArray removeObject:@""];
			
			styles = [NSString stringWithFormat:@" Style=\"%@\"", [styleArray componentsJoinedByString:@"+"]];
		}
		
		// Tags for the current range
		NSString *tagString = attrs[@"BeatTag"];
		NSString *tagAttribute = @"";
		if (tagString.length) {
			NSString *tagId = [self createId];
			
			NSInteger number = [self addFDXTag:tagString label:text tagId:tagId];
			tagAttribute = format(@" TagNumber=\"%lu\"", number);
		}
		
		// Escape quotes etc.
		[self escapeString:text];
		
		// Append snippet to paragraph
		[xmlString appendString:[NSString stringWithFormat:@"      <Text%@%@>%@</Text>\n", styles, tagAttribute, text]];
	}];
	
	return xmlString;
}

- (NSInteger)addFDXTag:(NSString*)tagName label:(NSString*)text tagId:(NSString*)tagId {
	/*
	NSDictionary *existingItems = _tagData[tagName];
	if (existingItems) {
		// This tag already exists.
		if (existingItems[text]) return [(NSNumber*)existingItems[text] integerValue];
	}
	 */
	
	// Add to the number
	_tagNumber += 1;
	
	NSDictionary *fdxData = fdxIds[tagName];
	if (!fdxData) {
		NSLog(@"FDXExport ERROR: No tag data found: %@", tagName);
		return NSNotFound;
	}

	// Add definition to list with its category number
	NSString *catId = fdxData[@"id"];
	NSString* definition = [NSString stringWithFormat:@"      <TagDefinition CatId=\"%@\" Id=\"%@\" Label=\"%@\" Number=\"%lu\"/>\n", catId, tagId, text, _tagNumber];
	[_tagDefinitions appendString:definition];
	
	// Add the tag itself
	NSString *tag = [NSString stringWithFormat:
					 @"      <Tag Number=\"%lu\">\n"
					 @"        <DefId>%@</DefId>\n"
					 @"      </Tag>\n",
					 _tagNumber, tagId
					];
	[_tagsStr appendString:tag];
	
	return _tagNumber;
}

- (NSString*)createId {
	// REWRITE MIGHT BE NEEDED:
	// Compare to a list of predefined tags (maybe a multi-level dict?) and return the previous ID
	// if a word is found which matches this current tag. Like Prop / Cloak, but not Costume / Cloak, though.
	// (... uh, never mind - I'm still unsure how FDX tagging ACTUALLY works)
	
	// FDX element IDs look like this:
	// 216f33fd-fc42-4269-be01-b05b18f815a0
	
	// It's not a hash or anything, just random numbers in a fixed sequence. I have no idea what
	// they're going for here. At least the probability for us hitting the number twice is so
	// astronomically small that I won't even bother to check if it's already used.

	NSUInteger seq1 = arc4random() % 0xFFFFFFFF;
	NSUInteger seq2 = arc4random() % 0xFFFF;
	NSUInteger seq3 = arc4random() % 0xFFFF;
	NSUInteger seq4 = arc4random() % 0xFFFF;
	NSUInteger seq5 = arc4random() % 0xFFFFFF;
	NSUInteger seq6 = arc4random() % 0xFFFFFF;
	
	NSString *hex = [NSString stringWithFormat:@"%@-%@-%@-%@-%@%@",
					 [NSString stringWithFormat:@"%08lX", (unsigned long)seq1].lowercaseString,
					 [NSString stringWithFormat:@"%04lX", (unsigned long)seq2].lowercaseString,
					 [NSString stringWithFormat:@"%04lX", (unsigned long)seq3].lowercaseString,
					 [NSString stringWithFormat:@"%04lX", (unsigned long)seq4].lowercaseString,
					 [NSString stringWithFormat:@"%06lX", (unsigned long)seq5].lowercaseString,
					 [NSString stringWithFormat:@"%06lX", (unsigned long)seq6].lowercaseString
					 ];
	NSLog(@"random id: %@", hex);
	return hex;
}

@end
