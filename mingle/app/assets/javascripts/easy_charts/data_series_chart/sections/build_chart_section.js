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
MingleUI.EasyCharts.DataSeriesChart = (MingleUI.EasyCharts.DataSeriesChart || {});
MingleUI.EasyCharts.DataSeriesChart.Sections = (MingleUI.EasyCharts.DataSeriesChart.Sections || {});

(function ($) {
  var PARAMETER_DEFINITIONS = [
    {
      name: 'x-label-property',
      initial_value: null,
      allowed_values: [],
      multiple_values_allowed: false,
      input_type: 'dropdown',
      label: 'Which property should be plotted on the X-axis?'
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

  MingleUI.EasyCharts.DataSeriesChart.Sections.BuildChartSection = function (initialData, callbacks, projectDataStore) {
    var self = this, customCallBacks = {},
        onUpdate = ensureFunction(callbacks.onUpdate),
        options = {
          seriesConfig: {
            enableSeriesTypeCustomization: true,
            'aggregate-pair': {
              isRequired: true,
              label: 'What determines the Y-axis values?'
            },
            group: {
              isRequired: true,
              values: {
                combine: {
                  isRequired: false
                },
                'series-type': {
                  isRequired: true,
                  initialValue: 'Line'
                }
              }
            },
            hidden: {isRequired: false}
          },
          sectionName: 'dataSeriesChartBuildChartSection',
          parameterDefinitions: PARAMETER_DEFINITIONS
        };

    function toggleXLabelFilters(updatedProperty) {
      if (updatedProperty.name !== 'xLabelProperty') return;
      var selectedProperty = updatedProperty.value();
      var projectData = self.projectData;
      var property = projectData.fetchCommonPropertyDefinitionDetails(self.selectedCardTypes, selectedProperty);

      if (property[selectedProperty].treeSpecial) {
        var validCardTypeName = property[selectedProperty].validCardTypeName;
        self._values.dummySeriesProperty = self._values[updatedProperty.name];
        self._values[updatedProperty.name] = validCardTypeName;
        self.params.xLabelFilters.show();
        self.params.xLabelFilters.reset(projectData, {selectedCardTypes: [validCardTypeName]});
        self._values.xLabelFilters = self.params.xLabelFilters.value();
      }
      else {
        self._values.xLabelFilters = null;
        self.params.xLabelFilters.hide();
        self._values.dummySeriesProperty = null;
      }
    }

    function buildXLabelsFilterMql(options, xLabelsFilterMqlConditionsClause) {
      var xLabelsFilterMql = 'SELECT name, number';
      if (options.validCardTypeName) {
        var whereClause = '{0}{1}'.supplant(['Type = "{0}"'.supplant([options.validCardTypeName]),
          xLabelsFilterMqlConditionsClause ? " AND " + xLabelsFilterMqlConditionsClause : ""
        ]);
        xLabelsFilterMql = '{0} WHERE {1}'.supplant([xLabelsFilterMql, whereClause]);
      }
      return xLabelsFilterMql;
    }

    function formatDataForXLabelTranslatorForCardProperty(translator, options) {
      return function (data) {
        var nameToValueMap = data.map(function (value) {
          var _value = {};
          _value[options.property] = "#{0} {1}".supplant([value.Number, value.Name]);
          return _value;
        });
        translator(nameToValueMap);
      };
    }

    function formatDataForXLabelTranslatorForUserProperty(translator) {
      return function (data) {
        var loginNames = data.map(function (userInfo) {
          var regex = /.*?\((.*?)\)/g, login = '', match = '';
          while (match !== null) {
            login = match[1];
            match = regex.exec(userInfo);
          }
          return login;
        });
        translator(loginNames);
      };
    }

    function populateLabelRangeFilters(xLabelsFilterMqlConditionsClause, options) {
      var translator = (self.xLabelTranslator[options.dataType] || self.xLabelTranslator.common)(options, self.projectData.getDisplayNameFor);

      if (options.dataType.toLowerCase() === 'card') {
        self.projectData.executeMql(buildXLabelsFilterMql(options, xLabelsFilterMqlConditionsClause), formatDataForXLabelTranslatorForCardProperty(translator, options));
      } else {
        translator = options.dataType.toLowerCase() === 'user' ? formatDataForXLabelTranslatorForUserProperty(translator) : translator;
        self.projectData.propertyDefinitionValues(options.propertyId, translator);
      }

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

    MingleUI.EasyCharts.StackedBarChart.Sections.BuildChartSection.call(this,initialData, callbacks, projectDataStore, options);

    this.customUpdateHandler = function (target) {
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
        if(!self._values.xLabelFilters) return "";
        var selectedFilters = self.params.xLabelFilters.value();
        self._values.xLabelFilters = selectedFilters;
        return new MQLBuilder({additionalConditions: selectedFilters}).buildConditionsClause();
      }

      toggleXLabelFilters(target);
      if (selectedProperty) {
        populateLabelRangeFilters(buildConditionClause(), {
          dataType: values[selectedProperty].dataType,
          propertyId: values[selectedProperty].id,
          isTreeSpecial: values[selectedProperty].treeSpecial,
          validCardTypeName: values[selectedProperty].validCardTypeName,
          dateFormat: self.projectData.dateFormat,
          property: selectedProperty,
          propValues: propertyValues,
          isManaged: values[selectedProperty].isManaged
        });

        onUpdate && onUpdate(self, target);
      }
    };

    this.updateSelectedFilters = function(){};
  };
})(jQuery);

