if (Prototype.Browser.Chrome) {
  throw "Do not run our test in Chrome, run in Fireforx/Safari";
}

Element.TestExtendMethods = {
  // elements position related to body left border
  // please cache the result for execution is quite expensive
  getScreenPosition: function(element) {
    var indicator = new Element('div', {style: 'width:1px; height:1px; position:absolute'});
    element.ownerDocument.body.appendChild(indicator);
    Position.clone(element, indicator);
    var position = {left: indicator.offsetLeft, top: indicator.offsetTop};
    indicator.remove();
    return position;
  },
  
  rawHTML: function(element) {
    if (Prototype.Browser.WebKit && navigator.userAgent.indexOf('Version/3') != -1) {
      return element.innerHTML.escapeHTML();
    }
    return element.innerHTML;
  }
};
Element.addMethods(Element.TestExtendMethods);


Object.extend(Test.Unit.Testcase.prototype, {
  dragAndDrop: function(element, toPosition, nextPartAssertions) {
    this.dragTo(element, toPosition);
    Event.trigger(document, 'mouseup', {
      which: 1, 
      button: 0,
      pointerX: function() { return toPosition[0]; }, 
      pointerY: function() { return toPosition[1]; },
      pageX: toPosition[0],
      pageY: toPosition[1]
    });
    this.wait(500, nextPartAssertions);
  },
  
  dragTo: function(element, toPosition) {
    element = $(element);
    Event.trigger(element, 'mousedown', {which: 1, button: 0});
    Event.trigger(document, 'mousedown', {which: 1, button: 0});

    var fromX = element.cumulativeOffset()[0];
    var fromY = element.cumulativeOffset()[1];
    var moveToX;
    var moveToY;
    var moveStep = 10;
    
    for(var i=0; i < moveStep; i++){
      moveToX = fromX + (toPosition[0] - fromX) / moveStep * i;
      moveToY = fromY + (toPosition[1] - fromY) / moveStep * i;
       
      element.style.left = moveToX + "px";
      element.style.top = moveToY + "px";
      
      Event.trigger(document, 'mousemove', {
        pointerX: function() { return moveToX; }, 
        pointerY: function() { return moveToY; },
        pageX: moveToX,
        pageY: moveToY
      });
    }
    
    if(moveToX != toPosition[0] || moveToY != toPosition[1]){
      element.style.left = toPosition[0] + "px";
      element.style.top = toPosition[1] + "px";
      
      Event.trigger(document, 'mousemove', {
        pointerX: function() { return toPosition[0]; }, 
        pointerY: function() { return toPosition[1]; },
        pageX: toPosition[0],
        pageY: toPosition[1]
      });  
    }    
  },
  
  clickCheckbox: function(element) {
    var element = $(element);
    element.checked = !element.checked;
    Event.trigger(element, 'click');
  },
  
  assertBlank: function(target) {
    if(target==null) {
      return;
    }
    this.assertEqual("", target);
  },
  
  assertFloatEqual: function(expected, actual, tolerance) {
    if (tolerance == null || tolerance < 0) tolerance = 0.01;
    this.assert(Math.abs(expected - actual) < tolerance);
  },
  
  assertBlank: function(target) {
    if(target==null) {
      return;
    }
    this.assertEqual("", target);
  },

  assertInclude: function(expected, actual) {
    var equal = actual.any(function(element) { return element == expected; });
    this.assert(equal, "The array '" + actual.inspect() + "' does not include the element '" + expected.inspect() + "'");
  },

  assertNotInclude: function(expected, actual) {
    var equal = actual.any(function(element) { return element == expected; });
    this.assert(!equal, "The array '" + actual.inspect() + "' is not expected to include the element '" + expected.inspect() + "'");
  },

  assertArrayEqual: function(expected, actual, message) {
    message = message || "Two array are not exactly same";
    expected = expected.toArray();
    actual = actual.toArray();
    this.assertEqual(expected.size(), actual.size(), message + ". You should at least give me arrays with same length, its " + expected.size() + ":" + actual.size() + ".");
    var equal = expected.all(function(element, index){ 
      return element == actual[index]; }
    );
    this.assert(equal, message + ", \n" + expected.inspect() + " : \n" + actual.inspect() + ".");
  },
  
  assertArrayNotEqual: function(expected, actual, message) {
    message = message || "Two array are exactly same";
    expected = expected.toArray();
    actual = actual.toArray();
    if (expected.size() != actual.size())
      return;
    var equal = expected.all(function(element, index){ return element == actual[index]; });
    this.assert(!equal, message + ", " + expected + " : " + actual + ".");
  },
  
  assertAboutEqual: function(expected, actual, durable) {
    this.assert(Math.abs(expected - actual) < durable);
  },
    
  assertOnCenter: function(element, container) {
    var elementPosition = element.getScreenPosition();
    var containerPosition = container.getScreenPosition();
    this.assertAboutEqual(container.offsetWidth, 2*(elementPosition.left - containerPosition.left) + element.offsetWidth, 1);
    this.assertAboutEqual(container.offsetHeight, 2*(elementPosition.top - containerPosition.top) + element.offsetHeight, 1);
  },
  
  assertDisabled: function(element) {
    this.assert($(element).disabled == true, 'Element "' + $(element).id + '" is not disabled.');
  },
  
  assertEnabled: function(element) {
    this.assert($(element).disabled == false, 'Element "' + $(element).id + '" is not enabled.');
  },
  
  assertHyperlinkDisabled: function(element) {
    this.assertNull($(element).readAttribute('href'),          "A disabled hyperlink should have its href set to null but it isn't.");
    this.assert($(element).hasClassName('disabled'), "A disabled hyperlink should be styled to 'disabled' but it isn't.");
  },
  
  assertHyperlinkEnabled: function(element, options) {
    var actualHref = $(element).readAttribute('href');
    this.assertNotNull(actualHref, "An enabled hyperlink should have its href set but it is still null.");
    if (options && options.href) {
      this.assertEqual(options.href, actualHref, "Expected redirect href to be '" + options.href + "' but was '" + actualHref + "'.");
    }
    this.assert(!$(element).hasClassName('disabled'), "An enabled hyperlink should not be styled to 'disabled' but it is.");
  },
  
  assertObserverExists: function(element, eventName) {
    var observers = Element.getStorage(element).get(eventName.toLowerCase()) || [];
    this.assert(observers.length !== 0,
      "Expected an observer is observing event '" + eventName + "' on element '" + element.inspect() + "' but such observer is not found.");
  },
  
  assertObserverNotExist: function(element, eventName) {
    var observers = Element.getStorage(element).get(eventName.toLowerCase()) || [];
    this.assert(observers.length === 0,
      "Expected no observers for event '" + eventName + "' on element '" + element.inspect() + "' but such observer is found.");
  },
  
  assertURLEqual: function(left, right) {
    this.assertEqual(decodeURIComponent(left), decodeURIComponent(right));
  },
  
  assertColorEqual: function(expectedColor, actualColor) {
    this.assertArrayEqual(this.normalizeColor(expectedColor), this.normalizeColor(actualColor));
  },

  assertColorNotEqual: function(expectedColor, actualColor) {
    this.assertArrayNotEqual(this.normalizeColor(expectedColor), this.normalizeColor(actualColor));
  },
  
  assertTooltip: function (element, message) {
    try {
      $j(element).trigger('mouseenter');
      this.assertEqual(message, $j('.tipsy').text());
    } finally {
      $j(element).trigger('mouseout');
	  this.assertArrayEqual([], $$('.tipsy'))
    }
  },

  normalizeColor: function(colorStr) {
    var matches = new RegExp('^#(.{2})(.{2})(.{2})$').exec(colorStr);
    
    if (matches)
      return [parseInt(matches[1], 16), parseInt(matches[2], 16), parseInt(matches[3], 16)];
    
    matches = new RegExp('^rgb\\((\\d+)\,\\s*(\\d+)\,\\s*(\\d+)\\)$').exec(colorStr);
    
    if (matches)
      return [ parseInt(matches[1], 10), parseInt(matches[2], 10), parseInt(matches[3], 10) ];
  }
});


 // https://github.com/kangax/protolicious/blob/master/event.simulate.js
 /**
  * Event.simulate(@element, eventName[, options]) -> Element
  *
  * - @element: element to fire event on
  * - eventName: name of event to fire (only MouseEvents and HTMLEvents interfaces are supported)
  * - options: optional object to fine-tune event properties - pointerX, pointerY, ctrlKey, etc.
  *
  *    $('foo').simulate('click'); // => fires "click" event on an element with id=foo
  *
  **/
 (function(){

   var eventMatchers = {
     'HTMLEvents': /^(?:load|unload|abort|error|select|change|submit|reset|focus|blur|resize|scroll)$/,
     'MouseEvents': /^(?:click|mouse(?:down|up|over|move|out))$/
   };
   var defaultOptions = {
     pointerX: 0,
     pointerY: 0,
     button: 0,
     ctrlKey: false,
     altKey: false,
     shiftKey: false,
     metaKey: false,
     bubbles: true,
     cancelable: true
   };

   Event.simulate = function(element, eventName) {
     var options = Object.extend(Object.clone(defaultOptions), arguments[2] || { });
     var oEvent, eventType = null;

     element = $(element);

     for (var name in eventMatchers) {
       if (eventMatchers[name].test(eventName)) { eventType = name; break; }
     }
     if (!eventType)
       throw new SyntaxError('Only HTMLEvents and MouseEvents interfaces are supported');

     if (document.createEvent) {
       oEvent = document.createEvent(eventType);
       if (eventType == 'HTMLEvents') {
         oEvent.initEvent(eventName, options.bubbles, options.cancelable);
       }
       else {
         oEvent.initMouseEvent(eventName, options.bubbles, options.cancelable, document.defaultView, 
           options.button, options.pointerX, options.pointerY, options.pointerX, options.pointerY,
           options.ctrlKey, options.altKey, options.shiftKey, options.metaKey, options.button, element);
       }
       element.dispatchEvent(oEvent);
     }
     else {
       options.clientX = options.pointerX;
       options.clientY = options.pointerY;
       oEvent = Object.extend(document.createEventObject(), options);
       element.fireEvent('on' + eventName, oEvent);
     }
     return element;
   };

   Element.addMethods({ simulate: Event.simulate });
 })();
