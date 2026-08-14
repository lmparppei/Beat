# Beat

An elegant screenwriting app for macOS and iOS, using the plain-text Fountain screenplay format. It's fast, lightweight and, above all, has a distraction-free, minimalistic UI. Beat is **fully open source** under GPL.

[Official website](https://www.beat-app.fi/)  
[Download releases on **App Store**](https://apps.apple.com/fi/app/beat/id1549538329)   
[Discord Community](https://discord.gg/FPHjfH7ms3)

**Plugin API documentation**  
Read more on public plugin repository: https://github.com/lmparppei/BeatPlugins/  


## About Beat

This started as a personal project as I needed a simple, multi-window, lightweight screenwriting application for my own films. All other existing screenwriting apps were weird, expensive, cumbersome or even lacked some pretty important features.

Beat is under active development, and worst bugs will usually be fixed ASAP. If you encounter a bug, contact me through e-mail, Discord or file an issue here on GitHub. 

Beat was originally a fork of [**Writer**](https://github.com/HendrikNoeller/Writer/) by Hendrik Noeller, but almost everything has been rewritten since.

**Selected Features**
* Minimalistic UI with as little distractions as possible
* Smart, automatic screenplay formatting
* Multiple story structure views with filtering, sections and synopses, including a collapsing list, index cards and timeline
* Dark mode for the children of the night
* Hide Fountain markup
* Final Draft import / export, including revisions, outline items and soon tags 
* Title page editor
* JavaScript [plugin API](https://github.com/lmparppei/BeatPlugins)
* Automatic scene numbering
* Page numbers and separators
* Revision generation management
* Autocompletion for characters and scene headings
* Color-coded scenes
* Statistics view, with line count per character, inclusivity by gender, scene locations, etc.
* Fountain QuickLook plugin for Finder
* Backup vault
* Version control (contained inside file metadata)  
* ... and much more!

## iOS version

Beat for iOS supports a limited set of features, but is getting up to speed with the desktop release. Some thing will, like plugin support, will remain macOS-exclusive, and the iOS version should be considered a companion app for the bigger sibling now.

The mobile version is currently a paid app, available on App Store, but it is still licensed under GPL and this repo contains the code for both platforms. You can build it yourself to avoid paying me anything.


## Building from repo

Open the `Beat` workspace and set your credentials. When building for macOS development, I suggest using the *Beat App Store* target. You will need multiple Beat frameworks built, but both releases have very few external dependencies.

## Plugins

Beat provides a JavaScript API for creating user extensions. You can learn more about creating your own plugins in the Beat Plugin repo: https://github.com/lmparppei/BeatPlugins


## Contributions

**Note:** The main branch in this repository follows my development, so it DOES NOT always match the latest release version on either platform.

The person behind this project is not a real programmer but an artist and a filmmaker, and sometimes it really shows in the code, so coding assistance, bug reports, feature requests and feedback are highly appreciated! 

For now, you can submit PRs directly to the main branch, but in the near future, I'll move to a development branch. LLM assistance is allowed, but please don't submit fully generated PRs. Parts of the code are very old, from the time I was still learning, and the structure can be a little convoluted. There are multiple self-reliant systems (like parsing, pagination and rendering), and changing one thing can lead to a lot of subtle issues throughout the app. Dread lightly. :-) 


## Supporting Beat

To fund the development, the binary for iOS release is currently distributed with a single lifetime fee. This is because Finnish law doesn't allow me to receive donations for my work, and because the iOS port was created due to popular demand. It is open source, though, so you can compile it yourself and install it on your own device. 

You can also help to keep the project alive by subscribing to my Patreon.

However, the creator of this app is a well-off person from a social-democratic welfare country, so you can consider sending your loose change to NGOs and charities instead. Currently, there is a genocide happening in Gaza, while the world is closing its eyes, and people are in desperate need of help.


## Post-mortem

**Beat is a political and an anti-capitalist venture at its heart.** 

The application will stay free (as in freedom) and open source forever. I'm sorry it's only available for Apple devices, which waters down the anti-capitalist stance, but solidarity is still woven into the core of the app. The project will never allow racism, facism, homophobia, transphobia, antisemitism, islamophobia or any sort of discrimination. 

If you have an issue with my politics, instead of threatening or trying to silence me, please direct your complaints to International Red Cross, UNICEF, Amnesty International, Human Rights Watch, International Criminal Court, UNHCR… I guess you get the idea.

I came to filmmaking from a DIY & underground art scene, which works on very different rules than the highly gate-kept film industry. We desperately need new voices and new people to tell their own stories instead of all the established middle-class people — nowadays including me. A free or affordable screenwriting app might not be the thing that helps you to break through, but it's a start, if you are able to afford (or steal) a Mac. Apple's phones fit into your pocket even more nicely, if you know what I mean.

If you are here just to steal some code for your own Fountain editor, please note that the code is licensed under GPL (v3), so you will need to share your derivative work publicly.

The app has been cooked up through trial and error, and might be rough around the edges, but it is -- above all -- a labour of love. At times, to vent my frustration, I've included quotes from my favourite poets as comments in the code. They include Forough Farrokhzad, Marina Tsvetayeva, Charles Bukowski and myself. All apologies.

Lauri-Matti Parppei    
[www.parppei.com](https://www.parppei.com)  
