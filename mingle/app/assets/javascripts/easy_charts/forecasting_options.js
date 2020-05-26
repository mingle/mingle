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
    name: 'scope-series',
    input_type: 'dropdown',
    label: 'Which series represents total scope in the chart?'
  }, {
    name: 'completion-series',
    input_type: 'dropdown',
    label: 'Which series represents completion in the chart?'
  }, {
    name: 'target-release-date',
    input_type: 'textbox',
    label: 'What is the target release date?',
    isDateType: true,
    placeholder: 'Target Release Date',
    config: {maxDate: '+5y'}
  }];

  MingleUI.EasyCharts.ForecastingOptions = function (selector, options, callbacks) {
    var self = this, params, seriesNames = options.seriesNames || [], hasFixedDateForecasting = options.hasFixedDate,
        startDate = new Date((options.startDate || new Date()).getTime());

    function restrictSeriesOptions(updatedSeries) {
      var selectedValue = updatedSeries.value();
      var series = updatedSeries.name.startsWith('scope') ? params.completionSeries : params.scopeSeries,
          options = seriesNames.reject(function (series) {
            return series[1] === selectedValue;
          });
      series.updateOptions(options, series.value());
    }

    function handleUpdate(parameter) {
      if (parameter.name.endsWith('Series')) restrictSeriesOptions(parameter);
      callbacks.onUpdate && callbacks.onUpdate(parameter);
    }

    function updateParameterOptions() {
      var selectedScopeSeries = params.scopeSeries.value(), selectedCompletionSeries = params.completionSeries.value(),
          scopeSeriesOptions = seriesNames.reject(function (series) {
            return series[1] === selectedCompletionSeries;
          }), completionSeriesOptions = seriesNames.reject(function (series) {
            return series[1] === selectedScopeSeries;
          });
      params.scopeSeries.updateOptions(scopeSeriesOptions, params.scopeSeries.value());
      params.completionSeries.updateOptions(completionSeriesOptions, params.completionSeries.value());
      if (hasFixedDateForecasting) {
        startDate.setDate(startDate.getDate() + 1);
        var currentTargetDate = new Date(params.targetReleaseDate.value());
        if (!isNaN(currentTargetDate.getTime()) && currentTargetDate.getTime() < startDate.getTime()) {
          params.targetReleaseDate.update($.datepicker.formatDate('d, M, yy', startDate));
        }
        params.targetReleaseDate.restrictDateRange(startDate);
      }
    }

    function setupParams() {
      updateParameterOptions();
      var targetReleaseDateParamContainer = self.htmlContainer.find('.parameter-container:last');
      hasFixedDateForecasting ? targetReleaseDateParamContainer.show() : targetReleaseDateParamContainer.hide();
    }

    function init() {
      var name = 'forecasting-options';
      self.name = name.toCamelCase('-');
      self.htmlContainer = $('<div>', {class: name});
      params = MingleUI.EasyCharts.SectionHelpers.addParameters.call(self, PARAMETER_DEFINITIONS, {
        onUpdate: handleUpdate
      });
      setupParams();
      selector.append(self.htmlContainer);
    }

    init();

    this.update = function (updatedOptions) {
      updatedOptions = $.extend(options, updatedOptions);
      seriesNames = updatedOptions.seriesNames;
      hasFixedDateForecasting = updatedOptions.hasFixedDate;
      if (hasFixedDateForecasting) startDate = new Date(updatedOptions.startDate.getTime());
      setupParams();
    };

    this.value = function () {
      var value = {
        scopeSeries: params.scopeSeries.text(),
        completionSeries: params.completionSeries.text()
      };
      if(hasFixedDateForecasting) value.targetReleaseDate = params.targetReleaseDate.value() || 'dd mmm yyyy';
      return value;
    };

    this.isValid = function () {
      return params.scopeSeries.value() && params.completionSeries.value() &&
          (hasFixedDateForecasting ? params.targetReleaseDate.value() : true);
    };
  };
}(jQuery));