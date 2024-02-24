

# Work in progress / considerations

## Importing FDX revisions

Import revised ranges from FDX files 

## Tagging

Tagging is already pretty much built into the code, but has to be thoroughly tested.

## Line Delegation

Lines are now aware of their parser, which potentially allows cleaning up some weirder practices. It could even potentially make it possible to change line object contents, and have it be directly updated in the editor. This is something I've been hoping for a long time, and would make life easier with plugins, but it has to be very robust before making those methods public. 

## Pagination

* Allow pagination to happen from a given index. This is a LOT harder than it sounds, because of everything.
* I've begun working on a completely new, native Cocoa pagination and rendering.

## Document.m

* Sanitize and clean old stuff (please define what exactly)
* Fix the logic on how current scene is set and read from elsewhere, especially outline & timeline

## Index Cards

* Full rewrite to Cocoa when possible
... though the above is a bit obsolete now, with the addition of floating index cards plugin. And maybe the dark mode should be abolished from cards, too. They are pretty dark already.
