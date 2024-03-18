// NOTE: You need to set let standalone = false/true somewhere

// Drag & drop should be true for in-app view, false for standalone
let dragDrop;
if (standalone) dragDrop = false;
else dragDrop = true;

let colorValues = {
	red: [239,0,73],
	blue: [0,129,239],
	green: [0,223,121],
	pink: [250,111,193],
	magenta: [236,0,140],
	orange: [255, 161, 13],
	brown: [169, 106, 7],
	gray: [150, 150, 150],
	purple: [181, 32, 218],
	yellow: [255, 162, 0],
	cyan: [7, 189, 236],
	teal: [12, 224, 227]
}
let textColors = {
	white: "white",
	black: "#222"
}
let blackTextFor = ["yellow", "orange", "pink", "green"];
let customStyles = 0;

let colors = ['none', 'red', 'blue', 'green', 'pink', 'brown', 'cyan', 'orange', 'magenta'];
let colorName = ['#color.none#', '#color.red#', '#color.blue#', '#color.green#', '#color.pink#', '#color.brown#', '#color.cyan#', '#color.orange#', '#color.magenta#'];

let scenes,
	container,
	closeButton,
	printButton,
	contextMenu,
	debugElement,
	wait;

let drake = "none..."

let zoomLevel = 2;


// Polyfills, just in case
if (!Object.entries) {
  Object.entries = function( obj ){
	var ownProps = Object.keys( obj ),
		i = ownProps.length,
		resArray = new Array(i); // preallocate the Array
	while (i--)
	  resArray[i] = [ownProps[i], obj[ownProps[i]]];

	return resArray;
  };
}
if (!String.prototype.replaceAll) {
	String.prototype.replaceAll = function(str, newStr){
		// If a regex pattern
		if (Object.prototype.toString.call(str).toLowerCase() === '[object regexp]') {
			return this.replace(str, newStr);
		}

		// If a string
		return this.replace(new RegExp(str, 'g'), newStr);
	};
}


function init () {
	debugElement = document.getElementById('debug');
	scenes = [];
	
	createStyles();
	container = document.getElementById('container');
	wait = document.getElementById('wait');
	
	// Only allow printing & closing for the standalone, windowed version
	if (!standalone) {
		printButton = document.getElementById('print');
		printButton.onclick = function () {
			// This is a janky implementation but I don't care right now
			var html = "<html>" + document.getElementsByTagName('html')[0].innerHTML + "</html>";
			window.webkit.messageHandlers.printCards.postMessage(html);
		}
	}
	
	// Init context menut
	contextMenu.init();
	document.body.onclick = function (e) { contextMenu.close(); }
	
	// Init drag & drop
	
	if (dragDrop) {
		initDragDrop()
	}
	
}

function log(message) {
	debugElement.innerHTML = message;
}

function findSceneWithIndex(index) {
	for (const scene of scenes) {
		if (index == scene.sceneIndex) return scene;
	}
	return null
}

function initDragDrop () {
	// Init dragula
	drake = dragula({
		direction: 'horizontal' ,
		
		invalid: function (el, handle) {
			return el.tagName === "H2";
		}
	});
		
	// Handle drop
	drake.on('drop', function (el, target, source, sibling) {
		var sceneIndex = el.getAttribute('sceneIndex')
		var nextIndex
		
		if (sibling) nextIndex = sibling.getAttribute('sceneIndex')
		else nextIndex =  scenes[scenes.length - 1].sceneIndex

		if (!nextIndex) {
			scenes[sceneIndex].sceneIndex;
			
		} else {
			let thisScene = findSceneWithIndex(sceneIndex);
			thisScene.sceneIndex = nextIndex;
			
			for (var i = scenes.indexOf(thisScene); i < scenes.count; i++) {
				let nextScene = scenes[i];
				if (nextScene.type != 'synopse') {
					scenes[i].sceneIndex += 1;
				}
			}
		}

		scenes.sort((a, b) => (a.sceneIndex > b.sceneIndex) ? 1 : -1)
		
		// Post move action to main window
		window.webkit.messageHandlers.move.postMessage(sceneIndex + "," + nextIndex);

		// Disable editing until the operation is complete
		wait.className = "waiting";

		//createCards(scenes);
	});
}

// Night mode
function nightModeOn () {
	document.body.classList.add('nightMode');
}
function nightModeOff () {
	document.body.classList.remove('nightMode');
}


/* ##### CONTEXT MENU ##### */

