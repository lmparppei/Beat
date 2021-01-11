#  Beat Plugin API

Plugins are written in JavaScript and Beat provides a simple API to interact with the app. Scripting support is at a very early and preliminary stage for now (Dec 2020), but might get better. Best way to learn about plugins is by dwelving into `.beatPlugin` files contained within the Beat source on GitHub. This documentation will be updated when I remember and have the time. 

If anybody ever writes a plugin, *please, please, please* be nice to people and test your code thoroughly before deploying it. Loss of work hurts and it might be completely possible to crash the whole app with plugin code. I'm doing my best to stay backwards-compatible 

There is a sample plugin included at the end to act as a starting point.

---
  

## Basics

### Writing Plugins

You can use any supported JavaScript features in WebKit, but the script is confined to run inside the app, so you can't access the web, for instance. Scripts run as functions, so they can be terminated any time using `return` when outside any other function scope.

Have fun and make something useful!

### Get Screenplay Content

`Beat.lines()` – all line objects in the script
`Beat.scenes()` – scene objects
`Beat.outline()` – all outline objects, including synopsis & heading markers
`Beat.linesForScene(scene)` – lines for a specified scene
`Beat.getText()` — whole document as string

### Navigate Through The Document

`Beat.setSelectedRange(start, length)` – select a range in the document (**always** double-check that the values are in document range)
`Beat.scrollTo(index)` – scroll to character index
`Beat.scrollToScene(scene)` – scroll to a scene object
`Beat.scrollToLine(line)` – scroll to line
 
### User Interaction

`Beat.alert("Alert title", "Informative Text")` – simple alert box
`Beat.confirm("Title", "Informative text")` — get user confirmation, returns `true` or `false`
`Beat.prompt("Title", "Informative Text", "Placeholder string")` – get text input from the user, returns a string
`Beat.dropdownPrompt("Title", "Informative Text", [value, value, value])` – allow the user to select a value from an array, returns a string 

For more elaborate inputs it is wiser to use `Beat.htmlPanel()`. 

### Save Plugin Defaults

`Beat.getUserDefault("setting name")` – get a value
`Beat.setUserDefault("setting name", value)` – save a value


  
## Manipulating the Document

### Document Model

Beat parser uses `Line` and `Scene` objects to store the screenplay content. To manipulate the document, you make direct changes to the plain-text screenplay content and parse your changes. `Line` object contains useful information about the parsed line, such as line type, position, if it is a Title Page element etc. The `string` property contains its plain-text contents.

`Scene` is more of an abstraction. It's used to determine where a scene starts, its total length in characters, its color and if it is visible or not. Its `string` property contains the scene heading. 

### Adding and Removing Content

`Beat.addString(String, index)` – add string at some index
`Beat.replaceRange(index, length, string)` – replace a range with a string (which can be empty)
`Beat.parse()` – parse changes you've made and update the lines/scenes arrays

### Get and Set Selection

`Beat.selectedRange()` – returns a range object with `.location` and `.length` properties
`Beat.setSelectedRange(location, length)` – set user selection 

### Lines

**PLEASE NOTE:** You can't just make changes to the line string objects. Every change to the screenplay has to go through the parser, which means using `Beat.addString`, `Beat.replaceRange` etc. to change the document and then parsing your changes.

Lines array contains all the lines in the script as objects. A line object contains multiple values, including but not limited to:

`line.string` —	string content
`line.position` — starting index of line
`line.typeAsString()` — "Heading" / "Action" / "Dialogue" / "Parenthetical" etc.
`line.isTitlePage()` — true/false
`line.isInvisible()` — true/false
`line.cleanedString()` — non-printing stuff removed

Iterate through lines:
```
for (const line of Beat.lines()) {
	// Do something
}
```	

### Scenes

`scene.sceneStart` — starting index
`scene.sceneLength` — length of the whole scene in characters
`scene.string` — scene heading (eg. INT. HOUSE - DAY)
`scene.color` — scene color as string
`scene.omited()` — true/false
`scene.typeAsString()` — scene type (heading, section, synopse)
	
