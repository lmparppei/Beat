# Beat

A simple and elegant screenwriting app for macOS, using the plain-text Fountain screenplay format. It's fast, lightweight and, above all, has a distraction-free, minimalistic UI. Beat is also **free and open source** under GPL.

[Official website](https://www.beat-app.fi/)  
[Download releases on **App Store**](https://apps.apple.com/fi/app/beat/id1549538329)   
[Discord Community](https://discord.gg/FPHjfH7ms3)

**Plugin API documentation**  
Read more on public plugin repository: https://github.com/lmparppei/BeatPlugins/  


## About Beat

This started as a personal project as I needed a simple, multi-window, lightweight screenwriting application for my own films. All other existing screenwriting apps were weird, expensive, cumbersome or even lacked some pretty important features - such as automatic and visible scene numbering while writing. At this point Beat pretty much outdoes most of the commercial Fountain editors, with certain limitations. To make up for those, Beat some **very** useful features, such as powerful outlining tools, scene coloring and filtering. 

Beat was originally a fork of [**Writer**](https://github.com/HendrikNoeller/Writer/) by Hendrik Noeller and some code still originates from his work, especially within the magnificent continuous Fountain parser. 


## Latest release: Beat 1.99.x

**Features**
* Minimalistic UI with as little distractions as possible
* Smart, automatic screenplay formatting
* Dark mode for the children of the night
* Fountain syntax fully supported
* Hide Fountain markup
* Final Draft import / export, supporting revisions and outline items 
* Title page editor
* JavaScript plugin API
* Automatic page and scene numbering in edit view
* Revision generation management
* Outline list view, with sections and synopses, scene reordering and filtering
* Outline card view, with sections & synopses
* Timeline view with sections & synopses
* Autocompletion for characters and scene headings
* Color-coded scenes
* Analysis view, with line count per character, inclusivity by gender, scene locations, etc.
* Fountain Quicklook in Finder
* Autosave & script backups in case of crashes 
* Automatic paragraphs & tab key for auto character cue
* Productivity timer


## Building from repo

**Note:** This repository follows my development, so it DOES NOT match the latest release version. I still can't use branches. Dread lightly, dear friend!

Use the `Beat` workspace.  When building for development, I suggest using the *Beat App Store* target. You will need multiple Beat frameworks built, but no external libraries or frameworks are be needed. If you want to build the ad hoc target (which is currently not maintained) you will need the latest Sparkle package.  


## FAQ

### Future & state of development

Beat is under active development when I have the time -- or rather, desperately need a new feature myself. Worst bugs will usually be fixed ASAP. If you encounter a bug, contact me through Twitter, e-mail or file an issue here on GitHub. 

### Plugins

You can download the latest public plugins (and learn more about creating your own) in the Beat Plugin repo: https://github.com/lmparppei/BeatPlugins

### iOS Version

Beat for iOS is in closed beta since August 2023. You can subscribe to [**Patreon**](https://www.patreon.com/user?u=61753992) to be a part of it!

### Will There Be a Windows Version? 

Unfortunately not. Beat is written in Objective C and relies on native macOS APIs. There are no good Fountain editors on Windows, and somebody should really write one! You might be able to use the Beat parser as starting point.

### Can I help?

Please do! The person behind this project is not a real programmer but an artist and a filmmaker, and it really shows in the code. Coding assistance, bug reports, feature requests, [donations](https://kapitan.fi/beat/support.html) and feedback are highly appreciated! 


### Support Beat

You can help to keep the project alive by [donating](https://www.beat-app.fi) some pennies or by subscribing to the Patreon. However, the creator of this app is a well-off person from a social-democratic welfare country, so you can also send your loose change to NGOs and charities.


## Post-mortem

**Beat is an anti-capitalist venture**. 

Beat will stay free and open source forever. I came to filmmaking from a DIY & underground art scene, which works on very different rules than the film industry. We desperately need new voices and new people to tell their own stories instead of all the established middle-class white people — including me. A free screenwriting app might not be the thing that helps you to break through, but it's a start, if you are able to afford (or steal) a Mac. Don't steal it from an individual, though.

If you are here just to steal some code for your own Fountain editor, note that the code is licensed under GPL (v3), so you will need to share your derivative work publicly.

The app has been cooked up through trial and error, and might be rough around the edges, but it is -- above all -- a labour of love. At times, to vent my frustration, I've included quotes from my favourite poets as comments in the code. They include Forough Farrokhzad, Marina Tsvetayeva, Charles Bukowski and me myself. All apologies.

Lauri-Matti Parppei    
www.parppei.com  
