
var colors = ['none', 'red', 'blue', 'green', 'pink', 'brown', 'cyan', 'orange', 'magenta'];

var scenes,
	container,
	closeButton,
	contextMenu;

function init () {
	scenes = [];
	container = document.getElementById('container');

	closeButton = document.getElementById('close');
	closeButton.onclick = function () {
		window.webkit.messageHandlers.cardClick.postMessage('exit');
	}
	
	document.body.setAttribute('oncontextmenu', 'event.preventDefault();');
	
	contextMenu.init();
	
	document.body.onclick = function (e) { contextMenu.close(); }
}

function setupCards () {
	return;
/*
	let cards = document.querySelectorAll('.card');
	cards.forEach(function (card) {
		card.onclick = function () { contextMenu.close(); }
		card.ondblclick = function () {
			var position = this.getAttribute('pos');
			window.webkit.messageHandlers.cardClick.postMessage(position);
		}
				  
		card.oncontextmenu = function (e) {
			e.preventDefault();
			//card.innerHTML = "JEE";
			contextMenu.toggle(e);
		}
	});	
	*/
}

function nightModeOn () {
	document.body.className = 'nightMode';
}
function nightModeOff () {
	document.body.className = '';
}

contextMenu = {};
contextMenu.init = function () {
/*
	contextMenu.menu = document.createElement('div');
	contextMenu.menu.id = 'contextMenu';
	
	var content = '';
	
	for (var i in colors) {
		var color = colors[i];
		content += "<div onclick=\"contextMenu.setColor('" + color + "')\"" + " class='menuItem " + color + "'><div class='color " + color + "'></div> " + color + "</div>";
	}
	
	contextMenu.menu.innerHTML = content;
	document.body.appendChild(contextMenu.menu);
*/
}
contextMenu.toggle = function (e) {
/*
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
	}
*/	
}
contextMenu.close = function () {
	/*
	contextMenu.open = false;
	contextMenu.menu.className = '';
	*/
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

function createScenes (timelineScenes) {
	var html = '<section>';
	for (let data in timelineScenes) {
		let scene = timelineScenes[data];
		scenes.push(card);

		var status = '';
		var color = '';
		var length = scene.length;

		if (scene.selected == "yes") {
			status = ' selected';
		}
		if (scene.color != "") {
			color = ' colored ' + scene.color;
		}

		if (scene.type == 'section') {
			//html += "</section><h2>" + card.name + "</h2><section>";
		} else if (scene.type == 'synopse') {
			//html += "<div pos='"+card.position+"' class='synopse'><h3>" + card.name + "</h3></div>"
		} else {
			html += "<div lineIndex='"+ scene.lineIndex +"' pos='"+scene.position+"' class='scene" + color + status + "'>"+
				"<div class='header'><div class='sceneNumber'>" + scene.sceneNumber	+ "</div>" +
				"<h3>" + scene.name + "</h3></div>" +
				"</div>";
		}
	}
	html += "</section>";
	
	container.innerHTML = html;
	setupCards();
}

init ();
