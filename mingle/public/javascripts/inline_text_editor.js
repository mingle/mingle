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
var InlineTextEditor = Class.create({
  initialize: function(formId, actionsWrapperId, allEditors) {
    this.inputForm = $(formId);
    this.actionsWrapper = $(actionsWrapperId);
    this.valueName = this.inputForm.down('span.name');
    this.updateMessage = this.inputForm.down('span.update_message');
    this.valueNameInput = this.inputForm.down('.inline-editor');
    this.editLink = this.actionsWrapper.down('.inline-edit-link');
    this.allEditors = allEditors;
    if (this.editLink) {
      this.saveLink = this.actionsWrapper.down('.inline-save-link');
      this.cancelLink = this.actionsWrapper.down('.inline-cancel-link');

      Event.observe(this.editLink, 'click', this._onEditLinkClick.bindAsEventListener(this));
      Event.observe(this.saveLink, 'click', this._onSaveLinkClick.bindAsEventListener(this));
      Event.observe(this.cancelLink, 'click', this._onCancelLinkClick.bindAsEventListener(this));
      $j(this.valueNameInput).keypress(this, this._onKeypress);
    }
  },
  
  onFailedUpdate: function() {
    this.updateMessage.hide();
    this._makeEditable();
  },
  
  onSuccessfulUpdate: function() {
    this.updateMessage.hide();
    this._makeNotEditable();
  },

  _onEditLinkClick: function() {
    if (this.allEditors) {
      this.allEditors.each(function (editor) {
        editor._makeNotEditable();
      });
    }
    
    this.valueNameInput.value = this.valueName.innerHTML.unescapeHTML();
    this._makeEditable();
  },

  _onSaveLinkClick: function() {
    InlineTextEditor.activeInstance = this;
    this.editLink.show();
    this.valueNameInput.hide();
    this._hideSaveAndCancel();
    this.updateMessage.show();
    if (this._isFormAjax()) {
      $('flash').update();
      this.inputForm.onsubmit();
    }
    else {
      this.inputForm.submit();
    }
  },
  
  _onCancelLinkClick: function() {
    $('flash').update();
    this._makeNotEditable();
  },
  
  _onKeypress: function(event) {
    var isEnterKeypressEvent = $j.ui.keyCode.ENTER === event.which;
    var editor = event.data;
    if (isEnterKeypressEvent) {
      editor._onSaveLinkClick();
      event.stopPropagation();
      event.preventDefault();
    }
  },
  
  _showSaveAndCancel: function() {
    this.saveLink.show();
    this.cancelLink.show();
  },
  
  _makeNotEditable: function() {
    this.editLink.show();
    this._hideSaveAndCancel();
    this.valueNameInput.hide();
    this.valueName.show();    
  },
  
  _makeEditable: function() {
    this.editLink.hide();
    this._showSaveAndCancel();
    this.valueNameInput.show();
    this.valueNameInput.focus();
    this.valueNameInput.select();
    this.valueName.hide();
  },
  
  _hideSaveAndCancel: function() {
    this.saveLink.hide();
    this.cancelLink.hide();
  },
  
  _isFormAjax: function() {
    return this.inputForm.onsubmit;
  }
});
  

