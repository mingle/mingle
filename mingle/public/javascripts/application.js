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
// Place your application-specific JavaScript functions and classes here
// This file is automatically included by javascript_include_tag :defaults

MingleConfiguration = {};

// monkey patch builder to make node generated prototype-aware on IE
if (Prototype.Browser.IE) {
  if(typeof(Builder) != 'undefined' && typeof(Builder.__node) == 'undefined') {
    Builder.__node = Builder.node;
    Builder.node = function() {
      return $(Builder.__node(arguments[0], arguments[1], arguments[2], arguments[3], arguments[4], arguments[5]));
    };
  }
}

function addLoadEvent(func) {
  var oldonload = window.onload;
  if (typeof window.onload != 'function') {
    window.onload = func;
  } else {
    window.onload = function() {
      if (oldonload) {
        oldonload();
      }
      func();
    };
  }
}

Prototype.Browser.Chrome = navigator.userAgent.indexOf('Chrome') > -1;

// monkey patch ajax GETs: append current time so that IE does not use cached result
Ajax.Request.prototype.__request = Ajax.Request.prototype.request;
Ajax.Updater.prototype.__request = Ajax.Updater.prototype.request;
Ajax.Request.prototype.__respondToReadyState = Ajax.Request.prototype.respondToReadyState;
Ajax.Updater.prototype.__respondToReadyState = Ajax.Updater.prototype.respondToReadyState;

Ajax.RequestOverriden = {
  requestIndex: 1,
  request: function(url) {
    var now = new Date();
    this.requestIndex += 1;
    if (this.options.method == 'get') {
      url += (url.include('?') ? '&' : '?') + "ms=" + now.getTime() + "_" + this.requestIndex;
    }
    this.__request(url);
  },

  //disable event dispatching for interactive stage, which cause a hug memory spike on more than 2m data transfered
  respondToReadyState: function(readyState) {
    if(readyState == 3) { return; }
    this.__respondToReadyState(readyState);
  }
};
Object.extend(Ajax.Request.prototype, Ajax.RequestOverriden);
Object.extend(Ajax.Updater.prototype, Ajax.RequestOverriden);


// monkey patch that fixes Draggable ghosting issue
// http://dev.rubyonrails.org/changeset/8680
Draggable.GhostingFix = {
  startDrag : function(event) {
    // CHANGE #1 -- begin
    document.observe('selectstart', function(event){Event.stop(event); return false;});
    // CHANGE #1 -- end
    this.dragging = true;
    if(!this.delta){
      this.delta = this.currentDelta();
    }

    if(this.options.zindex) {
      this.originalZ = parseInt(Element.getStyle(this.element,'z-index') || 0, 10);
      this.element.style.zIndex = this.options.zindex;
    }

    if(this.options.ghosting) {
      this._clone = this.element.cloneNode(true);
      // CHANGE #2 -- begin
      this._originallyAbsolute = (this.element.getStyle('position') == 'absolute');
      if (!this._originallyAbsolute){
      // CHANGE #2 -- end
        Position.absolutize(this.element);
      }
      this.element.parentNode.insertBefore(this._clone, this.element);
    }

    if(this.options.scroll) {
      if (this.options.scroll == window) {
        var where = this._getWindowScroll(this.options.scroll);
        this.originalScrollLeft = where.left;
        this.originalScrollTop = where.top;
      } else {
        this.originalScrollLeft = this.options.scroll.scrollLeft;
        this.originalScrollTop = this.options.scroll.scrollTop;
      }
    }

    Draggables.notify('onStart', this, event);

    if(this.options.starteffect) {
      this.options.starteffect(this.element);
    }
  },

  finishDrag: function(event, success) {
    // CHANGE #3 -- begin
    document.stopObserving('selectstart');
    // CHANGE #3 -- end
    this.dragging = false;

    if(this.options.quiet){
      Position.prepare();
      var pointer = [Event.pointerX(event), Event.pointerY(event)];
      Droppables.show(pointer, this.element);
    }

    if(this.options.ghosting) {
      // CHANGE #4-- begin
      if (!this._originallyAbsolute){
        Position.relativize(this.element);
      }
      delete this._originallyAbsolute;
      // CHANGE #4-- end
      Element.remove(this._clone);
      this._clone = null;
    }

    var dropped = false;
    if(success) {
      dropped = Droppables.fire(event, this.element);
      if (!dropped) {dropped = false;}
    }
    if(dropped && this.options.onDropped) {
      this.options.onDropped(this.element);
    }
    Draggables.notify('onEnd', this, event);

    var revert = this.options.revert;
    if(revert && Object.isFunction(revert)) {
      revert = revert(this.element);
    }

    var d = this.currentDelta();
    if(revert && this.options.reverteffect) {
      if (dropped == 0 || revert != 'failure'){
        this.options.reverteffect(this.element,
          d[1]-this.delta[1], d[0]-this.delta[0]);
      }
    } else {
      this.delta = d;
    }

    if(this.options.zindex){
      this.element.style.zIndex = this.originalZ || 0;
    }

    if(this.options.endeffect) {
      this.options.endeffect(this.element);
    }

    Draggables.deactivate(this);
    Droppables.reset();
  }

};

Object.extend(Draggable.prototype, Draggable.GhostingFix);

if (("console" in window) && ("firebug" in console)) {
  Prototype.isFireBugsEnabled = true;
}

var FirebugWarning = {
  show: function(warningElement) {
    if(Prototype.isFireBugsEnabled) {
      $(warningElement).show();
    }
  }
};

// for increasing testing ability, please don't direct depending on Ajax.Request
var AjaxServer = Class.create({
  request: function(url, options) {
    return new Ajax.Request(url, options);
  }
});

var EventHandlerStore = Class.create({
  initialize: function() {
    this.eventHandlers = $A();
  },

  observe: function(element, eventName, handler) {
    this.eventHandlers.push([element, eventName, handler]);
    return Event.observe(element, eventName, handler);
  },

  stopObserving: function() {
    this.eventHandlers.each(function(item){
      Event.stopObserving(item[0], item[1], item[2]);
    });
  }
});

var RoundtripJoinableArray = {
  joinFromArray: function(array) {
    return array.compact().uniq().collect(function(element) {
      return element.gsub(/\\/, '\\\\').gsub(/,/, '\\,');
    }).join(',');
  },

  fromStr: function(str) {
    if(!str) {return [];}
    var result = [];
    var one = [];
    var escape = false;

    str.toArray().each(function(ch) {
      if(escape) {
        escape = false;
        one.push(ch);
      } else if( ch == ',') {
        result.push(one.join(''));
        one = [];
      } else if( ch == '\\') {
        escape = true;
      } else {
        one.push(ch);
      }
    });

    if(one.length != 0) {
      result.push(one.join(''));
    }
    return result;
  }
};

var CheckBoxes = Class.create({
  initialize: function(form, nameRegExp, options) {
    this.form = form;
    this.nameRegExp = nameRegExp;
    this.observers = [];
    this.options = options;
    if (!this.options) {this.options = {};}
    Object.extend(this.options, {selectedRowClass: "selected"});
    if (this.options.selectedRowClass) {
      this.registerObserver(this._updateSelectedRowClass.bind(this));
      // update once, there may be boxes that have already been checked when the page loaded
      this._updateSelectedRowClass();
    }
    this._checkBoxesForForm().each(function(checkbox) {
      Event.observe(checkbox, 'click', this._notifyObservers.bindAsEventListener(this));
    }.bind(this));
    document.observe("listview:uncheckAllCards", this.uncheckAll.bindAsEventListener(this));
  },

  checkAll: function() {
    this._checkBoxesForForm().each(function(checkbox) {
      if(!(this.options['ignoreDisabledCheckbox'] && checkbox.disabled)){
        checkbox.checked =  true;
      }
    }.bind(this));
    this._notifyObservers();
  },

  uncheckAll: function() {
    this._checkBoxesForForm().each(function(checkbox) {
      checkbox.checked =  false;
    });
    this._notifyObservers();
  },

  disableAll: function(){
    this._checkBoxesForForm().each(function(checkbox) {
      checkbox.disabled =  true;
    });
  },

  enableAll: function(){
    this._checkBoxesForForm().each(function(checkbox) {
      checkbox.disabled =  false;
    });
  },

  getCheckedBoxes: function() {
    return this._checkBoxesForForm().select(function(checkbox) {
      return checkbox.checked;
    });
  },

  getSelectedValues: function() {
    return this.getCheckedBoxes().map(function(checkbox) {
      return checkbox.value;
    }.bind(this));
  },

  noSelection: function() {
    return this.getSelectedValues().length < 1;
  },

  registerObserver: function(observer) {
    this.observers.push(observer);
  },

  registerObserverAsFirst: function(observer) {
    this.observers.unshift(observer);
  },

  removeObserver: function(oldObserver) {
    this.observers = this.observers.reject(function(observer) {
      return observer == oldObserver;
    });
  },

  _notifyObservers: function() {
    this.observers.each(function(observer) {
      observer();
    });
  },

  _checkBoxesForForm: function() {
    var regexp = new RegExp(this.nameRegExp);
    return Form.getInputs(this.form, 'checkbox').select(function(checkbox) {
      return regexp.test(checkbox.name);
    }.bind(this));
  },

  _updateSelectedRowClass: function() {
    this._checkBoxesForForm().each(function(checkbox) {
      var tr = checkbox.up('tr');
      if (tr) {
        if (checkbox.checked) {
          tr.addClassName(this.options.selectedRowClass);
        } else {
          tr.removeClassName(this.options.selectedRowClass);
        }
      }
    }.bind(this));
  }
});

var AllCardsSelector = Class.create();
AllCardsSelector = {

  attach: function(checkBoxes, reallySelectAllInputName, selectedMessagePrefix, bulkOperationPanels, bulkTransitions, totalNumberOfCards) {
    this.attached = true;
    this.totalNumberOfCards = totalNumberOfCards;
    this.checkBoxes = checkBoxes;
    this.bulkOperationPanels = bulkOperationPanels;
    this.bulkTransitions = bulkTransitions;
    this.selectedAllMessageId = selectedMessagePrefix + "_message_box";
    this.numberOfCardsId = selectedMessagePrefix + "_number_of_cards";
    this.reallySelectAllInputs = $A(document.getElementsByName(reallySelectAllInputName));
    this.alreadySelectedAllMessageId = selectedMessagePrefix + "_selected_all_message";

    this.onCheckAllObserver = this.onCheckAll.bindAsEventListener(this);
    this.onUncheckAllObserver = this.onUncheckAll.bindAsEventListener(this);
    this.updateSelectedNumberObserver = this.updateSelectedNumber.bindAsEventListener(this);

    this.checkBoxes.registerObserver(this.onUncheckAllObserver);
    this.checkBoxes.registerObserverAsFirst(this.onCheckAllObserver);
    this.checkBoxes.registerObserver(this.updateSelectedNumberObserver);
  },

  selectAllCards: function(numberOfCards, wantPanelUpdate) {
    if (this.attached) {
      if (wantPanelUpdate == null) { wantPanelUpdate = true; }
      $(this.alreadySelectedAllMessageId).show();
      $(this.selectedAllMessageId).hide();
      this.reallySelectAllInputs.each(function(input) { input.value = true; });
      if (wantPanelUpdate) {
        $A(this.bulkOperationPanels).each(function(panel) { panel._update(); });
      }

      this.checkAllBoxesWithoutFiringEvents();
      this.checkBoxes.disableAll();
      this.bulkTransitions.disableTransitionButton();
    }
  },

  selectAllCardsWithNoPanelUpdate: function(numberOfCards) {
    if (this.attached) {
      this.selectAllCards(numberOfCards, false);
    }
  },


  onUncheckAll: function() {
    if (this.attached) {
      var numberOfSelectedValues = this.checkBoxes.getSelectedValues().size();
      if (numberOfSelectedValues == 0) {
        if ($(this.selectedAllMessageId)) {
          $(this.selectedAllMessageId).hide();
        }
        if ($(this.alreadySelectedAllMessageId)) {
          $(this.alreadySelectedAllMessageId).hide();
        }
        this.clearReallySelectAll();
        this.checkBoxes.enableAll();
        if (this.bulkTransitionPanel){
          this.bulkTransitionPanel.disable();
        }
      } else if (!this._allCheckBoxesOnPageSelected()) {
        if ($(this.selectedAllMessageId)) {
          $(this.selectedAllMessageId).hide();
        }
      }
    }
  },

  onCheckAll: function() {
    if (this.attached) {
      if (this._allCheckBoxesOnPageSelected() && !this._allCheckBoxesInViewSelected()) {
        if ($(this.alreadySelectedAllMessageId)) {
          $(this.alreadySelectedAllMessageId).hide();
        }
        if ($(this.selectedAllMessageId)) {
          $(this.selectedAllMessageId).show();
        }
        this.clearReallySelectAll();
        this.checkBoxes.enableAll();
      }
    }
  },

  clearReallySelectAll: function() {
    if (this.attached) {
      this.reallySelectAllInputs.each(function(input) { input.value = false; });
    }
  },

  updateSelectedNumber: function() {
    if (this.attached) {
      if ($(this.numberOfCardsId)) {
        $(this.numberOfCardsId).innerHTML = this.checkBoxes.getSelectedValues().size();
      }
    }
  },

  _allCheckBoxesOnPageSelected: function() {
    if (this.attached) {
      var numberOfSelectedValues = this.checkBoxes.getSelectedValues().size();
      var numberOfValuesOnCurrentPage = this.checkBoxes._checkBoxesForForm().size();
      return (numberOfSelectedValues == numberOfValuesOnCurrentPage);
    }
  },

  _allCheckBoxesInViewSelected: function() {
    if (this.attached) {
      var numberOfSelectedValues = this.checkBoxes.getSelectedValues().size();
      return (numberOfSelectedValues == this.totalNumberOfCards);
    }
  },

  checkAllBoxesWithoutFiringEvents: function() {
    if (this.attached) {
      this.checkBoxes._checkBoxesForForm().each(function(checkbox) {
        checkbox.checked =  true;
      });
    }
  }
};

