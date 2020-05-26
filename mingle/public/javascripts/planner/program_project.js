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
var ProgramProject = Class.create({
  initialize: function(program_project_path){
    this.program_project_path = program_project_path;
    this.status_values = $('program_project_done_status');
  },
  
  updateDoneStatusPropertyValues: function(propertyName) {
   var url = this.program_project_path + '/property_values_and_associations?property_name=' + encodeURIComponent(propertyName);
   new Ajax.Request(url, {
     method: 'get',
     onSuccess: this.updatePropertyValues.bind(this)
    });
  },
  
  updatePropertyValues: function(response){
    this.setPropertyValues(response.responseJSON.values);
    this.showAssociatedCardTypes(response.responseJSON.card_types);
    this.disableSaveButton(response.responseJSON.values, response.responseJSON.card_types);
  },

  setPropertyValues: function(values) {
    this.clearValues();
    this.setValues(values);
  },

  disableSaveButton: function(values, card_types) { 
	var saveButton = $('program_project_submit');
    saveButton.disabled = this.isEmpty(values) || this.isEmpty(card_types);
  },

  showAssociatedCardTypes: function(cardTypes) {
    var cardTypeMessage = 'No card types are associated with the selected property.';
    if (cardTypes.size() > 0) {
      cardTypeMessage = (cardTypes.size() > 1 ? 
              'The card types tracked by this definition are: ' : 
              'The card type tracked by this definition is: ' ) + 
              '<b>' + cardTypes.join(', ') +  '</b>';
    }
    
    $('card_types').innerHTML = cardTypeMessage;
  },

  isEmpty: function(collection){
    return collection.size() < 1;
  },

  clearValues: function(){
    this.status_values.descendants().each(Element.remove);     
  },

  setValues: function(values){
    values.each(this.addValue.bind(this));
    var valuesEmpty = this.isEmpty(values);    
    if(valuesEmpty) {
      this.addValue('No Values Defined', 0);
    }
  },

  addValue: function(value, index) {
    var opt = document.createElement('option');
    opt.value = value;
    opt.innerHTML = value;
    this.status_values.appendChild(opt);
  }
});
  
  