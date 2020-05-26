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
MingleUI.EasyCharts.PieChart = (MingleUI.EasyCharts.PieChart || {});
MingleUI.EasyCharts.PieChart.Sections = (MingleUI.EasyCharts.PieChart.Sections || {});

(function ($) {
  var PARAMETER_DEFINITIONS = [
    {
      name: 'property',
      initial_value: null,
      allowed_values: [],
      multiple_values_allowed: false,
      input_type: 'dropdown',
      label: 'Based on which property should the sectors of the pie chart be split?'
    }, {
      input_type: 'pair-parameter',
      label: 'What determines the size of each sector?',
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

  MingleUI.EasyCharts.PieChart.Sections.BuildChartSection = function (initialData, callbacks) {
    function updateProperties(params, properties, aggregateProperties, initialData) {
      params.property.updateOptions(properties, initialData.property);
      params.aggregatePair.setPairValues(aggregateProperties, initialData.aggregateProperty);
    }

    function hasValidInitialData() {
      return (initialData.property &&  initialData.aggregate && (initialData.aggregate === 'count' ? true : initialData.aggregateProperty));
    }

    return new MingleUI.EasyCharts.Sections.BuildChartSection({
      name: 'pieChartBuildChartSection',
      initialData: {
        aggregate: initialData.aggregate,
        property: initialData.property,
        aggregateProperty: initialData.aggregateProperty
      },
      parameterDefinitions: PARAMETER_DEFINITIONS,
      aggregatePairName: 'aggregate-pair',
      hasValidInitialData: hasValidInitialData(),
      extensionMethods: {
        updateProperties: updateProperties
      }
    }, callbacks);

  };
})(jQuery);
