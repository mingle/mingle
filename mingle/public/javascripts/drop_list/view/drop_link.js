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
DropList.View.DropLink = Class.create({

  initialize: function(model, element, truncate) {
    model.observe('changeSelection',  this.setSelection.bind(this));
    this.clickListener = Prototype.emptyFunction;
    this.element = element;
    this.truncate = truncate;
  },

  render: function(parent) {
    Event.observe(this.element, 'click', this.clickListener);
    return this.element;
  },

  setSelection: function(selection) {
    var name = selection.name.wordWrap(13);
    if(this.truncate){
      name = name.truncate(this.truncate);
    }
    this.element.innerHTML = name.escapeHTML();
    this.element.title = selection.tooltip;
  },

  setPrompt: function(prompt) {
    this.element.innerHTML = prompt;
  }
});
