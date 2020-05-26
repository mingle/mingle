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
MingleUI.EasyCharts.RatioBarChart = (MingleUI.EasyCharts.RatioBarChart || {});
MingleUI.EasyCharts.RatioBarChart.Sections = (MingleUI.EasyCharts.RatioBarChart.Sections || {});

(function() {
  var DEFAULTS = {
    chartSize: 'medium',
    labelFontAngle: 45,
    color: '#0B8ABA',
    showGuideLines: true
  }, PARAMETER_DEFINITIONS = [
    {
      name: 'customization-group-1',
      input_type: 'group-parameter',
      param_defs: [
        {
          name: 'chart-title',
          input_type: 'textbox',
          label: 'Chart title',
          placeholder: 'Chart title'
        },
        {
          name: 'color',
          input_type: 'color-picker',
          label: 'Color',
          initialColor: '#0B8ABA' //Default C3 js ratio bar color
        }
      ]
    },
    {
      name: 'customization-group-2',
      input_type: 'group-parameter',
      param_defs: [
        {
          name: 'x-axis-title',
          input_type: 'textbox',
          label: 'X-axis title',
          placeholder: 'X-axis title'
        },
        {
          name: 'y-axis-title',
          input_type: 'textbox',
          label: 'Y-axis title',
          placeholder: 'Y-axis title'
        }
      ]
    },
    {
      name: 'customization-group-3',
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
          name: 'label-font-angle',
          initial_value: DEFAULTS.labelFontAngle,
          allowed_values: [['Slant', 45], ['Vertical', 90], ['Horizontal', 0]],
          multiple_values_allowed: false,
          input_type: 'dropdown',
          label: 'Label angle'
        }
      ]
    },
    {
      name: 'show-guide-lines',
      input_type: 'single-checkbox',
      label: 'Show guide lines',
      checked: 'checked',
      displayProperty:'inline-parameter'
    }
  ];

  MingleUI.EasyCharts.RatioBarChart.Sections.CustomizeChartSection = function(initialData, callbacks) {
    return new MingleUI.EasyCharts.Sections.CustomizeChartSection({
      name: 'ratioBarChartCustomizeChartSection',
      initialData: initialData,
      paramNames: ['chartSize', 'chartTitle', 'color', 'xAxisTitle', 'yAxisTitle', 'labelFontAngle', 'showGuideLines'],
      parameterDefinitions: PARAMETER_DEFINITIONS,
      defaults: DEFAULTS
    }, callbacks);
  };
})();