Object.extend(Form, {
  focus: function(field) {
    $(field).select();
    $(field).focus();
  },

  updateButton: function(button, input) {
    button = $(button);
    input = $(input);
    button.disabled = ("" === input.value.strip());
  },

  updateButtonOnChange: function(button, input) {
    button = $(button);
    input = $(input);
    Form.updateButton(button, input);
    ['propertychange', 'change', 'keydown', 'keyup'].each(function(listener) {
      input.observe(listener, function(event) {
        if (event.keyCode && event.keyCode == Event.KEY_RETURN) {
          return;
        }
        Form.updateButton(button, input);
      });
    });
  },

  submitTo: function(form, url) {
    $(form).action = url;
    $(form).submit();
  },

  isLocking: function(form, button) {
    form = $(form);
    button = $(button);
    return form.isSubmitting || button.disabled;
  },

  lock: function(form, button) {
    form = $(form);
    button = $(button);
    form.isSubmitting = true;
    button.originalValue = button.value;
    button.value = 'Processing...';
    button.disable();
  },

  unlock: function(form, button) {
    form = $(form);
    button = $(button);
    form.isSubmitting = false;
    button.enable();
    button.value = button.originalValue;
  }
});

var InputElementHelp = Class.create();
InputElementHelp.instances = [];
InputElementHelp.clearHelpText = function() {
  InputElementHelp.instances.each(function(helpInstance) {
    helpInstance.clearHelpText();
  });
};

InputElementHelp.isDisabled = false;
InputElementHelp.disable = function() {
  InputElementHelp.isDisabled = true;
};
InputElementHelp.prototype = {
  initialize: function(input, helpText) {
    this.input = $(input);
    this.helpText = helpText;
    this.input.helper = this;
    this.showHelpText();
    Event.observe(this.input, 'focus', this.clearHelpText.bindAsEventListener(this));
    Event.observe(this.input, 'blur', this.showHelpText.bindAsEventListener(this));

    if(this.input.form) {
      var oldOnSubmit = this.input.form.onsubmit.bind(this.input.form);
      this.input.form.onsubmit = function(event){
        this.clearHelpText();
        if (oldOnSubmit != null){
          oldOnSubmit(event);
        }
        // make sure it return false to prevent dup submit on ie
        return false;
      }.bindAsEventListener(this);
    }

    InputElementHelp.instances.push(this);
  },

  clearHelpText: function() {
    if (this.input.hasClassName('inactive')){
      this.input.value = '';
      this.input.addClassName('accepting-input');
      this.input.removeClassName('inactive');
    }
  },

  showHelpText: function() {
    if (InputElementHelp.isDisabled) {return;}
    if (this.input.value == '' && !this.input.hasClassName('inactive')){
      this.input.addClassName('inactive');
      this.input.removeClassName('accepting-input');
      this.input.value = this.helpText;
    }
  }
};

var StartStopTimer = Class.create();
StartStopTimer.prototype = {
  initialize: function(callback, frequency, autostart) {
    this.frequency = frequency;
    this.callback = callback;
    this.started = false;
    if (autostart){
      this.start();
    }
  },

  start: function() {
    if (!this.started) {
      this.callback();
      this.intervalId = setInterval(this.callback, this.frequency * 1000);
      this.started = true;
    }
  },

  stop: function() {
    if (this.started) {
      clearInterval(this.intervalId);
      this.started = false;
    }
  },

  toggle: function() {
    if(this.started) {
      this.stop();
    } else {
      this.start();
    }
  }
};

var LastWinAjaxRequest = {
  create: function(){
    if(this._last) {
      MingleAjaxTracker.onComplete(this._last);
      this._last.transport.abort();
    }
    this._last = new Ajax.Request(arguments[0], arguments[1]);
  }
};

var MutuallyExclusiveOpenPanels = Class.create({
  initialize: function(){
    this.panels = $A(arguments);
    this.panels.each(function(panel){
      panel.registerPanelOpenObserver(this._closeAllExcept.bind(this));
    }.bind(this));
  },

  _closeAllExcept: function(openingPanel) {
    this.panels.each(function(panel){
      if (panel != openingPanel) { panel.close(); }
    });
  }
});

function disableLink(id, disabledClass) {
  var linkElement = $(id);
  if (linkElement.onclick) {
    linkElement.oldOnClick = linkElement.onclick;
    linkElement.onclick = Prototype.emptyFunction;
  }
  if ("undefined" !== typeof disabledClass && disabledClass !== null) {
    linkElement.addClassName(disabledClass);
  } else {
    linkElement.addClassName('disabled');
  }
}

function enableLink(id, enabledClass, disabledClass) {
  var linkElement = $(id);
  if (linkElement.oldOnClick) {
    linkElement.onclick = linkElement.oldOnClick;
    linkElement.oldOnClick = null;
  }
  if ("undefined" !== typeof disabledClass && disabledClass !== null) {
    linkElement.removeClassName(disabledClass);
  } else {
    linkElement.removeClassName('disabled');
  }
  if (enabledClass) {
    linkElement.addClassName(enabledClass);
  }
}

var BulkDestroy = Class.create();
BulkDestroy.prototype = {
  initialize: function(destroyButton, checkboxes, destroyFunction, selectionInput) {
    this.destroyButton = $(destroyButton);
    if(!this.destroyButton) {return;}
    this.checkboxes = checkboxes;
    this.destroyFunction = destroyFunction;
    this.selectionInput = $(selectionInput);

    Event.observe(this.destroyButton, 'click', this.destroyListener.bindAsEventListener(this));
    this.checkboxes.registerObserver(this._updateLinkStatus.bindAsEventListener(this));
    this._updateLinkStatus();
  },

  destroyListener: function() {
    this.selectionInput.value = this.checkboxes.getSelectedValues();
    this.destroyFunction();
  },

  _updateLinkStatus: function() {
    this.destroyButton.disabled = this.checkboxes.noSelection();
  }
};

var BulkOperationPanel = Class.create();
BulkOperationPanel.prototype = {
  initialize: function(options) {
    this.panelElement = $(options.panelElement);
    this.toggleLink = $(options.toggleLink);
    this.limit = options.limit;
    if(!this.toggleLink){
      return;
    }

    if (this.limit) {
      this.makeTooltip();
    }

    this.panelOpenObserver = Prototype.emptyFunction;
    this.checkboxes = options.checkboxes;
    this.toggleListener = this._toggle.bindAsEventListener(this);
    Event.observe(this.toggleLink, 'click', this.toggleListener);
    this.checkboxes.registerObserver(this._updateButtonStatus.bindAsEventListener(this));
    this.checkboxes.registerObserver(this._update.bindAsEventListener(this));
    this.updatePanelForm = $(options.updatePanelForm);
    this.cardSelectionHiddenInput = $(options.cardSelectionHiddenInput);
    this._updateButtonStatus();
  },

  open: function() {
    if (this.toggleLink.hasClassName('tab-disabled')) {return;}

    this.panelOpenObserver(this);
    this._getPanelContent();
    this.panelElement.show();
    this.toggleLink.className = 'tab-collapse';
  },

  close: function() {
    this.panelElement.hide();
    this.toggleLink.className = 'tab-expand';
  },

  registerPanelOpenObserver: function(observer){
    this.panelOpenObserver = observer;
  },

  deny: function() {
    return this.limit && this.checkboxes.getSelectedValues().length > BulkOperationPanel.CARD_LIMIT;
  },

  makeTooltip: function() {
    var message = "Bulk update is limited to " + BulkOperationPanel.CARD_LIMIT + " cards. Try refining your filter.";
    jQuery(this.toggleLink).tipsy({trigger: "hover", gravity: "n", fade: true, title: function() { return message; }});
    jQuery(this.toggleLink).tipsy("disable");
  },

  enableTooltip: function() {
    if (!jQuery(this.toggleLink).tipsy(true)) {
      this.makeTooltip();
    }
    jQuery(this.toggleLink).tipsy("enable");
  },

  disableTooltip: function() {
    if (!jQuery(this.toggleLink).tipsy(true)) {
      this.makeTooltip();
    }
    jQuery(this.toggleLink).tipsy("disable");
  },

  _updateButtonStatus: function() {
    this.disableTooltip();

    if (this.checkboxes.noSelection()) {
      this.panelElement.innerHTML = "";
      disableLink(this.toggleLink, "tab-disabled");
    } else if (this.deny()) {
      this.panelElement.innerHTML = "";
      disableLink(this.toggleLink, "tab-disabled");

      this.enableTooltip();
    } else {
      if (this.panelElement.innerHTML === "") {
        enableLink(this.toggleLink, "tab-expand", "tab-disabled");
      }else {
        enableLink(this.toggleLink, "tab-collapse", "tab-disabled");
      }
    }
  },

  _update: function() {
    if (this.checkboxes.noSelection() || this.deny()) {
      this.panelElement.hide();
      this.panelElement.innerHTML = "";
      this.toggleLink.className = "tab-disabled";
    }
    if (this.panelElement.visible()) {this._getPanelContent();}
  },

  _toggle: function() {
    if (this.panelElement.visible()) {
      this.close();
    } else {
      this.open();
    }
  },

  _getPanelContent: function() {
    this.cardSelectionHiddenInput.value = this.checkboxes.getSelectedValues();
    this.updatePanelForm.onsubmit();
  }
};

Object.Observer = Class.create();
Object.Observer.prototype = {

  observe: function(eventName, callback) {
    this.getObservers().push([eventName, callback]);
  },

  stopObservingEverything: function(){
    this.observers = [];
  },

  removeObserver: function(callback) {
    this.observers = this.getObservers().reject(function(observe){
      return observe[1] == callback;
    }.bind(this));
  },

  fireEvent: function(name, eventObj) {
    this.getObservers().each(function(observer) {
      if(observer[0] == name) {
        observer[1](eventObj);
      }
    });
  },

  delegateEvent: function(element, eventName) {
    this.observe(element, eventName, function(eventObj) {
      this.fireEvent(eventName, eventObj);
    }.bind(this));
  },

  getObservers: function() {
    this.observers = this.observers || [];
    return this.observers;
  }
};

var CompileCallbackMixin = {
  interpretCallback: function(callback, bindTo, args) {
    var doBinding = (arguments.length > 1 && "undefined" !== typeof bindTo);

    if ("function" === typeof callback) {
      return doBinding ? callback.bind(bindTo) : callback;
    }

    if ("string" === typeof callback) {
      var fn = new Function(args, callback);
      return doBinding ? fn.bind(bindTo) : fn;
    }

    return Prototype.emptyFunction;
  }
};

