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
CheckboxController = Class.create({
  initialize: function(actionLinks, checkboxes, id_postfix) {
    this.checkboxes = checkboxes;
    this.actionLinks = actionLinks;
    id_postfix = id_postfix ? id_postfix : '';
    var selectAllLink = $('select_all'+id_postfix);
    // TODO: this part need to be cleaned after story #11951 played
    if (selectAllLink && checkboxes.empty()) {
      $('select_all').addClassName('disabled');
      $('select_none').addClassName('disabled');
    } else if (selectAllLink) {
      $('select_all'+id_postfix).observe('click', this._onSelectAll.bindAsEventListener(this));
      $('select_none'+id_postfix).observe('click', this._onSelectNone.bindAsEventListener(this));
      this.checkboxes.each(function(checkbox) {
        checkbox.observe('click', this._onUpdateOperationStatus.bindAsEventListener(this));
      }.bind(this));
    }
    this._onUpdateOperationStatus();
  },
  
  _onUpdateOperationStatus: function(){
    this._anySelected() ?  this._enableLinks() : this._disableLinks();
  },
  
  _anySelected: function(){
    return this.checkboxes.any(function(checkbox) {
      return checkbox.checked;
    });
  },
  
  _onSelectAll: function(event) {
    this.checkboxes.each(function(checkbox){
      if(!checkbox.disabled) {
        checkbox.checked = true;
      }
    });
    this._onUpdateOperationStatus();
  },
  
  _onSelectNone: function(event) { 
    this.checkboxes.each(function(checkbox){
      if(!checkbox.disabled) {
        checkbox.checked = false;
      }
    });
    this._onUpdateOperationStatus();
  },
  
  _enableLinks: function() {
    this.actionLinks.each(function(actionLink){ 
      actionLink.removeClassName('disabled'); 
      if (actionLink.enable) {
        actionLink.enable();
      }
    });
  },
  
  _disableLinks: function(){
    this.actionLinks.each(function(actionLink){ 
      actionLink.addClassName('disabled');
      if (actionLink.disable) {
        actionLink.disable();
      }
    });
  }
  
});