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
MingleUI.EasyCharts.Sections = (MingleUI.EasyCharts.Sections || {});

(function($) {
  var SINGLE_DYNAMIC_VALUE_PARAMS_KEY = '__single_dynamic_value_params__';
  MingleUI.EasyCharts.Sections.CustomizeChartSection = function(sectionData, options) {
    var self = this, onUpdate = ensureFunction(options.onUpdate), values = $.extend({}, sectionData.defaults), params,
        paramsContainer, dynamicValueParams = {}, initialData;

    function handleUpdate(target) {
      values[target.name] = target.value();
      onUpdate && onUpdate(self);
    }

    function dynamicValueParamsFor(groupName) {
      groupName = groupName || SINGLE_DYNAMIC_VALUE_PARAMS_KEY;
      dynamicValueParams[groupName] = dynamicValueParams[groupName] || [];
      return dynamicValueParams[groupName];
    }

    function camelCasedName(paramDef) {
      return paramDef.name.toCamelCase('-');
    }

    function setDynamicValueParamNames() {
      sectionData.parameterDefinitions.each(function (paramDef) {
        if(paramDef.input_type === 'group-parameter') {
          paramDef.param_defs.each(function (groupedParamDef) {
            ('textbox'  === groupedParamDef.input_type) && dynamicValueParamsFor(camelCasedName(paramDef)).push(camelCasedName(groupedParamDef));
          });
        } else if ('textbox' === paramDef.input_type) {
           dynamicValueParamsFor(SINGLE_DYNAMIC_VALUE_PARAMS_KEY).push(camelCasedName(paramDef));
        }
      });
    }

    function hasValidInitialData() {
      return (sectionData.paramNames || []).any(function (paramName) {
        return initialData[paramName];
      });
    }

    function initialize() {
      self.name = sectionData.name;
      self.htmlContainer = $('<div>', {id: self.name.toSnakeCase(), class: 'chart-form-section customize-chart-section disabled'});
      MingleUI.EasyCharts.SectionHelpers.addTitle.call(self, 3, 'Customize the chart');
      initialData = MingleUI.EasyCharts.SectionHelpers.getInitialData(sectionData);
      setDynamicValueParamNames();
      if(hasValidInitialData()) self.enableWith();
      $.extend(values, initialData);
    }

    function sectionValues() {
      Object.keys(dynamicValueParams).each(function(key) {
        dynamicValueParams[key].each(function (dynamicValueParamName) {
          values[dynamicValueParamName] = (key === SINGLE_DYNAMIC_VALUE_PARAMS_KEY) ?
              params[dynamicValueParamName].value() :
              params[key].params[dynamicValueParamName].value();
        });
      });

      return values;
    }

    this.enableWith = function () {
      if (!self.htmlContainer.hasClass('disabled')) return;
      self.htmlContainer.toggleClass('disabled');
      params = MingleUI.EasyCharts.SectionHelpers.addParameters.call(self, sectionData.parameterDefinitions, {
        onUpdate: handleUpdate,
        initialData: MingleUI.EasyCharts.SectionHelpers.getInitialData(sectionData)
      });
      paramsContainer = self.htmlContainer.find('.section-params-container');
      var elementToScroll = $j('#'+self.htmlContainer.attr('id')+' > div:nth-child(2) > div:last-child');
      elementToScroll.scrollintoview && elementToScroll.scrollintoview({direction: 'vertical'});
    };

    this.disable = function () {
      self.htmlContainer.toggleClass('disabled');
      paramsContainer.remove();
      params = undefined;
    };

    this.isValid = function () {
      return true;
    };

    this.values = function () {
      return self.isEnabled() ? sectionValues() : sectionData.defaults;
    };

    this.isEnabled = function () {
      return !!params;
    };

    initialize();
  };
})(jQuery);