var TextPropertyEditor = Class.create();
TextPropertyEditor.prototype = {
  initialize: function(edit_link_id, editor_input_id, value, not_set_display_name, options) {
    this.editLink = $(edit_link_id);
    this.editorPanel = $(editor_input_id);
    jQuery(this.editLink).parent()[0].propertyEditor = this;
    this.notSetDisplayName = not_set_display_name;
    this.isMixedValue = options.isMixedValue;
    this.value = value;

    Event.observe(this.editLink, 'click', this._onEditLinkClick.bindAsEventListener(this));
    jQuery(this.editorPanel).keypress(this, this._onKeypress);
    Event.observe(this.editorPanel, 'blur', this._onBlur.bindAsEventListener(this));
    this._setupFieldValueOnchangeCallback(options.onchange);
  },

  _onEditLinkClick: function() {
    var linkCoords = this.editLink.positionedOffset();
    var topOffset = 4;
    this.editorPanel.setStyle({
      position: "absolute",
      width: this.editLink.getWidth() + "px",
      left: linkCoords.left + "px",
      top: (linkCoords.top + topOffset)+ "px"
    });
    this.editLink.hide();
    this.editorPanel.show();
    this.editorPanel.focus();
    this.editorPanel.select();
  },

  _onKeypress: function(event){
    var isEnterKeypressEvent = jQuery.ui.keyCode.ENTER === event.which;
    var editor = event.data;

    if (isEnterKeypressEvent) {
      var element = event.target;
      if (editor.editLink.innerHTML !== editor.editorPanel.value) {
        editor._changeFieldValue();
      }
      if ("" === jQuery.trim(element.value)) {
        editor.editLink.innerHTML = editor.notSetDisplayName;
      } else {
        editor.editLink.innerHTML = element.value.escapeHTML();
      }

      event.stopPropagation();
      event.preventDefault();

      editor.isMixedValue = false;
      editor.editorPanel.hide();
      editor.editLink.show();
      DropList.View.Layout.refix();
    }
  },

  _onBlur: function(event) {
    this.editLink.show();
    this.editorPanel.hide();
    DropList.View.Layout.refix();
    if (this.editLink.innerHTML.strip() == this.notSetDisplayName || this.isMixedValue) {
      this.editorPanel.value = "";
    } else {
      this.editorPanel.value = this.editLink.innerHTML.strip().unescapeHTML();
    }
  },

  _setupFieldValueOnchangeCallback: function(callback) {
    this.onchange = this.interpretCallback(callback, jQuery(this.editLink).parent()[0]);
  },

  _changeFieldValue: function() {
    this.onchange(this);
  }
};

Object.extend(TextPropertyEditor.prototype, CompileCallbackMixin);

var DatePropertyEditor = Class.create();
DatePropertyEditor.prototype = {
  initialize: function(html_id_prefix, value, not_set_display_name, edit_link_suffix, editor_suffix, options) {
    this.editLink = $([html_id_prefix, edit_link_suffix].compact().join("_"));
    this.editorPanel = $(html_id_prefix + '_' + editor_suffix);
    jQuery(this.editLink).parent()[0].propertyEditor = this;
    this.calendarLink = $(html_id_prefix + '_calendar');
    this.datePanel = $(html_id_prefix + '_date_panel');
    this.notSetDisplayName = not_set_display_name;
    this.value = value;
    this.isMixedValue = options.isMixedValue;

    jQuery(this.editorPanel).keypress(this, this._onKeypress);
    Event.observe(this.editorPanel, 'blur', this._onBlur.bindAsEventListener(this));
    Event.observe(this.editLink, 'click', this._onEditLinkClick.bindAsEventListener(this));

    this._setupFieldValueOnchangeCallback(options.onchange);
  },

  _onEditLinkClick: function(){
    if(!this.datePanel){
      //TODO return it because we need support droplist for date propertydefintion so that we can use plv, it need be clean when all plv story finished
      return;
    }
    this.editLink.hide();
    this.showEditorPanel();
    this.editorPanel.focus();
    this.editorPanel.select();
  },

  _onKeypress: function(event) {
    var isEnterKeypressEvent = jQuery.ui.keyCode.ENTER === event.which;
    var editor = event.data;

    if (isEnterKeypressEvent) {
      var element = event.target;
      var value = jQuery.trim(element.value);

      if (editor.editLink.innerHTML != editor.editorPanel.value) {
        editor._changeFieldValue();
      }

      if ("" === value) {
        editor.editLink.innerHTML = editor.notSetDisplayName;
      } else {
        editor.editLink.innerHTML = value;
      }

      event.stopPropagation();
      event.preventDefault();

      editor.isMixedValue = false;
      editor.hideEditorPanel();
      editor.editLink.show();
    }
  },

  _onUpdateFromCalendarWidget: function(calendar) {
    this._changeFieldValue();
  },

  _onBlur: function(event) {
    this.editLink.show();
    this.hideEditorPanel();
    if (this.editLink.innerHTML == this.notSetDisplayName || this.isMixedValue) {
      this.editorPanel.value = "";
    } else {
      this.editorPanel.value = this.editLink.innerHTML;
    }
  },

  hideEditorPanel: function() {
    this.editorPanel.hide();
    this.calendarLink.show();
  },

  showEditorPanel: function() {
    this.editorPanel.show();
    this.calendarLink.hide();
  },

  _setupFieldValueOnchangeCallback: function(callback) {
    this.onchange = this.interpretCallback(callback, jQuery(this.editLink).parent()[0]);
  },

  _changeFieldValue: function() {
    this.onchange(this);
  }
};

Object.extend(DatePropertyEditor.prototype, CompileCallbackMixin);

var CallbackInterpreter = Object.extend({}, CompileCallbackMixin);

Effect.SafeHighlight = Class.create();
Effect.SafeHighlight.prototype = {
  initialize: function(element) {
    if ($(element)) {
      if (this.outsideViewport($(element))) {
        $(element).scrollTo();
      }
      new Effect.Highlight(element, {afterFinish: function() {$(element).style.backgroundColor = null;}});
    }
  },
  outsideViewport: function(element) {
    var documentViewport = document.viewport.getDimensions();
    var elementViewportOffset = element.viewportOffset();
    var viewportHeightFix = 0;
    if ($('ft')) {
      viewportHeightFix = $('ft').getHeight();
    }
    return elementViewportOffset.top < 0 || elementViewportOffset.top > (documentViewport.height - viewportHeightFix) || elementViewportOffset.left < 0 || elementViewportOffset.left > documentViewport.width;
  }
};

var SlideDownPanel = Class.create({
  initialize: function(panelElement, toggleLink, cloneAlogrithm, options) {
    this.options = options || {};
    this.panelElement = $(panelElement);
    this.toggleLink = $(toggleLink);
    this.cloneAlogrithm = cloneAlogrithm || MingleUI.align.alignRight;
    this.eventStore = new EventHandlerStore();

    var listener = new GlobalClickListener([this.panelElement, this.toggleLink], this.close.bind(this));
    this.eventStore.observe(this.toggleLink, 'click', this.toggle.bindAsEventListener(this));
    this.eventStore.observe(document.body, 'click', listener.onGlobalClick.bindAsEventListener(listener));
    this.resizeHandler = this.onResize.bindAsEventListener(this);
  },

  toggle: function(event) {
    if (this.toggleLink.hasClassName('disabled')) {
      Event.stop(event);
      return;
    }
    if (this.panelElement.visible()) {
      this.close();
      this.stopObservingWindowResize();
    } else {
      if (!this.toggleLink.disabled) {
        this.show(event);
        this.observeWindowResize();
      }
    }
    Event.stop(event);
  },

  close: function() {
    this.panelElement.hide();
  },

  show: function(event) {
    if (Object.isFunction(this.options['beforeShow'])) {
      this.options['beforeShow']();
    }
    this.cloneAlogrithm(this.toggleLink, this.panelElement);
    this.panelElement.show();
    if (Object.isFunction(this.options['afterShow'])) {
      this.options['afterShow']();
    }
  },

  onResize: function(event) {
    if (Prototype.Browser.IE) {
      this._onResize.bind(this).delay();
    } else {
      this._onResize();
    }
  },

  _onResize: function() {
    this.cloneAlogrithm(this.toggleLink, this.panelElement);
  },

  observeWindowResize: function(){
    jQuery(document).on("mingle:relayout", this.resizeHandler);
  },

  stopObservingWindowResize: function(){
    jQuery(document).off("mingle:relayout", this.resizeHandler);
  },

  destroy: function() {
    this.eventStore.stopObserving();
    this.stopObservingWindowResize();
  }
});

var GlobalClickListener = Class.create({
  initialize: function(containers, callbackMethod) {
    this.containers = containers;
    this.callbackMethod = callbackMethod;
  },

  onGlobalClick: function(event) {
    var element = Event.element(event);
    if(!element || !element.ancestors) {return true;}
    var isClickedOutSide = !element.ancestors().any(function(node){
      return $A(this.containers).any(function(container) {
        return container == node;
      });
    }.bind(this));

    if (isClickedOutSide) {
      this.callbackMethod();
    }
    return true;
  }
});

/*jsl:ignore*/
// a global month names array
var gsMonthNames = new Array(
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec'
);
// a global day names array
var gsDayNames = new Array(
  'Sunday',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday'
);
/*jsl:end*/
Array.prototype.sum = function() {
  return this.inject(0, function(acc, n) { return acc + n; });
};

Date.now = function() {
  return typeof(Date.clockNow) != 'undefined' ? new Date(Date.clockNow).getTime() : new Date().getTime();
};

// the date format prototype
Date.prototype = Object.extend(Date.prototype, {
  format: function(f){
    if (!this.valueOf()){
      return '&nbsp;';
    }

    var d = this;

    return f.replace(/(yyyy|mmmm|mmm|mm|dddd|ddd|dd|hh|nn|ss|a\/p)/gi,
      function($1) {
        var h;
        switch ($1.toLowerCase()) {
          case 'yyyy': return d.getFullYear();
          case 'mmmm': return gsMonthNames[d.getMonth()];
          case 'mmm':  return gsMonthNames[d.getMonth()].substr(0, 3);
          case 'mm':   return (d.getMonth() + 1);
          case 'dddd': return gsDayNames[d.getDay()];
          case 'ddd':  return gsDayNames[d.getDay()].substr(0, 3);
          case 'dd':   return d.getDate();
          case 'hh':   return ((h = d.getHours() % 12) ? h : 12);
          case 'nn':   return d.getMinutes() < 10 ? ("0" + d.getMinutes()) : d.getMinutes() ;
          case 'ss':   return d.getSeconds();
          case 'a/p':  return d.getHours() < 12 ? 'AM' : 'PM';
          default: throw "Error data format: " + $1;
        }
      });
  },

  distanceInMinutesToNow: function() {
    var toTime = new Date(Date.now());
    var fromTime = this;
    var distance = Math.abs(toTime.getTime() - fromTime.getTime());

    return parseInt(distance/(60 * 1000), 10);
  },

  distanceOfTimeInWordsToNow: function() {
    var distanceInMinutes = this.distanceInMinutesToNow();

    if(distanceInMinutes == 0) {
      return 'less than a minute';
    }else if(distanceInMinutes == 1) {
      return '1 minute';
    }else if(distanceInMinutes > 2 && distanceInMinutes <= 44) {
      return distanceInMinutes + " minutes";
    }else if(distanceInMinutes > 44 && distanceInMinutes <= 89) {
      return "about 1 hour";
    }else if(distanceInMinutes > 89 && distanceInMinutes <= 1439) {
      return parseInt(distanceInMinutes/60, 10) + " hours";
    }else if(distanceInMinutes > 1439 && distanceInMinutes <= 2879) {
      return 'about 1 day';
    }else if(distanceInMinutes > 2879 && distanceInMinutes <= 43199) {
      return parseInt(distanceInMinutes/1440, 10) + " days";
    }else if(distanceInMinutes > 43199 && distanceInMinutes <= 86399) {
      return 'about 1 month';
    }else if(distanceInMinutes > 86399 && distanceInMinutes <= 525959) {
      return parseInt(distanceInMinutes/43200, 10) + " months";
    }else if(distanceInMinutes > 525959 && distanceInMinutes <= 1051919) {
      return 'about 1 year';
    }

    return 'over ' + parseInt(distanceInMinutes/525960, 10) + ' years';
  },

  isWithinLast7Days: function() {
    return this.distanceInMinutesToNow() < 10080;
  },

  isSameDay: function(anotherDay){
    if(anotherDay == null){
      return false;
    }
    return this.getYear() == anotherDay.getYear() && this.getMonth() == anotherDay.getMonth() && this.getDay() == anotherDay.getDay();
  },

  isSameWeek: function(anotherDay){
    return this.getYear() == anotherDay.getYear() && this.getWeekOfYear() == anotherDay.getWeekOfYear();
  },

  getWeekOfYear: function(){
    var onejan = new Date(this.getFullYear(),0,1);
    return Math.ceil((((this - onejan) / 86400000) + onejan.getDay())/7);
  }
});

