//
//  BeatFDXExport.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 8.2.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//
//  Based on FDXInterface by Hendrik Noeller,
//  originally translated to Objective C from: https://github.com/vilcans/screenplain/blob/master/screenplain/export/fdx.py

/*
 
 This implementation relies on a semi-clever hack. I'm converting style ranges (bold, italic, underline)
 created by the parser into custom attributes (ie. "Style": "Bold"). That attributed string can be
 requested from Line objects, along with ranges which contain Fountain markup, and we can use that data
 to create FDX compatible XML tags.
 
 This system also allows us to use FDX tagging, which requires some more weird hacking. It's a bit
 convoluted system right now, and baking tags into Line objects requires the original attributed
 string from the editor.

 As I'm writing this, screenplay tagging is very, very close to working, but requires some tweaking.
 
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
 
 
 For the individual tag definition IDs we need to create a lower-case UUID.
 Tags can then be attached to the screenplay using <Text TagNumber="1">some nice music</Text>
 
 Because the tagging system in Beat doesn't have literal definitions other than what's in the script,
 we'll just create a definition for each of the tags, UNLESS they are the same.
 
 
 */

#import <BeatParsing/BeatParsing.h>
#import <BeatCore/BeatCore.h>
#import "BeatFDXExport.h"


#define format(s, ...) [NSString stringWithFormat:s, ##__VA_ARGS__]
#define RevisionColors @[@"none", @"blue", @"orange", @"purple", @"green"]

static NSDictionary *fdxIds;

@interface BeatFDXExport ()
@property (nonatomic) ContinuousFountainParser *parser;
@property (nonatomic) NSMutableString *result;
@property (nonatomic) NSArray *preprocessedLines;

@property (nonatomic) NSMutableDictionary *tagData;

@property (nonatomic) NSMutableArray *tagDefinitions;
@property (nonatomic) NSMutableArray *tagItems;

@property (nonatomic) NSMutableString *tagDefinitionsStr;
@property (nonatomic) NSMutableString *tagIds;
@property (nonatomic) NSMutableString *tagsStr;
@property (nonatomic) NSInteger tagNumber;

@property (nonatomic) bool inDualDialogue;
@property (nonatomic) NSInteger dualDialogueCueCount;

@property (nonatomic) BeatPaperSize paperSize;

@end

@implementation BeatFDXExport

- (instancetype)initWithString:(NSString*)string attributedString:(NSAttributedString*)attrString includeTags:(bool)includeTags includeRevisions:(bool)includeRevisions paperSize:(BeatPaperSize)paperSize
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
	
	self.parser = [[ContinuousFountainParser alloc] initWithString:string];
	
	if (attrString) {
		// Bake tags
		[BeatTagging bakeAllTagsInString:attrString toLines:self.parser.lines];
		
		// Enumerate revision ranges and bake into lines
		[attrString enumerateAttribute:@"Revision" inRange:(NSRange){0, attrString.length} options:0 usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
			BeatRevisionItem *item = value;
			if (item.type == RevisionNone) return;
			
			NSArray *lines = [self.parser linesInRange:range];
			
			for (Line *line in lines) {
				if (!line.revisedRanges) line.revisedRanges = NSMutableDictionary.new;
				if (!line.removalSuggestionRanges) line.removalSuggestionRanges = NSMutableIndexSet.indexSet;
				
				NSRange rangeInLine = [line globalRangeToLocal:range];
				
				if (item.type == RevisionAddition) {
					// Add different revisions into the line
					if (!line.revisedRanges[item.colorName]) line.revisedRanges[item.colorName] = NSMutableIndexSet.new;
					[line.revisedRanges[item.colorName] addIndexesInRange:rangeInLine];
				}
				else if (item.type == RevisionRemovalSuggestion) [line.removalSuggestionRanges addIndexesInRange:rangeInLine];
			}
		}];
	}
	
	self.paperSize = paperSize;
	
	self.tagData = [NSMutableDictionary dictionary];

	self.tagItems = [NSMutableArray array];
	self.tagDefinitions = [NSMutableArray array];
	
	self.tagDefinitionsStr = [NSMutableString string];
	self.tagsStr = [NSMutableString string];
	
	[self createFDX];
	
	return self;
}

