# Beat

A simple and elegant screenwriting app for macOS, using the plain-text Fountain screenplay format. It's fast, lightweight and, above all, has a distraction-free, minimalistic UI. Beat is also **free and open source** under GPL.

Read more: https://kapitan.fi/beat/

This started as a personal project as I needed a simple, multi-window, lightweight screenwriting application for my own films. All other existing screenwriting apps were weird, expensive, cumbersome or even lacked some pretty important features - such as automatic and visible scene numbering while writing. At this point Beat pretty much outdoes most of the commercial Fountain editors, with certain limitations. To make up forthose, Beat some **very** useful features, such as powerful outlining tools, scene coloring and filtering. 

There is a working iOS prototype, but its development is on hiatus right now, as I'm working on my own films. I not a real programmer but an artist and a filmmaker, and it really shows in the code. I'm open to any suggestions, improvements, feedback and collaboration. 

Beat is originally a fork of **Writer** by Hendrik Noeller (https://github.com/HendrikNoeller/Writer/) and some code still originates from his work, especially within the magnificent continuous Fountain parser.


## Latest release: Beat 1.1 r2

**Features**
* Minimalistic UI that stays out of the way
* Automatic screenplay formatting, no need for shortcuts or hotkeys
* Dark mode for the children of the night
* Full support for Fountain syntax
* Final Draft import / export
* PDF export
* Title page editor
* Automatic scene numbering in edit view – with forced scene number recognition
* Outline list view, with sections and synopses, scene reordering and filtering
* Outline card view, with sections & synopses
* Timeline view with sections & synopses
* Autocomplete characters and scene headings
* Color-coded scenes
* Analysis view, with line count per character, amount lines by gender, scene locations, etc.
* Fountain Quicklook in Finder
* Autosave & script backups in case of crashes 

**Note:** This repository follows my development, so it DOES NOT match the latest release version. Dread lightly, dear friend!

## Future

### State of development

Beat is under active development when I have the time -- or rather, desperately need a new feature myself. Worst bugs will usually be fixed ASAP. As of 1.1.0, the app is getting more and more stable.

Some future milestones & considerations:

* Fixing the ancient Fountain open source stuff, incl. removing references to RegexKitLite
* Show pages in edit view (this might turn out to be a bigger problem than expected)
* Have Beat only allow happy endings (somewhat limiting)
* Making the world a better place (not enough coding skills)
* Planting some trees to fight climate change (WIP)

### Can I help?

Please do! As stated above, the person behind this project is not a real programmer. When I started the project, my understanding of Objective-C was little to none, and it shows. Though my code has been getting better, there are still silly things going on. Help, donations and feedback are highly appreciated! 

If you are here just to steal some code for your own Fountain editor, the best stuff can be found under Parsing, Fountain and User Interface folders in the project. Note that most of the code is under GPL, so you need to share your derivative work publicly. Interface elements are mostly unde MIT license. 

At times, to vent my frustration, I've included quotes from my favourite poets as comments in the code. They include Forough Farrokhzad, Marina Tsvetayeva and Charles Bukowski. All apologies.

Lauri-Matti Parppei  
KAPITAN!  
https://kapitan.fi/
