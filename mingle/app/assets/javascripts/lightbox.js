/*
*  Copyright 2020 ThoughtWorks, Inc.
*  
*  This program is free software: you can redistribute it and/or modify
*  it under the terms of the GNU Affero General Public License as
*  published by the Free Software Foundation, either version 3 of the
*  License, or (at your option) any later version.
*  
*  This program is distributed in the hope that it will be useful,
*  but WITHOUT ANY WARRANTY; without even the implied warranty of
*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*  GNU Affero General Public License for more details.
*  
*  You should have received a copy of the GNU Affero General Public License
*  along with this program.  If not, see <https://www.gnu.org/licenses/agpl-3.0.txt>.
*/
var Nolightbox = Class.create({
  createOnTop: function(options) {
    return new NewLightbox(options.contentStyles || {}, this, options);
  },
  shift: function() {
    $(document.body).setStyle({overflow: 'hidden'});
  },
  unshift: function() {
    $(document.body).setStyle({overflow: ''});
  },
  clearAllUnder: function() {},
  findElement: function(selector) { return document.select(selector).first(); },
  destroy: function(){}
});

var NewLightbox = Class.create();
NewLightbox.last = new Nolightbox();

NewLightbox.Dimension = function() {
  var lastPreferedDimensions = null;
  var changeThreshold = 10;

  var viewportDimensions = function() {
    return document.viewport.getDimensions();
  };

  var maxWidth = function() {
    return viewportDimensions().width * 0.8;
  };

  var maxHeight = function() {
    return viewportDimensions().height * 0.8;
  };

  var withStretchedClone = function(sourceElement, block) {
    var stretchedClone = sourceElement.cloneNode(true);
    stretchedClone.setStyle({visibility: 'hidden'});
    document.body.appendChild(stretchedClone);
    stretchedClone.setStyle({
      width: 'auto',
      height: 'auto',
      overflow: 'hidden'
    });
    block(stretchedClone);
    stretchedClone.remove();
  };

  return {
    getPrefered: function(lightbox) {
      var stretchedHeight, stretchedWidth;
      withStretchedClone(lightbox, function(stretchedClone) {
        stretchedHeight = stretchedClone.getHeight();
        stretchedClone.select(".lightbox-width-calc-exempted").invoke("hide");
        stretchedWidth = stretchedClone.getWidth();
      });

      var preferedWidth = stretchedWidth > maxWidth() ? maxWidth() : stretchedWidth + 30;
      var preferedHeight = stretchedHeight > maxHeight() ? maxHeight() : stretchedHeight + 30;

      var widthChanged = true, heightChanged = true;
      if(lastPreferedDimensions){
        widthChanged = Math.abs(lastPreferedDimensions.width - preferedWidth) > changeThreshold;
        heightChanged = Math.abs(lastPreferedDimensions.height - preferedHeight) > changeThreshold;
      }

      return (lastPreferedDimensions = {width: preferedWidth, height: preferedHeight, 'widthChanged': widthChanged, 'heightChanged': heightChanged });
    }
  };
};

NewLightbox.create = function(options) {
  var lightBox = NewLightbox.last.createOnTop(options || {});
  lightBox.show();
  return lightBox;
};

