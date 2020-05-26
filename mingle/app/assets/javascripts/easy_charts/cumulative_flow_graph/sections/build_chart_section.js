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
MingleUI.EasyCharts.CumulativeFlowGraph = (MingleUI.EasyCharts.CumulativeFlowGraph || {});
MingleUI.EasyCharts.CumulativeFlowGraph.Sections = (MingleUI.EasyCharts.CumulativeFlowGraph.Sections || {});
var NOT_SET_OPTION = [['(not set)', '']];

(function ($) {
  var PARAMETER_DEFINITIONS = [
    {
      name: 'x-label-property',
      initial_value: null,
      allowed_values: [],
      multiple_values_allowed: false,
      input_type: 'dropdown',
      label: 'Which property should the X-axis labels be based on?'
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
    }
  ];

  MingleUI.EasyCharts.CumulativeFlowGraph.Sections.BuildChartSection = function (initialData, callbacks, projectDataStore) {
   var  seriesConfig = {
     'trend-line':{isRequired:false},
     'burn-down':{isRequired:false},
     "aggregate-pair": {
       isRequired: true,
       label: "What determines the Y-axis values?"
     },
     "enableSeriesTypeCustomization": true,
     group: {
       isRequired: true,
       values: {
         "series-type": {
           initialValue: "Area",
           isRequired: true
         }
       }
     }
   };
    var options = {parameterDefinitions: PARAMETER_DEFINITIONS, seriesConfig: seriesConfig};
    MingleUI.EasyCharts.StackedBarChart.Sections.BuildChartSection.call(this,initialData, callbacks, projectDataStore, options);
    this._values = this._values || {};
    this._values.cumulative  = true;
  };
})(jQuery);

