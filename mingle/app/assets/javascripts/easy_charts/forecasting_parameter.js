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
  var PARAMETER_DEFINITIONS = [{
    name: 'forecasting-chart',
    input_type: 'single-checkbox',
    label: 'Add forecasting to this chart',
    displayProperty: 'inline-parameter'
  }, {
    name: 'fixed-date-chart',
    input_type: 'single-checkbox',
    label: 'Add a fixed date line to this chart',
    displayProperty: 'inline-parameter'
  }];

  MingleUI.EasyCharts.ForecastingParameter = function (containerSelector, options, callbacks) {
    var self = this, params, forecastingOptions, fixedDateForecastingEnabled = false,
        forecastOptionsContainer = $('<div>', {class: 'forecast-options-params-container'});

    function initialize() {
      self.name = 'forecastingParameter';
      self.htmlContainer = $j(containerSelector);
      params = MingleUI.EasyCharts.SectionHelpers.addParameters.call(self, PARAMETER_DEFINITIONS, {
        onUpdate: handleUpdate
      });
    }

    function setupForecastingOptions(enabled) {
      if(!enabled) {
        forecastOptionsContainer.empty();
        forecastingOptions = null;
      } else if (!forecastingOptions) {
        forecastingOptions = new MingleUI.EasyCharts.ForecastingOptions(forecastOptionsContainer, getOptions(), {
          onUpdate: callbacks.onUpdate
        });
        self.htmlContainer.append(forecastOptionsContainer);
      } else {
        forecastingOptions.update(getOptions());
      }
    }

    function getOptions() {
      return {
        hasFixedDate: fixedDateForecastingEnabled,
        seriesNames: options.seriesParameter.getSeriesNames(),
        startDate: new Date(options.startDate.value())
      };
    }

    function updateComplementaryForecastingOption(forecastingOption) {
      var fixedDateOptionChanged = forecastingOption.name === 'fixedDateChart';
      fixedDateForecastingEnabled = fixedDateOptionChanged && forecastingOption.value();
      var otherOption = (fixedDateOptionChanged ? params.forecastingChart : params.fixedDateChart);
      otherOption.unselect();
    }

    function handleUpdate(parameter) {
      updateComplementaryForecastingOption(parameter);
      setupForecastingOptions(parameter.value());
      callbacks.onUpdate && callbacks.onUpdate();
    }

    initialize();

    this.update = function () {
      forecastingOptions && forecastingOptions.update(getOptions());
    };

    this.value = function () {
      return forecastingOptions ? forecastingOptions.value() : {};
    };

    this.isValid = function () {
      return forecastingOptions ? forecastingOptions.isValid() : true;
    };
  };
}(jQuery));