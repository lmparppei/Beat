#  Beat Pagination 2.0

## Some Background

Because Beat is not a WYSIWYG app (and can't really become one, as it's a pure Fountain editor) pagination is a bit complicated. Earlier pagination code was a horrible mess, which was built on top of the original Beat repository pagination code, and later rewritten from ground up, but with similar logic. Pagination results were then sent to another class, which produced HTML for printing. 

I set up to write a class which would both paginate *and* render the contents. As I very soon became to realize, iOS and macOS required a different approach to rendering the content. HTML rendering on macOS isn't really feasible, because installed printers and such will affect printing from `WKWebView`. This led to writing TONS of failsafes and all sorts of weird tricks to produce a decent printout, which would also work on every computer.

That's why I once again separated rendering and pagination. `BeatRendererDelegate` protocol defines interoperability between pagination and the renderer, so when needed, you can replace the rendering code with a new implementation. 


## Paginating Fountain

Screenplay format has very strict rules about pagination. Some apps also allow the user to have some control over splitting paragraphs and dialogue, but to keep stuff consistent and avoid bugs, we'll be using hard-coded rules.

First, the parsed content has to be preprocessed to remove any non-printing elements, and to define which paragraphs have margins and which don't. Title page data is also separated from the rest of the content. Only the actual content is sent to pagination, while renderer will take care of the title page.

There's two types of pagination: STATIC and LIVE. Live pagination is used in the actual editor, so every change to the screenplay has to be reflected in pagination. Full pagination is surprisingly CPU-intensive, so live pagination does its best to reuse any unaffected paginated content. Live pagination results are also used in editor preview, but when exporting, the whole screenplay will be paginated from scratch to avoid erroneous parsing etc.

At its core, pagination is a `for` loop which iterates through the provided lines. We can't just see if the next element fits on a page, however — because of those pagination rules, we need to look forward at each element. Elements are grouped into "blocks", and some blocks also swallow each other.

For example:

A dialogue block begins with `CHARACTER CUE`, followed by parentheticals and dialogue lines, and each following element will be added to the block, until we encouter something that's doesn't belong into a dialogue block. **BUT** a dialogue block can be followed by a dual dialogue block, which has to be laid side-to-side with this current block. They have to be paginated at the same time, taking the height of both into account. **HOWEVER**, if the block is preceded by a scene heading, we don't want to leave it alone on the preceding page, even if this dialogue block doesn't fit current page.

`BeatPaginationPage` contains `BeatPaginationBlocks`, and while paginating, we'll create `BeatPaginationBlockGroup`s to handle the aforementioned situations. If something doesn't fit on a page, we'll call the `split` method on either a group or a single block and provide the remaining space. Some block types have their respective methods of breaking themselves apart across pages.

`BeatStylesheet` defines sizing for different elements, with a fixed font size. Styles are read from a faux-CSS file with a custom parser. Each block will remember its own sizing once it is added on a page. 

**NOTE** that NOTHING is actually rendered onto a page, or turned into an attributed string or HTML, or anything at this point. Everything is imaginary and happens in a black box. 

When rendering, you'll have to use the same style rules if you want anything to make sense. Think of it like this: you are providing a drawing for a shop in Benin, who will draw you the blueprint, and then send it over to the US to manufacture the parts, who in turn will send those parts to Estonia to be assembled. You will have to trust that everybody uses the same measurement system (or at least only A4 *or* US Letter) during the whole process, or your boat will sink.


## Post-Mortem 

Writing the new pagination has been the biggest undertaking in the history of this app. I originally hoped it would harmonize the whole process, but it actually made things *even more complicated*. The code might be a bit more maintainable now, though, and I've tried to explain which part does what. Looking at it now, I didn't do a very good job, but whatever.

Old pagination/rendering code was a Pandora's box. Whenever I touched it, I unleashed a ton of new issues. I *hope* this code makes those situations a bit less common. Stylesheets seem to work quite reliably, and sizings can be actually adjusted with little damage.

I hope this pagination works well long after I'm gone. I spent many evenings writing it, sometimes drinking tea, sometimes beer, and at times I even had fun. This is how I decided to spend my life, and I'm not too unhappy about it. 

All the best,
Lauri-Matti Parppei   
21.4.2023
