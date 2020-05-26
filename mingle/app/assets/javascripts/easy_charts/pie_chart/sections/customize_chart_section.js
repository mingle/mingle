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

(function() {
  var DEFAULTS = {
    chartSize: 'medium',
    labelType: 'percentage',
    legendPosition: 'right'
  }, PARAMETER_DEFINITIONS = [
    {
      name: 'chart-title',
      input_type: 'textbox',
      label: 'Chart title',
      placeholder: 'Chart title'
    },
    {
      name: 'chart-customization-group',
      input_type: 'group-parameter',
      param_defs: [
        {
          name: 'chart-size',
          initial_value: DEFAULTS.chartSize,
          allowed_values: [['Small', 'small'], ['Medium', 'medium'], ['Large', 'large']],
          multiple_values_allowed: false,
          input_type: 'dropdown',
          label: 'Chart size'
        },
        {
          name: 'label-type',
          initial_value: DEFAULTS.labelType,
          allowed_values: [['Percentage', 'percentage'], ['Whole number', 'whole-number']],
          multiple_values_allowed: false,
          input_type: 'dropdown',
          label: 'Label type'
        },
        {
          name: 'legend-position',
          initial_value: DEFAULTS.legendPosition,
          allowed_values: [['Right', 'right'], ['Bottom', 'bottom']],
          multiple_values_allowed: false,
          input_type: 'dropdown',
          label: 'Legend position'
        }
      ]
    }
  ];

  MingleUI.EasyCharts.PieChart.Sections.CustomizeChartSection = function(initialData, callbacks) {
    return new MingleUI.EasyCharts.Sections.CustomizeChartSection({
      name: 'pieChartCustomizeChartSection',
      paramNames: ['chartTitle', 'chartSize', 'labelType', 'legendPosition'],
      initialData: initialData,
      parameterDefinitions: PARAMETER_DEFINITIONS,
      defaults: DEFAULTS
    }, callbacks);
  };
})();