# Changelog

## Beat 1.998.0

- Lot of minor bug fixes
- Moved templates to BeatCore framework
- Moved this and that to base class, including registering views
- Focus mode
- Added selection observer protocol


## Beat 1.997.8

- Reanimating the ad hoc distribution
- Moved plugin methods to a separate agent
- Added very rudimentary license management
- Fixed translations



## Beat 1.997.7

- Some minor bug fixes


## Beat 1.997.6

- Lot of minor fixes to attributes and undoing
- Compressed images to make the app a bit smaller
- Added page separators, even for inline page breaks


## Beat 1.997.5

- Further bug fixes to show revisions as text color
- Fixes to bugs caused by previous version..... including when refreshing some registered views
- A lot of fixes for bugs caused by my OS-agnostic overhaul :-(


## Beat 1.997.3-4

Lots of bug fixes


## Beat 1.997.2

I started moving stuff into a OS-agnostic `BeatDocumentBaseController` class to avoid overlap between macOS and iOS document code.

- Preliminary markup support in notepad
- Fixed bugs with overlapping formatting
- Fixed drag & drop in text view
- Fixed and optimized character filtering in outline
- Optimization


## Beat 1.997.1

- All sorts of fixes


## Beat 1.997.0

- Fixes issues with Cyrillic ѐ (ye with grave)
- Toggle dual dialogue now works correctly again
- Fixed faulty revision markers when editing character cues
- Adding parenthesis before a closing parenthesis no longer creates extra symbols
- Preview is no longer empty when the document has only a title page 
- Plugin HTML views now support loading content from the bundle 


## Beat 1.996.9

- Fixed popover button on/off glitch
- Added options to print sections, synopsis lines and notes (which required a ton of refactoring here and there)
- Fixed a bug with long dialogue blocks with no sentence breaks
- Fixed the tutorial
- Added support for non-monospaced fonts (macOS)
- Template support
- Fixed issues with color customization
- Added macros: `{{ macro }}`, `{{ serial page = num }}`
- Made some edge case pagination situations a bit more pleasing  
- Move to next/prev revision of current generation
- Interface with other open documents via plugin API
- Fixed some logical issues with race conditions


## Beat 1.99.x

I've forgotten to update the log, but here it goes:

- Tons of changes for cross-platform compatibility
- Modularization of code
- Better export settings and preprocessing
- Lots and lots of bug fixes
- Plugin API enhancements, including stuff with pagination data
- Rewritten note parsing
- Visual cues for beats and markers  


## Beat 1.98.x

- Native rendering rewritten from scratch, once again, almost working already. Pagination and rendering are also separated from each other, with protocols for rendering on different platforms.
- Tons of plugin API extensions
- Stability fixes
- Fixes to parsing and export
- Moved pagination into a separate framework


## Beat 1.97.5-7

- Fixed some parsing issues
- Added support for some Turkic language uppercase symbols
- Native `NSAttributedString` rendering is *almost* there
- Outline view drag & drop fixes
- `synopsis` is no longer an outline object


## Beat 1.97.x

- Parsing moved into a separate framework (**requires testing**)


## Beat 1.97.x

- Pagination is implemented as a queue of operations, and the old word-by-word height checking is replaced by a more sensible line fragment calculation
- Formatting now checks if the current line already has parts of the formatting applied
- Better Mojave support via new fallback images 
- Plugin API expansions, including modules


## Beat 1.96.0

- Fixed issues with conditional flow when text changes (shouldChange...)
- Changed tab press behavior


## Beat 1.95.x

- Some plugin window logic fixed
- Further pagination bugs fixed... maybe
- View now scrolls to where changes were made when undoing
- Parsing and line lookup issues fixed
- Multiple other issues fixed and streamlined


## Beat 1.94.6

- New dialogue pagination system
- A lot of minor memory optimization etc



## Beat 1.94.4

- New print dialog + custom styles


## Beat 1.94.3

- Hotfix for weird UTI issues
- Added context menu item for adding reviews


## Beat 1.94.2

- Review mode
- Fixed a bug with scene filtering 


## Beat 1.94.0

- Lots of weirdness and Big Sur crashes fixed


## Beat 1.93.4

- Fixed average scene length in *Screenplay Statistics*
- Fixed the *Lock/Unlock Document* button
- Fixed time of day stats in *Screenplay Statistics*


## Beat 1.93.3

- Fixed a bug in FDX export which joined almost every line


## Beat 1.93.2

- Fixed some memory leaks with documents
- Fixed character stylization bugs with revised lines
- Fixed issues with editor context menu
- FDX export issues with split-paragraph omissions fixed


## Beat 1.93.1

- New *Screenplay* menu, which contains production and workflow related actions
- Revision system has been rethought, with change markers for only the changed ranges in both editor and print/export
- Lot of optimization in editor
- New API calls


## Beat 1.92.9

- Converted a single class to Swift (BeatRecentFileCell)
- Bugs with jumping to scene from preview fixed
- New class BeatScreenplay for transferring data between the document and PDF export/print. This should be expanded to contain document settings etc.  
- Sanitized formatting code in Document.m
- Fixed pagination issues with dialogue containing parentheticals mid-block 
- Fixed bugs with toggling bold/italic formatting
- Fixed bugs with localized revision colors
- New revision markers when exporting


## Beat 1.92.8

- Some localization bugs fixed
- Collapsing sections in Outline View, with reorganizing whole sections
- Fixed a bug with filtering scenes by character in OutlineScene objects


## Beat 1.92.7

- Localization support
- Minor note parsing fixes
- Further index card bugs fixed
- Some autocomplete weirdness with scene headings fixed
- Fixed dual dialogue symbol rendering in editor
- Assign scene colors from context menu in editor 
- File names in launch screen truncated from middle


## Beat 1.92.6

- Fixed a bug with drag & drop in Index Card View


## Beat 1.92.5

- Added a setting for changing scene heading spacing
- New launch screen
- Minor plugin API fixes


## Beat 1.92.4

- Fixed missing CSS and JS files for manual 
- Harmonized CSS in HTML export


## Beat 1.92.3

- Added widget support to plugin API (not yet publicly available)
- Multiple API fixes
- Fixes to outlining
- Manual rewrites
- Force symbols in joined paragraphs no longer break formatting
- Fixes to pagination and screenplay rendering (with a massive contribution by Fredrik T. Olsson)
- Manual now supports dark mode (contribution by BFLTP)


## Beat 1.92.2

- Plugin API expansions (including printing HTML files)
- Fixed more paper size bugs
- Fixed bugs with turning autocomplete off
- Fixed a bug which caused headings not be auto-capitalized
- Printed revision markers on right side


## Beat 1.92.1

- Rewritten Plugin Library
- Parsing fixes


## Beat 1.91.9

- Plugin API now reports errors in the console rather than as modal alert messages when in a background thread.


## Beat 1.91.8

- Fixed a serious bug in Final Draft export
- Fixed minor parsing issues
- Fixed a bug which caused extra spaces when setting color for a scene
- Some other stuff I've forgotten


## Beat 1.91.4

- Sidebar tabs with a notepad & dialogue/character list
- Remaining references to male/female removed from code and replaced with woman/man 
 

## Beat 1.91.x

Multiple fixes for minor bugs, including but not limited to:
- some parsing issues fixed, including 2-letter character cues
- rendering optimization
- title page preview errors fixed
- marker support added
- copy & paste revisions


## Beat 1.90.4

- Hide Fountain markup
- Multiline block parsing implemented in parser
- Fixed underlining in breaking dialogue across pages
- Fixed tons of other stuff
- Preferences panel
- Fixed FDX export
- User manual
- Fixes the jumping view in Typewriter Mode


## Beat 1.90.3

- Hotfix for a minor bug


## Beat 1.90.2

- Fixed a character name collection bug


## Beat 1.90.1

- Fixed problems with undoing uppercase elements with layout manager delegation
- ... and hence deprecated parser delegate methods 
- Fixed bugs with saving genders
- Fixed title bar bugs when finding or replacing text
- Fixed a bug with the editor not becoming focused after dismissing find/replace
- Slightly revised Screenplay Analysis UI
- Added option to revert to older versions


## Beat 1.90.0

- Copy & paste revised text (and probably tags in the future, too)
- Fixed visual bugs in sidebar + added slight animation
- Fixed some sizing busg
- Fixed scene heading input bugs
- Fixed title bar bugs in card view and print preview
- Minor optimizations


## Beat 1.89.9

- Fixed plugin window bugs
- Fixed plugin API memory issues with Big Sur
- Title bar harmonized with Big Sur UI
- Fixed minor bugs, such as the colors not saving as intended
- Use system accent color for selected text
- Option to select between serif / sans serif font
- Fixed typewriter mode weirdness


## Beat 1.89.6

- Outline parsing was optimized
- `OutlineScene` class is now a bit more sanitized and sensible
- Moving omitted scenes now works more reliably  



## Beat 1.89.5

- Fixed a bug with paper sizing in print panel


## Beat 1.89.4

- Plugin API fixes and expansions


## Beat 1.89.3

- Lines now know the parser they reside inside, allowing easier access to their index etc. in the future
- Plugin API expansions and fixes
- Document contents can be locked
- Margin view is now layer-backed, and no longer based on `drawRect`


## Beat 1.89.2

- Plugin API additions and sanitizing
- Other minor things, I guess


## Beat 1.89.1

I've forgotten most of the changes, but:
- A lot of plugin API fixes and expansions
- Overlapping formatting fixes
- Some parsing issues fixed


## Beat 1.89

- Color-code revised pages
- Save window position
- Save revision mode status
- Some bug fixes, can't remember what
- Some code was sanitized


## Beat 1.87.-

A catastrophic version with multiple changes to Plugin API, exporting and stuff. Some changes include:

- Fixes to exporting overlapping formatting (ie. bold-italic etc.)
- Text input fixes
- Performance optimizations
- `BeatExportSettings` class, which could potentially make exports cleaner and easier, as long as I have the time to clean up my clunky previous code.


## Beat 1.86

- Plugins can now be left running in the background


## Beat 1.85.1

- Fixed a bug in FDX export which could cause the export to fail


## Beat 1.84/85

- Crashing bug with Sparkle should be fixed now
- Plugin HTML panel can now be closed with esc
- Bug fixes to pagination and print layout
- Plugin method `Beat.scrollToLine()` now works
- Plugin console (`Beat.openConsole`)


## Beat 1.83

- Fixed a bug with sections in dark mode
- Added the option to filter out index cards, and changed how 2nd and 3rd level section are displayed
- Fixes to index card UI in dark mode
- Migrated ad hoc distribution to be sandboxed. We're now using Sparkle 2.0.
- Further fixes to layout bugs
- Fixed Final Draft export for in-paragraph line breaks, dual dialogue and lyrics



## Beat 1.82

- Fixed revision mode bugs which could cause crashes on older macOS systems
- Fixed bugs with scene numbering not toggling on and off correctly
- Scene numbering logic streamlined: toggling scene numbers on/off in editor now affects the print preview, too. Printing dialog still has its own checkbox for printing the numbers, and its value is saved separately  

## Beat 1.81

- Minor fixes to stuff I can't remember

## Beat 1.8

- Tagging support with FDX export (although hidden)
- Revision tracking, with export to FDX
- Quick Settings button
- UI cleanup
- Shadow under "paper"
- Flashing cursor bugs fixed
- Rewritten HTML (print) export
- Rewritten FDX export
- Plugin parser fixes
- Multiple other fixes here and there


## Beat 1.7.4

- Started implementing tagging into Beat. The goal is to be able to ship a tagged FDX straight out of Beat.
- Fixed a bug which caused document settings not to be saved when using a fresh document 
- Fixed bugs when importing OSF files created in Fade In 4
- Fixed bugs with jumping to prev/next scene 


## Beat 1.7.3

- Some bug fixes, can't remember anymore


## Beat 1.7.2

- Icon conforms to Big Sur guidelines
- Bug fix: Timer hides as intended
- Timer fades back in only when the mouse cursor is at the bottom-end of the window
- Plugin memory issues fixed
- Added the option to open Plugin Folder from within the app


## Beat 1.7.1

- Some UI optimization (Analysis UI moved to a separate class)
- Apple Silicon compatibility (updated Sparkle framework)
- Plugin wrapper support with external file assets
- App is notarized through Apple


## Beat 1.7

- Fixed a bug with the scene numbers printing out no matter what
- Fixed a bug which caused omitted scenes be invisible in the Outline View
- "Go to scene number..." action added
- Edit menu cleanup
- Autocomplete now suggest the most used characters first
- Fixed a bug which marked the document as being changed right at load
- JavaScript Plugin API
- Print episodes
- New About screen


## Beat 1.6

- New native timeline view, with support for storyline tracking and pinch-zooming
- Other minor fixes
- Beat now uses CocoaPods (.... for now)
- DiffMatchPatch modernization for ARC (about time)
- Many other bug fixes
- Lots and lots of code cleanup


## Beat 1.5

- New print view
- Pagination problems fixed
- Compare two different scripts
- There is still some pagination trouble. I should build the layout engine myself in ObjC and not rely on the completely unreliable HTML stuff. Also, the font size is a bit smaller than in a certain application starting with F. Rest of the letters you can figure out yourself. (fuckoff) A future consideration.
- Start scene numbering from a custom number 

## Beat 1.4.2

- Code cleanup & delegation
- Resizable Outline View
- Pagination fixes (more to come)	


## Beat 1.4

- Optimized parsing for large chunks of text
- Fixed some bugs with character input
- Code cleanup
- Typewriter mode (might be a bit buggy for now)
- New layout for sections and synopsis lines (let's see how people react to this :-)
- Fixed bugs with undoing paragraphs
- Finally fixed bugs with undoing headings
- Fixed a bug with notes taking up print space
- Some code cleanup
- Early experiments with the new Timeline class for replacing the weird JavaScript version :---) 
- Delegation and modularization


## Beat 1.3b

- Fixed an app-crashing bug happening when iterating through omitted ranges
- Fixed a bug with the JavaScript Timeline (which should be abolished anyway, tbh)


## Beat 1.3 

- Fixed memory issues
- Double-line breaks after scene headings, paragraphs and dialogue
- Index card view fixes
- Rebuilt, super-fast HTML preview 
- Parsing optimized a bit
- Automatic paragraphs
- Fixed some minor bugs with printing & PDF export
- Escaping formating characters finally works
- Updated tutorial
- Preview icon
- Tab now switches into dialogue input mode
- Jump to scenes from preview
- ... too many to mention


## Beat 1.2 r2

- Character name autocomplete fixed
- Weird asynchronous UI calls fixed


## Beat 1.2

- All sorts of stuff
- Bugs with match parentheses have been worked out
- Optimized document loading
- Optimized preview building
- Live pagination (View → Show Page Numbers)
- Force symbols are now formated (@, !, ~, etc.)
- Fixed quirks with scene heading editing
- Timeline View no longer scrolls randomly if the scene is already in view
- Caret position is saved per document
- Page numbering in edit mode (View → Show Page Numbers)


## Beat 1.1 r6

- Added Force Element menu that can be accessed while typing (option-Enter)
- Bug fixes for disappearing elements


### About the Upcoming App Store Release

Beat is is under GPL and will remain so. However, to pay for costs of hosting and development, there will be a Pro version available on the App Store.

The only difference between free and paid versions is the extra content: manual & some templates. Source code for the whole application will still be freely available, but actual built updates to the free version will not be as frequent. All the code providing the copyrighted bonus content is found right here in the source.


## Beat 1.1 r5

- Fixed a bug with zooming in not displaying the whole document before the user types in something
- Outline cards can now be printed
- Outline card excerpts are more compact
- FDX export now includes support for scene numbers
- FDX import now has better support for Final Draft 11 quirks and no longer adds extra line breaks
- Two line breaks are now automatically added after a scene heading
- All remaining references to RegexKitLite have been removed, code is fully modernized now
- Smaller zoom steps
- Overall optimization & multithreading
- Dual Dialogue menu item & keyboard shortcut
- Light mode can now be enabled even if OS in dark mode


## Beat 1.1 r4

Bug fixes:

- Fixed a bug with filtered outline not showing the currently edited scene
- Fixed bug with Fountain QuickLook
- Fixed bugs with the Title Page Editor
- Fixed a bug with pointers on the editor buttons (has been there since first version) 
- Fixed bugs with margin sizes in full screen mode

New stuff:

- Simplifying outline structure back to how it was
- UI and usability tweaks
- Single omited scenes now keep intact if moved
- Overall cleaning for App Store release
- Got rid of the ugly be/at icon


## Beat 1.1 r3

- Enable undoing with forced elements
- Fixed an app-crashing bug with section headers


## Beat 1.1 r2

- Fixed bug with pagination failing if there was an empty line after scene heading
- Fixed bugs with caret positioning while editing dialogue
- Fixed a bug which caused view buttons to disappear when using find/replace
- Fixed bugs with scene masking when filtering scenes
- New feature: Section heading markers


## Beat 1.1r

- Minor UI tweaks
- Completely rewritten pagination
- Experimental live pagination prototype


## Beat 1.1.0k

- Fixed some critical pagination issues
- Fixed a bug with paper sizing


## Beat 1.1.0j

- Some of the legacy open source Fountain stuff, which still use the old RegexKitLite library, has been rewritten. A lot of work still remains.
- Quick Look extension!
- Autosave
- If the app crashes, unsaved documents can be recovered


## 1.1.0i

- Script analysis has character genders (not the most inclusive implementation yet, unfortunately)
- Donut charts in analysis view instead of bars
- Preprocessing scene numbers is faster + more memory efficient (and some weird bugs are fixed)
- Fixed locking scene numbers with colored scenes
- Added filtering for colors & characters
- Fixed bugs with dragging & dropping in macOS Catalina
- Preliminary Final Draft (FDX) import
- ... and added bunch of stuff I have already forgotten about


## 1.1.0h beta

- Title page editor now supports multi-line text fields for Contact and Notes
- New document icon
- Fixed a bug with the tutorial opening just once (???)
- Outline view now cleans headings and synopses from formatting characters (TODO: same thing for timeline & card view) 


## 1.1.0g beta

- Added title page editor and fixed title page field layout
- Fixed a bug with the first line not becoming a scene 
- Title page editor
- Fixed bugs with outline filtering


## 1.1.0f beta

- Added support for custom title page fields & fixed its layout
- Script analysis view
- Outline searching and filtering
- Start screen now requires a double click before opening a document
- Reorganize scenes in card view (with undoing)
- New color scheme with a bit cooler dark grays
- More fixes with dialogue formatting, it should be reliable now
- Window won't go out of screen bounds when hiding / showing outline view
- Fixes with dark mode graphical glitches & zooming
- Autocomplete now works as it should


## 1.1.0e beta

- Fixed bugs with character cues and scene reorganization


## 1.1.0d beta

- Scenes can be reorganized in outline view
- Character cues & non-character related UPPERCASE strings now behave more sensibly in edit mode
- New *About* window


## 1.1.0 beta

- Timeline view (chronometry is still WIP)
- Zooming is now fast and efficient
- Support for native macOS dark mode (+ switching between modes is 100000 times faster)
- Fixed bugs in card view
- Find bar no more overlaps outline and card view buttons
- Fixed scrolling bugs for text view and optimized scene number labeling
- Fixed undoing scene colors
- Fixed bugs with fullscreen view


## 1.0.9d

- Fixed a stupid and silly bug which caused *every* screenplay get reformatted again, when another document was opened


## 1.0.9c

- Current scene is highlighted in outline view
- Whole scene heading is color-coded in outline view (instead of the dot)


## 1.0.9b

- Fixed a bug which prevented adding scene colors in card view.


## 1.0.9

- Oh well. Print layout was not really properly fixed, so it was kind of built from the ground up again. There MIGHT be some quirks left, but after testing it with 3 different feature-length scripts, it seems to work fine and return about the same page length as other screenwriting apps (within +-1-2 page range). I'm very sorry for any inconvenience. Mostly for myself.
- Print preview now jumps to the selected scene.
- Scenes can be reordered by dragging & dropping in card view. This is an experimental feature for now and not enabled in released version.
- Memory management issues with windows have been fixed.


## 1.0.8

- Major change: I'll start updating this changelog
- Beat now uses a customized RegexKitLite, as OSSpinLock is deprecated in macOS 10.12+
- PDF/printing layout is better now. It still uses the old FNHTMLScript and FNPaginate code, but they are customized. Longer action paragraphs will now break apart between pages. Dialogue blocks should also behave in a more consistent way.
- Omitted scenes no longer retain their scene number. They are still formatted correctly, though.
- New flat array structure for outline elements - just after I replaced it with the multi-level structure. The whole outline logic should be rewritten, but for now, I'll be using these parallel structures.