var LocaleDate = Class.create();
LocaleDate.timezoneOffset = new Date().getTimezoneOffset();
LocaleDate.prototype = {
  initialize: function(time) {
    if(time != null){
      this.date = new Date(time);
      this.date.getTimezoneOffset = function() {
        return LocaleDate.timezoneOffset;
      };
    }
  },

  isSameDay: function(localeDay) {
    return this.date.isSameDay(localeDay.getDate());
  },

  isWithinLast7Days: function() {
    return this.date.isWithinLast7Days();
  },

  getDate: function() {
    return this.date;
  },

  now: function() {
    return new Date(Date.now());
  },

  getFormattedDate: function(dateFormat) {
    return this.getDate().format(dateFormat);
  }
};

var HistoryDayHeadingsWriter = Class.create();
HistoryDayHeadingsWriter.prototype = {
  initialize: function(dateFormat, eventTimestamps) {
    var eventLocaleDates = $A(eventTimestamps).collect(function(timestamp) {
      return new LocaleDate(timestamp, dateFormat);
    }.bind(this));

    var previous = null;
    for(var i=0 ; i< eventLocaleDates.length ; i++){
      var current = eventLocaleDates[i];
      if (!(previous && current.isSameDay(previous))) {
        var heading_id = 'date_group_heading_' + i;

        if (current.isWithinLast7Days()) {
          $(heading_id).innerHTML = current.getFormattedDate('dddd (' + dateFormat + ')');
        } else {
          $(heading_id).innerHTML = current.getFormattedDate(dateFormat);
        }

        jQuery("#" + heading_id).removeAttr("style");
      }
      previous = current;
    }
  }
};

var ColorSelectPopups = {

  _openedPopups: $A(),

  create: function(colorBlock, popupData, color, options) {
    this.closeAllPopups();
    colorBlock = $(colorBlock);
    var popup = $(popupData);

    var macro_editor = popup.up("#macro_editor");
    if (macro_editor) {
      macro_editor.setStyle({position: "relative"});
    }

    if (options && options['alignRight']) {
      MingleUI.align.alignRight(colorBlock, popup);
    } else {
      MingleUI.align.alignLeft(colorBlock, popup);
    }
    popup.show();
    ColorSelector.create(this._colorSelectorOf(popup), {field: this._colorFieldOf(popup), transforms: HexTransforms});
    popup._colorSelectCreated = true;
    ColorSelector.select_color(this._colorSelectorOf(popup), color);
    this._openedPopups.push(popup);
    document.observe("colorpicker:scroll", ColorSelectPopups.closeAllPopups.bind(this));
  },

  closeAllPopups: function(){
    document.stopObserving("colorpicker:scroll");

    this._openedPopups.each(function(popup) {
      popup.hide();
      if (this._colorSelectorOf(popup) != null) {
        this._colorSelectorOf(popup).innerHTML = ''; // Avoid a second draggable square
      }
    }.bind(this));
    this._openedPopups = $A();
  },

  _colorSelectorOf: function(popup){
    return $(popup || document.body).select('.color_selector').first();
  },

  _colorFieldOf: function(popup){
    return $(popup || document.body).select('.color_field').first();
  }
};

var ColorPaletteEventHandler = Class.create({
  initialize: function(fieldName) {
    this.hiddenField = $$("input[name='" + fieldName +"']")[0];

    var container = this.hiddenField.up(".color-palette-container");
    this.palette = container.down(".color_selector_popup");
    this.colorField = this.palette.down(".color_field");
    this.colorBlock = container.down(".color_block");

    Event.observe(this.palette.down("input[type='submit']"), "click", this.onOkButtonClick.bind(this));
    Event.observe(this.hiddenField, "change", this.onEnteredNewColor.bind(this));
  },

  onColorBlockClick: function() {
    ColorSelectPopups.create(this.colorBlock, this.palette, this.getColorCode());
    return false;
  },

  onOkButtonClick: function(e) {
    Event.stop(e);
    this.setColorCode(this.colorField.getValue());
    this.updateColorBlock();

    ColorSelectPopups.closeAllPopups();
  },

  onEnteredNewColor:function(e) {
    this.updateColorBlock();
  },

  getColorCode: function() {
    return this.hiddenField.getValue();
  },

  setColorCode: function(value) {
    this.hiddenField.setValue(value);
  },

  updateColorBlock: function() {
    this.colorBlock.setStyle({ "background-color" : this.hiddenField.getValue() });
  }

});

var ProgressBar = {
  update: function(indicator, percentage) {
    indicator = $(indicator);
    if (percentage == 1) {
      indicator.setStyle({ width: '100%' }); // The progress should take direct effect for quick project imports.
    } else {
      new Effect.Morph(indicator, { style: "width: " + percentage * 100 + "%" });
    }
  }
};

var MingleAjaxTracker = {

  PENDING_REQUESTS: $A([]),

  onCreate: function(request){
    this.PENDING_REQUESTS.push(request.url);
  },

  onComplete: function(request){
    this.PENDING_REQUESTS = this.PENDING_REQUESTS.without(request.url);
  },

  onException: function(request, exception){
    try {
      this.onComplete(request);
    }catch(e){
      if (Prototype.isFireBugsEnabled) {
        console.log("Got Exception on request: " + request.url);
        console.log(e);
        throw(e);
      }
    }
  },

  allAjaxComplete: function(includeCardSummary){
    var requests;
    if (includeCardSummary == true) {
      requests = this.PENDING_REQUESTS;
    } else {
      requests = this.PENDING_REQUESTS.reject(function(url) {
        return url.match(/cards\/card_summary/) || url.match(/also_viewing/);
      });
    }
    return requests.size() == 0;
  }
};

jQuery(document).ajaxComplete(function(event, xhr, settings) {
  MingleAjaxTracker.onComplete(settings);
});

jQuery(document).ajaxSend(function(event, xhr, settings) {
  MingleAjaxTracker.onCreate(settings);
});

jQuery(document).ajaxError(function(event, xhr, settings, exception) {
  MingleAjaxTracker.onException(settings, exception);
});

Ajax.Responders.register(MingleAjaxTracker);

var MingleAjaxErrorHandler = {

  onComplete: function(request, transport) {
    if (request.parameters['bypassMingleAjaxErrorHandler']) {return;}
    if (this._isSuccess(transport)) {return;}
    if (this._isSessionTimout(transport)){
      alert('Sorry, your Mingle session has timed out. You will be redirected to the login page.');
      window.location.reload(true);
      return;
    }

    if (this._isServerError(transport)) {
      var msg = 'Sorry, Mingle encountered a problem it could not fix. Please try again. If this problem persists please contact your Mingle administrator.\n';
      if(MingleJavascript.env == 'test') {
        msg += "Request is: " + request.url + "\n";
        msg += "Response is: (status: " + transport.status + ")";
        msg += transport.responseText;
      }
      alert(msg);
    }
  },

  _isSuccess: function(transport) {
    //transport.status > 200000 is for firefox3 which triggers this responder when cancel the transfer
    return !transport.status || (transport.status >= 200 && transport.status < 300) || (transport.status > 200000);
  },

  _isSessionTimout: function(transport) {
    return transport.status == 401 && transport.responseText == "SESSION_TIMEOUT";
  },

  _isServerError: function(transport) {
    return transport.status == 500;
  },

  onException: function(request, e) {
    if (Prototype.isFireBugsEnabled) {
      console.log("Got Exception on request: " + request.url);
      console.log(e);
      throw(e);
    }
  }
};

Ajax.Responders.register(MingleAjaxErrorHandler);

var CardTypePropertiesController = Class.create();
CardTypePropertiesController.prototype = {
  initialize: function(allPropDefs, currentCardType, cardNameToPropertyDefIdMap, defaultPropertyDefinitionsContainer, cardTypeChangeObservers) {
    this.allPropDefs = allPropDefs;
    this.cardNameToPropertyDefIdMap = cardNameToPropertyDefIdMap;
    this.defaultPropertyDefinitionsContainer = defaultPropertyDefinitionsContainer;
    this.cardTypeChangeObservers = $A();
    if (cardTypeChangeObservers) {
      this.cardTypeChangeObservers = cardTypeChangeObservers;
    }
    this.changeCardTypeEditor(currentCardType);
  },

  changeCardTypeEditor: function(cardTypeName) {
    this.cardTypeChangeObservers.each(function(observer) {
      observer.onCardTypeChange(cardTypeName);
    });
    this.hideAllPropertyDefinitions();
    this.currentCardType = cardTypeName;
    this.cardNameToPropertyDefIdMap.get(this.currentCardType).each(function(prop_def) {
      var parent = $(prop_def).parentNode;
      if(parent && !(this.defaultPropertyDefinitionsContainer &&
          this.defaultPropertyDefinitionsContainer != parent) &&
          !$(prop_def).hasClassName('tree_belonging_property_definition')){
         // reorder properties for changed card type
        parent.appendChild($(prop_def).remove());
      }

      $(prop_def).show();
    }.bind(this));
  },

  destroyUnselectedCardTypeEditors: function() {
    this.allPropDefs.each(function(prop_def) {
      if(this.cardNameToPropertyDefIdMap.get(this.currentCardType).include(prop_def)) {
        return;
      }
      $(prop_def).remove();
    }.bind(this));
  },

  hideAllPropertyDefinitions: function() {
    this.allPropDefs.each(function(prop_def) {
      $(prop_def).hide();
    }.bind(this));
  }
};

var LazyContentLoader = Class.create();
LazyContentLoader.prototype = {
  initialize: function(loadingFunction, spinner, contentContainer) {
    this.loadingFunction = loadingFunction;
    this.spinner = $(spinner);
    this.contentContainer = $(contentContainer);
  },
  reload: function() {
    if (this._isLoadedOnce) {
      this.contentContainer.loaded = false;  // hook for selenium testing. uggh.
      if (this.isLoading) {
        this.isLoadQueued = true;
      } else {
        this.isLoading = true;
        this.spinner.show();
        eval(this.loadingFunction);
      }
    }
  },
  loadComplete: function() {
    if (this.isLoadQueued) {
      this.isLoadQueued = false;
      this.reload();
    } else {
      this.isLoading = false;
      this.spinner.hide();
      this.contentContainer.loaded = true;  // hook for selenium testing. uggh.
    }
  },
  loadIfNotLoadedOnce: function() {
    if (!this._isLoadedOnce) {
      this._isLoadedOnce = true;
      this.reload();
    }
  }
};

ReloadHistoryTabLoader = Class.create({
  initialize: function(url) {
    this.url = url.unescapeHTML();
  },
  reload: function() {
    window.location = this.url;
  }
});

var CardHistory = Class.create();
CardHistory.attach = function(loadingFunction) {
  this.loader = new LazyContentLoader(loadingFunction, 'history-spinner', 'history-container');
};
CardHistory.reload = function() {
  this.loader.reload();
};
CardHistory.loadComplete = function() {
  this.loader.loadComplete();
};
CardHistory.loadIfNotLoadedOnce = function() {
  this.loader.loadIfNotLoadedOnce();
};

var CardDiscussion = Class.create();
CardDiscussion.attach = function(loadingFunction) {
  this.loader = new LazyContentLoader(loadingFunction, 'discussion-spinner', 'card-murmurs');
};
CardDiscussion.reload = function() {
  this.loader.reload();
};
CardDiscussion.loadComplete = function() {
  this.loader.loadComplete();
};
CardDiscussion.loadIfNotLoadedOnce = function() {
  this.loader.loadIfNotLoadedOnce();
};

