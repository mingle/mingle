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
DropList.View.InlineEditor = Class.create({

  initialize: function(model, options, inlineAddOptionActionTitle) {
    this.model = model;
    this.options = options;
    this.inlineAddOptionActionTitle = inlineAddOptionActionTitle || "New value...";
    this.mouseOverListener = Prototype.emptyFunction;
    this.clickListener = Prototype.emptyFunction;
    this.blurListener = Prototype.emptyFunction;
    this.keyPressListener = Prototype.emptyFunction;
  },

  render: function(dropLinkPanel, dropdownPanel) {
    var htmlId = this.options.generateId('action_adding_value');
    var newValueOptionContainer = new Element('ul');
    newValueOptionContainer.addClassName('inline-add-new-value-container');
    var inlineAddNewValueOption = new Element('li', {id: htmlId});
    inlineAddNewValueOption.addClassName('inline-add-new-value');
    inlineAddNewValueOption.innerHTML = this.inlineAddOptionActionTitle;
    newValueOptionContainer.appendChild(inlineAddNewValueOption);
    dropdownPanel.panelElement.insertBefore(newValueOptionContainer, dropdownPanel.panelElement.firstChild);
    dropdownPanel._newValueOptionContainer = newValueOptionContainer;
    this.dropLinkPanel = dropLinkPanel;
    Event.observe(inlineAddNewValueOption, 'click', this.clickListener);
    Event.observe(inlineAddNewValueOption, 'mouseover', this.mouseOverListener);

    this.editor = new Element('input', {id: this.options.generateId('inline_editor'), type: 'text'});
    this.editor.addClassName('inline-editor');
    $j(this.editor).keypress(this.keyPressListener);
    Event.observe(this.editor, 'blur', this.blurListener);
  },

  clear: function() {
    this.editor.value = '';
  },

  show: function(container, replacing) {
    var scrollOffset = Element.cumulativeScrollOffset(this.dropLinkPanel);
    Position.clone(this.dropLinkPanel, this.editor, {setWidth: true, setHeight: false, offsetTop: scrollOffset.top, offsetLeft: scrollOffset.left });
    container.replaceChild(this.editor, replacing);
    this.editor.setValue(this.model.currentFilterValue);
    this.editor.focus();
    this.editor.select();
  },

  close: function(container, replacing) {
    try {
      container.replaceChild(replacing, this.editor);
    }catch(e) {
      // safari3 throw an error, even the node has been replaced.
    }
  }
});
