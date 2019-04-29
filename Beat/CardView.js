var scenes = [];

document.body.setAttribute('oncontextmenu', 'event.preventDefault();');

function setupCards () {
	let cards = document.querySelectorAll('.card');
	cards.forEach(function (card) {
		card.ondblclick = function () {
			var position = this.getAttribute('pos');
			window.webkit.messageHandlers.cardClick.postMessage(position);
		}
	});	
}

function nightModeOn () {
	document.body.className = 'nightMode';
}
function nightModeOff () {
	document.body.className = '';
}

function createCards (cards) {
	var html = '<section>';
	for (let data in cards) {
		let card = cards[data];
		scenes.push(card);

		var status = '';
		if (card.selected == "yes") {
			status = ' selected';
		}

		if (card.type == 'section') {
			html += "</section><h2>" + card.name + "</h2><section>";
		} else if (card.type == 'synopse') {
			html += "<div pos='"+card.position+"' class='synopse'><h3>" + card.name + "</h3></div>"
		} else {
			html += "<div pos='"+card.position+"' class='card" + status + "'>"+
				"<div class='header'><div class='sceneNumber'>" + card.sceneNumber	+ "</div>" +
				"<h3>"+ card.name + "</h3></div>" +
				"<p>" + card.snippet + "</p></div>";
		}
	}
	html += "</section>";
	
	document.body.innerHTML = html;
	setupCards();
}