NewLightbox.prototype = {
  initialize: function(contentStyles, lightboxUnder, options) {
    this.options = options || {};
    this.contentStyles = Object.extend({zIndex: 10001}, contentStyles || {});
    this.lightboxUnder = lightboxUnder;
    var overlayOptions = {id: new Date().toString()};

    this.overlay =  new Element('div', overlayOptions);

    this.blurHandler = this._onOverlayClick.bind(this);
    this.overlay.observe('click', this.blurHandler);

    this._closeOnBlur = this.options.closeOnBlur;

    this.overlay.addClassName('overlay');
    this.content = new Element('div', {id: 'lightbox'});
    this.content.addClassName('animated fadeInUp lightbox');

    if(this.options.lightboxCssClass !== undefined) {
        this.content.addClassName(this.options.lightboxCssClass);
    }
    this.lightBoxContent = new Element('div', {id: 'lightbox_inner'});
    document.body.appendChild(this.overlay);

    if(this.options.headerText) {
        var header = new Element('div');
        header.addClassName('lightbox_header');
        var heading = new Element('h2');
        heading.innerHTML = this.options.headerText;

        header.insert(heading);
        var close_link = new Element('a', {'href': 'javascript:void(0)'});
        close_link.observe('click', function(e) {
          InputingContexts.pop();
          return false;
        });
        close_link.addClassName('popup-close remove-button');
        header.insert(close_link);
        this.content.appendChild(header);
    }

    this.content.appendChild(this.lightBoxContent);
    this.overlay.appendChild(this.content);
    this.lightBoxContent.innerHTML = $('lightbox_loading_message_div') ? $('lightbox_loading_message_div').innerHTML : 'loading...';
    this._initOnScrollListener();

    NewLightbox.last = this;
    this.shifted = false;
    this.dimensions = new NewLightbox.Dimension();
  },

  destroy: function() {
    if (this.blurHandler) {
      this.overlay.stopObserving('click', this.blurHandler);
    }
    this.overlay.remove();
    this.content.remove();
    this.overlay = null;
    this.content = null;

    if (this.lightboxUnder) {
      this.lightboxUnder.unshift();
      NewLightbox.last = this.lightboxUnder;
    }

    if ("function" === typeof this.options.afterDestroy) {
      this.options.afterDestroy(this);
    }
  },

  show: function() {
    this.lightboxUnder.shift();

    this.overlay.setStyle({zIndex: (this.contentStyles.zIndex - 1)});
    this.content.setStyle(this.contentStyles);
    this.overlay.style.display = 'block';
    this.content.style.display = 'block';
  },

  update: function(args) {
    var contentHtml;
    if(args.length == 1) {
      contentHtml = args[0];
      this.content.update(contentHtml);
    }else {
      var id = args[0];
      contentHtml = args[1];
      this.$(id).update(contentHtml);
    }
    this.notifyContentChange();

    if ("function" === typeof this.options.afterUpdate) {
      this.options.afterUpdate(this);
    }
  },

  notifyContentChange: function(){
    if(!this.currentVersion){
      this.currentVersion = 0;
    }
    this.currentVersion += 1;
  },

  isContentChanged: function(){
    if(this._previousCheckedVersion != this.currentVersion){
      this._previousCheckedVersion = this.currentVersion;
      return true;
    }
    return false;
  },

  createOnTop: function(options) {
    var topContentStyles = Object.clone(this.contentStyles);
    topContentStyles.zIndex = ((options && Object(options.contentStyles).zIndex ) || this.contentStyles.zIndex) + 1;
    return new NewLightbox(topContentStyles, this, options);
  },

  isAbove: function(anotherLightbox) {
    return this.contentStyles.zIndex > anotherLightbox.contentStyles.zIndex;
  },

  shift: function() {
    this.shifted = true;

    this.topBeforeShift = this.content.style.top;
    this.content.setStyle({
      top: "80%"
    });

    this.overlay.setStyle({
        'overflow-y': 'hidden'
    });
  },

  unshift: function() {
    this.shifted = false;
    this.content.setStyle({
      top: this.topBeforeShift
    });

    (function() {
      if(this.overlay) {
        this.overlay.setStyle({
          'overflow-y': 'auto'
        });
      }
    }).bind(this).delay(0.6);
  },

  clearAllUnder: function() {
    this.destroy();
    this.lightboxUnder.destroy();
  },

  $: function(id) {
    var candidates = this.content.descendants();
    return candidates.detect(function(e) { return e.id == id;});
  },

  findElement: function(selector) {
    return this.content.select(selector).first();
  },

  setScrollTop: function(value) {
    this.content.scrollTop = value;
  },

  setStyle: function(style) {
    this.content.setStyle(style);
  },

  disableBlurClick: function() {
    this._closeOnBlur = false;
  },

  enableBlurClick: function() {
    this._closeOnBlur = true;
  },

  _onOverlayClick: function(event) {
    var element = Event.element(event);

    if(element === this.overlay && this._closeOnBlur) {
      InputingContexts.pop();
    }

    return false;
  },

  _initOnScrollListener: function() {
    this.lastScrollTop = this.content.scrollTop;
    this.content.onscroll = function() {
      var delta = this.content.scrollTop - this.lastScrollTop;
      this.lastScrollTop = this.content.scrollTop;
      document.fire("lightbox:scroll", {'delta': delta, element: this.content});
    }.bind(this);
  }
};