- (NSString*)createCategories {
	NSMutableString *c = [NSMutableString string];
	[c appendString:format(@"      <TagCategory Color=\"#000000000000\" Id=\"8e5e75c2-713b-47df-a75f-f12648b98ded\" Name=\"Synopsis\" Number=\"1\" Style=\"Bold\"/>")];
	[c appendString:format(@"      <TagCategory Color=\"#%@\" Id=\"01fc9642-84ff-4366-b37c-a3068dee57e8\" Name=\"Cast Members\" Number=\"2\" Style=\"Bold\"/>", [BeatTagging hexForKey:@"Cast"])];
	[c appendString:format(@"      <TagCategory Color=\"#%@\" Id=\"028a4e2b-b507-4d09-88ab-90e3edae9071\" Name=\"Background Actors\" Number=\"3\" Style=\"Bold\"/>", [BeatTagging hexForKey:@"Extras"])];
	[c appendString:format(@"      <TagCategory Color=\"#94AA11150000\" Id=\"0377dbe6-77a3-41af-bda8-86eb2468fdbf\" Name=\"Stunts\" Number=\"4\" Style=\"Bold\"/>")];
	[c appendString:format(@"      <TagCategory Color=\"#%@\" Id=\"04721a56-f54b-49c8-80ad-d53887d6b851\" Name=\"Vehicles\" Number=\"5\" Style=\"Bold\"/>", [BeatTagging hexForKey:@"Vehicle"])];
	[c appendString:format(@"      <TagCategory Color=\"#%@\" Id=\"05c556eb-6bc1-4a3a-b09f-f8b5ba1b6afa\" Name=\"Props\" Number=\"6\" Style=\"Bold\"/>", [BeatTagging hexForKey:@"Prop"])];
	[c appendString:format(@"      <TagCategory Color=\"#94AA11150000\" Id=\"47b02ff1-5161-4137-b736-f36eebba7643\" Name=\"Camera\" Number=\"7\" Style=\"Bold\"/>")];
	[c appendString:format(@"      <TagCategory Color=\"#94AA11150000\" Id=\"069e18b8-2109-4f3d-94e7-d802027a60a8\" Name=\"Special Effects\" Number=\"8\" Style=\"Bold\"/>")];
	[c appendString:format(@"      <TagCategory Color=\"#%@\" Id=\"0726fa85-1e65-4ab8-87de-bf21d09b01f0\" Name=\"Wardrobe\" Number=\"9\" Style=\"Bold\"/>", [BeatTagging hexForKey:@"Costume"])];
	[c appendString:format(@"      <TagCategory Color=\"#%@\" Id=\"08ae1eef-32ce-415f-9a9b-0982d2453ec4\" Name=\"Makeup/Hair\" Number=\"10\" Style=\"Bold\"/>", [BeatTagging hexForKey:@"Makeup"])];
	[c appendString:format(@"      <TagCategory Color=\"#%@\" Id=\"09cb0d1c-ce01-4f22-bb64-b5f2e6c491c6\" Name=\"Animals\" Number=\"11\" Style=\"Bold\"/>", [BeatTagging hexForKey:@"Animal"])];
	[c appendString:format(@"      <TagCategory Color=\"#%@\" Id=\"0ae40617-cc7c-48e6-ae2b-5aaecc09986f\" Name=\"Animal Wrangler\" Number=\"12\" Style=\"Bold\"/>", [BeatTagging hexForKey:@"Animal"])];
	[c appendString:format(@"      <TagCategory Color=\"#%@\" Id=\"0b0b44c9-aa4b-4c40-88b1-d94472ad7a26\" Name=\"Music\" Number=\"13\" Style=\"Bold\"/>", [BeatTagging hexForKey:@"Music"])];
	[c appendString:format(@"      <TagCategory Color=\"#94AA11150000\" Id=\"0ce7d308-096d-4603-8fe8-349f72cd89ff\" Name=\"Sound\" Number=\"15\" Style=\"Bold\"/>")];
	[c appendString:format(@"      <TagCategory Color=\"#94AA11150000\" Id=\"c86eae40-3b01-41c3-a7de-6859e6ec971d\" Name=\"Art Department\" Number=\"16\" Style=\"Bold\"/>")];
	[c appendString:format(@"      <TagCategory Color=\"#94AA11150000\" Id=\"0debb71b-5743-4c53-80cc-e17e841ce645\" Name=\"Set Dressing\" Number=\"17\" Style=\"Bold\"/>")];
	[c appendString:format(@"      <TagCategory Color=\"#94AA11150000\" Id=\"0e7a8fc5-5441-4bad-a9bf-5ddd3fe51c69\" Name=\"Greenery\" Number=\"18\" Style=\"Bold\"/>")];
	[c appendString:format(@"      <TagCategory Color=\"#94AA11150000\" Id=\"0ff5cda4-4d43-4cfe-940f-91380c46fdad\" Name=\"Special Equipment\" Number=\"19\" Style=\"Bold\"/>")];
	[c appendString:format(@"      <TagCategory Color=\"#94AA11150000\" Id=\"109d0eaa-0334-4823-ac0c-b44d3f209dc4\" Name=\"Security\" Number=\"20\" Style=\"Bold\"/>")];
	[c appendString:format(@"      <TagCategory Color=\"#94AA11150000\" Id=\"1179a4b1-70ee-4011-b4a2-809a0af09e92\" Name=\"Additional Labor\" Number=\"21\" Style=\"Bold\"/>")];
	[c appendString:format(@"      <TagCategory Color=\"#%@\" Id=\"12ab0932-e3b9-4b4a-bcd0-3da1b4e61d5e\" Name=\"Visual Effects\" Number=\"23\" Style=\"Bold\"/>", [BeatTagging hexForKey:@"VFX"])];
	[c appendString:format(@"      <TagCategory Color=\"#94AA11150000\" Id=\"135cc9d1-c4d5-4d00-83d9-571f584ea9cd\" Name=\"Mechanical Effects\" Number=\"24\" Style=\"Bold\"/>")];
	[c appendString:format(@"      <TagCategory Color=\"#94AA11150000\" Id=\"ce04f547-f7ee-40c9-ab66-d95a0c98034e\" Name=\"Miscellaneous\" Number=\"25\" Style=\"Bold\"/>")];
	[c appendString:format(@"      <TagCategory Color=\"#94AA11150000\" Id=\"15b6f4fd-4e74-4ad8-9971-b239d88c2997\" Name=\"Notes\" Number=\"26\" Style=\"Bold\"/>")];
	[c appendString:format(@"      <TagCategory Color=\"#94AA11150000\" Id=\"63c140da-ef2b-491a-b416-b46f461abb89\" Name=\"Script Day\" Number=\"27\" Style=\"Bold\"/>")];
	[c appendString:format(@"      <TagCategory Color=\"#94AA11150000\" Id=\"849f1ebf-5507-4f33-bff6-3a5b4d73be14\" Name=\"Unit\" Number=\"28\" Style=\"Bold\"/>")];
	[c appendString:format(@"      <TagCategory Color=\"#94AA11150000\" Id=\"70877d87-30ef-45b6-be46-c6fa94b83a71\" Name=\"Sequence\" Number=\"29\" Style=\"Bold\"/>")];
	[c appendString:format(@"      <TagCategory Color=\"#94AA11150000\" Id=\"c5e89e4d-f83e-4c28-950c-92a63f1b5f26\" Name=\"Location\" Number=\"30\" Style=\"Bold\"/>")];
	[c appendString:format(@"      <TagCategory Color=\"#94AA11150000\" Id=\"216f33fd-fc42-4269-be01-b05b18f815a0\" Name=\"Comments\" Number=\"31\" Style=\"Bold\"/>")];
	
	return c;
}

