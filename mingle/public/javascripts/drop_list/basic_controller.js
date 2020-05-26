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
DropList.BasicController = Class.create({

  initialize: function(model, options) {
    this.model = model;
    this.supportInlineEdit = options.supportInlineEdit;
    this.actions = $A();
    this.dropLink = new DropList.View.DropLink(this.model, options.dropLink, options.truncateLink);
    this.dropLink.clickListener = this.onDropLinkClicked.bindAsEventListener(this);

    this.field = new DropList.View.Field(this.model);

    this.dropdown = new DropList.View.DropDown(model, options);
    this.dropdown.mouseOverListener = this.onDropDownMouseOver.bindAsEventListener(this);
    this.dropdown.clickListener = this.onDropDownClicked.bindAsEventListener(this);
    this.keydownListener = this.onDropDownKeydown.bindAsEventListener(this);
  },

  appendAction: function(action) {
    action.controller = this;
    this.actions.push(action);
  },

  getField: function() {
    return this.field.panel;
  },

  onDropLinkClicked: function(event) {
    this.dropdown.show(event);
    this.model.resetCursor();
    this.actions.each(function(action){
      Object.isFunction(action.onEvent) && action.onEvent('onDropLinkClicked', event);
    });
    this.dropdown.fixDimension();
    this.dropdown.scrollUnlessVisible();
    this._selectFilter();


    if(DropList.hideObserver != null) {
      DropList.hideObserver(event);
    }

    DropList.hideObserver = this.hideDropdown.bindAsEventListener(this);

    Event.observe(document, 'click', DropList.hideObserver);

    DropList.GlobalHotKeyController.disable();
    if(Prototype.Browser.Gecko) {
      Event.observe(this._filterInput() || document, 'keypress', this.keydownListener);
    } else {
      Event.observe(document, 'keydown', this.keydownListener);
    }
    Event.fire(document, 'mingle:droplink_clicked');
  },

  hideDropdown: function(event) {
    if(Prototype.Browser.Gecko) {
      Event.stopObserving(this._filterInput() || document, 'keypress', this.keydownListener);
    } else {
      Event.stopObserving(document, 'keydown', this.keydownListener);
    }
    DropList.GlobalHotKeyController.enable();

    Event.stopObserving(document, 'click', DropList.hideObserver);
    DropList.hideObserver = null;

    if(this._blurEvent(event)) {
        this.model.fireEvent('dropDownBlur');
    }

    this.dropdown.hide();
    this.model.clearFilter();
    this.model.resetAllOptions(); // bug #10607
    // change drop list back to default options if options changed by
    // ajax load options
    this.actions.invoke('reset');
  },

  _blurEvent: function(event) {
      if(event === undefined) {
          return false;
      }

      var isKeyEvent = (event.keyCode === Event.KEY_ESC || event.keyCode === Event.KEY_RETURN);
      var isClickEventNotToInvokeNewValue = event.element && !$j(event.element()).hasClass('inline-add-new-value');
      return isKeyEvent || isClickEventNotToInvokeNewValue;
  },


  _selectFilter: function(){
    var filterInput = this._filterInput();
    if(filterInput) {
      filterInput.focus();
      filterInput.select();
    }
  },

  _filterInput: function() {
    return this.dropdown.panel.down('.dropdown-options-filter');
  },


  onDropDownClicked: function(event) {
    var li = Event.element(event);
    if (!this._isListItemTag(li)) {
      li = li.up('li');
    }
    this.model.changeSelection(li.__option);

    // bug #14389 - in IE7 mode, there is no event capturing phase, only event bubbling
    // and something is preventing event propogation up the the document (CKEditor??).
    // thus, explicitly call our hide method on click.
    DropList.hideObserver && DropList.hideObserver(event);
  },

  onDropDownMouseOver: function(event) {
    if(this.dropdown.scrolling) { return; }

    var li = Event.element(event);
    if (!this._isListItemTag(li)) {
      return;
    }

    if(li.__option) {
      this.model.cursor.moveTo(li.__option);
    }
  },

  onDropDownKeydown: function(event) {
    if (event.keyCode == Event.KEY_ESC) {
      this.hideDropdown(event);
      Event.stop(event);
    }

    if(event.keyCode == Event.KEY_UP) {
      this.model.cursor.movePre();
      Event.stop(event);
    }

    if(event.keyCode == Event.KEY_DOWN) {
      this.model.cursor.moveNext();
      Event.stop(event);
    }

    if(event.keyCode == Event.KEY_RETURN) {
      if(this.model.cursor.option() !== null) {
        this.model.changeSelection(this.model.cursor.option());
        this.hideDropdown(event);
      } else if(this.supportInlineEdit && this.model.currentFilterValue !== null) {
         var value = $j.trim(this.model.currentFilterValue);
         var optionModel = new DropList.Option(value, value);
         this.model.addOption([value, value], true);
         this.model.changeSelection(optionModel);
         this.hideDropdown(event);
      }
      Event.stop(event);
    }
  },

  onFilterChanged: function(event) {
    this.dropdown.redraw(this.model);
  },

  render: function() {
    this.panel = $(this.dropLink.element.parentNode);
    if (this.panel.hasClassName('tree-drop-link-holder')) {
      this.panel = this.panel.parentNode;
    }
    this.dropLink.render(this.panel);
    this.field.render(this.panel);
    this.dropdown.render(this.dropLink.element);
    this.actions.invoke("render", this.dropLink.element, this.dropdown.panel);
  },

  _isListItemTag: function(tag) {
    return tag.tagName.toLowerCase() == 'li';
  }
});
