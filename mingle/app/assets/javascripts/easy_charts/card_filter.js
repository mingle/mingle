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
  var PART_CLASSES = {
    property: 'property',
    operator: 'operator',
    value: 'property-value'
  };

  MingleUI.EasyCharts.CardFilter = function (index, prefix, data) {
    var self = this, defaultOperators = [['is', 'eq'], ['is not', 'ne']], _isValid = false,
        updateHandlers = {
          Property: propertyUpdated,
          Operator: operatorUpdated
        }, operatorValueMap = {
          'is': 'eq',
          'is not': 'ne',
          'is greater than': 'gt',
          'is less than': 'lt',
          'is before': 'lt',
          'is after': 'gt'
        }, propertyDefinitionsData = data.propertyDefinitions,
        onUpdate = ensureFunction(data.onUpdate),
        onRemove = ensureFunction(data.onRemove),
        isRemovable = data.hasOwnProperty('isRemovable') ? data.isRemovable : true,
        initialData = data.initialData || {};

    function containerFor(id, partName) {
      var container = $('<span></span>', {id: id + '_container', class: 'part-container ' + PART_CLASSES[partName]});
      container.append($('<div></div>', {id: id }));
      return container;
    }

    function handleUpdate(dropDown) {
      var eventTarget = dropDown.name.replace(self.identifier.toCamelCase(), '');
      var eventHandler = updateHandlers[eventTarget];
      eventHandler && eventHandler.call();
      _isValid = !!(self.property.hasValue() && self.operator.hasValue() && self.value.isValid());
      onUpdate && onUpdate(self);
    }

    function propertyUpdated() {
      self.value.update(currentPropertyDefinition());
      var operators = operatorsForCurrentProperty();
      self.operator.updateOptions(operators, firstOperator(operators));
    }

    function shouldShowRelativeValues() {
      var selectedOperator = self.operator.value();
      return (selectedOperator === 'eq' || selectedOperator === 'ne');
    }

    function operatorUpdated() {
      shouldShowRelativeValues() ? self.value.showRelativeValues() : self.value.hideRelativeValues();
    }

    function createDropDownFor(name, values, initialValue, defaultValue) {
      var dropDownId = self.identifier + '_' + name.toSnakeCase();
      var dropDownContainer = containerFor(dropDownId, name);
      self.htmlContainer.append(dropDownContainer);

      var dropDownName = dropDownId.toCamelCase();
      self[name] = new MingleUI.DropDown(dropDownName, dropDownContainer.find('div#' + dropDownId), values, {
        initialValue: initialValue,
        defaultOption: defaultValue || '(any)',
        onValueChange: handleUpdate,
        disabled: data.disabled
      });
    }

    function currentPropertyDefinition() {
      return propertyDefinitionsData[self.property.value()];
    }

    function operatorsForCurrentProperty() {
      var propertyDefinition = currentPropertyDefinition();
      if(propertyDefinition) {
        return propertyDefinition.operatorOptions.collect(function(operator) {
          return [operator[0], operatorValueMap[operator[1]]];
        });
      }
      return defaultOperators;
    }

    function firstOperator(operators) {
      return operators[0][1];
    }


    this.isValid = function () {
      return _isValid;
    };

    this.getMql = function () {
      if (!_isValid) return '';

      return MQLBuilder.mqlForFilter(self);
    };

    this.isForCardProperty = function () {
      return currentPropertyDefinition().dataType === 'card';
    };

    this.remove = function() {
      this.htmlContainer.remove();
    };

    function initialize() {
      self.identifier = prefix + '_' + index;
      self.htmlContainer = $('<div>', {class: 'card-filter-container', id: self.identifier});
      self.index = index;

      createDropDownFor('property', Object.keys(propertyDefinitionsData), initialData.property, '(select)');
      var operators = operatorsForCurrentProperty();
      createDropDownFor('operator', operators, operatorValueMap[initialData.operator] || firstOperator(operators));
      var valueContainer = containerFor(self.identifier + '_value', 'value');
      self.htmlContainer.append(valueContainer);
      self.value = new MingleUI.EasyCharts.CardFilterValueWrapper(valueContainer, self.identifier, {
        propertyDefinition: currentPropertyDefinition(),
        project: data.project,
        enableThisCardOption: data.enableThisCardOption,
        disableProjectVariables: data.disableProjectVariables,
        onValueChange: handleUpdate,
        showRelativeValues: shouldShowRelativeValues(),
        initialValues: initialData.values,
        disabled: data.disabled
      });
      if (isRemovable) {
        var removeButton = $('<span>', {class: 'remove-filter'}).on('click', function() {
          self.remove();
          onRemove && onRemove(self);
        });
        self.htmlContainer.append(removeButton);
      }
      _isValid = !!(self.property.hasValue() && self.operator.hasValue() && self.value.isValid());
    }
    initialize();
  };
})(jQuery);