- (NSString*)fdxString {
	return self.result;
}

- (NSString*)createFDX {
	return [self createFDXwithRevisions:NO tags:NO];
}
- (NSString*)createFDXwithRevisions:(bool)includeRevisions tags:(bool)includeTags {

	if (self.parser.lines.count == 0) return @"";

	_result = [@"<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\" ?>\n"
			   @"<FinalDraft DocumentType=\"Script\" Template=\"No\" Version=\"1\">\n"
			   @"\n"
			   @"  <Content>\n" mutableCopy];
	
	_inDualDialogue = NO;
	
	_preprocessedLines = [self preprocessLines];
	
	for (int i = 0; i < _preprocessedLines.count; i++) {
		[self appendLineAtIndex:i];
		//inDualDialogue = [self appendLineAtIndex:i fromLines:parser.lines toString:result inDualDialogue:inDualDialogue tags:tags];
	}
	
	[_result appendString:@"  </Content>\n"];
	
	[self appendTitlePage];
	[self appendElementStyles];
	[self appendPageLayout];
	
	// Tagging data
	[_result appendString:@"  <TagData>\n"];
	[_result appendString:@"    <TagCategories>\n"];
	[_result appendString:[self createCategories]];
	[_result appendString:@"    </TagCategories>\n"];
	[_result appendString:@"    <TagDefinitions>\n"];
	[_result appendString:_tagDefinitionsStr];
	[_result appendString:@"    </TagDefinitions>\n"];
	[_result appendString:@"    <Tags>\n"];
	[_result appendString:_tagsStr];
	[_result appendString:@"    </Tags>\n"];
	[_result appendString:@"  </TagData>\n"];

	// Revision data
	[_result appendString:@"	<Revisions ActiveSet=\"1\" Location=\"7.75\" RevisionsShown=\"Active\" ShowAllMarks=\"No\" ShowAllSets=\"No\">\n"];
	[_result appendString:format(@"		<Revision Color=\"#%@\" FullRevision=\"No\" ID=\"1\" Mark=\"*\" Name=\"First Revision\" PageColor=\"#FFFFFFFFFFFF\" Style=\"\"/>\n", [BeatColors colorWith16bitHex:@"blue"])];
	[_result appendString:format(@"		<Revision Color=\"#%@\" FullRevision=\"No\" ID=\"2\" Mark=\"**\" Name=\"First Revision\" PageColor=\"#FFFFFFFFFFFF\" Style=\"\"/>\n", [BeatColors colorWith16bitHex:@"orange"])];
	[_result appendString:format(@"		<Revision Color=\"#%@\" FullRevision=\"No\" ID=\"3\" Mark=\"+\" Name=\"First Revision\" PageColor=\"#FFFFFFFFFFFF\" Style=\"\"/>\n", [BeatColors colorWith16bitHex:@"purple"])];
	[_result appendString:format(@"		<Revision Color=\"#%@\" FullRevision=\"No\" ID=\"4\" Mark=\"++\" Name=\"First Revision\" PageColor=\"#FFFFFFFFFFFF\" Style=\"\"/>\n", [BeatColors colorWith16bitHex:@"green"])];
	[_result appendString:@"	</Revisions>\n"];
	/*
	<Revisions ActiveSet="1" Location="7.75" RevisionMode="No" RevisionsShown="Active" ShowAllMarks="No" ShowAllSets="No" ShowPageColor="No">
	  <Revision Color="#FFFF7E7E7979" FullRevision="No" ID="1" Mark="*" Name="First Revision" PageColor="#FFFFFFFFFFFF" Style=""/>
	 */
	
	[_result appendString:@"</FinalDraft>\n"];
	
	return _result;
}