Iterate through scenes:

```
for (const scene of Beat.scenes()) {
	// ...
}
```

## Advanced

### Import Data

`beat.openFile([extensions], function (filePath) { })` – displays an open dialog for an array of extensions and returns a path to the callback
`beat.fileToString(path)` – file contents as string
`beat.pdfToString(path)` – converts PDF file contents into a string

### HTML Panel

`Beat.htmlPanel(htmlContent, width, height, callback)` 

Displays HTML content with preloaded CSS. You can fetch data from here using two ways. Callback function receives an object, which contains keys `data` and `inputData`. 

You can store an object (***note**: only an object*) in `Beat.data` inside your HTML, which will be returned in the callback. You can also use inputs, just add `rel='beat'` to their attributes. The received object will then contain  `inputData` object, which contains every input with their respective name and value (and `checked` value, too). 

```
Beat.htmlPanel(
	"<h1>Hello World</h1><input type='text' rel='beat' name='textInput'><script>Beat.data = { 'hello': 'world' }</script>",
	600, 300,
	function (data) {
		/*
		
		Returned data in this case:
		{
			data: { hello: 'world' },
			inputData: { name: 'textInput', value: '' }
		}
		
		*/
	}
)
```

Be careful not to overwrite the `Beat` object inside the page, as it can cause the app to be unresponsive to user. Also, only store **an object** in `Beat.data`. You can add your own CSS alongside the HTML if you so will — the current CSS is still under development. Just remember to add `!important` when needed.

## Sample Plugin

This plugin doesn't really do anything, just demonstrates some plugin features.
It should act as a starting-point to begin writing your own extensions for Beat.

```
let confirm = Beat.confirm("This is a sample plugin", "Do you want to continue running it?")

// User hit Cancel
if (!confirm) {
	Beat.alert("Sad to see you go", "Plugin will now terminate")
	return
}

// ########################################
// USER INPUT
// ########################################

let value, stringValue;

value = Beat.dropdownPrompt(
	"Select a value", 
	"This is a drop-down menu with selectable items", 
	["First Item", "Second Item", "Third Item"]
)
if (value == null) return;

stringValue = Beat.prompt(
	"Enter a string value",
	"Type anything"
)
if (stringValue == null) return;


// ########################################
// INTERACTING WITH THE DOCUMENT
// ########################################

// Add a some text in the beginning of the document
Beat.replaceRange(0, 0, "INT. SAMPLE SCENE\n\nThis is a sample script.\n\n")

// Parse any changes we've made
Beat.parse()

// Get line content
const lines = Beat.lines()
const scenes = Beat.scenes()

// Scroll to scene (ie. select the range)
Beat.scrollToScene(scenes[0])

// Go through the lines
for (const line of lines) {
	let content = line.string
	let position = line.position
	let type = line.typeAsString()

	// Do something with this data
}

for (const scene of scenes) {
	let start = scene.sceneStart
	let length = scene.sceneLength

	let lines = Beat.linesForScene(scene)
}

// ########################################
// MORE UI STUFF
// ########################################

let html = 
	"<h1>Hello World</h1>\
	<h2>User Input</h2>\
	<p>Dropdown value: " + value + "<br>\
	String value: " + stringValue + "</p> \
	<p>Input something:<br>\
	<input name='input' rel='beat' type='text'></input></p>"

// Inject some script. Beat.data is an object you can pass onto callback function
html += "<script>Beat.data = { hello: 'World' }</script>"

Beat.htmlPanel(html, 400, 300,
	function (data) {
		Beat.log("here?")
		// The data can be passed here
		Beat.alert("Data from HTML panel:", JSON.stringify(data));
		openFile()
	}
);

function openFile() {
	Beat.openFile(["fountain"], // Allowed file extensions
		function (path) { // Callback
			if (!path) return

			let content = Beat.fileToString(path)
			
			// Do something with the string. 
			// In this sample we create a new document with the file contents.
			// NOTE NOTE NOTE: Never call newDocument while a modal is displayed.
			Beat.newDocument(content)
		}
	)
}


```
