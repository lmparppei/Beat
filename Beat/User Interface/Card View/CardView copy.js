
var dragDrop = true;

var colors = ['none', 'red', 'blue', 'green', 'pink', 'brown', 'cyan', 'orange', 'magenta'];

var scenes,
	container,
	closeButton,
	printButton,
	contextMenu;

var drake;
var debugElement;
var wait;

	
function init () {
	scenes = [];
	
	container = document.getElementById('container');
	wait = document.getElementById('wait');

	printButton = document.getElementById('print');
	printButton.onclick = function () {
		// This is a janky implementation but I don't care right now
		var html = "<html>" + document.getElementsByTagName('html')[0].innerHTML + "</html>";
		window.webkit.messageHandlers.printCards.postMessage(html);
	}
	
	closeButton = document.getElementById('close');
	closeButton.onclick = function () {
		window.webkit.messageHandlers.cardClick.postMessage('exit');
	}
	
	document.body.setAttribute('oncontextmenu', 'event.preventDefault();');
	
	// Init context menut
	contextMenu.init();
	document.body.onclick = function (e) { contextMenu.close(); }

	debugElement = document.getElementById('debug');
	
	// Init drag & drop
	if (dragDrop) initDragDrop();
}

function log(message) {
	debugElement.innerHTML = message;
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

		var sceneIndex = el.getAttribute('sceneIndex');
		
		if (sibling) {
			var nextIndex = sibling.getAttribute('sceneIndex');
		} else {
			var nextIndex = scenes.length;
		}

		if (!nextIndex) {
			scenes[sceneIndex].sceneIndex;
		} else {
			scenes[sceneIndex].sceneIndex = nextIndex;
			for (var i = nextIndex; i < scenes.count; i++) {
				scenes[i].sceneIndex += 1;
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

// Context menu
contextMenu = {};
contextMenu.init = function () {
	contextMenu.menu = document.createElement('div');
	contextMenu.menu.id = 'contextMenu';
	
	var content = '';

	for (var i in colors) {
		var color = colors[i];
		if (typeof color === 'string') {
			content += "<div onclick=\"contextMenu.setColor('" + color + "')\"" + " class='menuItem " + color + "'><div class='color " + color + "'></div> " + color + "</div>";
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
	
	window.webkit.messageHandlers.setColor.postMessage(contextMenu.target.getAttribute('lineIndex') + ":" + color );
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


// Cards

function setupCards () {
	let cards = document.querySelectorAll('.card');
	cards.forEach(function (card) {
		card.onclick = function () { contextMenu.close(); }
		card.ondblclick = function () {
			var position = this.getAttribute('pos');
			var index = this.getAttribute('sceneIndex');
			//window.webkit.messageHandlers.cardClick.postMessage(position);
			window.webkit.messageHandlers.cardClick.postMessage(index);
		}
				  
		card.oncontextmenu = function (e) {
			e.preventDefault();
			//card.innerHTML = "JEE";
			contextMenu.toggle(e);
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
	var html = "<section id='cardContainer'>";
	var index = -1;

	var selected = null;

	scenes = [];
	debugElement.innerHTML = '';

	if (cards.length < 1) html += "<div id='noData'><h2>No scenes</h2><p>When you write some scenes, they will be visible as cards in this view</p></div>";
	
	for (let card of cards) {
		if (!card.name) { continue; }
		
		index = card.sceneIndex;
		// Don't show synopsis lines
		if (card.type == 'synopse') card.invisible = true;
		
		// Let's save the data to scenes array for later use
		scenes.push(card);

		var status = '';
		var color = '';
		var changed = '';
		var customStyles = 0;

		if (card.selected) {
			status = ' selected';
			selected = index;
		}
		if (String(card.color) != "") {
			if (String(card.color).substring(0,1) == "#") {
				// lol
				var customColor = String(card.color).substring(1);
				var style = document.createElement('style');
				
				customStyles++;
				var customStyleName = "customStyle" + customStyles.count;
				
				style.innerHTML = ".card."+customStyleName+", ."+customStyleName+".selected .sceneNumber { background-color: #"+customColor+"; color: white; } .card."+customStyleName+" p { color: #000; }";
				document.head.appendChild(style);
				
				color = ' colored ' + customStyleName;
			} else {
				color = ' colored ' + card.color;
			}
		}
		if (index == changedIndex) {
			changed = ' indexChanged ';
		}
		
		if (card.type == 'section') {
			if (card.depth == 1) {
				html += "<h2 class='depth-" + card.depth + "' sceneIndex='" + card.sceneIndex + "'>" + card.name + "</h2>";
			} else {
				if (card.depth > 3) depth = 3;
				let sectionCardClass = " section-" + card.depth;
				
				html += "<div sceneIndex='" + card.sceneIndex + "' class='sectionCardContainer " + sectionCardClass + "'><div lineIndex='" +
						card.lineIndex + "' pos='" + card.position + "' " +
						"sceneIndex='" + card.sceneIndex + "' " +
						"class='sectionCard" + sectionCardClass + color + status + changed +
						"'>"+
					"<p>" + card.name + "</p></div></div>";
			}
		}

		else if (card.type == 'synopse') {
			// Hidden
			html += "<div sceneIndex='" + card.sceneIndex + "' style='display: none;'></div>";
		}
		else {
			html += "<div sceneIndex='" + card.sceneIndex + "' class='cardContainer'><div lineIndex='" + 
					card.lineIndex + "' pos='" + card.position + "' " +
					"sceneIndex='" + card.sceneIndex + "' " +
					"class='card" + color + status + changed +
					"'>"+
				"<div class='header'><div class='sceneNumber'>" + card.sceneNumber	+ "</div>" +
				"<h3>" + card.name + "</h3></div>" +
				"<p>" + card.snippet + "</p></div></div>";
		}
	}
	html += "</section>";

	container.innerHTML = html;
	if (dragDrop) drake.containers = [document.getElementById("cardContainer")];

	// If the view is already visible, don't scroll to selected scene
	if (selected && !alreadyVisible) {
		var el = document.querySelector("div[sceneIndex='" + selected + "']");
		el.scrollIntoView({ inline: "center", block: "center" });
	}

	// Enable editing if we were waiting for something
	wait.className = "";

	// Setup drag & drop and context menus
	setupCards();
}

init();
