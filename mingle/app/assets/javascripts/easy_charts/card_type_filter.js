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

  MingleUI.EasyCharts.CardTypeFilter = function (index, prefix, data) {
    var self = this, _isValid = false,
        onUpdate = ensureFunction(data.onUpdate);

    function containerFor(id, partName) {
      var container = $('<span></span>', {id: id + '_container', class: 'part-container ' + PART_CLASSES[partName]});
      container.append($('<div></div>', {id: id }));
      return container;
    }

    function handleUpdate() {
      _isValid = !!(self.property.hasValue() && self.operator.hasValue() && self.value.hasValue());
      onUpdate && onUpdate(self);
    }

    function createDropDownFor(name, values, initialValue, defaultValue, options) {
      var dropDownId = self.identifier + '_' + name;
      var dropDownContainer = containerFor(dropDownId, name);
      self.htmlContainer.append(dropDownContainer);

      var dropDownName = dropDownId.toCamelCase();
      self[name] = new MingleUI.DropDown(dropDownName, dropDownContainer.find('div#' + dropDownId), values, $.extend({
        initialValue: initialValue,
        defaultOption: defaultValue || '(any)',
        onValueChange: handleUpdate
      }, options));
    }

    function initialize() {
      self.identifier = prefix + '_' + index;
      self.htmlContainer = $('<div>', {class: 'card-filter-container', id: self.identifier});
      self.index = index;

      createDropDownFor('property', ['Type'], 'Type', '(select)', {disabled: true});
      createDropDownFor('operator', [['is', 'eq']], 'eq','', {disabled: true});
      createDropDownFor('value', data.cardTypes || [], data.selectedCardTypes || [], '(any)', {multiSelect: true});
      _isValid = !!(self.property.hasValue() && self.operator.hasValue() && self.value.hasValue());
    }

    this.isValid = function () {
      return _isValid;
    };

    this.getMql = function () {
      if (!_isValid) return '';

      return MQLBuilder.mqlForFilter(self);
    };

    this.isForCardProperty = function () {
      return false;
    };

    initialize();
  };
})(jQuery);
