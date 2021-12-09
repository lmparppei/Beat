/* 

TextAnimation © Lauri-Matti Parppei 2020
Created for BEAT manual

*/

const textAnimation = function (data) {
	if (!data.waitAt) data.waitAt = {};

	const container = document.getElementById(data.container);
	const text = data.text;
	const wait = data.wait;

	let speed = data.speed;
	if (!speed) speed = 150;

	let waiting = 0;
	let waitAt = 0;
	let skipped = 0;

	let _that = this;
	let typing = "";
	let index = -1;
	let done = false;

	let classes = [];

	this.addClass = function (className) {
		classes.push(className);
		container.classList.add(className);
	}

	function reset() {
		typing = '';
		container.innerHTML = '';

		waiting = 0;
		skipped = 0;
		index = -1;
		done = false;

		for (const className of classes) {
			container.classList.remove(className);
		}
		classes = [];
	}

	setInterval(function () {
		if (index >= text.length) done = true;

		if (!done) {
			// Run any possible events first
			if (data.events[index - skipped]) data.events[index - skipped]();
			if (data.waitAt[index - skipped] && waitAt > 0) waitAt = data.waitAt[index - skipped];

			if (waitAt > 0) {
				waitAt--;
				return;
			} else {
				waitAt = -1;
			}

			index++;
			let character = text[index];

			// Skip over HTML
			if (character == "<") {
				typing += character;

				while (character != ">" && index < text.length) {
					index++;

					character = text[index];
					typing += character;

					skipped++;
				}

				return;
			}

			if (text[index]) {
				typing += text[index];

				if (data.caret) container.innerHTML = typing + caret;
				else container.innerHTML = typing;

				if (index == text.length - 1) done = true;
			}

		} else {
			waiting++;
			if (waiting >= wait) reset();
		}

	}, speed);
}

var caret = "<div class='caret'></div>";

var sceneAnimation = new textAnimation({
	text: "int. school room - day", wait: 15, container: "scene", caret: caret, events: {
		2: function () { sceneAnimation.addClass('bold'); }
	}
});

var dialogueAnimation = new textAnimation({
	text: "CHARACTER\nWelcome to Beat!", wait: 15, container: "dialogue", caret: caret, events: {
		4: function () { dialogueAnimation.addClass('inset'); }
	}
});

var parenthesesAnimation = new textAnimation({
	text: "CHARACTER\n<span>(shrugging)</span>\nWell this is easy.",
	wait: 15,
	caret: caret,
	container: "parentheses",
	speed: 150,
	events: {
		3: function () { parenthesesAnimation.addClass('inset'); },
		11: function () { parenthesesAnimation.addClass('parenthesesInset'); }
	}
});

var bigFish = new textAnimation({
	text: "<span class='fauxCharacter'>FADE IN:</span>\n\n<span class='fauxCharacter2'>A RIVER.</span>\n\nWe're underwater, watching a fat catfish swim along.",
	container: "bigFish",
	wait: 15,
	caret: caret,
	speed: 155,
	caret: caret,
	events: {
		11: function () { bigFish.addClass('firstFaux'); },
		19: function () { bigFish.addClass('secondFaux'); }
	}
});

var stylization = new textAnimation({
	text:
		"<span class='symbol'>*</span><span class='fItalic'>I am in italic</span><span class='symbol'>*</span>\n" +
		"<span class='symbol2'>**</span><span class='fBold'>And I am bold</span><span class='symbol2'>**</span>\n" +
		"<span class='symbol3'>_</span><span class='fUnderline'>You can underline stuff, too.</span><span class='symbol3'>_</span>",
	wait: 15,
	caret: caret,
	speed: 120,
	debug: true,
	container: "stylization",
	events: {
		20: function () { stylization.addClass('makeItalic'); },
		44: function () { stylization.addClass('makeBold'); },
		79: function () { stylization.addClass('makeUnderline'); }
	}
});

/*

TableOfContents © Lauri-Matti Parppei 2020
Created for Beat Manual

*/

function tableOfContents(exclude) {
	if (!exclude) exclude = [];

	const sections = document.querySelectorAll('section');

	let toc = [];

	// Go through high-level headings
	for (const section of sections) {
		const titleNode = section.querySelector('h1');
		title = titleNode.innerText;
		if (exclude.includes(title.innerText)) continue;

		// Generate anchor
		let anchor = document.createElement("a");
		anchor.name = title.replace(/\W/g, '');
		titleNode.parentNode.insertBefore(anchor, titleNode);

		let subSections = [];
		for (let node of section.querySelectorAll('h2')) {

			let sectionAnchor = document.createElement("a");
			sectionAnchor.name = anchor.name + "-" + node.innerHTML.replace(/\W/g, '');

			node.parentNode.insertBefore(sectionAnchor, node);

			subSections.push({
				title: node.innerHTML,
				anchor: sectionAnchor.name
			});
		}

		let chapter = {
			title: section.querySelector('h1').innerText,
			anchor: anchor.name,
			subSections: subSections
		}

		toc.push(chapter);
	}

	let string = "<ol>";
	for (const chapter of toc) {
		if (chapter.anchor) {
			string += "<li><a href='#" + chapter.anchor + "'>" + chapter.title + "</a></li>";
		} else {
			string += "<li>" + chapter.title + "</li>";
		}


		if (chapter.subSections.length) {
			string += "<ul>";
			for (let section of chapter.subSections) {
				string += "<li><a href='#" + section.anchor + "'>" + section.title + "</a></li>";
			}
			string += "</ul>";
		}

	}
	string += "</ol>";
	return string;
}

let menu = document.getElementById('menuToc');
menu.innerHTML = tableOfContents(["Welcome to Beat"]);

/*

Dark Mode

*/

/*
function toggleDarkMode() {
	var elements = document.getElementsByTagName('*');
	if (document.getElementById('darkModeToggle').checked) {
		for (var i = 0; i < elements.length; i++) {
			elements[i].classList.add('dark');
		}
	}
	else {
		for (var i = 0; i < elements.length; i++) {
			elements[i].classList.remove('dark');
		}
	}
}
*/