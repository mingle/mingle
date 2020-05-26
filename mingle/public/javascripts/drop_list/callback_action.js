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
DropList.CallbackAction = Class.create(CallbackInterpreter, {
  initialize: function(title, callback) {
    this.controller = null;
    this.title = title;
    this.callback = this.interpretCallback(callback);
  },

  onEvent: function(eventType, domEvent){
    if(eventType == 'onDropLinkClicked'){
      this._onDropLinkClicked();
    }
  },

  _onDropLinkClicked: function(){
    this.optionsContainer.insert({bottom : this.optionElement});
  },

  onActionClicked: function(event) {
    InputingContexts.push(new LightboxInputingContext(this.onValueFeed.bind(this), {closeOnBlur: true}));
    this.callback();
  },

  onValueFeed: function(value) {
    this.controller.model.changeSelection(value);
  },

  render: function(dropLinkPanel, dropdownPanel) {
    this.optionElement = new Element('li');
    this.optionElement.addClassName('select-option');
    this.optionElement.addClassName('droplist-action-option');
    this.optionElement.update(this.title);
    this.optionElement.__option = [this.title, ''];
    this.optionsContainer = dropdownPanel.down('.options-only-container');
    dropdownPanel._CallbackAction_select_option = this.optionElement;
    Event.observe(this.optionElement, 'click', this.onActionClicked.bindAsEventListener(this));
    Event.observe(this.optionElement, 'mouseover', this.controller.onDropDownMouseOver.bindAsEventListener(this.controller));
  },

  reset: function() {
  }
});