var DependencyHistory = Class.create();
DependencyHistory.attach = function(loadingFunction) {
  this.loader = new LazyContentLoader(loadingFunction, 'history-spinner', 'dependency-history-container');
};
DependencyHistory.reload = function() {
  this.loader.reload();
};
DependencyHistory.loadComplete = function() {
  this.loader.loadComplete();
};
DependencyHistory.loadIfNotLoadedOnce = function() {
  this.loader.loadIfNotLoadedOnce();
};

var LazyLoadingCollapsible = Class.create();
LazyLoadingCollapsible.prototype = {

  initialize: function(collapsibleId, loadingFunction) {
    this.content = $(collapsibleId + '_collapsible_content');
    this.collapseHeader = $(collapsibleId + '_collapsible_collapse_header');
    this.expandHeader = $(collapsibleId + '_collapsible_expand_header');
    this.loader = new LazyContentLoader(loadingFunction, collapsibleId + '_collapsible_spinner', collapsibleId + '_collapsible_content');
  },

  expand: function() {
    this.loader.loadIfNotLoadedOnce();
    [this.content, this.collapseHeader].each(Element.show);
    [this.expandHeader].each(Element.hide);
  },

  collapse: function() {
    [this.content, this.collapseHeader].each(Element.hide);
    [this.expandHeader].each(Element.show);
  },

  reload: function() {
    this.loader.reload();
  },

  loadComplete: function() {
    this.loader.loadComplete();
  }
};

var SetChangedProperty = Class.create();
SetChangedProperty.update =function(property_name){
  $('changed_property').value = property_name;
};

var LinkHandler = Class.create();
LinkHandler.prototype = {
  initialize: function(divs_to_break_links_of) {
    this.divs_to_break_links_of = $A(divs_to_break_links_of);
    this.overlays = this.divs_to_break_links_of.collect(function(div_id) {
      return $(div_id + "_overlay");
    });
  },

  disableLinks: function() {
    this.divs_to_break_links_of.each(function(div_id, i) {
      var overlay = this.overlays[i];
      Position.clone(div_id, overlay);
      overlay.setStyle({opacity: 0.25});
      overlay.show();
    }.bind(this));
  },

  enableLinks: function() {
    this.overlays.each(function(overlay) {
      overlay.hide();
    });
  }
};

var TransitionPopupForm = Class.create();
TransitionPopupForm.instance = null;

TransitionPopupForm.attach = function(namePrefix, hasComment) {
  TransitionPopupForm.instance = new TransitionPopupForm(namePrefix, hasComment);
};

TransitionPopupForm.prototype = {
  initialize: function(inputElementNames, hasComment) {
    this.inputElements = inputElementNames.collect(function(inputElementName) { return $$('input[name="' + inputElementName + '"]'); }).flatten();
    if (hasComment) {
      this.inputElements.push($('popup-comment'));
    }
  },

  onChange: function() {
    var comment = $('popup-comment');
    var submitButton = $('complete_transition');
    if (this.allFieldsAreSet()){
      submitButton.disabled = false;
    } else {
      submitButton.disabled = true;
    }
  },

  allFieldsAreSet: function() {
    return this.inputElements.all( function(element) {
      return element.value.strip() != '';
    });
  }
};

var AttachmentsContainer = Class.create();
AttachmentsContainer.attach = function(containId, attachmentFieldName){
  AttachmentsContainer.instance = new AttachmentsContainer(containId, attachmentFieldName);
};
AttachmentsContainer.prototype = {
  initialize: function(fieldsContainId, attachmentFieldName){
    this.container = $(fieldsContainId);
    this.attachmentFieldName = attachmentFieldName;
    this.count = 1;
  },

  attachAnotherFile: function(){
    var anotherFieldId =  this.attachmentFieldName + "_" + this.count;
    var anotherFieldName =  this.attachmentFieldName + "[" + this.count +"]";
    var anotherField = Builder.node('input', {id: anotherFieldId , name: anotherFieldName, type: 'file', size: 30});
    this.container.appendChild(anotherField);
    this.count++;
  }
};

var FavoriteCheckboxes = Class.create();

FavoriteCheckboxes.prototype = {

  initialize: function() {},

  favoriteLinkOnClick: function() {
    this._linkOnClick('top', 'favorite', 'team favorite', 'tab', 'tab');
    this._linkOnClick('bottom', 'favorite', 'team favorite', 'tab', 'tab');
    $('top_status').onsubmit();
  },

  tabLinkOnClick: function() {
    this._linkOnClick('top', 'tab', 'tab', 'favorite', 'team favorite');
    this._linkOnClick('bottom', 'tab', 'tab', 'favorite', 'team favorite');
    $('top_status').onsubmit();
  },

  _linkOnClick: function(id_prefix, clickedOnOptionPrefix, clickedOnOptionLinkText, otherOptionPrefix, otherOptionLinkText) {
    var clickedOnLink = $(id_prefix + '_' + clickedOnOptionPrefix + '_link');
    var clickedOnCheckBox = $(id_prefix + '_' + 'status[' + clickedOnOptionPrefix + ']');

    clickedOnLink.toggleClassName('wiki-' + clickedOnOptionPrefix + '-selected').toggleClassName('wiki-' + clickedOnOptionPrefix + '-unselected');
    clickedOnCheckBox.checked = !clickedOnCheckBox.checked;
    if (clickedOnCheckBox.checked) {
      var otherOptionLink = $(id_prefix + '_' + otherOptionPrefix + '_link');
      var otherOptionCheckbox = $(id_prefix + '_' + 'status[' + otherOptionPrefix + ']');
      clickedOnLink.innerHTML = clickedOnLink.title = 'Remove ' + clickedOnOptionLinkText;

      if (otherOptionLink) {
        otherOptionLink.innerHTML = otherOptionLink.title = 'Make ' + otherOptionLinkText;
        otherOptionLink.removeClassName('wiki-' + otherOptionPrefix + '-selected').addClassName('wiki-' + otherOptionPrefix + '-unselected');
      }
      otherOptionCheckbox.checked = false;
    } else {
      clickedOnLink.innerHTML = clickedOnLink.title = 'Make ' + clickedOnOptionLinkText;
    }
  }
};

var ConfirmBox = Class.create();
ConfirmBox.deactivate = function() {
  if(this.nearByElement) {
    this.nearByElement.removeClassName("highlight-border");
    this.nearByElement = null;
  }

  if(this.boxContentElement && this.boxContentElement.visible()) {
    new Effect.SwitchOff(this.boxContentElement);
  }
  this.boxContentElement = null;

  if(this.cancelByClickOutsideAction) {
    document.stopObserving('mousedown', this.cancelByClickOutsideAction);
  }

  this.cancelByClickOutsideAction = null;
  this.confirmActions = [];
  this.cancelAction = null;
};

ConfirmBox.initForActivate = function(confirmActions, cancelAction, boxContentElement) {
  if(window.event) {
    Event.stop(window.event);
  }

  if(this.boxContentElement) {
    this.boxContentElement.hide();
    this.cancel();
  }

  this.confirmActions = confirmActions;
  this.cancelAction = cancelAction;

  this.boxContentElement = $(boxContentElement || "confirm-box");
};

ConfirmBox.activateInline = function(confirmActions, cancelAction, boxContentElement) {
  this.initForActivate(confirmActions, cancelAction, boxContentElement);
  this.boxContentElement.show();
};

ConfirmBox.activate = function(nearByElement, confirmActions, cancelAction, boxContentElement, extraOptions) {
  this.initForActivate(confirmActions, cancelAction, boxContentElement);
  this.nearByElement = $(nearByElement);

  var topDelta = 30;
  var leftDelta = this.nearByElement.getWidth() - 10;

  if(extraOptions){
    if(extraOptions.offsetTop != undefined){
      topDelta = extraOptions.offsetTop;
    }
    if(extraOptions.offsetLeft != undefined){
      leftDelta = extraOptions.offsetLeft;
    }
  }

  Position.clone(this.nearByElement, this.boxContentElement, {
    offsetTop: topDelta,
    offsetLeft: leftDelta,
    setHeight: false,
    setWidth: false});

  this.cancelByClickOutsideAction = function(event){
    if(this.boxContentElement.isFiredInside(event)) {
      return;
    }
    this.cancel();
  }.bindAsEventListener(this);
  document.observe('mousedown', this.cancelByClickOutsideAction);

  if(!extraOptions || !extraOptions.dont_add_border){
    this.nearByElement.addClassName("highlight-border");
  }

  ViewHelper.displayElmentInside(this.boxContentElement, this.boxContentElement.getOffsetParent(), {top: topDelta});
};

ConfirmBox.confirm = function(index) {
  this.boxContentElement.hide();
  this.confirmActions[index]();
  this.deactivate();
};

ConfirmBox.cancel = function() {
  if(this.cancelAction) {
    this.cancelAction(this.boxContentElement);
  }
  this.deactivate();
};

var ViewHelper = Class.create();
ViewHelper.delta = new Hash({left: 5, top: 5});
ViewHelper.displayElmentInside = function(element, container, delta) {
  if(typeof(delta) != 'undefined') {
    this.delta = this.delta.merge(delta);
  }
  element.show();

  var newOffsetTop = this.fixedOffsetTop(element, container) - element.offsetTop;
  var newOffsetLeft = this.fixedOffsetLeft(element, container) - element.offsetLeft;
  Position.clone(element, element, {
    offsetTop: newOffsetTop,
    offsetLeft: newOffsetLeft,
    setHeight: false, setWidth: false});

  element.hide();

  new Effect.Appear(element, {duration: 0.5});
};

ViewHelper.fixedOffsetLeft = function(element, container) {
  if(element.offsetLeft < 0) {
    return 0;
  }

  var outside = element.offsetLeft + element.getWidth() - container.getWidth();
  if(outside < 0) {
    return element.offsetLeft;
  }

  var offset = element.offsetLeft - outside - this.delta.get('left');
  if(offset < 0) {
    return 0;
  }
  return offset;
};

ViewHelper.fixedOffsetTop = function(element, container) {
  if(element.offsetTop < 0) {
    return 0;
  }

  var outside = element.offsetTop + element.getHeight() - container.getHeight();
  if(outside < 0) {
    return element.offsetTop;
  }

  var offset = element.offsetTop - element.getHeight() - this.delta.get('top');
  if(offset < 0) {
    return 0;
  }
  return offset;
};

var AppendableForm = Class.create({
  initialize: function(form, inputClass, inputRowClass) {
    this.form = $(form);
    this.form.observe('entry:add', this.onAddButtonClick.bindAsEventListener(this));
    this.form.observe('entry:remove', this.onRemoveButtonClick.bindAsEventListener(this));

    this.inputSelector = '.' + inputClass;
    this.inputRowSelector = '.' + inputRowClass;
    this.addButtonSelector = '.add-button';

    var addEntryListener = function(event){
      var element = Event.element(event);
      element.fire('entry:add', { eventElement : element });
    };
    var removeEntryListener = function(event){
      var element = Event.element(event);
      element.fire('entry:remove', { eventElement : element });
    };
    this.addEntryListener = addEntryListener;
    this.removeEntryListener = removeEntryListener;

    this.form.select(this.addButtonSelector).each(function(element) {
        element.observe('click', addEntryListener);
    });
    this.form.select('.remove-button').each(function(element) {
        element.observe('click', removeEntryListener);
    });
  },

  onRemoveButtonClick: function(event) {
    if (this.form.select(this.inputRowSelector).size() < 2) {return;}
    var row = $(event.memo.eventElement.up(this.inputRowSelector));
    if (row.down(this.addButtonSelector)) {
      var addButton = row.down(this.addButtonSelector);
      row.previous(this.inputRowSelector).down('.remove-button').insert({ before: addButton });
    }
    row.remove();
  },

  onAddButtonClick: function(event) {
    var row = $(event.memo.eventElement.up(this.inputRowSelector));
    var newRow = row.cloneNode(true);

    row.down(this.addButtonSelector).remove();

    row.insert({ after : newRow });
    newRow.down(this.inputSelector).value = '';

    // hack
    newRow.down(this.inputSelector).removeClassName('error');

    var newAddButton = newRow.down(this.addButtonSelector);
    var newRemoveButton = newRow.down('.remove-button');
    newAddButton.observe('click', this.addEntryListener);
    newRemoveButton.observe('click', this.removeEntryListener);
  }
});

