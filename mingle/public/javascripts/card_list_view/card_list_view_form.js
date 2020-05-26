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
var CardListViewForm = Class.create(ParamsChangeListener, {
  onParamsUpdate: function(params) {
    this.generatedInputs().each(Element.remove);
    params.each(this.createHiddenInput.bind(this));
  },
  
  createHiddenInput: function(pair) {
    var hiddenInput = new Element('input', {'type': 'hidden', 'name': pair[0], 'value': pair[1].toString(), 'generator': this});
    this.element.appendChild(hiddenInput);
  },
  
  generatedInputs: function() {
    return this.element.childElements().select(function(element){
      return element.readAttribute('generator') == this;
    }.bind(this));
  }
});