- (void)appendPageLayout {
	[_result appendString:@"  <PageLayout BackgroundColor=\"#FFFFFFFFFFFF\" BottomMargin=\"45\" BreakDialogueAndActionAtSentences=\"Yes\" DocumentLeading=\"Normal\" FooterMargin=\"36\" ForegroundColor=\"#000000000000\" HeaderMargin=\"29\" InvisiblesColor=\"#808080808080\" TopMargin=\"0\" UsesSmartQuotes=\"Yes\">"];
	
	// Add correct paper size
	if (self.paperSize == BeatA4) [_result appendString:@"    <PageSize Height=\"11.70\" Width=\"8.30\"/>"];
	else [_result appendString:@"    <PageSize Height=\"11.00\" Width=\"8.50\"/>"];
	
	[_result appendString:@"  </PageLayout>"];
}

- (NSArray*)preprocessLines {
	NSMutableArray *lines = [NSMutableArray array];
	
	Line *previousLine;
	for (Line* line in self.parser.lines) {
		// Fix a weird bug
		if (line.type == empty && line.string.length && !line.string.containsOnlyWhitespace) line.type = action;
		
		// Skip omited lines
		if (line.omitted) {
			if (line.type == empty) previousLine = line;
			continue;
		}

		if (((line.type == action && previousLine.type == action) ||
			(line.type == lyrics && previousLine.type == lyrics)) &&
			(previousLine.length > 0 && previousLine.type == action)) {
			[previousLine joinWithLine:line];
			continue;
		}
		
		// Mark dual dialogue
		if (line.type == dualDialogueCharacter) {
			NSInteger i = lines.count - 1;
			while (i >= 0) {
				Line *precedingLine = lines[i];
				
				if (!(previousLine.isDialogueElement || previousLine.isDualDialogueElement)) break;
				
				if (precedingLine.type == character) {
					precedingLine.nextElementIsDualDialogue = YES;
					break;
				}
				i--;
			}
		}
		
		[lines addObject:line];
		previousLine = line;
	}
	
	return  lines;
}

