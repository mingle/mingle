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
if (typeof MacroBuilder === 'undefined') {
  MacroBuilder = {};
}

MacroBuilder.SeriesEditor = Class.create({
  initialize: function(macroType, seriesNumber, seriesParamDefs) {
    this.macroType = macroType;
    this.seriesNumber = seriesNumber;
    this.seriesParamDefs = seriesParamDefs;
    this.seriesElement = $(this.macroType + '_series-container-' + this.seriesNumber);
  },
  
  show: function(){
    this._toggleParameterInputDisplay();
    this._addAdditionalOptionalParameterElement();
    this.seriesElement.show();
  },
  
  _inputFields: function(){
    return $(this.seriesElement).select('.parameter-input');
  },
  
  _inputContainerForParameter: function(parameterName){
    return this._inputFields().detect(function(inputContainer){
      return this._extractParameterNameFrom(inputContainer) == parameterName;
    }.bind(this));
  },
  
  _visibleInputFields: function(){
    return this._inputFields().select(Element.visible);
  },
  
  _lastVisibleParameter: function(){
    return this._visibleInputFields().last();
  },
  
  _addAdditionalOptionalParameterElement: function(){
    var additionalOptionalParameterElement = $(this.macroType + '_series_' + this.seriesNumber + '_optional_parameter_dropdown_container');
    var elementToInsertAddAfter = this._elementToInsertAddAfter();
    if (!elementToInsertAddAfter){
      return;
    }
    elementToInsertAddAfter.insert({after: additionalOptionalParameterElement});
    this._setupOptionalParameterDroplist();
    additionalOptionalParameterElement.show();
    // setTimeout is for damned IE, need to wait additionalOptionalParameterElement rendering on IE
    setTimeout(function(){
      this._setupRemoveButtonForSiblingsOf(additionalOptionalParameterElement);
    }.bind(this), 5);
  },
  
  _setupRemoveButtonForSiblingsOf: function(additionalOptionalParameterElement) {
    var visibleSiblingParameters = additionalOptionalParameterElement.up('div').select('.parameter-input').findAll(function(element){
      return element.visible();
    });
    
    if(visibleSiblingParameters.size() == 1){
      var removeButton = this._getRemoveButtonFor(visibleSiblingParameters.first());
      removeButton && removeButton.hide();
    } else {
      visibleSiblingParameters.each(function(parameterContainerElement){
        var removeButton = this._getRemoveButtonFor(parameterContainerElement);
        removeButton && removeButton.show();
      }, this);
    }
  },
  
  _getRemoveButtonFor: function(parameterContainerElement){
    if(parameterContainerElement._removeButton){
      return parameterContainerElement._removeButton;
    } else {
      var removeButton = parameterContainerElement.select('.remove-optional-parameter').first();
      parameterContainerElement._removeButton = removeButton;
      return removeButton;
    }
  },
  
  _elementToInsertAddAfter: function(){
    var lastVisibleParameter = this._lastVisibleParameter();
    if (!lastVisibleParameter){
      return;
    }
    return lastVisibleParameter.select('.input_editor_type_wrapper').last();
  },
  
  _extractParameterNameFrom: function(inputContainer){
    return inputContainer.id.match(this._inputContainerIdPattern())[1];
  }, 

  _inputContainerIdPattern: function(){
    return new RegExp(this.macroType + '_series_' + this.seriesNumber + '_(.*)_' + 'parameter');
  },
  
  _toggleParameterInputDisplay: function(){
    this.seriesElement.select('.parameter-input').each(function(inputContainer) {
      if (this._isInitiallyVisible(this._extractParameterNameFrom(inputContainer))){
        this._showInputContainer(inputContainer);
      } else {
        inputContainer.hide();
      }
    }, this);
  },
  
  _showInputContainer: function(inputContainer) {
    inputContainer.show();
    this._setRadioButtonsToDefaultOrInitialValue(inputContainer);
    this._setColourParameterToDefaultOrInitialValue(inputContainer);
  },
  
  _setRadioButtonsToDefaultOrInitialValue: function(inputContainer) {
    var paramDef = this._detectParamDefNamed(this._extractParameterNameFrom(inputContainer));
    if (paramDef['default'] == null && paramDef.initial_value == null) {
      return;
    }
    var initialValue = this._getInitialValue(paramDef);
    inputContainer.select('input[type=radio]').each(function(radioButton) {
      radioButton.checked = (radioButton.value.toString() == initialValue.toString());
    });
  },
  
  _setColourParameterToDefaultOrInitialValue: function(inputContainer) {
    var formTextField = inputContainer.select('input.selected_value').first();
    if (formTextField == null) {return;}
    var paramDef = this._detectParamDefNamed(this._extractParameterNameFrom(inputContainer));
    if (paramDef['default'] == null && paramDef.initial_value == null) {
      return;
    }
    var initialValue = this._getInitialValue(paramDef);
    inputContainer.select('input.selected_value').first().value = initialValue;
    inputContainer.select('.color_block').first().setStyle({ 'backgroundColor': initialValue });
  },
  
  _getInitialValue: function(paramDef) {
    if (paramDef.initial_value != null) {
      return paramDef.initial_value;
    } else {
      return paramDef['default'];
    }
  },
  
  _isInitiallyVisible: function(parameterName){
    var paramDef = this._detectParamDefNamed(parameterName);
    return (paramDef != null) ? paramDef['initially_shown'] : false;
  },

  _detectParamDefNamed: function(paramName){
    return this.seriesParamDefs.detect(function(paramDefDetails) {
      if (paramDefDetails.name == paramName){
        return paramDefDetails;
      }
    });
  },
  
  _parameterNamesAvailableForAddition: function(){
    var parameterDefinitionsAvailableForAddition = this.seriesParamDefs.reject(function(paramDefintion) { 
       return paramDefintion.required || this._isCurrentlyUsed(paramDefintion);
    }, this);
    return parameterDefinitionsAvailableForAddition.collect(function(parameterDefintion) { 
      return parameterDefintion.name;
    });
  },
  
  _setupOptionalParameterDroplist: function() {
    var dropdownOptions = this._parameterNamesAvailableForAddition().collect(function(name){
      return [name, name];
    });
    if (this.optionalParameterDroplist){
      this.optionalParameterDroplist.replaceOptions(dropdownOptions, ['+', '']);
    } else {
      var options = {
              selectOptions: dropdownOptions,
              numeric: false,
              initialSelected: ['+', ''],
              htmlIdPrefix: this.macroType + '_series_' + this.seriesNumber + '_optional_parameter',
              dropLinkStyle: 'optional-parameter-add-button',
              onchange: this._showOptionalParameterFor.bind(this),
              position: 'left',
              macroEditor: true
            };
      this.optionalParameterDroplist = new DropList(options);
    }
    this._toggleAddOptionalParameterButton(dropdownOptions);
  },
  
  _toggleAddOptionalParameterButton: function(availableOptionalParameters){
    var editPanel = $(this.macroType + '_series-container-' + this.seriesNumber);
    if (availableOptionalParameters.size() == 0){
      editPanel.select('.optional-parameter-add-button').first().hide();
    } else {
      editPanel.select('.optional-parameter-add-button').first().show();
    }
  },
  
  _showOptionalParameterFor: function(parameter){
    if (!parameter.value.blank()){
      var editPanel = $(this.macroType + '_series-container-' + this.seriesNumber);
      var optionalParameterToDisplay = editPanel.select('.parameter-input').detect(function(inputContainer){
        return this._extractParameterNameFrom(inputContainer) == parameter.name;
      }, this);
      var elementToAddTo = optionalParameterToDisplay.up('.series-content');
      var elementToAdd = optionalParameterToDisplay.remove();
      elementToAddTo.appendChild(elementToAdd);
      this._showInputContainer(optionalParameterToDisplay);
      this._addAdditionalOptionalParameterElement();
    }
  },
  
  _isCurrentlyUsed: function(parameterDefintion) {
    return this._inputContainerForParameter(parameterDefintion.name).visible();
  }  
});