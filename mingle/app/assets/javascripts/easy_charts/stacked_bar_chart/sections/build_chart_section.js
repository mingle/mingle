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
MingleUI.EasyCharts.StackedBarChart = (MingleUI.EasyCharts.StackedBarChart || {});
MingleUI.EasyCharts.StackedBarChart.Sections = (MingleUI.EasyCharts.StackedBarChart.Sections || {});
var NOT_SET_OPTION = [['(not set)', '']];

(function ($) {
  var PARAMETER_DEFINITIONS = [
    {
      name: 'x-label-property',
      initial_value: null,
      allowed_values: [],
      multiple_values_allowed: false,
      input_type: 'dropdown',
      label: 'Which property should each stack be based on?'
    }, {
      name: 'x-label-filters',
      input_type: 'card-filters',
      label: 'Filter X-axis values',
      withoutCardTypeFilter: true,
      options: {disabled: true}
    }, {
      name: 'build-chart-group-1',
      input_type: 'group-parameter',
      param_defs: [
        {
          name: 'first-x-label',
          label: 'First X label',
          input_type: 'dropdown',
          initial_value: null,
          allowed_values: [],
          multiple_values_allowed: false,
          placeholder: 'X label start'
        },
        {
          name: 'last-x-label',
          label: 'Last X label',
          input_type: 'dropdown',
          initial_value: null,
          allowed_values: [],
          multiple_values_allowed: false,
          placeholder: 'X label end'
        },
        {
          name: 'x-label-interval',
          label: 'X label interval',
          input_type: 'dropdown',
          initial_value: 1,
          allowed_values: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20],
          multiple_values_allowed: false,
          placeholder: 'X label interval'
        }
      ],
      options: {disabled: true}
    },
    {
      name: 'cumulative',
      input_type: 'single-checkbox',
      label: 'Make this a cumulative chart',
      displayProperty: 'inline-parameter',
      checked: ''
    }
  ];

  MingleUI.EasyCharts.StackedBarChart.Sections.BuildChartSection = function (initialData, callbacks, projectDataStore, options) {
    var self = this,
        customizeChartCallback = ensureFunction(callbacks.onComplete),
        onUpdate = ensureFunction(callbacks.onUpdate), customizeSectionButtonAdded = false,
        customizeSectionButton = $('<button>', {class: 'enable-customize-section', text: 'Proceed to Step 3'}),
        seriesConfig = {'trend-line':{isRequired:false}, 'burn-down':{isRequired:false}},
        parameterDefinitions = PARAMETER_DEFINITIONS,
        sectionName = MingleUI.EasyCharts.chartType.toCamelCase('-') + 'BuildChartSection';
    self.updateHandler = {xLabelProperty: xLabelPropertyChanged};
    self.xLabelTranslator = new MingleUI.EasyCharts.StackedBarChart.XLabelTranslator(updateLabelRangeFilters);

    if(options) {
      seriesConfig = options.seriesConfig || seriesConfig;
      parameterDefinitions = options.parameterDefinitions || parameterDefinitions;
    }

    self.projectDataStore = projectDataStore;
    function xLabelPropertyChanged(propertyValues, projectData) {
      self.params.xLabelFilters.reset(projectData, {disabled: false});
      updateLabelRangeFilters(propertyValues);
      if (!self.seriesParameter.isEnabled()) {
        self.seriesParameter.enable(self.params.xLabelProperty.value());
      } else {
        self.seriesParameter.update(self.params.xLabelProperty.value());
        self._values.seriesParameter = self.seriesParameter.value();
      }
    }

    this.selectedCardTypes = [];

    function updateLabelRangeFilters(propertyValues) {
      var xLabelsFilterGroup = self.params.buildChartGroup1.params;
      var firstXLabelParam = xLabelsFilterGroup.firstXLabel;
      var lastXLabelParam = xLabelsFilterGroup.lastXLabel;
      var xLabelInterval = xLabelsFilterGroup.xLabelInterval;
      firstXLabelParam.updateOptions(NOT_SET_OPTION.concat(propertyValues), firstXLabelParam.value());
      firstXLabelParam._disabled && firstXLabelParam.enable();
      lastXLabelParam.updateOptions(NOT_SET_OPTION.concat(propertyValues), lastXLabelParam.value());
      lastXLabelParam._disabled && lastXLabelParam.enable();
      xLabelInterval._disabled && xLabelInterval.enable();
      resetXLabelRangeFilterValues();
    }

    function resetXLabelRangeFilterValues() {
      var xLabelsFilterGroup = self.params.buildChartGroup1.params;
      self._values.firstXLabel = xLabelsFilterGroup.firstXLabel.value() || null;
      self._values.lastXLabel = xLabelsFilterGroup.lastXLabel.value() || null;
    }

    function populateLabelRangeFilters(_xLabelsFilterMqlConditionsClause, options) {
      var xLabelsFilterMql = "SELECT DISTINCT '{property}'{whereClause}".supplant({
        property: options.property,
        whereClause: _xLabelsFilterMqlConditionsClause ? " WHERE " + _xLabelsFilterMqlConditionsClause : ""
      });
      var translator = (self.xLabelTranslator[options.dataType] || self.xLabelTranslator.common)(options, self.projectData.getDisplayNameFor);
      self.projectData.executeMql(xLabelsFilterMql, translator);
    }

    function getPropertyValues(values, selectedProperty) {
      var propertyValueDetails = values[selectedProperty].propertyValueDetails || [];
      if (propertyValueDetails.length && propertyValueDetails[0].position)
        propertyValueDetails = propertyValueDetails.sort(function (left, right) {
          return left.position - right.position;
        });
      return propertyValueDetails.map(function (v) {
        return v.value;
      });
    }

    this.customUpdateHandler = function (target, skipUpdateTrigger) {
      var selectedProperty = self.params.xLabelProperty.value(), values, propertyValues;
      if (selectedProperty) {
        self.projectData = self.projectDataStore.dataFor(self.currentProject);
        values = self.projectData.fetchCommonPropertyDefinitionDetails(self.selectedCardTypes, selectedProperty);
        propertyValues = getPropertyValues(values, selectedProperty);
      }

      if (target) {
        self.updateHandler[target.name] && self.updateHandler[target.name](propertyValues, self.projectData);
        self._values[target.name] = target.value();
      }

      function buildConditionClause() {
        var selectedFilters = self.params.xLabelFilters.value();
        self._values.xLabelFilters = selectedFilters;
        var _xLabelsFilterMqlConditionsClause = new MQLBuilder({additionalConditions: selectedFilters}).buildConditionsClause();
        var _dataSectionFilterConditionClause;
        if (self.dataSectionSelectedFilters) {
          _dataSectionFilterConditionClause = new MQLBuilder({
            additionalConditions: self.dataSectionSelectedFilters.filters,
            tags: self.dataSectionSelectedFilters.tags || []
          }).buildConditionsClause();
        }
        var _xLabelsConditionClause = _dataSectionFilterConditionClause;
        if (_xLabelsFilterMqlConditionsClause) _xLabelsConditionClause = _xLabelsFilterMqlConditionsClause + 'AND' + _xLabelsConditionClause;
        return _xLabelsConditionClause;
      }

      if (selectedProperty) {
        populateLabelRangeFilters(buildConditionClause(), {
          dataType: values[selectedProperty].dataType,
          dateFormat: self.projectData.dateFormat,
          property: selectedProperty,
          propValues: propertyValues,
          isManaged: values[selectedProperty].isManaged
        });

        !skipUpdateTrigger && onUpdate && onUpdate(self, target);
      }
    };

    this.updateSelectedFilters = function (filterValues, filterType) {
      this.dataSectionSelectedFilters = this.dataSectionSelectedFilters || {};
      if (this.dataSectionSelectedFilters[filterType] != filterValues) {
        this.dataSectionSelectedFilters[filterType] = filterValues;
        if (this.isValid())
          this.customUpdateHandler(null, true);
      }
    };

    function addCustomizeButton() {
      if (customizeSectionButtonAdded) return;
      customizeSectionButtonAdded = true;
      customizeSectionButton.on('click', function (event) {
        customizeChartCallback && customizeChartCallback();
        $(event.target).remove();
      });
      self.seriesParameter.buttonContainer.append(customizeSectionButton);
    }

    function handleSeriesParameterError(errorMessage) {
      self._values.seriesParameter = self.seriesParameter.value();
      callbacks.onError && callbacks.onError(errorMessage);
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
          onUpdate: self.customUpdateHandler,
          onAdd: addCustomizeButton,
          onError: handleSeriesParameterError
        }
      };
      self.seriesParameter = new MingleUI.EasyCharts.SeriesParameter(self.htmlContainer, projectDataStore, options);
    }

    MingleUI.EasyCharts.Sections.BuildChartSection.call(this, {
      name:  sectionName,
      parameterDefinitions: parameterDefinitions,
      extensionMethods: {
        updateProperties: updateProperties
      }
    }, $.extend({onEnabled: initializeSeriesParameter}, callbacks));

    function updateProperties(params, properties) {
      params.xLabelProperty.updateOptions(properties);
    }

    this.isValid = function () {
      return self.params && (!!self.params.xLabelProperty.value());
    };

    this.enableInsert = function () {
      return this.isValid() && this.seriesParameter.isValid();
    };

    this.values = function () {
      var values = {};
      if (this.isEnabled()) {
        var buildChartGroup1 = self.params.buildChartGroup1;
        values = $.extend(this._values, {xLabelInterval: buildChartGroup1.params.xLabelInterval.value()});
      }
      return values;
    };

    var disableInParent = this.disable; //Getting reference to the parent disable
    this.disable = function () {
      disableInParent.call(self);
      customizeSectionButtonAdded = false;
      self.seriesParameter.htmlContainer.remove();
      this._values = {};
    };
  };
})(jQuery);