- (void)appendLineAtIndex:(NSUInteger)index
{
	NSArray *lines = self.preprocessedLines;
	Line* line = lines[index];
		
	NSString* paragraphType = [self typeAsFDXString:line.type];
	if (paragraphType.length == 0) {
		//Ignore if no type is available
		return;
	}
	// Add section depth for outline elements
	if (line.type == section) {
		paragraphType = format(@"%@ %lu", paragraphType, line.sectionDepth);
	}
	
	NSMutableArray<NSString*>* additionalTags = NSMutableArray.new;
	NSMutableArray<NSString*>* paragraphStyles = NSMutableArray.new;
	[paragraphStyles addObject:[NSString stringWithFormat:@"Type=\"%@\"", paragraphType]];
	
	// Create dual dialogue block.
	// This is a mess, fix ASAP.
	if (line.type == character && line.nextElementIsDualDialogue && !_inDualDialogue) {
		[_result appendString:@"    <Paragraph>\n"];
		[_result appendString:@"      <DualDialogue>\n"];
		
		_inDualDialogue = YES;
		_dualDialogueCueCount = 1;
	}
	else if (line.type == dualDialogueCharacter && _inDualDialogue) {
		_dualDialogueCueCount = 2;
	}
	else if (_inDualDialogue && line.type == character) {
		_inDualDialogue = NO;
		_dualDialogueCueCount = 0;
		[_result appendString:@"      </DualDialogue>\n"];
		[_result appendString:@"    </Paragraph>\n"];
	}
	
	// Append special styles for some elements
	if (line.type == centered) {
		[paragraphStyles addObject: @"Alignment=\"Centered\""];
	}
	else if (line.type == heading) {
		// Strip possible scene number
		//if (line.sceneNumber) line.string = [line.string stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"#%@#", line.sceneNumber] withString:@""];
		
		[paragraphStyles addObject:[NSString stringWithFormat:@"Number=\"%@\"", line.sceneNumber]];
		
		if (line.color) {
			NSString* color = [BeatColors colorWith16bitHex:line.color];
			if (color != nil) {
				NSString* sceneProperties = format(@"      <SceneProperties Color=\"#%@\" Title=\"\">\n        <SceneArcBeats />\n      </SceneProperties>\n", color);
				[additionalTags addObject:sceneProperties];
			}
		}
	}
		
	[_result appendFormat:@"    <Paragraph %@>\n", [paragraphStyles componentsJoinedByString:@" "]];
	for (NSString* additionalTag in additionalTags) {
		[_result appendString:additionalTag];
	}
	
	//Append content
	[self appendLineContents:line];
	
	//Apend close paragraph
	[_result appendString:@"    </Paragraph>\n"];
	
	// If a double dialogue is currently in action, check wether it needs to be closed after this
	// This is a duct-tape fix, this has to be cleaned up ASAP.
	if (_inDualDialogue) {
		
		if (index < lines.count - 1) {
			//If the following line doesn't have anything to do with dialogue, end double dialogue
			Line* nextLine = lines[index+1];
			if (nextLine.type != empty &&
				nextLine.type != character &&
				nextLine.type != parenthetical &&
				nextLine.type != dialogue &&
				nextLine.type != dualDialogueCharacter &&
				nextLine.type != dualDialogueParenthetical &
				nextLine.type != dualDialogue &&
				nextLine.string.length > 0) {
				_inDualDialogue = NO;
				[_result appendString:@"      </DualDialogue>\n"];
				[_result appendString:@"    </Paragraph>\n"];
			}
		}
	}
	
	if (line == _preprocessedLines.lastObject && _inDualDialogue) {
		//If the line is the last line, it's also time to close the dual dialogue tag
		_inDualDialogue = NO;
		[_result appendString:@"      </DualDialogue>\n"];
		[_result appendString:@"    </Paragraph>\n"];
	}
}