var CardView = Class.create();
CardView = {
  showQuickAdd: function(cardElement, quickAddElement) {
    cardElement = $(cardElement);
    quickAddElement = $(quickAddElement);
    quickAddElement.show();
    MingleUI.align.cumulativeAlign(cardElement, quickAddElement, {left: cardElement.getWidth() + 2});
    quickAddElement.down('.card-name-input').focus();
  }
};

var CardTypeTreePropertiesController = Class.create({
  initialize: function(lastCardTypeInTreeMap, removeNodeWithChildrenOptions, removeNodeOnlyOptions, droplistObjects, noChangeSelection, removeThisCardFromTreeSelection) {
    this.lastCardTypeInTreeMap = lastCardTypeInTreeMap;
    this.removeNodeWithChildrenOptions = removeNodeWithChildrenOptions;
    this.droplistObjects = droplistObjects;
    this.removeNodeOnlyOptions = removeNodeOnlyOptions;
    this.noChangeSelection = noChangeSelection;
    this.removeThisCardFromTreeSelection = removeThisCardFromTreeSelection;
  },

  updateTreeOptions: function(cardType) {
    this.droplistObjects.each(function(droplistObject) {
      this._setTreeOptionsToDefault(droplistObject);
    }.bind(this));
    if(cardType == '' || cardType == undefined){
      return;
    }
    this.lastCardTypeInTreeMap.get(cardType).each(function(treeDropDownId) {
      this._removeWithChildrenOption(treeDropDownId);
    }.bind(this));
  },

  _setTreeOptionsToDefault: function(droplistObject) {
    droplistObject.replaceOptions(this.removeNodeWithChildrenOptions, [droplistObject.getSelectedName(), droplistObject.getSelectedValue()]);
  },

  _removeWithChildrenOption: function(treeDropDownId) {
    var droplistObject = this.droplistObjects.detect(function(droplistObject) {
      return (droplistObject.htmlIdPrefix == treeDropDownId);
    });
    if (droplistObject != null) {
      var selection;
      if (droplistObject.getSelectedValue() == this.noChangeSelection.last()) {
        selection = this.noChangeSelection;
      } else {
        selection = this.removeThisCardFromTreeSelection;
      }
      droplistObject.replaceOptions(this.removeNodeOnlyOptions, selection);
    }
  }
});

var TransitionRelationshipProperties = Class.create();
TransitionRelationshipProperties.prototype = {
  initialize: function(disabledMessageMap) {
    this.disabledMessageMap = disabledMessageMap;
  },

  ignoreValue: ':ignore',

  setDisabledChildLink: function(changedRelationshipIdPrefix, disabledLink) {
    disabledLink.innerHTML = this.disabledMessageMap.get(changedRelationshipIdPrefix).childMessage;
  },

  setDisabledParentLink: function(relationship, disabledLink, changedRelationshipValue) {
    if (changedRelationshipValue == '') {
      disabledLink.innerHTML = '(no change)';
    } else {
      disabledLink.innerHTML = this.disabledMessageMap.get(relationship).parentMessage;
    }
  }
};

var CardDefaultsRelationshipProperties = Class.create();
CardDefaultsRelationshipProperties.prototype = {
  initialize: function() {},

  ignoreValue: '',

  setDisabledChildLink: function(changedRelationshipIdPrefix, disabledLink) {
    disabledLink.innerHTML = '(not set)';
  },

  setDisabledParentLink: function(relationship, disabledLink, changedRelationshipValue) {
    if (changedRelationshipValue == '') {
      disabledLink.innerHTML = '(no change)';
    } else {
      disabledLink.innerHTML = '(determined by tree)';
    }
  }
};

var RelationshipPropertiesController = Class.create();
RelationshipPropertiesController.instance = null;
RelationshipPropertiesController.attach = function(relationshipsMap, relationshipProperties) {
  RelationshipPropertiesController.instance = new RelationshipPropertiesController(relationshipsMap, relationshipProperties);
};

RelationshipPropertiesController.prototype = {
  initialize: function(relationshipsMap, relationshipProperties) {
    this.relationshipsMap = relationshipsMap;
    this.relationshipProperties = relationshipProperties;
    this.initialDisabling();
  },

  onChange: function(htmlIdPrefix) {
    var otherRelationshipsInTree = this.relationshipsMap.get(htmlIdPrefix).otherRelationshipsInTree;

    var changedRelationshipValue = $(this.relationshipsMap.get(htmlIdPrefix).valueField).value;

    if (changedRelationshipValue == this.relationshipProperties.ignoreValue) {
      this._enableLinks(otherRelationshipsInTree);
    } else {
      this._disableLinks(htmlIdPrefix, otherRelationshipsInTree);
    }
  },

  initialDisabling: function() {
    var allRelationships = this.relationshipsMap.keys();
    allRelationships.each(function(relationship) {
      if ($(this.relationshipsMap.get(relationship).valueField).value != this.relationshipProperties.ignoreValue) {
        this.onChange(relationship);
      }
    }.bind(this));
  },

  _enableLinks: function(relationships) {
    relationships.each( function(relationship) {
      $(relationship + '_drop_link').show();
      $(relationship + '_disabled_link').hide();
    });
  },

  _disableLinks: function(changedRelationshipIdPrefix, relationships) {
    var relationshipsMap = this.relationshipsMap;
    var changedRelationshipDisplayValue = $(changedRelationshipIdPrefix + '_drop_link').innerHTML;
    var changedRelationshipValue = $(relationshipsMap.get(changedRelationshipIdPrefix).valueField).value;

    relationships.each( function(relationship) {
      var disabledLink = this._disabledLink(relationship);
      $(relationshipsMap.get(relationship).valueField).value = this.relationshipProperties.ignoreValue;
      $(relationship + '_drop_link').hide();
      if ( this._firstRelationshipHigherInTreeThanSecond(relationship, changedRelationshipIdPrefix) ) {
        this.relationshipProperties.setDisabledParentLink(relationship, disabledLink, changedRelationshipValue);
      } else {
        this.relationshipProperties.setDisabledChildLink(changedRelationshipIdPrefix, disabledLink);
      }
      disabledLink.show();
    }.bind(this));
  },

  _disabledLink: function(prefix) {
    return $(prefix + '_disabled_link');
  },

  _firstRelationshipHigherInTreeThanSecond: function(firstRelationship, secondRelationship) {
    var relationshipsMap = this.relationshipsMap;
    return relationshipsMap.get(firstRelationship).index < relationshipsMap.get(secondRelationship).index;
  }
};

var Errors = {
  refresh: function(pattern, errorIndexs) {
    $$(pattern).each(function(element, index){
      errorIndexs.include(index) ? element.addClassName('error') : element.removeClassName('error');
    });
  }
};

Element.addMethods({
  // elements position related to body left border
  // please cache the result for execution is quite expensive
  getScreenPosition: function(element) {
    var indicator = new Element('div', {style: 'width:1px; height:1px; position:absolute'});
    element.ownerDocument.body.appendChild(indicator);
    Position.clone(element, indicator);
    var position = {left: indicator.offsetLeft, top: indicator.offsetTop};
    indicator.remove();
    return position;
  }
});

var TreeGroupsSelect = Class.create({
  initialize: function(element, trees) {
    this.selectElement = $(element);
    this.trees = trees;
    var treeSelectListener = this.onOneTreeSelect.bind(this);

    this.trees.each(function(tree) {
      Module.mixin(tree, TreeGroupsSelect.Tree);
      tree.selectListener = treeSelectListener;
    });
    Event.observe(this.selectElement, 'change', this.refreshTreeColumnsStatus.bindAsEventListener(this));
    this.refreshTreeColumnsStatus();
  },

  onOneTreeSelect: function(tree) {
    this.trees.without(tree).invoke('ignore');
  },

  refreshTreeColumnsStatus: function(event) {
    var selectedTree = this.trees.detect(function(tree) {
      return tree.id == this.selectElement.value;
    }.bind(this));

    if( selectedTree ) {
      selectedTree.select();
    } else {
      this.trees.invoke('ignore');
    }
  }
});

TreeGroupsSelect.Tree = {
  moduleIncluded: function() {
    this.columns = this.columns.collect(function(name){
      return new TreeGroupsSelect.Column(name);
    });
  },

  ignore: function() {
    this.columns.invoke('ignore');
  },

  select: function() {
    this.columns.invoke('pickup');
    if(this.selectListener) {this.selectListener(this);}
  }
};

TreeGroupsSelect.Column = Class.create({
  initialize: function(name) {
    this.name = name;
    this.element = $(name + '_import_as');
  },

  pickup: function() {
    if(this.element.options.length > 1){
      this.element.value = this.element.options[1].value;
    }
  },

  ignore: function() {
    this.element.value = this.element.options[0].value;
  }

});

CancelPreviousEffectMoving = {
  effectMove: function(options) {
    this.cancelMovingEffect();
    this.movingEffect = new Effect.Move((this.element || this), options);
  },

  cancelMovingEffect: function() {
    if(this.movingEffect) {
      this.movingEffect.cancel();
      this.movingEffect = null;
    }
  }
};

var SimpleTooltip = Class.create({
  initialize: function(onElement, panelElement, options) {
    this.onElement = $(onElement);
    this.panelElement = $(panelElement);
    this.options = {
      offsetLeft: 20,
      offsetTop: 50,
      duration: 2.5
    };
    Object.extend(this.options, options || { });
    this.panelElement.style.position = 'absolute';
    this.show();
  },

  show: function() {
    if(this.panelElement.__timer) {clearTimeout(this.panelElement.__timer);}
    this.panelElement.show();
    this.panelElement.clonePosition(this.onElement, {
      setHeight: false,
      setWidth: false,
      offsetLeft: this.options.offsetLeft,
      offsetTop:this.options.offsetTop
    });
    this.panelElement.__timer = this.hide.bind(this).delay(this.options.duration);
  },

  hide: function() {
    this.panelElement.hide();
  }
});

var TransitionExecutor = {
  executeForm: null,
  popupForm: null,
  popupsHolder: null,

  execute: function(transitionId, cardId, cardNumber, projectId){
    if (typeof(this.popupsHolder) === "function") {

      if (MingleUI.grid.instance) {
        MingleUI.grid.instance.cardByNumber(cardNumber).addClass("operating");
      }
    }
    this._process(this.executeForm, transitionId, cardId, projectId);
  },

  popup: function(transitionId, cardId, projectId){
    this._process(this.popupForm, transitionId, cardId, projectId);
  },

  _process: function(form, transitionId, cardId, projectId) {
    form.getInputs('hidden', 'transition_id').first().value = transitionId;
    form.getInputs('hidden', 'id').first().value = cardId;
    form.getInputs('hidden', 'project_id').first().value = projectId;
    form.onsubmit();
  }
};

