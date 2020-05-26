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
var AggregateGridDropdowns = Class.create();

AggregateGridDropdowns.prototype = {
  initialize: function(formId, typeId, propertyHiddenFieldId, aggregatePropertyDropLinkId) {
    this.form = $(formId);
    this.typeField = $(typeId);
    this.propertyDropdown = $(aggregatePropertyDropLinkId);
    this.propertyHiddenField = $(propertyHiddenFieldId);
  },

  initUI: function() {
    if (this.typeField.value == 'count') {
      this._disablePropertyDropdown();
    }
  },

  onTypeDropdownChange: function(event) {
    window.docLinkHandler.disableLinks();
    if (this.typeField.value == 'count') {
      this._submitCount();
    } else {
      this._enablePropertyDropdown();
      if (this.propertyHiddenField.value != '') {
        this._submit();
      }
    }
    window.docLinkHandler.enableLinks();
  },

  onPropertyDropdownChange: function(event) {
    window.docLinkHandler.disableLinks();
    this._submit();
  },

  _submitCount: function(){
    this._disablePropertyDropdown();
    this._submit();
  },

  _submit: function(){
    this.form.submit();
  },

  _enablePropertyDropdown: function() {
    this.propertyDropdown.show();
  },

  _disablePropertyDropdown: function() {
    this.propertyHiddenField.value = '';
    this.propertyDropdown.hide();
  }

};