#define BOLD_PATTERN_LENGTH 2
#define ITALIC_UNDERLINE_PATTERN_LENGTH 1

- (void)appendLineContents:(Line*)line
{
	NSString *string = [self lineToXML:line];
	if (string.length) [_result appendString:string];
}

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
			return @"Outline";
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
		case shot:
			return @"Shot";
		case more:
			return @"More";
		case dualDialogueMore:
			return @"More";
		case typeCount:
			return @"";
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

- (void)appendElementStyles {
	[_result appendString:@"\
	<ElementSettings Type=\"Lyrics\">\n\
		<FontSpec  Style=\"Italic\"/>\
		<ParagraphSpec Alignment=\"Center\"/>\n\
		<Behavior PaginateAs=\"Action\" ReturnKey=\"Action\" />\n\
	 </ElementSettings>"];
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
	NSMutableAttributedString *result = NSMutableAttributedString.new;
	[line.contentRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		[result appendAttributedString:[string attributedSubstringFromRange:range]];
	}];
	
	NSMutableString *xmlString = [NSMutableString string];
	__block NSString* styleString = @"";
	
	[result enumerateAttributesInRange:(NSRange){0, result.length} options:0 usingBlock:^(NSDictionary<NSAttributedStringKey,id> * _Nonnull attrs, NSRange range, BOOL * _Nonnull stop) {
		NSMutableString* text = [[result.string substringWithRange:range] mutableCopy];
		
		// Get stylization in the current attribute range
		NSMutableSet* styles = attrs[@"Style"];
		NSString* additionalStyles = @"";
		
		// Add revisions
		NSString* revision = attrs[BeatRevisions.attributeKey];
		if (revision.length > 0) {
			// Get color for revision.
			NSString *highlightColor = [BeatColors colorWith16bitHex:revision];
			NSInteger revisionNumber = [BeatRevisions.revisionColors indexOfObject:revision] + 1; // + 1 as arrays begin from 0
			additionalStyles = [additionalStyles stringByAppendingFormat:@" Color=\"#%@\" RevisionID=\"%lu\"", highlightColor.uppercaseString, revisionNumber];
		}
		
		if (styles.count > 0) {
			// Highlighting, Addition and Removal do not conform to FDX styles
			if ([styles containsObject:@"Highlight"]) {
				[styles removeObject:@"Highlight"];
				NSString *highlightColor = [BeatColors colorWith16bitHex:@"blue"];
				additionalStyles = [additionalStyles stringByAppendingFormat:@" Color=\"#%@\"", highlightColor.uppercaseString];
			}
			if ([styles containsObject:@"RemovalSuggestion"]) {
				[styles removeObject:@"RemovalSuggestion"];
				[styles addObject:@"Strikeout"];
				NSString *highlightColor = [BeatColors colorWith16bitHex:@"fdxRemoval"];
				additionalStyles = [additionalStyles stringByAppendingFormat:@" Background=\"#%@\"", highlightColor.uppercaseString];
			}
		}
				
		NSString *styleClasses = @"";
		// Set stylization for action, dialogue and dual dialogue elements.
		// Ignore other blocks, because Final Draft doesn't like additional styles in those.
		if (styles.count > 0 &&
			(line.type == action || line.type == dialogue || line.type == dualDialogue))
			styleClasses = [NSString stringWithFormat:@"Style=\"%@\"", [styles.allObjects componentsJoinedByString:@"+"]];
		
		styleString = [NSString stringWithFormat:@" %@%@", styleClasses, additionalStyles];
		
		// Tags for the current range
		BeatTag *tag = attrs[@"BeatTag"];
		NSString *tagAttribute = @"";
		
		if (tag) {
			NSInteger number = [self addFDXTag:tag];
			tagAttribute = format(@" TagNumber=\"%lu\"", number);
		}
		
		// Escape quotes etc.
		[self escapeString:text];
		
		// Remove old-style carriage returns (just in case)
		// NSString* c = [NSString stringWithFormat:@"%c", 0x03];
		
		// Remove unwanted characters
		NSArray* l = [text componentsSeparatedByCharactersInSet:NSCharacterSet.badControlCharacters];
		[text setString:[l componentsJoinedByString:@""]];
		
		// Append snippet to paragraph
		[xmlString appendString:[NSString stringWithFormat:@"      <Text%@%@>%@</Text>\n", styleString, tagAttribute, text]];
	}];
	
	return xmlString;
}