var InplaceTextareaEditor = Class.create({
  initialize: function(readView, editView, defaultMessage){
    this.readView = $(readView);
    this.editView = $(editView);
    this.textarea = this.editView.down('textarea');
    this.submitButton = this.editView.down('.finish-editing');
    this.cancelButton = this.editView.down('.cancel-editing');
    this.defaultMessage = defaultMessage;
    this.readView.observe('click', this.onReadViewClicked.bindAsEventListener(this));
    this.submitButton.observe('click', this.onSubmitButtonClicked.bindAsEventListener(this));
    this.cancelButton.observe('click', this.onCancelButtonClicked.bindAsEventListener(this));
    this.textarea.observe('focus', this.onTextAreaFocus);
    this.textarea.observe('blur', this.onTextAreaBlur);
    this.readView.innerHTML += this.defaultMessage;
  },

  setRailsEscapedContent: function(content) {
    this._setReadViewContent(content);
    this.textarea.value = content ? new Element('div').update(content.strip()).innerHTML.unescapeHTML() : '';
    this.lastContent = this.textarea.value;
  },

  _setReadViewContent: function(content) {
    this.clearContent();
    if(content && !content.blank()) {
      this.readView.innerHTML += content;
    } else {
      this.readView.innerHTML += this.defaultMessage;
    }
  },

  onTextAreaFocus: function(event) {
    var textarea = event.target;
    if(!textarea.isNotFirstFocus){
      (function(){
        textarea.focus();
        textarea.select();
      });
    }
    textarea.isNotFirstFocus = true;
  },

  onTextAreaBlur: function(event) {
    event.target.isNotFirstFocus = false;
  },

  onReadViewClicked: function(event) {
    this.readView.hide();
    this.editView.show();
    this.textarea.focus();
    this.textarea.select();
  },

  clearContent: function() {
    var readView = $(this.readView);
    var noneContentElement = readView.select('.none-content');
    noneContentElement.invoke('remove');

    readView.innerHTML = '';

    noneContentElement.each(function(element){
      readView.appendChild(element);
    });
  },

  onSubmitButtonClicked: function(event){
    this.submit();
    this.editView.hide();
    this.lastContent = this.textarea.value;
    this._setReadViewContent(this.textarea.value.escapeHTML());
    this.readView.show();
    Event.stop(event);
    return false;
  },

  onCancelButtonClicked: function(event){
    this.editView.hide();
    this.textarea.value = this.lastContent || '';
    this._setReadViewContent(this.textarea.value.escapeHTML());
    this.readView.show();

    Event.stop(event);
  },

  submit: function() {
    jQuery(this.submitButton.form).submit();
  }
});

var PixelsPerEmCalculatorModule = {
  calculateHowManyPixelsPerEm: function(){
    if($('mingle-1em-width-element')){
      this.testDiv = $('mingle-1em-width-element').setStyle({width: '1em'});
    }
    if(!this.testDiv){
      this.testDiv = Builder.node('div', {id: 'mingle-1em-width-element', style: "width: 1em;"});
      document.body.appendChild(this.testDiv);
    }
    this.pixelsPerEm = this.testDiv.getWidth();
    return this.pixelsPerEm;
  }
};

var UrlMerger = Class.create({
  initialize: function(link){
    this.link_element = $(link);
    //var params_seperator_index = link_url.lastIndexOf('?') == -1 ? link_url.length : link_url.lastIndexOf('?');
  },

  addParams: function(params){
    var link_url = this.link_element.href;
    $H(params).each(function(pair){
      var key = pair.key;
      var value = pair.value;

      if(link_url.lastIndexOf(key+'=') > 0){
        var rule = new RegExp(key+'=[^&]*|'+key+'=[^&]*$', 'ig');
        link_url = link_url.replace(rule, key+'='+value);
      } else {
        if(link_url.lastIndexOf('?') > 0){
          link_url += '&' + key+'='+value;
        }else{
          link_url += '?' + key+'='+value;
        }
      }
    });
    this.link_element.href = link_url;
  }
});

var CheckBoxUrlAppender = Class.create({
  initialize: function(checkBox, link, key){
    this.checkBox = $(checkBox);
    this.link = $(link);
    this.parameter_name = key;
    this.merger = new UrlMerger(link);
    this.onCheckBoxClickedLisener = this.onCheckBoxClicked.bindAsEventListener(this);
    this.checkBox.observe('click', this.onCheckBoxClickedLisener);
  },

  onCheckBoxClicked: function(event){
    var value;
    if(this.checkBox.checked){
      value = 'true';
    } else {
      value = 'false';
    }
    var params = $H();
    params.set(this.parameter_name, value);
    this.merger.addParams(params);
  },

  stopObserving: function(){
    Event.stopObserving(this.checkBox, 'click', this.onCheckBoxClickedLisener);
  }
});

var HotKeyClass = Class.create({

  initialize: function() {
    this.keyActions = $H();
    this.eventListener = this.onDocuKeypress.bindAsEventListener(this);
    this.observeKeyEvent();
    this.enable();
  },
  disable: function() {
    this.enabled = false;
  },
  enable: function() {
    this.enabled = true;
  },
  observeKeyEvent: function() {
    Event.observe(document, 'keypress', this.eventListener);
    if(!Prototype.Browser.Gecko) {
      // Safari and IE using keydown for none char key, but FF does not treat those key differently.
      Event.observe(document, 'keydown', this.eventListener);
    }
  },

  clear: function() {
    this.keyActions = $H();
    Event.stopObserving(document, 'keypress', this.eventListener);
    if(!Prototype.Browser.Gecko) {
      Event.stopObserve(document, 'keydown', this.eventListener);
    }
  },

  register: function(key, listener){
    if(Object.isString(key)){
      for(var index = 0; index < key.length; index++){
        this.keyActions.set(key.charCodeAt(index), listener);
      }
    } else {
      this.keyActions.set(key, listener);
    }
  },

  onDocuKeypress: function(event) {
    if(!this.enabled) {return;}
    if(this.isEventFromInput(event)) {return;}

    var listener = this.getKeyAction(event);
    if(listener) {
      listener(event);
      Event.stop(event);
    }
  },

  getKeyAction: function(event) {
    var inputCharCode = event.keyCode != 0 ? event.keyCode : event.charCode;
    return this.keyActions.get(inputCharCode);
  },

  isEventFromInput: function(event) {
    var element = Event.element(event);

    if(!element || !element.tagName){
      return false;
    }

    return ['input', 'textarea'].include(element.tagName.toLowerCase());
  }
});

var HotKey = new HotKeyClass();

var Button = Class.create({
  initialize: function(element, action, hotKey){
    this.element = $(element);
    this.action = action;

    this.element.observe('click', this.trigger.bindAsEventListener(this));
    if(hotKey) {
      HotKey.register(hotKey, this.trigger.bindAsEventListener(this));
    }
  },

  trigger: function(event) {
    this.highlight();
    this.action(event);
  },

  highlight: function() {
    this.element.addClassName('highlight');
    setTimeout(function(){
      this.element.removeClassName('highlight');
    }.bind(this), 400);
  },

  enable: function(){
    this.element.disabled = false;
  },

  disable: function() {
    this.element.disabled = true;
  }
});

var EventCenter = new (Class.create({
  initialize: function(){
    this.eventListeners = $H();
  },
  clear: function(){
    this.eventListeners = $H();
  },
  /* The listener's function signature is (eventSource, eventName, parameters) */
  addListener: function(eventName, eventListener){
    if(!Object.isFunction(eventListener)){
      return;
    }
    this.eventListeners.set(eventName, eventListener);
  },
  removeListener: function(eventName){
    if(this.eventListeners.get(eventName)){
      this.eventListeners.unset(eventName);
    }
  },
  trigger: function(eventName, parameters, scope){
    var listener = this.eventListeners.get(eventName);
    if(listener){
      if(Object.isFunction(listener)){
        if(scope){
          listener.call(scope, eventName, parameters);
        } else {
          listener(eventName, parameters);
        }
      }
    }
  }
}))();

var TransitionsFilter = Class.create({
  initialize: function(transitions){
    var filter = this;
    transitions.each(function(transition){
      var result = transition.property_definitions.collect(function(property_definition){
        return filter.completeTransitionPropDefValues(property_definition);
      });
      transition.property_definitions = result;
    });
    this.transitions = transitions;
  },

  findAll: function(cardTypeId, propertyDefinitionId){
    var matchedTransitions = this.transitions.select(function(t){
      if (t.card_type_id && t.card_type_id == cardTypeId) {
        return this.isTransitionPropertyMatch(t.property_definitions, propertyDefinitionId);
      }
      return false;
    }.bind(this));

    if(!this.showAll(propertyDefinitionId)){
      var matchedTransitionsMapping =  matchedTransitions.collect(function(transition){
        var mapping = transition.property_definitions.find(function(prop_def){
          return prop_def.id == propertyDefinitionId;
        });
        mapping.transition_id = transition.transition_id;
        mapping.transition_name = transition.transition_name;
        return mapping;
      });
      matchedTransitions =  this.splitSort(matchedTransitionsMapping);
    }
    return matchedTransitions;
  },

  getNameByTransitionId: function(transitionId) {
    return this.transitions.find(function(transition) {
      return transition.transition_id == transitionId;
    }).transition_name;
  },

  splitSort: function(transitions, sortKey){
    if(!sortKey){
      sortKey = 'from';
    }
    var notSetList = [];
    var fromNumberList = [];
    var fromTextList = [];
    transitions.each(function(transition){
      if(Object.isNumber(transition[sortKey])){
        fromNumberList.push(transition);
      } else if(transition[sortKey] == '(not set)'){
        notSetList.push(transition);
      } else {
        fromTextList.push(transition);
      }
    });

    fromTextList = fromTextList.sortBy(function(transition){
      return this.shiftTextLenthTo64(this.replaceSpecialTextValue(transition[sortKey]));
    }.bind(this));
    fromNumberList = fromNumberList.sortBy(function(transition){
      return transition[sortKey];
    });
    if(sortKey == 'from'){
      return this.distinctPartition($A([notSetList, fromNumberList, fromTextList]).flatten(), 'from').collect(function(fromArray){
        return this.splitSort(fromArray, 'to');
      }.bind(this)).flatten();
    } else {
      var result = $A([notSetList, fromNumberList, fromTextList]).flatten();
      this.sortByNameIfFromAndToIsSame(result);
      return result;
    }
  },

  sortByNameIfFromAndToIsSame: function(mappings){
    for(var i = 0; i < mappings.length; i++){
      for(var j = mappings.length - 2; j >= i; j--){
        if(mappings[j].from == mappings[j+1].from && mappings[j].to == mappings[j+1].to && mappings[j].transition_name.toLowerCase() > mappings[j+1].transition_name.toLowerCase()){
          var temp = mappings[j];
          mappings[j] = mappings[j+1];
          mappings[j+1] = mappings[j];
        }
      }
    }
  },

  distinctPartition: function(objectArray, property){
    var distinctPartition = [];
    var reference = this;
    var bucket = [];
    var previous;

    if(objectArray.length == 0) {return distinctPartition;}

    while(objectArray.length > 0){
      var current = objectArray.shift();
      if(!previous || current[property] != previous[property]){
        distinctPartition.push(bucket);
        bucket = [];
      }
      bucket.push(current);
      previous = current;
    }
    distinctPartition.push(bucket);
    distinctPartition.shift();

    return distinctPartition;
  },

  replaceSpecialTextValue: function(text){
    text = text.toLowerCase();
    if(text == '(not set)'){
      return '';
    }else if(text == '(today)' || text == '(current user)'){
        return '~'.times(16);
    }else if(text == '(user input - required)'){
      return '~'.times(62) + 'b';
    } else if(text == '(user input - optional)'){
      return '~'.times(62) + 'z';
    } else if (text == '(set)'){
      return '~'.times(63);
    }else if(text == '(any)' || text == '(no change)'){
      return '~'.times(64);
    }else if(/^\(.*\)$/.test(text)){
      return '~'.times(32) + text;
    }else {
      return text;
    }
  },

  shiftTextLenthTo64: function(text){
    if(text.length >= 64){
      return text.truncate(64, '');
    } else {
      return text + ' '.times(64 - text.length);
    }
  },

  isTransitionPropertyMatch: function(propertyDefinitionsGroupedByTransition, selectedPropertyDefinitionId){
    if (this.showAll(selectedPropertyDefinitionId)) {return true;}
    return propertyDefinitionsGroupedByTransition.any(function(p){
      return p.id == selectedPropertyDefinitionId;
    });
  },

  completeTransitionPropDefValues: function(transition_prop_def_values){
    return {
      id:   transition_prop_def_values.id,
      name: transition_prop_def_values.name,
      from: (transition_prop_def_values.from ? transition_prop_def_values.from : '(any)'),
      to:   (transition_prop_def_values.to ? transition_prop_def_values.to : (transition_prop_def_values.from ? '(no change)' : '(not set)') )
    };
  },

  ALL_PROPERTIES : '',

  showAll: function(value){
    return value == this.ALL_PROPERTIES;
  }
});

var TransitionMessages = Class.create({
  initialize: function(firstOptionToSecondOptions, mapFromTransitionIdToCardTypeAndPropertyDefinitions){
    this.noTransitionMessage = $('no-transition-message');
    this.backgroundColorNotice = $('back-ground-color-notice');
  },

  hide: function(){
    this.noTransitionMessage.hide();
    this.backgroundColorNotice.hide();
  },

  toggle: function(allTransitions){
    if(allTransitions.size() == 0){
      this.noTransitionMessage.show();
      this.backgroundColorNotice.hide();
    } else {
      this.backgroundColorNotice.show();
      this.noTransitionMessage.hide();
    }
  }
});

