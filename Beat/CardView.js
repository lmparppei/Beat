
var dragDrop = false;

var colors = ['none', 'red', 'blue', 'green', 'pink', 'brown', 'cyan', 'orange', 'magenta'];

var scenes,
	container,
	closeButton,
	contextMenu;

var drake;
var debugElement;

Array.prototype.move = function (from, to) {
  this.splice(to, 0, this.splice(from, 1)[0]);
};

function init () {
	scenes = [];
	container = document.getElementById('container');

	closeButton = document.getElementById('close');
	closeButton.onclick = function () {
		window.webkit.messageHandlers.cardClick.postMessage('exit');
	}
	
	document.body.setAttribute('oncontextmenu', 'event.preventDefault();');
	
	// Init context menut
	contextMenu.init();
	document.body.onclick = function (e) { contextMenu.close(); }

	debugElement = document.getElementById('debug');
	
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

	drake.on('drop', function (el, target, source, sibling) {

		var sceneIndex = el.getAttribute('sceneIndex');
		
		if (sibling) {
			var nextIndex = sibling.getAttribute('sceneIndex');
		} else {
			var nextIndex = scenes.length;
		}

		//log("dropped " + sceneIndex + " before " + nextIndex);

		if (!nextIndex) {
			scenes[sceneIndex].sceneIndex;
		} else {
			scenes[sceneIndex].sceneIndex = nextIndex;
			for (var i = nextIndex; i < scenes.count; i++) {
				scenes[i].sceneIndex += 1;
			}
		}

		scenes.sort((a, b) => (a.sceneIndex > b.sceneIndex) ? 1 : -1)
		window.webkit.messageHandlers.move.postMessage(sceneIndex + "," + nextIndex);
		//createCards(scenes);
	});

}

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
	
	//debugElement.innerHTML = drake;
}

function nightModeOn () {
	document.body.className = 'nightMode';
}
function nightModeOff () {
	document.body.className = '';
}

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

function createCards (cards) {
	var html = "<section id='cardContainer'>";
	var index = -1;

	var selected = null;

	scenes = [];
	debugElement.innerHTML = '';

	for (let data in cards) {
		let card = cards[data];
		if (!card.name) { continue; }
		
		index++;
		card.sceneIndex = index;

		// Let's save the data to scenes array for later use
		scenes.push(card);

		var status = '';
		var color = '';

		if (card.selected == "yes") {
			status = ' selected';
			selected = index;
		}
		if (card.color != "") {
			color = ' colored ' + card.color;
		}

		if (card.type == 'section') {
			html += "<h2 sceneIndex='" + card.sceneIndex + "'>" + card.name + "</h2>";
		} else if (card.type == 'synopse') {
			html += "<div sceneIndex='" + card.sceneIndex + "' class='cardContainer'><div sceneIndex='" + card.sceneIndex + "' pos='"+card.position+"' class='synopse'><h3>" + card.name + "</h3></div></div>"
		} else {
			html += "<div sceneIndex='" + card.sceneIndex + "' class='cardContainer'><div lineIndex='" + 
					card.lineIndex + "' pos='" + card.position + "' " +
					"sceneIndex='" + card.sceneIndex + "' " +
					"class='card" + color + status + 
					"'>"+
				"<div class='header'><div class='sceneNumber'>" + card.sceneNumber	+ "</div>" +
				"<h3>" + card.name + "</h3></div>" +
				"<p>" + card.snippet + "</p></div></div>";
		}
	}
	html += "</section>";

	container.innerHTML = html;
	if (dragDrop) drake.containers = [document.getElementById("cardContainer")];

	if (selected) {
		var el = document.querySelector("div[sceneIndex='" + selected + "']");
		el.scrollIntoView({ inline: "center", block: "center" });
	}

	setupCards();
}

init ();