- (NSInteger)addFDXTag:(BeatTag*)tag {
	if (![_tagItems containsObject:tag]) {
		[_tagItems addObject:tag];
		[_tagDefinitions addObject:tag.definition];
		NSInteger number = [_tagItems indexOfObject:tag] + 1;
		
		// Add definition
		NSDictionary *fdxTag = fdxIds[tag.key];
	
		NSString* definition = [NSString stringWithFormat:@"      <TagDefinition CatId=\"%@\" Id=\"%@\" Label=\"%@\" Number=\"%lu\"/>\n", fdxTag[@"id"], tag.defId.lowercaseString, tag.definition.name, number];
		[_tagDefinitionsStr appendString:definition];
		
		// Add the tag itself
		NSString *tagStr = [NSString stringWithFormat:
						 @"      <Tag Number=\"%lu\">\n"
						 @"        <DefId>%@</DefId>\n"
						 @"      </Tag>\n",
						 number, tag.defId.lowercaseString
						];
		[_tagsStr appendString:tagStr];
		
		// Return the number for to be used in the script
		return number;
	} else {
		return [_tagItems indexOfObject:tag] + 1;
	}
}

- (NSString*)createId {
	NSUUID *uuid = [NSUUID UUID];
	return [uuid UUIDString];
}

@end
/*
 
 pelkään että olen kuollut sisältä
 
 */
