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

MingleUI.EasyCharts.TrendLineParameter = function (container, paramDefinitions, options) {
  var PARAM_DEF = {
    name: 'add-trend-line',
    input_type: 'single-checkbox',
    label: 'Add a trend line',
    displayProperty: 'inline-parameter'
  };
  var self = this, trendLineCustomizationParamContainer = null, values = {addTrendLine: false}, trendLineCustomizationParam = null;

  function trendLineToggled(target) {
    if (target.value()) {
      initTrendLineCustomizationParameter();
    }
    else {
      removeTrendCustomizationValues();
    }
    values[target.name] = target.value();
    options.onUpdate && options.onUpdate(self);
  }

  function handleTrendLineCustomizationUpdate(target) {
    values[target.name] = target.value();
    options.onUpdate && options.onUpdate(self);
  }

  function scroll(container, element) {
    var elementToScroll = container.find(element);
    elementToScroll.scrollintoview && elementToScroll.scrollintoview({direction: 'vertical'});
  }

  function initTrendLineCustomizationParameter() {
    trendLineCustomizationParamContainer = $j('<div></div>', {class: 'trend-line-customization-params-container'});
    var customOptions = $j.extend({}, options);
    customOptions.paramsContainer = trendLineCustomizationParamContainer;
    customOptions.onUpdate = handleTrendLineCustomizationUpdate;
    trendLineCustomizationParam = MingleUI.EasyCharts.SectionHelpers.addParameters.call(self, paramDefinitions.param_defs, customOptions);
    scroll(trendLineCustomizationParamContainer,'.color-picker');
    initTrendCustomizationValues();
  }

  function initAddTrendLineParameter() {
    var addTrendLineParamContainer = $j('<div></div>', {class: 'add-trend-line-param-container'});
    MingleUI.EasyCharts.SectionHelpers.addParameters.call(self, [PARAM_DEF], {
      onUpdate: trendLineToggled,
      paramsContainer: addTrendLineParamContainer
    });
  }

  function initTrendCustomizationValues(){
    values = $j.extend(values, trendLineCustomizationParam.trendCustomization.value());
  }

  function removeTrendCustomizationValues(){
    trendLineCustomizationParamContainer.remove();
    delete values.scope;
    delete values.ignore;
    delete values.style;
  }

  function initialize() {
    self.name = paramDefinitions.name.toCamelCase('-');
    self.htmlContainer = $j(container);

    initAddTrendLineParameter();
  }

  this.value = function () {
    return values;
  };
  initialize();
};
