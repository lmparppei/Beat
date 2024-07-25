(function(f){if(typeof exports==="object"&&typeof module!=="undefined"){module.exports=f()}else if(typeof define==="function"&&define.amd){define([],f)}else{var g;if(typeof window!=="undefined"){g=window}else if(typeof global!=="undefined"){g=global}else if(typeof self!=="undefined"){g=self}else{g=this}g.dragula = f()}})(function(){var define,module,exports;return (function(){function r(e,n,t){function o(i,f){if(!n[i]){if(!e[i]){var c="function"==typeof require&&require;if(!f&&c)return c(i,!0);if(u)return u(i,!0);var a=new Error("Cannot find module '"+i+"'");throw a.code="MODULE_NOT_FOUND",a}var p=n[i]={exports:{}};e[i][0].call(p.exports,function(r){var n=e[i][1][r];return o(n||r)},p,p.exports,r,e,n,t)}return n[i].exports}for(var u="function"==typeof require&&require,i=0;i<t.length;i++)o(t[i]);return o}return r})()({1:[function(require,module,exports){
'use strict';

var cache = {};
var start = '(?:^|\\s)';
var end = '(?:\\s|$)';

function lookupClass (className) {
  var cached = cache[className];
  if (cached) {
	cached.lastIndex = 0;
  } else {
	cache[className] = cached = new RegExp(start + className + end, 'g');
  }
  return cached;
}

function addClass (el, className) {
  var current = el.className;
  if (!current.length) {
	el.className = className;
  } else if (!lookupClass(className).test(current)) {
	el.className += ' ' + className;
  }
}

function rmClass (el, className) {
  el.className = el.className.replace(lookupClass(className), ' ').trim();
}

module.exports = {
  add: addClass,
  rm: rmClass
};

},{}],2:[function(require,module,exports){
(function (global){
'use strict';

var emitter = require('contra/emitter');
var crossvent = require('crossvent');
var classes = require('./classes');
var doc = document;
var documentElement = doc.documentElement;

function dragula (initialContainers, options) {
  var len = arguments.length;
  if (len === 1 && Array.isArray(initialContainers) === false) {
	options = initialContainers;
	initialContainers = [];
  }
  var _mirror; // mirror image
  var _source; // source container
  var _item; // item being dragged
  var _offsetX; // reference x
  var _offsetY; // reference y
  var _moveX; // reference move x
  var _moveY; // reference move y
  var _initialSibling; // reference sibling when grabbed
  var _currentSibling; // reference sibling now
  var _copy; // item used for copying
  var _renderTimer; // timer for setTimeout renderMirrorImage
  var _lastDropTarget = null; // last container item was over
  var _grabbed; // holds mousedown context until first mousemove

  var o = options || {};
  if (o.moves === void 0) { o.moves = always; }
  if (o.accepts === void 0) { o.accepts = always; }
  if (o.invalid === void 0) { o.invalid = invalidTarget; }
  if (o.containers === void 0) { o.containers = initialContainers || []; }
  if (o.isContainer === void 0) { o.isContainer = never; }
  if (o.copy === void 0) { o.copy = false; }
  if (o.copySortSource === void 0) { o.copySortSource = false; }
  if (o.revertOnSpill === void 0) { o.revertOnSpill = false; }
  if (o.removeOnSpill === void 0) { o.removeOnSpill = false; }
  if (o.direction === void 0) { o.direction = 'vertical'; }
  if (o.ignoreInputTextSelection === void 0) { o.ignoreInputTextSelection = true; }
  if (o.mirrorContainer === void 0) { o.mirrorContainer = doc.body; }
  if (o.animation === void 0) { o.animation = false; }

  var drake = emitter({
	containers: o.containers,
	start: manualStart,
	end: end,
	cancel: cancel,
	remove: remove,
	destroy: destroy,
	canMove: canMove,
	dragging: false
  });

  if (o.removeOnSpill === true) {
	drake.on('over', spillOver).on('out', spillOut);
  }

  events();

  return drake;

  function isContainer (el) {
	return drake.containers.indexOf(el) !== -1 || o.isContainer(el);
  }

  function events (remove) {
	var op = remove ? 'remove' : 'add';
	touchy(documentElement, op, 'mousedown', grab);
	touchy(documentElement, op, 'mouseup', release);
  }

  function eventualMovements (remove) {
	var op = remove ? 'remove' : 'add';
	touchy(documentElement, op, 'mousemove', startBecauseMouseMoved);
  }

  function movements (remove) {
	var op = remove ? 'remove' : 'add';
	crossvent[op](documentElement, 'selectstart', preventGrabbed); // IE8
	crossvent[op](documentElement, 'click', preventGrabbed);
  }

  function destroy () {
	events(true);
	release({});
  }

  function preventGrabbed (e) {
	if (_grabbed) {
	  e.preventDefault();
	}
  }

  function grab (e) {
	_moveX = e.clientX;
	_moveY = e.clientY;

	var ignore = whichMouseButton(e) !== 1 || e.metaKey || e.ctrlKey;
	if (ignore) {
	  return; // we only care about honest-to-god left clicks and touch events
	}
	var item = e.target;
	var context = canStart(item);
	if (!context) {
	  return;
	}
	_grabbed = context;
	eventualMovements();
	if (e.type === 'mousedown') {
	  if (isInput(item)) { // see also: https://github.com/bevacqua/dragula/issues/208
		item.focus(); // fixes https://github.com/bevacqua/dragula/issues/176
	  } else {
		e.preventDefault(); // fixes https://github.com/bevacqua/dragula/issues/155
	  }
	}
  }

  function startBecauseMouseMoved (e) {
	if (!_grabbed) {
	  return;
	}
	if (whichMouseButton(e) === 0) {
	  release({});
	  return; // when text is selected on an input and then dragged, mouseup doesn't fire. this is our only hope
	}

	// truthy check fixes #239, equality fixes #207, fixes #501
	if ((e.clientX !== void 0 && Math.abs(e.clientX - _moveX) <= (o.slideFactorX || 0)) &&
	  (e.clientY !== void 0 && Math.abs(e.clientY - _moveY) <= (o.slideFactorY || 0))) {
	  return;
	}

	if (o.ignoreInputTextSelection) {
	  var clientX = getCoord('clientX', e) || 0;
	  var clientY = getCoord('clientY', e) || 0;
	  var elementBehindCursor = doc.elementFromPoint(clientX, clientY);
	  if (isInput(elementBehindCursor)) {
		return;
	  }
	}

	var grabbed = _grabbed; // call to end() unsets _grabbed
	eventualMovements(true);
	movements();
	end();
	start(grabbed);

	var offset = getOffset(_item);
	_offsetX = getCoord('pageX', e) - offset.left;
	_offsetY = getCoord('pageY', e) - offset.top;

	classes.add(_copy || _item, 'gu-transit');
	renderMirrorImage();
	drag(e);
  }

  function canStart (item) {
	if (drake.dragging && _mirror) {
	  return;
	}
	if (isContainer(item)) {
	  return; // don't drag container itself
	}
	var handle = item;
	while (getParent(item) && isContainer(getParent(item)) === false) {
	  if (o.invalid(item, handle)) {
		return;
	  }
	  item = getParent(item); // drag target should be a top element
	  if (!item) {
		return;
	  }
	}
	var source = getParent(item);
	if (!source) {
	  return;
	}
	if (o.invalid(item, handle)) {
	  return;
	}

	var movable = o.moves(item, source, handle, nextEl(item));
	if (!movable) {
	  return;
	}

	return {
	  item: item,
	  source: source
	};
  }

  function canMove (item) {
	return !!canStart(item);
  }

  function manualStart (item) {
	var context = canStart(item);
	if (context) {
	  start(context);
	}
  }

  function start (context) {
	if (isCopy(context.item, context.source)) {
	  _copy = context.item.cloneNode(true);
	  drake.emit('cloned', _copy, context.item, 'copy');
	}

	_source = context.source;
	_item = context.item;
	_initialSibling = _currentSibling = nextEl(context.item);

	drake.dragging = true;
	drake.emit('drag', _item, _source);
  }

  function invalidTarget () {
	return false;
  }

  function end () {
	if (!drake.dragging) {
	  return;
	}
	var item = _copy || _item;
	drop(item, getParent(item));
  }

  function ungrab () {
	_grabbed = false;
	eventualMovements(true);
	movements(true);
  }

  function release (e) {
	ungrab();

	if (!drake.dragging) {
	  return;
	}
	var item = _copy || _item;
	var clientX = getCoord('clientX', e) || 0;
	var clientY = getCoord('clientY', e) || 0;
	var elementBehindCursor = getElementBehindPoint(_mirror, clientX, clientY);
	var dropTarget = findDropTarget(elementBehindCursor, clientX, clientY);
	if (dropTarget && ((_copy && o.copySortSource) || (!_copy || dropTarget !== _source))) {
	  drop(item, dropTarget);
	} else if (o.removeOnSpill) {
	  remove();
	} else {
	  cancel();
	}
  }

  function drop (item, target) {
	var parent = getParent(item);
	if (_copy && o.copySortSource && target === _source) {
	  parent.removeChild(_item);
	}
	if (isInitialPlacement(target)) {
	  drake.emit('cancel', item, _source, _source);
	} else {
	  drake.emit('drop', item, target, _source, _currentSibling);
	}
	cleanup();
  }

  function remove () {
	if (!drake.dragging) {
	  return;
	}
	var item = _copy || _item;
	var parent = getParent(item);
	if (parent) {
	  parent.removeChild(item);
	}
	drake.emit(_copy ? 'cancel' : 'remove', item, parent, _source);
	cleanup();
  }

  function cancel (revert) {
	if (!drake.dragging) {
	  return;
	}
	var reverts = arguments.length > 0 ? revert : o.revertOnSpill;
	var item = _copy || _item;
	var parent = getParent(item);
	var initial = isInitialPlacement(parent);
	if (initial === false && reverts) {
	  if (_copy) {
		if (parent) {
		  parent.removeChild(_copy);
		}
	  } else {
		_source.insertBefore(item, _initialSibling);
	  }
	}
	if (initial || reverts) {
	  drake.emit('cancel', item, _source, _source);
	} else {
	  drake.emit('drop', item, parent, _source, _currentSibling);
	}
	cleanup();
  }

  function cleanup () {
	var item = _copy || _item;
	ungrab();
	removeMirrorImage();
	if (item) {
	  classes.rm(item, 'gu-transit');
	}
	if (_renderTimer) {
	  clearTimeout(_renderTimer);
	}
	drake.dragging = false;
	if (_lastDropTarget) {
	  drake.emit('out', item, _lastDropTarget, _source);
	}
	drake.emit('dragend', item);
	_source = _item = _copy = _initialSibling = _currentSibling = _renderTimer = _lastDropTarget = null;
  }

  function isInitialPlacement (target, s) {
	var sibling;
	if (s !== void 0) {
	  sibling = s;
	} else if (_mirror) {
	  sibling = _currentSibling;
	} else {
	  sibling = nextEl(_copy || _item);
	}
	return target === _source && sibling === _initialSibling;
  }

  function findDropTarget (elementBehindCursor, clientX, clientY) {
	var target = elementBehindCursor;
	while (target && !accepted()) {
	  target = getParent(target);
	}
	return target;

	function accepted () {
	  var droppable = isContainer(target);
	  if (droppable === false) {
		return false;
	  }

	  var immediate = getImmediateChild(target, elementBehindCursor);
	  var reference = getReference(target, immediate, clientX, clientY);
	  var initial = isInitialPlacement(target, reference);
	  if (initial) {
		return true; // should always be able to drop it right back where it was
	  }
	  return o.accepts(_item, target, _source, reference);
	}
  }

  function drag (e) {
	if (!_mirror) {
	  return;
	}
	e.preventDefault();

	var clientX = getCoord('clientX', e) || 0;
	var clientY = getCoord('clientY', e) || 0;
	var x = clientX - _offsetX;
	var y = clientY - _offsetY;

	_mirror.style.left = x + 'px';
	_mirror.style.top = y + 'px';

	var item = _copy || _item;
	var elementBehindCursor = getElementBehindPoint(_mirror, clientX, clientY);
	var dropTarget = findDropTarget(elementBehindCursor, clientX, clientY);
	var changed = dropTarget !== null && dropTarget !== _lastDropTarget;
	if (changed || dropTarget === null) {
	  out();
	  _lastDropTarget = dropTarget;
	  over();
	}
	var parent = getParent(item);
	if (dropTarget === _source && _copy && !o.copySortSource) {
	  if (parent) {
		parent.removeChild(item);
	  }
	  return;
	}
	  
	var reference;
    var mover, moverRect;
    var previous, next, previousRect, nextRect, itemRect;
	var currentPrevious, currentNext;
	  
	var immediate = getImmediateChild(dropTarget, elementBehindCursor);
	if (immediate !== null) {
	  reference = getReference(dropTarget, immediate, clientX, clientY);
	} else if (o.revertOnSpill === true && !_copy) {
	  reference = _initialSibling;
	  dropTarget = _source;
	} else {
	  if (_copy && parent) {
		parent.removeChild(item);
	  }
	  return;
	}
	if (
	  (reference === null && changed) ||
	  reference !== item &&
	  reference !== nextEl(item)
	) {
	  _currentSibling = reference;
		
		var isBrother = item.parentElement === dropTarget;
		var shouldAnimate = isBrother && o.animation;
		if (shouldAnimate) {
			previous = item && previousEl(item);
			next = item && nextEl(item);
			previousRect, nextRect;
			itemRect = item.getBoundingClientRect();
			
			if(!previous){
				mover = next;
				moverRect = mover.getBoundingClientRect();
			} else if(!next){
				mover = previous;
				moverRect = mover.getBoundingClientRect();
			} else {
				previousRect = previous.getBoundingClientRect();
				nextRect = next.getBoundingClientRect();
			}
		}
		
	  dropTarget.insertBefore(item, reference);
		
		if (shouldAnimate) {
			if(!mover){
				currentPrevious = item && previousEl(item);
				currentNext = item && nextEl(item);
				if (previous === currentNext) { // up
					mover = previous;
					moverRect = previousRect;
				}
				if (next === currentPrevious) { // down
					mover = next;
					moverRect = nextRect;
				}
			}
			animate(moverRect, mover, o.animation);
			animate(itemRect, item, o.animation);
		}
		
	  drake.emit('shadow', item, dropTarget, _source);
	}
	function moved (type) { drake.emit(type, item, _lastDropTarget, _source); }
	function over () { if (changed) { moved('over'); } }
	function out () { if (_lastDropTarget) { moved('out'); } }
  }

  function spillOver (el) {
	classes.rm(el, 'gu-hide');
  }

  function spillOut (el) {
	if (drake.dragging) { classes.add(el, 'gu-hide'); }
  }

  function renderMirrorImage () {
	if (_mirror) {
	  return;
	}
	var rect = _item.getBoundingClientRect();
	_mirror = _item.cloneNode(true);
	_mirror.style.width = getRectWidth(rect) + 'px';
	_mirror.style.height = getRectHeight(rect) + 'px';
	classes.rm(_mirror, 'gu-transit');
	classes.add(_mirror, 'gu-mirror');
	o.mirrorContainer.appendChild(_mirror);
	touchy(documentElement, 'add', 'mousemove', drag);
	classes.add(o.mirrorContainer, 'gu-unselectable');
	drake.emit('cloned', _mirror, _item, 'mirror');
  }

  function removeMirrorImage () {
	if (_mirror) {
	  classes.rm(o.mirrorContainer, 'gu-unselectable');
	  touchy(documentElement, 'remove', 'mousemove', drag);
	  getParent(_mirror).removeChild(_mirror);
	  _mirror = null;
	}
  }

  function getImmediateChild (dropTarget, target) {
	var immediate = target;
	while (immediate !== dropTarget && getParent(immediate) !== dropTarget) {
	  immediate = getParent(immediate);
	}
	if (immediate === documentElement) {
	  return null;
	}
	return immediate;
  }

  function getReference (dropTarget, target, x, y) {
	var horizontal = o.direction === 'horizontal';
	var reference = target !== dropTarget ? inside() : outside();
	return reference;

	function outside () { // slower, but able to figure out any position
	  var len = dropTarget.children.length;
	  var i;
	  var el;
	  var rect;
	  for (i = 0; i < len; i++) {
		el = dropTarget.children[i];
		rect = el.getBoundingClientRect();
		if (horizontal && (rect.left + rect.width / 2) > x) { return el; }
		if (!horizontal && (rect.top + rect.height / 2) > y) { return el; }
	  }
	  return null;
	}

	function inside () { // faster, but only available if dropped inside a child element
	  var rect = target.getBoundingClientRect();
	  if (horizontal) {
		return resolve(x > rect.left + getRectWidth(rect) / 2);
	  }
	  return resolve(y > rect.top + getRectHeight(rect) / 2);
	}

	function resolve (after) {
	  return after ? nextEl(target) : target;
	}
  }

  function isCopy (item, container) {
	return typeof o.copy === 'boolean' ? o.copy : o.copy(item, container);
  }
}

function touchy (el, op, type, fn) {
  var touch = {
	mouseup: 'touchend',
	mousedown: 'touchstart',
	mousemove: 'touchmove'
  };
  var pointers = {
	mouseup: 'pointerup',
	mousedown: 'pointerdown',
	mousemove: 'pointermove'
  };
  var microsoft = {
	mouseup: 'MSPointerUp',
	mousedown: 'MSPointerDown',
	mousemove: 'MSPointerMove'
  };
  if (global.navigator.pointerEnabled) {
	crossvent[op](el, pointers[type], fn);
  } else if (global.navigator.msPointerEnabled) {
	crossvent[op](el, microsoft[type], fn);
  } else {
	crossvent[op](el, touch[type], fn);
	crossvent[op](el, type, fn);
  }
}

function whichMouseButton (e) {
  if (e.touches !== void 0) { return e.touches.length; }
  if (e.which !== void 0 && e.which !== 0) { return e.which; } // see https://github.com/bevacqua/dragula/issues/261
  if (e.buttons !== void 0) { return e.buttons; }
  var button = e.button;
  if (button !== void 0) { // see https://github.com/jquery/jquery/blob/99e8ff1baa7ae341e94bb89c3e84570c7c3ad9ea/src/event.js#L573-L575
	return button & 1 ? 1 : button & 2 ? 3 : (button & 4 ? 2 : 0);
  }
}

function getOffset (el) {
  var rect = el.getBoundingClientRect();
  return {
	left: rect.left + getScroll('scrollLeft', 'pageXOffset'),
	top: rect.top + getScroll('scrollTop', 'pageYOffset')
  };
}

function getScroll (scrollProp, offsetProp) {
  if (typeof global[offsetProp] !== 'undefined') {
	return global[offsetProp];
  }
  if (documentElement.clientHeight) {
	return documentElement[scrollProp];
  }
  return doc.body[scrollProp];
}

function getElementBehindPoint (point, x, y) {
  point = point || {};
  var state = point.className || '';
  var el;
  point.className += ' gu-hide';
  el = doc.elementFromPoint(x, y);
  point.className = state;
  return el;
}

function never () { return false; }
function always () { return true; }
function getRectWidth (rect) { return rect.width || (rect.right - rect.left); }
function getRectHeight (rect) { return rect.height || (rect.bottom - rect.top); }
function getParent (el) { return el.parentNode === doc ? null : el.parentNode; }
function isInput (el) { return el.tagName === 'INPUT' || el.tagName === 'TEXTAREA' || el.tagName === 'SELECT' || isEditable(el); }
function isEditable (el) {
  if (!el) { return false; } // no parents were editable
  if (el.contentEditable === 'false') { return false; } // stop the lookup
  if (el.contentEditable === 'true') { return true; } // found a contentEditable element in the chain
  return isEditable(getParent(el)); // contentEditable is set to 'inherit'
}

function previousEl (el) {
  return el.previousElementSibling || manually();
  function manually () {
	var sibling = el;
	do {
	  sibling = sibling.previousSibling;
	} while (sibling && sibling.nodeType !== 1);
	return sibling;
  }
}

function animate (prevRect, target, time) {
  if (time) {
	var currentRect = target.getBoundingClientRect();
	target.style.transition = 'none';
	target.style.transform = 'translate3d(' + (prevRect.left - currentRect.left) + 'px,' + (prevRect.top - currentRect.top) + 'px,0)';
	target.offsetWidth; // repaint
	target.style.transition = 'all ' + time + 'ms';
	target.style.transform = 'translate3d(0,0,0)';
	clearTimeout(target.animated);
	target.animated = setTimeout(function () {
	  target.style.transition = '';
	  target.style.transform = '';
	  target.animated = false;
	}, time);
  }
}
	
function nextEl (el) {
  return el.nextElementSibling || manually();
  function manually () {
	var sibling = el;
	do {
	  sibling = sibling.nextSibling;
	} while (sibling && sibling.nodeType !== 1);
	return sibling;
  }
}

function getEventHost (e) {
  // on touchend event, we have to use `e.changedTouches`
  // see http://stackoverflow.com/questions/7192563/touchend-event-properties
  // see https://github.com/bevacqua/dragula/issues/34
  if (e.targetTouches && e.targetTouches.length) {
	return e.targetTouches[0];
  }
  if (e.changedTouches && e.changedTouches.length) {
	return e.changedTouches[0];
  }
  return e;
}

function getCoord (coord, e) {
  var host = getEventHost(e);
  var missMap = {
	pageX: 'clientX', // IE8
	pageY: 'clientY' // IE8
  };
  if (coord in missMap && !(coord in host) && missMap[coord] in host) {
	coord = missMap[coord];
  }
  return host[coord];
}

module.exports = dragula;

}).call(this,typeof global !== "undefined" ? global : typeof self !== "undefined" ? self : typeof window !== "undefined" ? window : {})

},{"./classes":1,"contra/emitter":5,"crossvent":6}],3:[function(require,module,exports){
module.exports = function atoa (a, n) { return Array.prototype.slice.call(a, n); }

},{}],4:[function(require,module,exports){
'use strict';

var ticky = require('ticky');

module.exports = function debounce (fn, args, ctx) {
  if (!fn) { return; }
  ticky(function run () {
	fn.apply(ctx || null, args || []);
  });
};

},{"ticky":10}],5:[function(require,module,exports){
'use strict';

var atoa = require('atoa');
var debounce = require('./debounce');

module.exports = function emitter (thing, options) {
  var opts = options || {};
  var evt = {};
  if (thing === undefined) { thing = {}; }
  thing.on = function (type, fn) {
	if (!evt[type]) {
	  evt[type] = [fn];
	} else {
	  evt[type].push(fn);
	}
	return thing;
  };
  thing.once = function (type, fn) {
	fn._once = true; // thing.off(fn) still works!
	thing.on(type, fn);
	return thing;
  };
  thing.off = function (type, fn) {
	var c = arguments.length;
	if (c === 1) {
	  delete evt[type];
	} else if (c === 0) {
	  evt = {};
	} else {
	  var et = evt[type];
	  if (!et) { return thing; }
	  et.splice(et.indexOf(fn), 1);
	}
	return thing;
  };
  thing.emit = function () {
	var args = atoa(arguments);
	return thing.emitterSnapshot(args.shift()).apply(this, args);
  };
  thing.emitterSnapshot = function (type) {
	var et = (evt[type] || []).slice(0);
	return function () {
	  var args = atoa(arguments);
	  var ctx = this || thing;
	  if (type === 'error' && opts.throws !== false && !et.length) { throw args.length === 1 ? args[0] : args; }
	  et.forEach(function emitter (listen) {
		if (opts.async) { debounce(listen, args, ctx); } else { listen.apply(ctx, args); }
		if (listen._once) { thing.off(type, listen); }
	  });
	  return thing;
	};
  };
  return thing;
};

},{"./debounce":4,"atoa":3}],6:[function(require,module,exports){
(function (global){
'use strict';

var customEvent = require('custom-event');
var eventmap = require('./eventmap');
var doc = global.document;
var addEvent = addEventEasy;
var removeEvent = removeEventEasy;
var hardCache = [];

if (!global.addEventListener) {
  addEvent = addEventHard;
  removeEvent = removeEventHard;
}

module.exports = {
  add: addEvent,
  remove: removeEvent,
  fabricate: fabricateEvent
};

function addEventEasy (el, type, fn, capturing) {
  return el.addEventListener(type, fn, capturing);
}

function addEventHard (el, type, fn) {
  return el.attachEvent('on' + type, wrap(el, type, fn));
}

function removeEventEasy (el, type, fn, capturing) {
  return el.removeEventListener(type, fn, capturing);
}

function removeEventHard (el, type, fn) {
  var listener = unwrap(el, type, fn);
  if (listener) {
	return el.detachEvent('on' + type, listener);
  }
}

function fabricateEvent (el, type, model) {
  var e = eventmap.indexOf(type) === -1 ? makeCustomEvent() : makeClassicEvent();
  if (el.dispatchEvent) {
	el.dispatchEvent(e);
  } else {
	el.fireEvent('on' + type, e);
  }
  function makeClassicEvent () {
	var e;
	if (doc.createEvent) {
	  e = doc.createEvent('Event');
	  e.initEvent(type, true, true);
	} else if (doc.createEventObject) {
	  e = doc.createEventObject();
	}
	return e;
  }
  function makeCustomEvent () {
	return new customEvent(type, { detail: model });
  }
}

function wrapperFactory (el, type, fn) {
  return function wrapper (originalEvent) {
	var e = originalEvent || global.event;
	e.target = e.target || e.srcElement;
	e.preventDefault = e.preventDefault || function preventDefault () { e.returnValue = false; };
	e.stopPropagation = e.stopPropagation || function stopPropagation () { e.cancelBubble = true; };
	e.which = e.which || e.keyCode;
	fn.call(el, e);
  };
}

function wrap (el, type, fn) {
  var wrapper = unwrap(el, type, fn) || wrapperFactory(el, type, fn);
  hardCache.push({
	wrapper: wrapper,
	element: el,
	type: type,
	fn: fn
  });
  return wrapper;
}

function unwrap (el, type, fn) {
  var i = find(el, type, fn);
  if (i) {
	var wrapper = hardCache[i].wrapper;
	hardCache.splice(i, 1); // free up a tad of memory
	return wrapper;
  }
}

function find (el, type, fn) {
  var i, item;
  for (i = 0; i < hardCache.length; i++) {
	item = hardCache[i];
	if (item.element === el && item.type === type && item.fn === fn) {
	  return i;
	}
  }
}

}).call(this,typeof global !== "undefined" ? global : typeof self !== "undefined" ? self : typeof window !== "undefined" ? window : {})

},{"./eventmap":7,"custom-event":8}],7:[function(require,module,exports){
(function (global){
'use strict';

var eventmap = [];
var eventname = '';
var ron = /^on/;

for (eventname in global) {
  if (ron.test(eventname)) {
	eventmap.push(eventname.slice(2));
  }
}

module.exports = eventmap;

}).call(this,typeof global !== "undefined" ? global : typeof self !== "undefined" ? self : typeof window !== "undefined" ? window : {})

},{}],8:[function(require,module,exports){
(function (global){

var NativeCustomEvent = global.CustomEvent;

function useNative () {
  try {
	var p = new NativeCustomEvent('cat', { detail: { foo: 'bar' } });
	return  'cat' === p.type && 'bar' === p.detail.foo;
  } catch (e) {
  }
  return false;
}

/**
 * Cross-browser `CustomEvent` constructor.
 *
 * https://developer.mozilla.org/en-US/docs/Web/API/CustomEvent.CustomEvent
 *
 * @public
 */

module.exports = useNative() ? NativeCustomEvent :

// IE >= 9
'undefined' !== typeof document && 'function' === typeof document.createEvent ? function CustomEvent (type, params) {
  var e = document.createEvent('CustomEvent');
  if (params) {
	e.initCustomEvent(type, params.bubbles, params.cancelable, params.detail);
  } else {
	e.initCustomEvent(type, false, false, void 0);
  }
  return e;
} :

// IE <= 8
function CustomEvent (type, params) {
  var e = document.createEventObject();
  e.type = type;
  if (params) {
	e.bubbles = Boolean(params.bubbles);
	e.cancelable = Boolean(params.cancelable);
	e.detail = params.detail;
  } else {
	e.bubbles = false;
	e.cancelable = false;
	e.detail = void 0;
  }
  return e;
}

}).call(this,typeof global !== "undefined" ? global : typeof self !== "undefined" ? self : typeof window !== "undefined" ? window : {})

},{}],9:[function(require,module,exports){
// shim for using process in browser
var process = module.exports = {};

// cached from whatever global is present so that test runners that stub it
// don't break things.  But we need to wrap it in a try catch in case it is
// wrapped in strict mode code which doesn't define any globals.  It's inside a
// function because try/catches deoptimize in certain engines.

var cachedSetTimeout;
var cachedClearTimeout;

function defaultSetTimout() {
	throw new Error('setTimeout has not been defined');
}
function defaultClearTimeout () {
	throw new Error('clearTimeout has not been defined');
}
(function () {
	try {
		if (typeof setTimeout === 'function') {
			cachedSetTimeout = setTimeout;
		} else {
			cachedSetTimeout = defaultSetTimout;
		}
	} catch (e) {
		cachedSetTimeout = defaultSetTimout;
	}
	try {
		if (typeof clearTimeout === 'function') {
			cachedClearTimeout = clearTimeout;
		} else {
			cachedClearTimeout = defaultClearTimeout;
		}
	} catch (e) {
		cachedClearTimeout = defaultClearTimeout;
	}
} ())
function runTimeout(fun) {
	if (cachedSetTimeout === setTimeout) {
		//normal enviroments in sane situations
		return setTimeout(fun, 0);
	}
	// if setTimeout wasn't available but was latter defined
	if ((cachedSetTimeout === defaultSetTimout || !cachedSetTimeout) && setTimeout) {
		cachedSetTimeout = setTimeout;
		return setTimeout(fun, 0);
	}
	try {
		// when when somebody has screwed with setTimeout but no I.E. maddness
		return cachedSetTimeout(fun, 0);
	} catch(e){
		try {
			// When we are in I.E. but the script has been evaled so I.E. doesn't trust the global object when called normally
			return cachedSetTimeout.call(null, fun, 0);
		} catch(e){
			// same as above but when it's a version of I.E. that must have the global object for 'this', hopfully our context correct otherwise it will throw a global error
			return cachedSetTimeout.call(this, fun, 0);
		}
	}


}
function runClearTimeout(marker) {
	if (cachedClearTimeout === clearTimeout) {
		//normal enviroments in sane situations
		return clearTimeout(marker);
	}
	// if clearTimeout wasn't available but was latter defined
	if ((cachedClearTimeout === defaultClearTimeout || !cachedClearTimeout) && clearTimeout) {
		cachedClearTimeout = clearTimeout;
		return clearTimeout(marker);
	}
	try {
		// when when somebody has screwed with setTimeout but no I.E. maddness
		return cachedClearTimeout(marker);
	} catch (e){
		try {
			// When we are in I.E. but the script has been evaled so I.E. doesn't  trust the global object when called normally
			return cachedClearTimeout.call(null, marker);
		} catch (e){
			// same as above but when it's a version of I.E. that must have the global object for 'this', hopfully our context correct otherwise it will throw a global error.
			// Some versions of I.E. have different rules for clearTimeout vs setTimeout
			return cachedClearTimeout.call(this, marker);
		}
	}



}
var queue = [];
var draining = false;
var currentQueue;
var queueIndex = -1;

function cleanUpNextTick() {
	if (!draining || !currentQueue) {
		return;
	}
	draining = false;
	if (currentQueue.length) {
		queue = currentQueue.concat(queue);
	} else {
		queueIndex = -1;
	}
	if (queue.length) {
		drainQueue();
	}
}

function drainQueue() {
	if (draining) {
		return;
	}
	var timeout = runTimeout(cleanUpNextTick);
	draining = true;

	var len = queue.length;
	while(len) {
		currentQueue = queue;
		queue = [];
		while (++queueIndex < len) {
			if (currentQueue) {
				currentQueue[queueIndex].run();
			}
		}
		queueIndex = -1;
		len = queue.length;
	}
	currentQueue = null;
	draining = false;
	runClearTimeout(timeout);
}

process.nextTick = function (fun) {
	var args = new Array(arguments.length - 1);
	if (arguments.length > 1) {
		for (var i = 1; i < arguments.length; i++) {
			args[i - 1] = arguments[i];
		}
	}
	queue.push(new Item(fun, args));
	if (queue.length === 1 && !draining) {
		runTimeout(drainQueue);
	}
};

// v8 likes predictible objects
function Item(fun, array) {
	this.fun = fun;
	this.array = array;
}
Item.prototype.run = function () {
	this.fun.apply(null, this.array);
};
process.title = 'browser';
process.browser = true;
process.env = {};
process.argv = [];
process.version = ''; // empty string to avoid regexp issues
process.versions = {};

function noop() {}

process.on = noop;
process.addListener = noop;
process.once = noop;
process.off = noop;
process.removeListener = noop;
process.removeAllListeners = noop;
process.emit = noop;
process.prependListener = noop;
process.prependOnceListener = noop;

process.listeners = function (name) { return [] }

process.binding = function (name) {
	throw new Error('process.binding is not supported');
};

process.cwd = function () { return '/' };
process.chdir = function (dir) {
	throw new Error('process.chdir is not supported');
};
process.umask = function() { return 0; };

},{}],10:[function(require,module,exports){
(function (setImmediate){
var si = typeof setImmediate === 'function', tick;
if (si) {
  tick = function (fn) { setImmediate(fn); };
} else {
  tick = function (fn) { setTimeout(fn, 0); };
}

module.exports = tick;
}).call(this,require("timers").setImmediate)

},{"timers":11}],11:[function(require,module,exports){
(function (setImmediate,clearImmediate){
var nextTick = require('process/browser.js').nextTick;
var apply = Function.prototype.apply;
var slice = Array.prototype.slice;
var immediateIds = {};
var nextImmediateId = 0;

// DOM APIs, for completeness

exports.setTimeout = function() {
  return new Timeout(apply.call(setTimeout, window, arguments), clearTimeout);
};
exports.setInterval = function() {
  return new Timeout(apply.call(setInterval, window, arguments), clearInterval);
};
exports.clearTimeout =
exports.clearInterval = function(timeout) { timeout.close(); };

function Timeout(id, clearFn) {
  this._id = id;
  this._clearFn = clearFn;
}
Timeout.prototype.unref = Timeout.prototype.ref = function() {};
Timeout.prototype.close = function() {
  this._clearFn.call(window, this._id);
};

// Does not start the time, just sets up the members needed.
exports.enroll = function(item, msecs) {
  clearTimeout(item._idleTimeoutId);
  item._idleTimeout = msecs;
};

exports.unenroll = function(item) {
  clearTimeout(item._idleTimeoutId);
  item._idleTimeout = -1;
};

exports._unrefActive = exports.active = function(item) {
  clearTimeout(item._idleTimeoutId);

  var msecs = item._idleTimeout;
  if (msecs >= 0) {
	item._idleTimeoutId = setTimeout(function onTimeout() {
	  if (item._onTimeout)
		item._onTimeout();
	}, msecs);
  }
};

// That's not how node.js implements it but the exposed api is the same.
exports.setImmediate = typeof setImmediate === "function" ? setImmediate : function(fn) {
  var id = nextImmediateId++;
  var args = arguments.length < 2 ? false : slice.call(arguments, 1);

  immediateIds[id] = true;

  nextTick(function onNextTick() {
	if (immediateIds[id]) {
	  // fn.call() is faster so we optimize for the common use-case
	  // @see http://jsperf.com/call-apply-segu
	  if (args) {
		fn.apply(null, args);
	  } else {
		fn.call(null);
	  }
	  // Prevent ids from leaking
	  exports.clearImmediate(id);
	}
  });

  return id;
};

exports.clearImmediate = typeof clearImmediate === "function" ? clearImmediate : function(id) {
  delete immediateIds[id];
};
}).call(this,require("timers").setImmediate,require("timers").clearImmediate)

},{"process/browser.js":9,"timers":11}]},{},[2])(2)
});

 /*
 !function(e){"object"==typeof exports&&"undefined"!=typeof module?module.exports=e():"function"==typeof define&&define.amd?define([],e):("undefined"!=typeof window?window:"undefined"!=typeof global?global:"undefined"!=typeof self?self:this).dragula=e()}(function(){return function o(r,i,u){function c(t,e){if(!i[t]){if(!r[t]){var n="function"==typeof require&&require;if(!e&&n)return n(t,!0);if(a)return a(t,!0);throw(n=new Error("Cannot find module '"+t+"'")).code="MODULE_NOT_FOUND",n}n=i[t]={exports:{}},r[t][0].call(n.exports,function(e){return c(r[t][1][e]||e)},n,n.exports,o,r,i,u)}return i[t].exports}for(var a="function"==typeof require&&require,e=0;e<u.length;e++)c(u[e]);return c}({1:[function(e,t,n){"use strict";var o={},r="(?:^|\\s)",i="(?:\\s|$)";function u(e){var t=o[e];return t?t.lastIndex=0:o[e]=t=new RegExp(r+e+i,"g"),t}t.exports={add:function(e,t){var n=e.className;n.length?u(t).test(n)||(e.className+=" "+t):e.className=t},rm:function(e,t){e.className=e.className.replace(u(t)," ").trim()}}},{}],2:[function(e,t,n){(function(r){"use strict";var M=e("contra/emitter"),k=e("crossvent"),j=e("./classes"),R=document,q=R.documentElement;function U(e,t,n,o){r.navigator.pointerEnabled?k[t](e,{mouseup:"pointerup",mousedown:"pointerdown",mousemove:"pointermove"}[n],o):r.navigator.msPointerEnabled?k[t](e,{mouseup:"MSPointerUp",mousedown:"MSPointerDown",mousemove:"MSPointerMove"}[n],o):(k[t](e,{mouseup:"touchend",mousedown:"touchstart",mousemove:"touchmove"}[n],o),k[t](e,n,o))}function K(e){if(void 0!==e.touches)return e.touches.length;if(void 0!==e.which&&0!==e.which)return e.which;if(void 0!==e.buttons)return e.buttons;e=e.button;return void 0!==e?1&e?1:2&e?3:4&e?2:0:void 0}function z(e,t){return void 0!==r[t]?r[t]:(q.clientHeight?q:R.body)[e]}function H(e,t,n){var o=(e=e||{}).className||"";return e.className+=" gu-hide",n=R.elementFromPoint(t,n),e.className=o,n}function V(){return!1}function $(){return!0}function G(e){return e.width||e.right-e.left}function J(e){return e.height||e.bottom-e.top}function Q(e){return e.parentNode===R?null:e.parentNode}function W(e){return"INPUT"===e.tagName||"TEXTAREA"===e.tagName||"SELECT"===e.tagName||function e(t){if(!t)return!1;if("false"===t.contentEditable)return!1;if("true"===t.contentEditable)return!0;return e(Q(t))}(e)}function Z(t){return t.nextElementSibling||function(){var e=t;for(;e=e.nextSibling,e&&1!==e.nodeType;);return e}()}function ee(e,t){var t=(n=t).targetTouches&&n.targetTouches.length?n.targetTouches[0]:n.changedTouches&&n.changedTouches.length?n.changedTouches[0]:n,n={pageX:"clientX",pageY:"clientY"};return e in n&&!(e in t)&&n[e]in t&&(e=n[e]),t[e]}t.exports=function(e,t){var l,f,s,d,m,o,r,v,p,h,n;1===arguments.length&&!1===Array.isArray(e)&&(t=e,e=[]);var i,g=null,y=t||{};void 0===y.moves&&(y.moves=$),void 0===y.accepts&&(y.accepts=$),void 0===y.invalid&&(y.invalid=function(){return!1}),void 0===y.containers&&(y.containers=e||[]),void 0===y.isContainer&&(y.isContainer=V),void 0===y.copy&&(y.copy=!1),void 0===y.copySortSource&&(y.copySortSource=!1),void 0===y.revertOnSpill&&(y.revertOnSpill=!1),void 0===y.removeOnSpill&&(y.removeOnSpill=!1),void 0===y.direction&&(y.direction="vertical"),void 0===y.ignoreInputTextSelection&&(y.ignoreInputTextSelection=!0),void 0===y.mirrorContainer&&(y.mirrorContainer=R.body);var w=M({containers:y.containers,start:function(e){e=S(e);e&&C(e)},end:O,cancel:L,remove:X,destroy:function(){c(!0),N({})},canMove:function(e){return!!S(e)},dragging:!1});return!0===y.removeOnSpill&&w.on("over",function(e){j.rm(e,"gu-hide")}).on("out",function(e){w.dragging&&j.add(e,"gu-hide")}),c(),w;function u(e){return-1!==w.containers.indexOf(e)||y.isContainer(e)}function c(e){e=e?"remove":"add";U(q,e,"mousedown",E),U(q,e,"mouseup",N)}function a(e){U(q,e?"remove":"add","mousemove",x)}function b(e){e=e?"remove":"add";k[e](q,"selectstart",T),k[e](q,"click",T)}function T(e){i&&e.preventDefault()}function E(e){var t,n;o=e.clientX,r=e.clientY,1!==K(e)||e.metaKey||e.ctrlKey||(n=S(t=e.target))&&(i=n,a(),"mousedown"===e.type&&(W(t)?t.focus():e.preventDefault()))}function x(e){if(i)if(0!==K(e)){if(!(void 0!==e.clientX&&Math.abs(e.clientX-o)<=(y.slideFactorX||0)&&void 0!==e.clientY&&Math.abs(e.clientY-r)<=(y.slideFactorY||0))){if(y.ignoreInputTextSelection){var t=ee("clientX",e)||0,n=ee("clientY",e)||0;if(W(R.elementFromPoint(t,n)))return}n=i;a(!0),b(),O(),C(n);n=function(e){e=e.getBoundingClientRect();return{left:e.left+z("scrollLeft","pageXOffset"),top:e.top+z("scrollTop","pageYOffset")}}(s);d=ee("pageX",e)-n.left,m=ee("pageY",e)-n.top,j.add(h||s,"gu-transit"),function(){if(l)return;var e=s.getBoundingClientRect();(l=s.cloneNode(!0)).style.width=G(e)+"px",l.style.height=J(e)+"px",j.rm(l,"gu-transit"),j.add(l,"gu-mirror"),y.mirrorContainer.appendChild(l),U(q,"add","mousemove",P),j.add(y.mirrorContainer,"gu-unselectable"),w.emit("cloned",l,s,"mirror")}(),P(e)}}else N({})}function S(e){if(!(w.dragging&&l||u(e))){for(var t=e;Q(e)&&!1===u(Q(e));){if(y.invalid(e,t))return;if(!(e=Q(e)))return}var n=Q(e);if(n)if(!y.invalid(e,t))if(y.moves(e,n,t,Z(e)))return{item:e,source:n}}}function C(e){var t,n;t=e.item,n=e.source,("boolean"==typeof y.copy?y.copy:y.copy(t,n))&&(h=e.item.cloneNode(!0),w.emit("cloned",h,e.item,"copy")),f=e.source,s=e.item,v=p=Z(e.item),w.dragging=!0,w.emit("drag",s,f)}function O(){var e;w.dragging&&_(e=h||s,Q(e))}function I(){a(!(i=!1)),b(!0)}function N(e){var t,n;I(),w.dragging&&(t=h||s,n=ee("clientX",e)||0,e=ee("clientY",e)||0,(e=B(H(l,n,e),n,e))&&(h&&y.copySortSource||!h||e!==f)?_(t,e):(y.removeOnSpill?X:L)())}function _(e,t){var n=Q(e);h&&y.copySortSource&&t===f&&n.removeChild(s),A(t)?w.emit("cancel",e,f,f):w.emit("drop",e,t,f,p),Y()}function X(){var e,t;w.dragging&&((t=Q(e=h||s))&&t.removeChild(e),w.emit(h?"cancel":"remove",e,t,f),Y())}function L(e){var t,n,o;w.dragging&&(t=0<arguments.length?e:y.revertOnSpill,!1===(e=A(o=Q(n=h||s)))&&t&&(h?o&&o.removeChild(h):f.insertBefore(n,v)),e||t?w.emit("cancel",n,f,f):w.emit("drop",n,o,f,p),Y())}function Y(){var e=h||s;I(),l&&(j.rm(y.mirrorContainer,"gu-unselectable"),U(q,"remove","mousemove",P),Q(l).removeChild(l),l=null),e&&j.rm(e,"gu-transit"),n&&clearTimeout(n),w.dragging=!1,g&&w.emit("out",e,g,f),w.emit("dragend",e),f=s=h=v=p=n=g=null}function A(e,t){t=void 0!==t?t:l?p:Z(h||s);return e===f&&t===v}function B(t,n,o){for(var r=t;r&&!function(){if(!1===u(r))return!1;var e=D(r,t),e=F(r,e,n,o);if(A(r,e))return!0;return y.accepts(s,r,f,e)}();)r=Q(r);return r}function P(e){if(l){e.preventDefault();var t=ee("clientX",e)||0,n=ee("clientY",e)||0,o=t-d,r=n-m;l.style.left=o+"px",l.style.top=r+"px";var i=h||s,e=H(l,t,n),o=B(e,t,n),u=null!==o&&o!==g;!u&&null!==o||(g&&a("out"),g=o,u&&a("over"));r=Q(i);if(o!==f||!h||y.copySortSource){var c,e=D(o,e);if(null!==e)c=F(o,e,t,n);else{if(!0!==y.revertOnSpill||h)return void(h&&r&&r.removeChild(i));c=v,o=f}(null===c&&u||c!==i&&c!==Z(i))&&(p=c,o.insertBefore(i,c),w.emit("shadow",i,o,f))}else r&&r.removeChild(i)}function a(e){w.emit(e,i,g,f)}}function D(e,t){for(var n=t;n!==e&&Q(n)!==e;)n=Q(n);return n===q?null:n}function F(r,t,i,u){var c="horizontal"===y.direction;return(t!==r?function(){var e=t.getBoundingClientRect();if(c)return n(i>e.left+G(e)/2);return n(u>e.top+J(e)/2)}:function(){var e,t,n,o=r.children.length;for(e=0;e<o;e++){if(t=r.children[e],n=t.getBoundingClientRect(),c&&n.left+n.width/2>i)return t;if(!c&&n.top+n.height/2>u)return t}return null})();function n(e){return e?Z(t):t}}}}).call(this,"undefined"!=typeof global?global:"undefined"!=typeof self?self:"undefined"!=typeof window?window:{})},{"./classes":1,"contra/emitter":5,crossvent:6}],3:[function(e,t,n){t.exports=function(e,t){return Array.prototype.slice.call(e,t)}},{}],4:[function(e,t,n){"use strict";var o=e("ticky");t.exports=function(e,t,n){e&&o(function(){e.apply(n||null,t||[])})}},{ticky:10}],5:[function(e,t,n){"use strict";var c=e("atoa"),a=e("./debounce");t.exports=function(r,e){var i=e||{},u={};return void 0===r&&(r={}),r.on=function(e,t){return u[e]?u[e].push(t):u[e]=[t],r},r.once=function(e,t){return t._once=!0,r.on(e,t),r},r.off=function(e,t){var n=arguments.length;if(1===n)delete u[e];else if(0===n)u={};else{e=u[e];if(!e)return r;e.splice(e.indexOf(t),1)}return r},r.emit=function(){var e=c(arguments);return r.emitterSnapshot(e.shift()).apply(this,e)},r.emitterSnapshot=function(o){var e=(u[o]||[]).slice(0);return function(){var t=c(arguments),n=this||r;if("error"===o&&!1!==i.throws&&!e.length)throw 1===t.length?t[0]:t;return e.forEach(function(e){i.async?a(e,t,n):e.apply(n,t),e._once&&r.off(o,e)}),r}},r}},{"./debounce":4,atoa:3}],6:[function(n,o,e){(function(r){"use strict";var i=n("custom-event"),u=n("./eventmap"),c=r.document,e=function(e,t,n,o){return e.addEventListener(t,n,o)},t=function(e,t,n,o){return e.removeEventListener(t,n,o)},a=[];function l(e,t,n){t=function(e,t,n){var o,r;for(o=0;o<a.length;o++)if((r=a[o]).element===e&&r.type===t&&r.fn===n)return o}(e,t,n);if(t){n=a[t].wrapper;return a.splice(t,1),n}}r.addEventListener||(e=function(e,t,n){return e.attachEvent("on"+t,function(e,t,n){var o=l(e,t,n)||function(n,o){return function(e){var t=e||r.event;t.target=t.target||t.srcElement,t.preventDefault=t.preventDefault||function(){t.returnValue=!1},t.stopPropagation=t.stopPropagation||function(){t.cancelBubble=!0},t.which=t.which||t.keyCode,o.call(n,t)}}(e,n);return a.push({wrapper:o,element:e,type:t,fn:n}),o}(e,t,n))},t=function(e,t,n){n=l(e,t,n);if(n)return e.detachEvent("on"+t,n)}),o.exports={add:e,remove:t,fabricate:function(e,t,n){var o=-1===u.indexOf(t)?new i(t,{detail:n}):function(){var e;c.createEvent?(e=c.createEvent("Event")).initEvent(t,!0,!0):c.createEventObject&&(e=c.createEventObject());return e}();e.dispatchEvent?e.dispatchEvent(o):e.fireEvent("on"+t,o)}}}).call(this,"undefined"!=typeof global?global:"undefined"!=typeof self?self:"undefined"!=typeof window?window:{})},{"./eventmap":7,"custom-event":8}],7:[function(e,r,t){(function(e){"use strict";var t=[],n="",o=/^on/;for(n in e)o.test(n)&&t.push(n.slice(2));r.exports=t}).call(this,"undefined"!=typeof global?global:"undefined"!=typeof self?self:"undefined"!=typeof window?window:{})},{}],8:[function(e,n,t){(function(e){var t=e.CustomEvent;n.exports=function(){try{var e=new t("cat",{detail:{foo:"bar"}});return"cat"===e.type&&"bar"===e.detail.foo}catch(e){}}()?t:"undefined"!=typeof document&&"function"==typeof document.createEvent?function(e,t){var n=document.createEvent("CustomEvent");return t?n.initCustomEvent(e,t.bubbles,t.cancelable,t.detail):n.initCustomEvent(e,!1,!1,void 0),n}:function(e,t){var n=document.createEventObject();return n.type=e,t?(n.bubbles=Boolean(t.bubbles),n.cancelable=Boolean(t.cancelable),n.detail=t.detail):(n.bubbles=!1,n.cancelable=!1,n.detail=void 0),n}}).call(this,"undefined"!=typeof global?global:"undefined"!=typeof self?self:"undefined"!=typeof window?window:{})},{}],9:[function(e,t,n){var o,r,t=t.exports={};function i(){throw new Error("setTimeout has not been defined")}function u(){throw new Error("clearTimeout has not been defined")}function c(t){if(o===setTimeout)return setTimeout(t,0);if((o===i||!o)&&setTimeout)return o=setTimeout,setTimeout(t,0);try{return o(t,0)}catch(e){try{return o.call(null,t,0)}catch(e){return o.call(this,t,0)}}}!function(){try{o="function"==typeof setTimeout?setTimeout:i}catch(e){o=i}try{r="function"==typeof clearTimeout?clearTimeout:u}catch(e){r=u}}();var a,l=[],f=!1,s=-1;function d(){f&&a&&(f=!1,a.length?l=a.concat(l):s=-1,l.length&&m())}function m(){if(!f){var e=c(d);f=!0;for(var t=l.length;t;){for(a=l,l=[];++s<t;)a&&a[s].run();s=-1,t=l.length}a=null,f=!1,function(t){if(r===clearTimeout)return clearTimeout(t);if((r===u||!r)&&clearTimeout)return r=clearTimeout,clearTimeout(t);try{r(t)}catch(e){try{return r.call(null,t)}catch(e){return r.call(this,t)}}}(e)}}function v(e,t){this.fun=e,this.array=t}function p(){}t.nextTick=function(e){var t=new Array(arguments.length-1);if(1<arguments.length)for(var n=1;n<arguments.length;n++)t[n-1]=arguments[n];l.push(new v(e,t)),1!==l.length||f||c(m)},v.prototype.run=function(){this.fun.apply(null,this.array)},t.title="browser",t.browser=!0,t.env={},t.argv=[],t.version="",t.versions={},t.on=p,t.addListener=p,t.once=p,t.off=p,t.removeListener=p,t.removeAllListeners=p,t.emit=p,t.prependListener=p,t.prependOnceListener=p,t.listeners=function(e){return[]},t.binding=function(e){throw new Error("process.binding is not supported")},t.cwd=function(){return"/"},t.chdir=function(e){throw new Error("process.chdir is not supported")},t.umask=function(){return 0}},{}],10:[function(e,n,t){(function(t){var e="function"==typeof t?function(e){t(e)}:function(e){setTimeout(e,0)};n.exports=e}).call(this,e("timers").setImmediate)},{timers:11}],11:[function(a,e,l){(function(e,t){var o=a("process/browser.js").nextTick,n=Function.prototype.apply,r=Array.prototype.slice,i={},u=0;function c(e,t){this._id=e,this._clearFn=t}l.setTimeout=function(){return new c(n.call(setTimeout,window,arguments),clearTimeout)},l.setInterval=function(){return new c(n.call(setInterval,window,arguments),clearInterval)},l.clearTimeout=l.clearInterval=function(e){e.close()},c.prototype.unref=c.prototype.ref=function(){},c.prototype.close=function(){this._clearFn.call(window,this._id)},l.enroll=function(e,t){clearTimeout(e._idleTimeoutId),e._idleTimeout=t},l.unenroll=function(e){clearTimeout(e._idleTimeoutId),e._idleTimeout=-1},l._unrefActive=l.active=function(e){clearTimeout(e._idleTimeoutId);var t=e._idleTimeout;0<=t&&(e._idleTimeoutId=setTimeout(function(){e._onTimeout&&e._onTimeout()},t))},l.setImmediate="function"==typeof e?e:function(e){var t=u++,n=!(arguments.length<2)&&r.call(arguments,1);return i[t]=!0,o(function(){i[t]&&(n?e.apply(null,n):e.call(null),l.clearImmediate(t))}),t},l.clearImmediate="function"==typeof t?t:function(e){delete i[e]}}).call(this,a("timers").setImmediate,a("timers").clearImmediate)},{"process/browser.js":9,timers:11}]},{},[2])(2)});
 */
