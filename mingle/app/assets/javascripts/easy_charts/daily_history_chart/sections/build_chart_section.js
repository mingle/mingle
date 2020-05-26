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
MingleUI.EasyCharts.DailyHistoryChart = (MingleUI.EasyCharts.DailyHistoryChart || {});
MingleUI.EasyCharts.DailyHistoryChart.Sections = (MingleUI.EasyCharts.DailyHistoryChart.Sections || {});

(function ($) {
  var PARAMETER_DEFINITIONS = [
    {
      name: 'customization-group-1',
      input_type: 'group-parameter',
      param_defs: [
        {
          name: 'start-date',
          input_type: 'textbox',
          label: 'Start date',
          isDateType: true,
          config: {date: {minDate: "-5y", dateFormat: 'd, M, yy'}},
          placeholder: 'Start date'
        },
        {
          name: 'end-date',
          input_type: 'textbox',
          label: 'End date',
          isDateType: true,
          placeholder: 'End date'
        }
      ]
    },
    {
      name: 'x-label-interval',
      label: 'X label interval',
      input_type: 'dropdown',
      initial_value: 7,
      allowed_values: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20],
      multiple_values_allowed: false,
      placeholder: 'X label interval'
    },
    {
      input_type: 'pair-parameter',
      label: 'What determines the Y-value of each series?',
      connecting_text: 'of',
      name: 'aggregate-pair',
      param_defs: [
        {
          name: 'aggregate',
          initial_value: 'count',
          allowed_values: [['Number of cards', 'count'], ['Sum', 'sum'], ['Average', 'avg']],
          multiple_values_allowed: false,
          input_type: 'dropdown'
        }, {
          name: 'aggregate-property',
          initial_value: null,
          allowed_values: [],
          multiple_values_allowed: false,
          input_type: 'dropdown'
        }
      ]
    }
  ];

  MingleUI.EasyCharts.DailyHistoryChart.Sections.BuildChartSection = function (initialData, callbacks, projectDataStore, options) {
    var self = this, forecastingParameterContainer = $('<div>', {class: 'forecasting-parameter-container'}),
        customizeChartCallback = ensureFunction(callbacks.onComplete), customizeSectionButtonAdded = false,
        customizeSectionButton = $('<button>', {class: 'enable-customize-section', text: 'Proceed to Step 3'}),
        sectionName = 'dailyHistoryChartBuildChartSection',
        aggregatePairName = 'aggregate-pair';

    var seriesConfig = {
      'trend-line': {isRequired: false},
      'burn-down': {isRequired: false},
      'project': {isRequired: false},
      'tags-filter': {isRequired: false},
      'property': {isRequired: false},
      'aggregate-pair': {isRequired: false},
      'hidden': {isRequired: false},
      'filters': {
        isRequired: true,
        label: 'What conditions determine this series?',
        disableProjectVariables: true,
        propertyDefinitionFilters: ['aggregate']
      },
      'group': {
        isRequired: true,
        values: {
          'combine': {isRequired: false},
          'series-type': {isRequired: false},
          'color': {isRequired: true}
        }
      }
    };

    function setupForecastingParameter() {
      var seriesCount = self.seriesParameter.getSeriesCount();
      if (seriesCount < 2) {
        forecastingParameterContainer.empty();
        self.forecastingParameter = undefined;
      } else if (!self.forecastingParameter && seriesCount === 2) {
        self.forecastingParameter = new MingleUI.EasyCharts.ForecastingParameter(forecastingParameterContainer, {
          seriesParameter: self.seriesParameter,
          startDate: self.params.customizationGroup1.params.startDate
        }, {
          onUpdate: triggerUpdate
        });
        self.seriesParameter.buttonContainer.before(forecastingParameterContainer);
      } else {
        self.forecastingParameter.update();
        self.seriesParameter.buttonContainer.before(forecastingParameterContainer);
      }
    }

    function initializeSeriesParameter() {
      var options = {
        seriesConfig: seriesConfig,
        currentProject: self.currentProject,
        cardFilters: [{
          property: 'Type',
          values: self.selectedCardTypes,
          operator: 'is'
        }],
        callBacks: {
          onUpdate: seriesUpdated,
          onAdd: seriesAdded
        }
      };
      self.seriesParameter = new MingleUI.EasyCharts.SeriesParameter(self.htmlContainer, projectDataStore, options);
    }

    MingleUI.EasyCharts.Sections.BuildChartSection.call(this, {
      name: sectionName,
      parameterDefinitions: PARAMETER_DEFINITIONS,
      initialData: {
        aggregate: initialData.aggregate,
        aggregateProperty: initialData.aggregateProperty
      },
      aggregatePairName: aggregatePairName,
      extensionMethods: {
        updateProperties: updateProperties
      }
    }, $.extend({onEnabled: sectionEnabled, startDate: startDateUpdated, endDate: enableSeriesParameter}, callbacks));

    self.projectDataStore = projectDataStore;

    function updateProperties(params, properties, aggregateProperties) {
      params.aggregatePair.setPairValues(aggregateProperties);
    }

    function addCustomizeButton() {
      if (customizeSectionButtonAdded) return;
      customizeSectionButtonAdded = true;
      customizeSectionButton.on('click', function (event) {
        customizeChartCallback && customizeChartCallback();
        $(event.target).remove();
      });
      self.seriesParameter.buttonContainer.append(customizeSectionButton);
    }

    function seriesAdded() {
      addCustomizeButton();
      setupForecastingParameter();
      callbacks.onUpdate && callbacks.onUpdate(self);
    }

    function sectionEnabled() {
      initializeSeriesParameter();
      self.params.customizationGroup1.params.endDate.disable();
      self._values.xLabelInterval = self.params.xLabelInterval.value();
      $.extend(self._values, self.params.aggregatePair.value());
    }

    function enableSeriesParameter() {
      if (self._values.startDate && self._values.endDate && !self.seriesParameter.isEnabled()) {
        self.seriesParameter.enable();
      }
    }

    function triggerUpdate() {
      callbacks.onUpdate && callbacks.onUpdate(self);
    }

    function seriesUpdated() {
      setupForecastingParameter();
      triggerUpdate();
    }

    function startDateUpdated(startDate) {
      var start = new Date(startDate.value());
      if (!isNaN(start.getTime())) {
        self.params.customizationGroup1.params.endDate.enable();
        start.setDate(start.getDate() + 1);
        self.params.customizationGroup1.params.endDate.restrictDateRange(start);
        self.forecastingParameter && self.forecastingParameter.update();
        enableSeriesParameter();
      }
    }

    this.values = function () {
      if (!this.isEnabled()) return {};
      return $.extend(this._values, {
        seriesParameter: self.seriesParameter.value(),
        forecastingParameter: self.forecastingParameter ? self.forecastingParameter.value() : {}
      });
    };

    this.isValid = function () {
      return self.params && self.params.customizationGroup1.params.startDate.value() &&
          self.params.customizationGroup1.params.endDate.value() && self.params.aggregatePair.isValid() &&
          (self.forecastingParameter ? self.forecastingParameter.isValid() : true);
    };

    this.enableInsert = function () {
      return this.isValid() && self.seriesParameter.isValid();
    };

    var disableInParent = this.disable; //Getting reference to the parent disable
    this.disable = function () {
      disableInParent.call(self);
      self.seriesParameter.htmlContainer.remove();
      this._values = {};
    };
  };
})(jQuery);