contextMenu = {};
contextMenu.init = function () {
	contextMenu.menu = document.createElement('div');
	contextMenu.menu.id = 'contextMenu';
	
	var content = '';

	for (var i in colors) {
		var color = colors[i];
		if (typeof color === 'string') {
			content += "<div onclick=\"contextMenu.setColor('" + color + "')\"" + " class='menuItem " + color + "'><div class='color " + color + "'></div> " + colorName[i] + "</div>";
		}
	}
	
	contextMenu.menu.innerHTML = content;
	document.body.appendChild(contextMenu.menu);
}
contextMenu.toggle = function (e) {
	if (contextMenu.menu == null) contextMenu.init();
	
	if (contextMenu.open == true) {
		contextMenu.close();
	} else {
		var coordinates = getPosition(e);
		
		contextMenu.menu.style.left = coordinates.x + "px";
		contextMenu.menu.style.top = coordinates.y + "px";

		contextMenu.target = e.target;
		contextMenu.open = true;
		
		contextMenu.menu.className = 'visible';
		
		// Avoid overflow
		if (contextMenu.menu.clientWidth + coordinates.x > window.innerWidth) {
			contextMenu.menu.style.left = (coordinates.x - contextMenu.menu.clientWidth) + "px";
		}

		if (contextMenu.menu.clientHeight + coordinates.y > window.scrollY + document.body.clientHeight) {
			contextMenu.menu.style.top = (coordinates.y - contextMenu.menu.clientHeight) + "px";
		}
	}
}
contextMenu.close = function () {
	contextMenu.open = false;
	contextMenu.menu.className = '';
}
contextMenu.setColor = function (color) {
	for (var c in colors) {
		if (typeof colors[c] === 'string') {
			contextMenu.target.classList.remove(colors[c]);
		}
	}
	
	contextMenu.target.classList.add(color);
	
	// SET COLOR
	let index = contextMenu.target.getAttribute('lineIndex');
	let sceneIndex = contextMenu.target.getAttribute('sceneIndex');
	
	if (standalone) Beat.call("Beat.custom.setColor(" + sceneIndex + ", '" + color + "')")
	else window.webkit.messageHandlers.setColor.postMessage(contextMenu.target.getAttribute('lineIndex') + ":" + color );
}
function getPosition(e) {
	var posx = 0;
	var posy = 0;
	
	if (!e) var e = window.event;
	
	if (e.pageX || e.pageY) {
		posx = e.pageX;
		posy = e.pageY;
	} else if (e.clientX || e.clientY) {
		posx = e.clientX + document.body.scrollLeft +
		document.documentElement.scrollLeft;
		posy = e.clientY + document.body.scrollTop +
		document.documentElement.scrollTop;
	}
	
	return {
		x: posx,
		y: posy
	}
}


/* ##### CARDS ##### */

function setupCards () {
	let cards = document.querySelectorAll('.card');
	cards.forEach(function (card) {
		card.onclick = function () { contextMenu.close(); }
		card.ondblclick = function () {
			let index = this.getAttribute('sceneIndex');

			if (!standalone) {
				window.webkit.messageHandlers.cardClick.postMessage(index);
			}
			else Beat.call("Beat.custom.goToScene(" + index + ")")
		}
		
		document.body.oncontextmenu = function (e) {
			e.preventDefault()
		}
		
		card.oncontextmenu = function (e) {
			e.preventDefault()
			contextMenu.toggle(e)
		}
	});
}

function filter(element) {
	const value = element.checked;
	let className = 'hide-' + element.name;
	
	if (value) {
		document.body.classList.remove(className);
	} else {
		document.body.classList.add(className);
	}
}

