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
var MacroBuilder = Class.create({
  initialize: function(editor, macroType, macroDefDetails, addNewSeriesUrl, ajaxServer) {
    this.macroType = macroType;
    this.macroDefDetails = macroDefDetails;
    this.seriesEditor = this._createSeriesEditors(editor, macroType, macroDefDetails, addNewSeriesUrl, ajaxServer);
    this._attach(editor);
    this.currentlyDisplayedParameterDefinitionIds = $A();
  },

  _attach: function(editor) {
    this.element = $(editor);
    this.macroEditPanel = $(this.macroType + '_macro_panel');
    this.optionalParameterDroplistOf = $H();
    this.element.observe('optional-parameter:remove', this._hideOptionalParameter.bindAsEventListener(this));
  },

  _createSeriesEditors: function(editor, macroType, macroDefDetails, addNewSeriesUrl, ajaxServer) {
    return new MacroBuilder.SeriesEditors(editor, macroType, macroDefDetails[macroType + "-series"], addNewSeriesUrl, ajaxServer);
  },

  detach: function(){
    Event.stopObserving('data-series-chart_macro_panel');
    Event.stopObserving('stack-bar-chart_macro_panel');
    $$('.series-container').each(function(addedNode){
        addedNode.remove();
    });
    this.element.select('.remove-optional-parameter').each(function(removeOptionalParameterButton){
      Event.stopObserving(removeOptionalParameterButton);
    });
  },

  _parameterNamesAvailableForAdditionTo: function(macroType){
    var currentMacroParameterDefinitions = this.macroDefDetails[macroType];

    var parameterDefinitionsAvailableForAddition = currentMacroParameterDefinitions.reject(function(paramDefintion) {
      return paramDefintion.required || this._isCurrentlyUsed(macroType, paramDefintion);
    }, this);

    return parameterDefinitionsAvailableForAddition.collect(function(parameterDefintion) {
      return parameterDefintion.name;
    });
  },

  _setupOptionalParameterDroplistFor: function(chartName) {
    var dropdownOptions = this._parameterNamesAvailableForAdditionTo(chartName).collect(function(name){
      return [name, name];
    });
    if (this.optionalParameterDroplistOf[chartName]){
      var theDroplist = this.optionalParameterDroplistOf[chartName];
      theDroplist.replaceOptions(dropdownOptions, ['+', '']);
    } else {
      var options = {
              selectOptions: dropdownOptions,
              numeric: false,
              initialSelected: ['+', ''],
              htmlIdPrefix: chartName + '_optional_parameter',
              dropLinkStyle: 'optional-parameter-add-button',
              onchange: this._showOptionalParameterFor.bind(this),
              position: 'left',
              macroEditor: true
            };
      this.optionalParameterDroplistOf[chartName] = new DropList(options);
    }
    this._toggleAddOptionalParameterButton(dropdownOptions);
  },

  _toggleAddOptionalParameterButton: function(availableOptionalParameters){
    if (availableOptionalParameters.size() == 0){
      this.correspondingEditPanel().select('.optional-parameter-add-button').first().hide();
    } else {
      this.correspondingEditPanel().select('.optional-parameter-add-button').first().show();
    }
  },

  _showOptionalParameterFor: function(parameter){
    if (!parameter.value.blank()){
      var optionalParameterToDisplay = this.correspondingEditPanel().select('.parameter-input').detect(function(inputContainer){
        return this._extractParameterNameFrom(inputContainer) == parameter.name;
      }, this);
      if (!optionalParameterToDisplay){
        return;
      }
      var elementToAddTo = optionalParameterToDisplay.up('.chart-editor');
      var elementToAdd = optionalParameterToDisplay.remove();
      elementToAddTo.appendChild(elementToAdd);
      this._showInputContainer(optionalParameterToDisplay);
      this._setupRemoveButtonForSiblingsOf(optionalParameterToDisplay);
      this._addAdditionalOptionalParameterElement();
    }
  },

  _isCurrentlyUsed: function(macroType, parameterDefintion) {
    return this.currentlyDisplayedParameterDefinitionIds.include(macroType + '_' + parameterDefintion.name + '_parameter');
  },

  correspondingEditPanel: function() {
    return $(this.macroType + '_macro_panel');
  },

  show: function() {
    this.macroEditPanel.hide();
    this.correspondingEditPanel().show();
    this.seriesEditor.createInitialSeriesContainers();
    this.focusFirstTextInput();
    this.element.show();
    this._toggleParameterInputDisplay(this.correspondingEditPanel());
    this._addAdditionalOptionalParameterElement();
  },

  scrollToPreview: function() {
    var preview = this.element.select('.preview-panel-container').first();
    var pos = preview.cumulativeOffset();
    this.element.scrollTop = pos.top;
  },

  _addAdditionalOptionalParameterElement: function(){
    var additionalOptionalParameterElement = $(this.macroType + '_optional_parameter_dropdown_container');
    var elementToInsertAddAfter = this._elementToInsertAddAfter();
    if (!elementToInsertAddAfter){
      return;
    }
    additionalOptionalParameterElement.remove();
    elementToInsertAddAfter.insert({after: additionalOptionalParameterElement});
    this._setupOptionalParameterDroplistFor(this.macroType);
    additionalOptionalParameterElement.show();
  },

  _elementToInsertAddAfter: function(){
    var lastVisibleParameter = this._lastVisibleParameter();
    if (!lastVisibleParameter){
      return;
    }
    return lastVisibleParameter.select('.input_editor_type_wrapper').last();
  },

  _lastVisibleParameter: function(){
    var allParameterInputs = this.correspondingEditPanel().select('.chart-editor .parameter-input');
    return allParameterInputs.reverse().detect(function(parameterInput) {
      return parameterInput.visible();
    });
  },

  _hideOptionalParameter: function(event){
    var hideButton = $(event.target);
    var parameter = hideButton.up('p');
    this._hideInputContainer(parameter);
    this._setupRemoveButtonForSiblingsOf(parameter);
    parameter.select('input[type=text]').each(function(input){
      input.value = '';
    });

    this._addAdditionalOptionalParameterElement();
    this.seriesEditor.addAdditionalOptionalParameterElements();
  },

  _setupRemoveButtonForSiblingsOf: function(parameter){
    if(!this._getRemoveButtonFor) {
      return;
    }
    var visibleSiblingParameters = parameter.up('div').select('.parameter-input').findAll(function(element){
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

  _toggleParameterInputDisplay: function(ancestor){
    ancestor.select('.parameter-input').each(function(inputContainer) {
      var paramName = this._extractParameterNameFrom(inputContainer);
      if (this._isInitiallyVisible(this.macroType, paramName)){
        this._showInputContainer(inputContainer);
      } else {
        this._hideInputContainer(inputContainer);
      }
    }, this);
  },

  _showInputContainer: function(inputContainer) {
    this.currentlyDisplayedParameterDefinitionIds.push(inputContainer.id);
    inputContainer.show();
    this._setRadioButtonsToDefaultOrInitialValue(inputContainer);
    this._setColourParameterToDefaultOrInitialValue(inputContainer);
  },

  _hideInputContainer: function(inputContainer) {
    this.currentlyDisplayedParameterDefinitionIds = this.currentlyDisplayedParameterDefinitionIds.without(inputContainer.id);
    var paramDef = this._getParamDef(this.macroType, this._extractParameterNameFrom(inputContainer));
    inputContainer.select('input[type=radio]').each(function(radioButton) {
      radioButton.checked = false;
    });
    inputContainer.hide();
  },

  _setRadioButtonsToDefaultOrInitialValue: function(inputContainer) {
    var paramDef = this._getParamDef(this.macroType, this._extractParameterNameFrom(inputContainer));
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
    var paramDef = this._getParamDef(this.macroType, this._extractParameterNameFrom(inputContainer));
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

  _isInitiallyVisible: function(macroName, parameterName){
    var paramDef = this._getParamDef(macroName, parameterName);
    return (paramDef != null) ? paramDef['initially_shown'] : false;
  },

  _getParamDef: function(macroName, parameterName) {
    var paramDef = null;
    if (parameterName.startsWith('series')){
      var realParamName = parameterName.match(new RegExp('series_(\\d)+_(.*)'))[2];
      paramDef = this._detectParamDefNamed(macroName + '-series', realParamName);
    } else {
      paramDef = this._detectParamDefNamed(macroName, parameterName);
    }
    return paramDef;
  },

  _detectParamDefNamed: function(macroName, paramName){
    return this.macroDefDetails[macroName].detect(function(paramDefDetails) {
      if (paramDefDetails.name == paramName){
        return paramDefDetails;
      }
    });
  },

  _extractParameterNameFrom: function(inputContainer){
    return inputContainer.id.match(this._inputContainerIdPattern())[1];
  },

  _inputContainerIdPattern: function(){
    return new RegExp(this.macroType + '_(.*)_' + 'parameter');
  },

  focusFirstTextInput: function() {
    var firstInput = this.correspondingEditPanel().select("input[type=text]").first();
    if(firstInput) {
      setTimeout(function() {
        firstInput.focus();
      }, 10);
    }
  }
});
