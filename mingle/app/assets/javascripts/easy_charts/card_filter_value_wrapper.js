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
var MingleUI = (MingleUI || {});
MingleUI.EasyCharts = (MingleUI.EasyCharts || {});

(function ($) {
  var NOT_SET_OPTION = ['(not set)', 'null'], THIS_CARD_OPTION = 'THIS CARD';

  function CardFilterValueWrapper(container, identifier, options) {
    var valueIdentifier = identifier + '_value', valueDropDown, self = this, propertyDefinition = options.propertyDefinition,
        name = valueIdentifier.toCamelCase(), accessibilityActionActive = false, _showRelativeValues = options.showRelativeValues,
        initialValue = '', valueInput, dynamicValueOptions = {}, cardTypeNameField = $('#card_type_name_field'),
        currentCardTypeName = cardTypeNameField.length ? cardTypeNameField.val() : '',
        onValueChange = typeof options.onValueChange === 'function' ? options.onValueChange : undefined;

    function shouldAddThisCard() {
      return options.enableThisCardOption && propertyDefinition.dataType === 'card' && _showRelativeValues && currentCardTypeName &&
          [undefined, currentCardTypeName].include(propertyDefinition.validCardTypeName);
    }

    function allowedValues() {
      var propertyValues = [];
      if (propertyDefinition) {
        if (propertyDefinition.nullable && _showRelativeValues) propertyValues.push(NOT_SET_OPTION);

        shouldAddThisCard() && propertyValues.push(THIS_CARD_OPTION);

        if (!options.disableProjectVariables) {
          $A(propertyDefinition.projectLevelVariableOptions).each(function (plv) {
            propertyValues.push(plv);
          });
        }

        $A(propertyDefinition.propertyValueDetails).each(function (propertyValueDetail) {
          propertyValues.push(propertyValueDetail.value);
        });
      }
      return propertyValues;
    }

    function ensureValueDropDown() {
      var valueOptions = allowedValues().concat(Object.values(dynamicValueOptions));
      if (valueDropDown && valueDropDown instanceof MingleUI.DropDown) {
        valueDropDown.isMultiSelect = _showRelativeValues;
        valueDropDown.updateOptions(valueOptions, initialValue);
        valueDropDown.htmlContainer.show();
        container.find('input[type=text]').hide();
        accessibilityActionActive = false;
      } else {
        valueDropDown = new MingleUI.DropDown(name, self.htmlContainer, valueOptions, {
          initialValue: options.initialValues || initialValue, multiSelect: _showRelativeValues,
          defaultOption: '(any)', onValueChange: onValueChange, disabled: options.disabled
        });
      }
    }

    function addDynamicValueOption(optionDisplay, optionValue, keepOptionsOpen, silently) {
      valueDropDown.addOption(optionDisplay, optionValue, true, keepOptionsOpen, silently);
      dynamicValueOptions[optionValue] = dynamicValueOptions[optionValue] || [optionDisplay, optionValue];
    }

    function setupCalendar(triggerElement) {
      Calendar.setup({
        daFormat: options.project.dateFormat,
        button: triggerElement,
        align: "Br",
        electric: false,
        showOthers: true,
        weekNumbers: false,
        firstDayOfWeek: 0,
        showAtElement: self.htmlContainer[0],
        onUpdate: function (calendar) {
          var selectedDate = calendar.date.print(options.project.dateFormat);
          var selectedDateValue = calendar.date.print('%d-%m-%Y');
          addDynamicValueOption(selectedDate, selectedDateValue, true);
        },
        cache: true
      });
    }

    function addAccessibilityAction() {
      var type = propertyDefinition.dataType;
      var accessibilityOption = {};
      switch(type) {
        case 'date':
          accessibilityOption = new DropDownAccessibilityOption('Select a date', function () {
            $('.calendar').scrollintoview({direction: 'vertical'});
          }, { setup: setupCalendar, class: type } );
          break;
        case 'user':
        case 'card':
          accessibilityOption = new DropDownAccessibilityOption('Select a {type}'.supplant({type: type}), initSelector, {class: type});
          break;
        case 'numeric':
        case 'string':
          accessibilityOption = new DropDownAccessibilityOption('Enter value', toggleTextBoxValue, {position: 'top', class: type});
          break;
      }
      valueDropDown.setAccessibilityOption(accessibilityOption);
    }

    function updateTextValue(textBox, textValue) {
      addDynamicValueOption(textValue, textValue, false);
      toggleTextBoxValue();
    }

    function toggleTextBoxValue() {
      setupTextBoxValue();
      var inputBox = container.find('input[type=text]');
      inputBox.toggle();
      container.find('.accessibility-action').toggle();
      valueDropDown.htmlContainer.toggle();
      if (inputBox.is(':visible')) {
        valueInput.reset();
        inputBox.focus();
        accessibilityActionActive = true;
      } else {
        accessibilityActionActive = false;
      }
    }

    function setupTextBoxValue() {
      if (!valueInput) {
        container.prepend($('<input>', {type: 'text', name: name}));
        valueInput = new MingleUI.TextBox(container, {
          numeric: propertyDefinition.isNumeric, multiValued: false,
          onValueChange: updateTextValue, onCancel: toggleTextBoxValue,
          name: name, placeholder: 'value'
        });
        container.find('input[type=text]').hide();
      }
    }

    function initSelector() {
      if (!accessibilityActionActive) {
        accessibilityActionActive = true;
        $.ajax({
          url: isUserProperty() ? UrlHelper.showUserSelectorUrl(options.project.identifier) : UrlHelper.showCardSelectorUrl(options.project.identifier),
          dataType: "script",
          data: selectorParams(),
          type: 'GET',
          beforeSend: function () {
            InputingContexts.push(new LightboxInputingContext(function (selectedOption) {
              addDynamicValueOption(selectedOption.name, selectedOption.value, true);
            }, {closeOnBlur: true, contentStyles: {zIndex: 2220000}, afterDestroy: function() { accessibilityActionActive = false; }}));
          },
          error: function () { InputingContexts.pop(); }
        });
      }
    }

    function isUserProperty() {
      return propertyDefinition && propertyDefinition.dataType === 'user';
    }

    function selectorParams() {
      return isUserProperty() ?
          {property_definition_name: propertyDefinition.name, action_type: 'filter'} :
          {card_selector: {title: 'Select card for ' + propertyDefinition.name,
                           context_mql: propertyDefinition.cardSelectorFilterValuesMql,
                           search_context: propertyDefinition.cardSelectorFilterValuesSearchContext,
                           card_result_attribute: 'number'}};
    }

    function addInitialValues () {
      (options.initialValues || []).each(function (initialValue) {
        addDynamicValueOption(initialValue[0], initialValue[1], false, true);
      });
    }

    function updateValueOptions() {
      container.find('.accessibility-action').remove();
      ensureValueDropDown();
      if(propertyDefinition && !propertyDefinition.isManaged) {
        switch (propertyDefinition.dataType) {
          case 'date':
          case 'card':
          case 'numeric':
          case 'string':
          case 'user': addAccessibilityAction();
                       addInitialValues();
                       break;
        }
      }
    }

    this.htmlContainer = container.find('div#' + valueIdentifier);
    updateValueOptions();

    this.value = function () {
      var values = valueDropDown.value();
      values = values && values.constructor === Array ? values : new Array(values);
      return values.filter(function (value) { return !!value; });
    };

    this.update = function (propertyDef, showRelativeValues) {
      propertyDefinition = propertyDef;
      _showRelativeValues = showRelativeValues || true;
      dynamicValueOptions = {};
      updateValueOptions();
    };

    this.isValid = function () {
      return valueDropDown.hasValue();
    };

    this.hideRelativeValues = function () {
      if (!_showRelativeValues) return;
      _showRelativeValues = false;
      var values = self.value();
      initialValue = values[0] === NOT_SET_OPTION[1] ? values[1] : values[0];
      updateValueOptions();
    };

    this.showRelativeValues = function () {
      if (_showRelativeValues) return;
      _showRelativeValues = true;
      initialValue = self.value()[0];
      updateValueOptions();
    };
    this.enable = function(){
      valueDropDown.enable();
    };
  }

  MingleUI.EasyCharts.CardFilterValueWrapper = CardFilterValueWrapper;
})(jQuery);