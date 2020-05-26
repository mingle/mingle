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

MingleUI.EasyCharts.Parameter = function (sectionName, paramDef, options) {
  var paramName = paramDef.name.toSnakeCase(), containerId = sectionName + '_' + paramName + '_parameter', self = this;
  var PARAM_CLASSES = {
    'dropdown': 'drop-down',
    'textbox': 'text-box',
    'singlecheckbox': 'single-checkbox',
    'colorpicker': 'color-picker'
  };

  function buildLabel() {
    if (paramDef.label) {
      var labelClass = 'parameter-label {0}'.supplant([(paramDef.labelDisplayProperty || '')]);
      var labelHtml = $j('<div>', {class: labelClass, text: paramDef.label});
      self.htmlContainer.append(labelHtml);
    }
  }

  function initialData() {
    return (options.initialData || {})[self.name];
  }

  function buildParameter() {
    var paramContainer = $j('<div>', {class: 'parameter ' + (PARAM_CLASSES[paramDef.input_type] || paramDef.input_type) });
    var localOptions = Object.extend({disabled: options.disabled}, paramDef.options);
    switch (paramDef.input_type) {
      case 'dropdown':
        self.param = new MingleUI.DropDown(self.name, paramContainer, paramDef.allowed_values, {
          initialValue: initialData() || paramDef.initial_value,
          multiSelect: paramDef.multiple_values_allowed,
          onValueChange: options.onUpdate,
          disabled: options.disabled
        });
        break;
      case 'card-filters':
        self.param = new MingleUI.EasyCharts.CardFilters(paramContainer, options.projectData, {
          enableThisCardOption: options.enableThisCardOption,
          onUpdate: options.onUpdate,
          withoutCardTypeFilter: !!paramDef.withoutCardTypeFilter,
          selectedCardTypes: options.selectedCardTypes,
          initialData: initialData(),
          disableProjectVariables: paramDef.disableProjectVariables || options.disableProjectVariables,
          propertyDefinitionFilters: paramDef.propertyDefinitionFilters || options.propertyDefinitionFilters,
          disabled: localOptions.disabled,
          allowedCardTypes: options.allowedCardTypes,
          name: self.name
        });
        break;
      case 'tags-filter':
        self.param = new MingleUI.TagsFilter(self.name, paramContainer, options.projectData, {
          onUpdate: options.onUpdate,
          initialTags: initialData()
        });
        break;
      case 'pair-parameter':
        self.param = new MingleUI.EasyCharts.PairParameter(paramContainer, paramDef, {
          onUpdate: options.onUpdate, initialData: options.initialData
        });
        break;
      case 'textbox':
        self.param = new MingleUI.TextBox(paramContainer, {
          onValueChange: options.onUpdate,
          name: self.name,
          initialValue: initialData() || paramDef.initial_value,
          placeholder: paramDef.placeholder,
          isDate: paramDef.isDateType,
          config: paramDef.config
        });
        break;
      case 'group-parameter':
        self.param = new MingleUI.EasyCharts.GroupParameter(paramContainer, paramDef, {
          onUpdate: options.onUpdate, initialData: options.initialData,
          disabled: localOptions.disabled
        });
        break;
      case 'single-checkbox':
        self.param = new MingleUI.SingleCheckbox(paramContainer, {
          name: paramDef.name,
          checked: initialData() || paramDef.checked,
          onValueChange: options.onUpdate
        });
        break;
      case 'color-picker':
        self.param = new MingleUI.ColorPicker(paramContainer, {
          name: paramDef.name,
          onValueChange: options.onUpdate,
          initialColor: initialData() || paramDef.initialColor
        });
        break;
      case 'trend-line-parameter':
        self.param = new MingleUI.EasyCharts.TrendLineParameter(paramContainer, paramDef, options);
        break;
    }
    self.htmlContainer.append(paramContainer);
    self.htmlContainer.addClass(paramDef.displayProperty || '');
  }

  function initialize() {
    self.htmlContainer = $j('<div>', {id: containerId, class: 'parameter-container'});
    self.name = paramName.toCamelCase();

    buildLabel();
    buildParameter();
  }

  initialize();
};
