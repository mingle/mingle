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
DropList.InlineEditAction = Class.create({

  initialize: function(model, basicController, inlineAddOptionActionTitle, options) {
    this.basicController = basicController;
    this.model = model;
    this.inlineEditor = new DropList.View.InlineEditor(this.model, options, inlineAddOptionActionTitle);
    this.inlineEditor.mouseOverListener = this.onInlineEditorOptionMouseOver.bindAsEventListener(this);
    this.inlineEditor.blurListener = this.onInlineEditorBlur.bindAsEventListener(this);
    this.inlineEditor.clickListener = this.onInlineEditorOptionClick.bindAsEventListener(this);
    this.inlineEditor.keyPressListener = $j.proxy(this.onInlineEditorKeyPress, this);

    if(options.allowBlank != null) {
      this.allowBlank = options.allowBlank;
    } else {
      this.allowBlank = true;
    }
  },

  onInlineEditorOptionMouseOver: function(event) {
    this.basicController.onDropDownMouseOver(event);
  },

  onInlineEditorKeyPress: function(event) {
    var isEnterKeypressEvent = $j.ui.keyCode.ENTER === event.which;
    if(!isEnterKeypressEvent) {return;}

    var element = event.target;

    event.preventDefault();
    event.stopPropagation();

    var value = $j.trim(element.value);
    if(!this.allowBlank && "" === value) { return;}

    var optionModel = new DropList.Option(value, value);
    this.model.addOption([value, value], true);
    this.model.changeSelection(optionModel);
    this.model.clearFilter();
    this.inlineEditor.clear();
    this.inlineEditor.close(this.basicController.panel, this.basicController.dropLink.element);
    DropList.View.Layout.refix();
  },

  onInlineEditorBlur: function(event) {
    this.inlineEditor.clear();
    this.model.clearFilter();
    this.inlineEditor.close(this.basicController.panel, this.basicController.dropLink.element);
    DropList.View.Layout.refix();
    this.model.fireEvent('dropDownBlur');
    Event.stop(event);
  },

  onInlineEditorOptionClick: function(event) {
    this.inlineEditor.show(this.basicController.panel, this.basicController.dropLink.element);
  },

  render: function(dropLinkElement, dropdownPanel) {
    this.inlineEditor.render(dropLinkElement, dropdownPanel);
  },

  reset: function() {
  }
});