// This refreshes the cards
function createCards (cards, alreadyVisible = false, changedIndex = -1) {
	customStyles = 0;
	let html = "<section id='cardContainer'>";
	let index = -1;

	let selected = null;

	scenes = [];
	debugElement.innerHTML = '';

	// No cards
	if (cards.length < 1) html += "<div id='noData'><h2>#cardView.noScenes#</h2><p></p></div>";
	
	// Iterate through index card data
	for (let card of cards) {
		if (!card.name)	continue; // Skip empty
		
		index = card.sceneIndex;
		
		// Don't show synopsis lines, but still add them
		if (card.type == 'synopse') card.invisible = true;
		
		// Let's save the data into an array for later use
		scenes.push(card);

		// Style object
		let style = { status: '', color: '', changed: '' };

		if (card.selected) {
			style.status = ' selected';
			selected = index;
		}

		if (String(card.color) != "") {
			let colorName = "";

			if (String(card.color).substring(0,1) == "#") {
				// This is a custom, hex color
				let customStyleName = addCustomColor(card.color);
				colorName = customStyleName;
			} else {
				// Use default colors
				colorName = card.color;
			}
			style.color = ' colored ' + colorName;
		}

		// For moving stuff around
		if (index == changedIndex) style.changed = ' indexChanged ';
		
		// Create HTML for different card types
		if (card.type == 'section') {
			if (card.depth == 1) {
				html += "<h2 class='depth-" + card.depth + style.color + "' sceneIndex='" + card.sceneIndex + "'>" + card.name + "</h2>";
			} else {
				if (card.depth > 3) depth = 3;
				let sectionCardClass = " section-" + card.depth;
				
				html += "<div sceneIndex='" + card.sceneIndex + "' class='cardWrapper sectionCardContainer " + sectionCardClass + style.color + "'><div lineIndex='" +
						card.lineIndex + "' pos='" + card.position + "' " +
						"sceneIndex='" + card.sceneIndex + "' " +
						"class='basicCard sectionCard" + sectionCardClass + style.color + style.status + style.changed +
						"'>"+
					"<p>" + card.name + "</p></div></div>";
			}
		}

		else if (card.type == 'synopse') {
			// Hidden
			html += "<div sceneIndex='" + card.sceneIndex + "' style='display: none;'></div>";
		}
		else {
			// Normal card
			html += "<div sceneIndex='" + card.sceneIndex + "' class='cardWrapper cardContainer'><div lineIndex='" +
					card.lineIndex + "' pos='" + card.position + "' " +
					"sceneIndex='" + card.sceneIndex + "' " +
					"class='basicCard card" + style.color + style.status + style.changed +
					"'>"+
				"<div class='header'><div class='sceneNumber'>" + card.sceneNumber	+ "</div>" +
				"<h3>" + card.name + "</h3></div>" +
				"<p>" + card.snippet + "</p></div></div>";
		}
	}
	html += "</section>";

	// Set page HTML nad update drag & drop objects
	container.innerHTML = html;

	// If the view is already visible, don't scroll to selected scene
	if (selected && !alreadyVisible) {
		let el = document.querySelector("div[sceneIndex='" + selected + "']");
		el.scrollIntoViewIfNeeded(true);
	}

	// Enable editing if we were waiting for something
	wait.className = "";

	// Setup drag & drop and context menus
	setupCards();
	
	if (dragDrop) {
		const container = document.getElementById("cardContainer")
		drake.containers = [container]
	}
}

function select(index) {
	// Selects a card in the given index
	const cards = document.querySelectorAll("div.card")

	cards.forEach(function (item) {
		if (!item.classList) return;
		
		let cardIndex = item.getAttribute('sceneIndex');
		if (index != cardIndex) item.classList.remove("selected");
		else {
			item.classList.add("selected");
			if (item.scrollIntoViewIfNeeded) item.scrollIntoViewIfNeeded(true);
		}
	})
}

function addCustomColor(color) {
	// Adds a custom hex class into styles
	var customColor = String(color).substring(1);
	//var style = document.createElement('style');
	
	customStyles++;
	
	let style = document.getElementById('customStyle-' + customStyles)
	if (!style) {
		style = document.createElement('style');
		style.setAttribute('id', 'customStyle-' + customStyles);
		
		document.head.appendChild(style);
	}
	
	var customStyleName = "customStyle-" + customStyles;
	
	style.innerHTML = "h2."+customStyleName+" { color: #"+customColor+"; }\n" +
		".card."+customStyleName+", ."+customStyleName+".selected .sceneNumber, .color."+customStyleName+", .sectionCard."+customStyleName+" { background-color: #"+customColor+" !important; color: white; } .card."+customStyleName+" p { color: #000; }";

	return customStyleName;
}

function createStyles() {
	let template = "h2.#name# { color: rgb(#values#); }\n" +
		".card.#name#, .#name#.selected .sceneNumber, .color.#name#, .sectionCard.#name# { background-color: rgb(#values#) !important; color: #textColor# !important; }\n" +
		".card.#name# p { color: #textColor# !important; }\n";
	
	let styles = "";

	for (const [colorName, value] of Object.entries(colorValues)) {
		let colorValue = value.join(",");
		let textColor = textColors.white;
		if (blackTextFor.includes(colorName)) textColor = textColors.black;

		let style = template.replaceAll("#name#", colorName);
		style = style.replaceAll("#values#", colorValue);
		style = style.replaceAll("#textColor#", textColor);

		styles += style;
	}
	
	let element = document.createElement('style');
	element.innerHTML = styles;
	document.head.appendChild(element);
}

function zoomIn () {
	if (zoomLevel < 3) zoomLevel++;
	
	let zoomClass = 'zoomLevel-' + zoomLevel
	document.body.className = zoomClass
}
function zoomOut () {
	if (zoomLevel > 0) zoomLevel--;
	
	let zoomClass = 'zoomLevel-' + zoomLevel
	document.body.className = zoomClass
}

init();
