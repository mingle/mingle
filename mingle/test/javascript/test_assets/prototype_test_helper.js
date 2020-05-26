Event.trigger = function(element, name, event, bubble) {
  element = $(element);

	if(!element) throw 'element not exist: ' + element;

  var eventObj = event || {};
	eventObj.type = name;

  return Event.triggerEvent(element, eventObj, !!bubble);
};

Event.triggerReturnKeypressEvent = function(element) {
 return Event.triggerKeypressEvent(element, Event.KEY_RETURN);
};

Event.triggerKeypressEvent = function(element, keyCode) {
  element = $(element);
	if(!element) return;

	var eventObj = new Object;
  eventObj.type = 'keypress';

	eventObj.charCode = keyCode;
	eventObj.keyCode = keyCode;
  Event.triggerEvent(element, eventObj);
	return eventObj;
};

Event.triggerKeydownEvent = function(element, keyCode) {
  element = $(element);
	if(!element) return;

  var eventObj = new Object;
  eventObj.type = 'keydown';

  eventObj.charCode = keyCode;
	eventObj.keyCode = keyCode;
  Event.triggerEvent(element, eventObj);
	return eventObj;
};

Event.triggerEvent = function(element, eventObj, bubble) {
  eventObj.target = element;
  eventObj.element = function(){ return element; };

  var elems = [element];
  if (bubble) {
    elems = elems.concat(element.ancestors().toArray());
  }

  var relatedObservers = []
  elems.each(function(el) {
    relatedObservers = relatedObservers.concat(Element.getStorage(el).get(eventObj.type.toLowerCase()) || []);
  });

  relatedObservers.map(function(observer) {
    if (Event.isStopped(eventObj)) {
      throw $break;
    }
    observer(eventObj);
  });

  return eventObj;
};

function registerHandler(element, eventName, fn) {
  if (!element || !eventName || !fn) return;

  var key = eventName.toLowerCase();
  var result = Element.getStorage(element).get(key) || [];
  result.push(fn);
  Element.getStorage(element).set(key, result.uniq());
};

function unregisterHandler(element, eventName, fn) {
  if (!element || !eventName) return;

  var key = eventName.toLowerCase();
  var result = Element.getStorage(element).get(key) || [];
  if (!fn) {
    result = [];
  } else {
    result = result.reject(function(obj) {
      return fn === obj;
    });
  }
  Element.getStorage(element).set(key, result.uniq());
};

var oldObserve = Event.observe;
Event.observe = function(element, eventName, handler) {
  var fn = !!handler ? handler : Prototype.emptyFunction;
  registerHandler(element, eventName, fn);
  return oldObserve(element, eventName, fn);
};


var oldStopObserving = Event.stopObserving;
Event.stopObserving = function(element, eventName, observer) {
  unregisterHandler(element, eventName, observer);
  return oldStopObserving(element, eventName, observer);
};

Event.stop = function(event) {
  event._is_stopped = true;
};

Event.isStopped = function(event) {
  return event._is_stopped;
};

Element.addMethods({
  observe:       Event.observe,
  stopObserving: Event.stopObserving
});