var InputingContextsClass = Class.create({
  initialize: function() {
    this.contexts = [];
  },

  push: function(context) {
    context.start();
    this.pruneDuplicatesAndRelink(context);
    this.contexts.push(context);
  },

  pruneDuplicatesAndRelink: function(currentContext) {
    if ("string" === typeof currentContext.options.ensureSingletonWithId && jQuery.trim(currentContext.options.ensureSingletonWithId).length > 0) {
      var contexts = [], key = jQuery.trim(currentContext.options.ensureSingletonWithId), len = this.contexts.length, previousLightbox, terminal;

      if (len) {
        terminal = this.contexts[0].lightbox.lightboxUnder;
      }

      for (var i = len - 1; i >= 0; i--) {
        var ctx = this.contexts[i];

        if ("string" === typeof ctx.options.ensureSingletonWithId && key === jQuery.trim(ctx.options.ensureSingletonWithId)) {
          ctx.lightbox.lightboxUnder = null;
          ctx.end();
        } else {
          if (previousLightbox) {
            previousLightbox.lightboxUnder = ctx.lightbox; // relink the list in case we pruned a lightbox
          }
          previousLightbox = ctx.lightbox;
          contexts.unshift(ctx);
        }
      }

      if (contexts.length) { // ensure our new context list has the proper termination on both ends
        if (terminal) {
          contexts[0].lightbox.lightboxUnder = terminal; // a Nolightbox instance
        }

        currentContext.lightbox.lightboxUnder = contexts[contexts.length - 1].lightbox;
      }

      this.contexts = contexts;
    }
  },

  feed: function(value) {
    this.pop().feed(value);
  },

  update: function() {
    this.top().update.apply(this.top(), arguments);
  },

  pop: function() {
    var popped = this.contexts.pop();
    if (popped) {
        popped.end();
    }
    return popped;
  },

  top: function() {
    return this.contexts[this.contexts.length - 1];
  },

  clear: function() {
    $j(".tipsy").hide();
    while (this.contexts.length > 0) {
      this.pop();
    }
  },

  escapeKeyHandler: function escapeKeyHandler(e) {
    if (!InputingContexts.top()) {
      return;
    }

    var c = $j(InputingContexts.top().findElement('.close-popup'));
    if (c.length > 0) {
      c.click();
    } else {
      InputingContexts.pop();
    }

    return false;
  }
});

var InputingContexts = new InputingContextsClass();

var LightboxInputingContext = Class.create({
  initialize: function(waiter, options) {
    this.waiter = waiter;
    this.options = options || {};
  },

  start: function() {
    this.lightbox = NewLightbox.create(this.options);
  },

  feed: function(value) {
    this.waiter(value);
  },

  update: function() {
    this.lightbox.update(arguments);
  },

  end: function() {
    this.lightbox.destroy();
  },

  $: function(id) {
    return this.lightbox.$(id);
  },

  findElement: function(selector) {
    return this.lightbox.findElement(selector);
  }
});

document.getElementByIdWithoutLightboxContext = document.getElementById;

document.getElementById = function(elementId) {
  if(Object.isUndefined(window.InputingContexts) || !InputingContexts.top()) {
    // on IE '$' method may be called before InputingContexts defined :(
    return document.getElementByIdWithoutLightboxContext(elementId);
  }

  var inContextElement = InputingContexts.top().$(elementId);
  return inContextElement || document.getElementByIdWithoutLightboxContext(elementId);
};
