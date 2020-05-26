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
ManageUsers = Class.create({
  initialize: function() {
    this.sortForm = $('user-sort');
    this.orderByField = $('order_by');
    this.directionField = $('direction');
    this._attachHeaderClickListeners($('users'));
  },
  
  onHeaderClick: function(event) {
    var target = Event.element(event);
    this._toggleDirection(target);
    this._ajaxRequest(target);
  },
  
  currentOrderBy: function() {
    return this.orderByField.value;
  },
  
  currentDirection: function() {
    return this.directionField.value;
  },
  
  _attachHeaderClickListeners: function(table){
    if (!table){
      return;
    }
    table.select('th span.sortable_column').each(function(element) {
      element.observe('click', this.onHeaderClick.bindAsEventListener(this));
    }, this);
  },
  
  _ajaxRequest: function(element) {
    new Ajax.Request(this.sortForm.action, {
      method: "get",
      parameters: this.sortForm.serialize(true)
    });
  },
  
  _toggleDirection: function(element) {
    if (this.orderByField.value != element.id) {
      this._setToAscending(element);
    }
    else if(this.directionField.value == "DESC") {
      this._setToAscending(element);
    }
    else {
      this._setToDescending(element);
    }
    this.orderByField.value = element.id;
  },
  
  _setToAscending: function(element) {
    this.directionField.value = 'ASC';
  },
  
  _setToDescending: function(element) {
    this.directionField.value = 'DESC';
  }
});