var TransitionsFiltersManager = Class.create({
  initialize: function(cardTypePropertyDefinitionMappings, mapFromTransitionIdToCardTypeAndPropertyDefinitions, dropdownSelections, options) {
    this.transitionsFilter = new TransitionsFilter(mapFromTransitionIdToCardTypeAndPropertyDefinitions);
    this.options = (options || {});

    this.cardTypeSelect = $('card-types-filter');
    this.propertyDefinitionSelect = $('property-definitions-of-card-type-filter');
    this.dropdownSelections = dropdownSelections;
    this.mappingData = cardTypePropertyDefinitionMappings;
    this.allTransitions = $$('#all-transitions div.transition-container');
    this.originalTransitionsOrder = this.allTransitions.pluck('id');
    this.allTransitionsContainer = $('all-transitions');
    this.noTransitionMessage = $('no-transition-message');
    this.backgroundColorNotice = $('back-ground-color-notice');
    this.transitionMessages = new TransitionMessages();
    this.transitionMessages.toggle(this.allTransitions);

    this.cardTypeSelect.observe('change', this.onCardTypeChange.bindAsEventListener(this));
    this.propertyDefinitionSelect.observe('change', this.onFilter.bindAsEventListener(this));

    if (this.dropdownSelections['card_type_id']) {
      this.cardTypeSelect.value = this.dropdownSelections['card_type_id'];
    }
    this.onCardTypeChange();

    if (this.options['createdTransitionId']) {
      this._displayFlashMessage('created', this.options['createdTransitionId']);
    } else if (this.options['updatedTransitionId']) {
      this._displayFlashMessage('updated', this.options['updatedTransitionId']);
    }
  },

  onCardTypeChange: function(event) {
    this._filterPropertyDefintionsByCardType();
    this.onFilter();
  },

  onFilter: function(event) {
    this.transitionMessages.hide();
    this._showTransitionElementInOrder(this.allTransitionsContainer, this.originalTransitionsOrder);

    if (this.cardTypeSelect.value == '') {
      this.allTransitions.invoke('show');
      this.transitionMessages.toggle(this.allTransitions);
    } else {
      this.allTransitions.invoke('hide');

      var transitionsToShow = this.transitionsFilter.findAll(this.cardTypeSelect.value, this.propertyDefinitionSelect.value);
      if (transitionsToShow.any()) {
        this._showTransitionsInOrder(transitionsToShow);
        transitionsToShow.each(function(t) {
          $('transition-' + t.transition_id).show();
        });
      }
      this.transitionMessages.toggle(transitionsToShow);
    }
  },

  _filterPropertyDefintionsByCardType: function() {
    this.propertyDefinitionSelect.update(''); // Safari 4: Clear all drop down options.
    this.mappingData[this.cardTypeSelect.value].each(function(nameValuePair) {
      var isSelected = (nameValuePair[1] == this.dropdownSelections['property_definition_id']);
      var option = new Option(nameValuePair[0], nameValuePair[1], isSelected, isSelected);
      this.propertyDefinitionSelect[this.propertyDefinitionSelect.length] = option;
    }, this);

    this.dropdownSelections = {};
    this.propertyDefinitionSelect.disabled = (this.cardTypeSelect.value == '');
  },

  _showTransitionsInOrder: function(transitions){
    var transitionIds = transitions.collect(function(transition){
      return 'transition-' + transition.transition_id;
    });
    this._showTransitionElementInOrder(this.allTransitionsContainer, transitionIds);
  },

  _showTransitionElementInOrder: function(allTransitionsContainer, transitionElementIds){
    transitionElementIds.each(function(transitionElementID){
      allTransitionsContainer.appendChild($(transitionElementID).remove());
    });
  },

  _displayFlashMessage: function(actionPerformed, createdTransitionId) {
    var transitionName = this.transitionsFilter.getNameByTransitionId(createdTransitionId).escapeHTML();
    var message = "";
    if ($('transition-' + createdTransitionId).visible()) {
      message = "Transition <b>#{transitionName}</b> was successfully #{actionPerformed}.";
    } else {
      message = "Transition <b>#{transitionName}</b> was successfully #{actionPerformed}, but is not shown because it does not match the current filter.";
    }
    if ($('notice')) {
      $('notice').innerHTML = message.interpolate({ transitionName : transitionName, actionPerformed : actionPerformed });
    }
  }
});

var Transition = {
  navigateToUrl: function(baseUrl) {
    window.location.href = this._assembleNavigateToUrl(baseUrl);
  },

  postToUrl: function(baseUrl, link) {
    if (confirm('Are you sure?')) {
      var f = document.createElement('form');
      f.style.display = 'none';
      AuthenticityToken.appendToForm(f);
      link.appendChild(f);
      f.method = 'POST';
      f.action = this._assembleNavigateToUrl(baseUrl);
      f.submit();
    }
  },

  buildFilterParams: function(innerParams) {
    var redirectParams = innerParams.map(function(pair) {
      return 'filter[' + pair.key + ']=' + pair.value;
    });
    return redirectParams.join('&');
  },

  _assembleNavigateToUrl: function(baseUrl) {
    var params = this.buildFilterParams($H({ card_type_id : $F('card-types-filter'), property_definition_id : $F('property-definitions-of-card-type-filter') }));
    if (baseUrl.indexOf('?') > 0) {
      return baseUrl + '&' + params;
    } else {
      return baseUrl + '?' + params;
    }
  }
};

var SubscriptionsCounter = Class.create({
  initialize : function() {
    this.tableElementDomIds = $A([]);
  },

  noSubscriptionsCheck: function() {
    this.tableElementDomIds.each(function(tableDomId) {
      var tableElement = $(tableDomId);
      if (tableElement.select('tbody > tr').size() == 1) {
        tableElement.select('tbody > tr').invoke('show');
      }
    });
  }
});
SubscriptionsCounter.attach = function(subscriptionTableDomIds) {
  SubscriptionsCounter.instance = new SubscriptionsCounter();
};
SubscriptionsCounter.add = function(tableDomIds){
  $A(tableDomIds).each(function(domId){
    SubscriptionsCounter.instance.tableElementDomIds.push(domId);
  });
};
SubscriptionsCounter.noSubscriptionsCheck = function() {
  SubscriptionsCounter.instance.noSubscriptionsCheck();
};

// example:
//   create a cookie named 'auto_enroll' with value 'hide' expired after 30 days:
//      new Cookie('auto_enroll', 'hide', 30)
//   delete the cookie:
//      new Cookie('auto_enroll', '', -1)
var Cookie = Class.create({
  initialize: function(name, value, days, path) {
    var expires = "";
    if (days) {
      var date = new Date();
      date.setTime(date.getTime()+(days*24*60*60*1000));
      expires = "; expires="+date.toGMTString();
    }
    if(!path) {
      path = '/';
    }
    document.cookie = name + "=" + value + expires + "; path=" + path;
  }
});

var Benchmark = Class.create({

  initialize : function(container) {
    this.capturedTimes = $A();
    this.messages = $A();
    this.container = $(container);
  },

  benchmark : function(message, codeBlock) {
    var beginTime = new Date();
    codeBlock();
    var endTime = new Date();
    this.messages.push(message);
    this.capturedTimes.push(endTime - beginTime);
  },

  report: function() {
    var reportMessages = this.capturedTimes.map(function(time, index) { return this.messages[index] + " : " + time + "ms"; }.bind(this));
    var report = reportMessages.join("<br />");
    this.container.innerHTML = report + "<br />" + "total   :   " + this.capturedTimes.sum() + 'ms';
  }
});

var StringComparison = function(value1, value2) {
  return value1.toLowerCase() == value2.toLowerCase();
};

var NumericComparison = function(value1, value2) {
  if (value1.blank()){
    return value2.blank();
  } else if (value2.blank()){
    return value1.blank();
  } else if (isNaN(value1) || isNaN(value2)) {
    return StringComparison(value1, value2);
  } else {
    return Number(value1) == Number(value2);
  }
};

var ToggleSynchronizerClass = Class.create({
  toggle: function(element_class, checked){
    $$('.' + element_class).each(function(element){
      checked ? element.show() : element.hide();
    });
  }
});
var ToggleSynchronizer = new ToggleSynchronizerClass();


var IEInputEnterKeyFix = {
  attach: function(form) {
    form = $(form);
    var keydown = function(e) {
      e = e || window.event;
      if (e.keyCode == 13) {
        form.onsubmit();
        return false;
      }
    };

    form.getInputs().each(function(input) {
      input.onkeydown = keydown;
    });
  }
};

var MurmurForm = Class.create({
  initialize: function() {
    this.container = $('quick-add');
    this.input = $('murmur_murmur');
    this.form = this.input.up('form');
    this.form.observe('keypress', this.onKeypress.bindAsEventListener(this));
  },

  beforeSend: function() {
    this.container.disable();
    this.input.addClassName('fade-out');
  },

  postComplete: function() {
    this.container.enable();
    this.input.clear();
    this.input.removeClassName('fade-out');
    this._postComplete.bind(this).delay(0.1);
  },

  _postComplete: function() {
    if(Prototype.Browser.IE){
      this.input.enable();
    }
    this.input.focus();
  },

  onKeypress: function(event) {
    if (event.keyCode == Event.KEY_RETURN) {
      this.form.onsubmit();
      return false;
    }
  }
});

var ReplaceHTMLIfElementExist ={
  update: function(id, content){
    if($(id)){
      Element.update(id, content);
    }
  }
};

var SingleCard = function() {
  function copyPseudoCardCommentInformationToHiddenFields() {
    InputElementHelp.clearHelpText();
    $('edit-card-comment').value = $('pseudo-card-comment').value;
    if ($('murmur-this-edit')) {
      $('edit-murmur-this').checked = $('murmur-this-edit').checked;
    }
  }

  return {
    saveCreate: function(element) {
      if (jQuery(element).hasClass('disabled')) {
          return;
      }
      jQuery(element).addClass('disabled');
      copyPseudoCardCommentInformationToHiddenFields();
      $('card-create-form').submit();
    },
    saveEdit: function(element) {
      if (jQuery(element).hasClass('disabled')) {
          return;
      }
      jQuery(element).addClass('disabled');

      copyPseudoCardCommentInformationToHiddenFields();
      if ($('original_card_type').value != $('card_type_name_field').value) {
        InputingContexts.push(new LightboxInputingContext());
        InputingContexts.update($('change_card_type_confirmation_actions_container').innerHTML);
      } else {
        $('card-edit-form').submit();
      }
      MingleUI.EasyCharts.ActionTracker.postCreateEvents();
    }
  };
}();

var AdminJob = {
  disable: function(id) {
    var overlay = this.createOverlay(id);
    var progressBar = this.createProgressBar(id);
    var button = $(id).down('input');
    button.onclick = this.adminJobButtonOnclick.bindAsEventListener(button);

    $(id).appendChild(overlay);
    $(id).appendChild(progressBar);

    this.showOverlay(id, overlay);

    this.resizeHandler = function(event) {
      this.showOverlay(id, overlay);
    }.bindAsEventListener(this);

    jQuery(document).on("mingle:relayout", this.resizeHandler);
    progressBar.show();
  },

  adminJobButtonOnclick: function(button) {
    window.docLinkHandler.disableLinks();
    return true;
  },

  createProgressBar: function(id) {
    return new Element('img', {src: $('progress_bar_blue').src, className: 'admin-job-progress-bar', style: 'display: none'});
  },

  createOverlay: function(eid) {
    return new Element("div", {id: eid + "_overlay", style: 'background-color: white; display:none; position:absolute;'});
  },

  showOverlay: function(id, overlay) {
    Position.clone(id, overlay);
    overlay.setStyle({opacity: 0.4});
    overlay.show();
  }
};


Element.disableLink = function(link) {
    link.setAttribute('href', 'javascript:void(0)');
    link.setAttribute("onclick", "");
    link.addClassName('disabled');
    link.update('Processing...');
};

function ensureFunction(func) {
  return typeof func === 'function' ? func : null;
}
