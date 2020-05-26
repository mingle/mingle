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

var TransitionWorkflowGenerator = Class.create({
  
  initialize : function(cardTypeSelectElementId, propertyDefinitionSelectElementId, previewContainerId, spinnerElementId, generateTransitionsSelector, cancelGenerateSelector, cardTypeProperties, options) {
    this.cardTypeSelectElement = $(cardTypeSelectElementId);
    this.propertyDefinitionSelectElement = $(propertyDefinitionSelectElementId);
    this.previewContainer = $(previewContainerId);
    this.spinner = $(spinnerElementId);
    this.generateTransitionsElements = $$(generateTransitionsSelector);
    this.cancelGenerateElements = $$(cancelGenerateSelector);
    this.flash = $('flash');
    this.cardTypeProperties = cardTypeProperties;
    this.options = options;
    
    this.cardTypeSelectElement.observe('change', this.onCardTypeChange.bindAsEventListener(this));
    this.propertyDefinitionSelectElement.observe('change', this.onPropertyChange.bindAsEventListener(this));
    this.propertyDefinitionSelectElement.disable();
    this.disableGenerateTransitions();
    this._setupCancelParameters();
	this.onCardTypeChange();
  },
  
  onCardTypeChange : function(event) {
    this._clearPropertyDefinitions();
    this._clearPreviewContainer();
    this.disableGenerateTransitions();
    
    if (this.cardTypeSelectElement.value.blank()) {
      this.propertyDefinitionSelectElement.disable();
    }
    else {
      this.propertyDefinitionSelectElement.enable();
    }
    
    var properties = this.cardTypeProperties[this.cardTypeSelectElement.value];
    if (properties) {
      properties.each(function(property, index) {
        this.propertyDefinitionSelectElement.options[index + 1] = new Option(property.name, property.id);
      }.bind(this));
    }
  },
  
  onPropertyChange : function(event) {
    if (this.propertyDefinitionSelectElement.value.blank()) {
      this.disableGenerateTransitions();
      this._clearPreviewContainer();
    }
    else {
      this._remoteCall(this.options['previewUrl'] , { evalJS     : true,
                                                      parameters : this._form().serialize(),
                                                      method     : 'get',
                                                      onCreate   : function(request) { this.spinner.show(); }.bind(this),
                                                      onComplete : function(request) { this.spinner.hide(); }.bind(this) });
    }
  },

  enableGenerateTransitions : function() {
    this.generateTransitionsElements.each(function(element) {
      element.writeAttribute('href', this._returnUrl());
      element.removeClassName('disabled');
      element.observe('click', function(event) { this._submitForm(); event.preventDefault(); }.bind(this));
    }, this);
  },
  
  disableGenerateTransitions : function() {
    this.generateTransitionsElements.each(function(element) {
      element.writeAttribute('href', null);
      element.addClassName('disabled');
      element.stopObserving('click');
    }, this);
  },
  
  _returnUrl : function() {
    return this.options['returnUrl'] + '?' + Transition.buildFilterParams($H({ card_type_id : this.cardTypeSelectElement.value, property_definition_id : this.propertyDefinitionSelectElement.value }));
  },
  
  _form : function() {
    return $(this.cardTypeSelectElement.form);
  },
  
  _submitForm : function() {
    this._form().submit();
  },
  
  _clearPropertyDefinitions : function() {
    this.propertyDefinitionSelectElement.update('');
    this.propertyDefinitionSelectElement.options[0] = new Option(this.options['prompt'], '');
  },
  
  _clearPreviewContainer : function() {
    this.previewContainer.update();
    this.flash.update();
  },
  
  _setupCancelParameters: function() {
    this.cancelGenerateElements.each(function(element) {
      element.observe('click', function(event) {
        event.element().writeAttribute('href', this._returnUrl());
      }.bind(this));
    }, this);
  },
  
  _remoteCall: function(url, ajaxOptions) {
    new Ajax.Request(url, ajaxOptions);
  }
  
});