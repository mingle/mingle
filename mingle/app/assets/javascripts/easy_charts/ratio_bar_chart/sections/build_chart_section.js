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

(function ($) {
  var PARAMETER_DEFINITIONS = [
    {
      name: 'property',
      initial_value: null,
      allowed_values: [],
      multiple_values_allowed: false,
      input_type: 'dropdown',
      label: 'Which card property is each bar based on?'
    }, {
      input_type: 'pair-parameter',
      label: 'What determines the full height (100%) of the bars?',
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
    },
    {
      name: 'restrict-ratio-with',
      input_type: 'card-filters',
      label: 'What determines the actual height of the bars?',
      withoutCardTypeFilter:true
    }
  ];

  MingleUI.EasyCharts.RatioBarChart.Sections.BuildChartSection = function (initialData, callbacks) {
    var aggregatePairName = 'aggregate-pair';

    MingleUI.EasyCharts.Sections.BuildChartSection.call(this,{
      name: 'ratioBarChartBuildChartSection',
      parameterDefinitions: PARAMETER_DEFINITIONS,
      initialData: {
        property: initialData.property,
        aggregate: initialData.aggregate,
        aggregateProperty: initialData.aggregateProperty,
        restrictRatioWith: initialData.restrictRatioWith
      },
      aggregatePairName: aggregatePairName,
      extensionMethods: {
        updateProperties: updateProperties
      }
    }, callbacks);


    function updateProperties(params, properties, aggregateProperties) {
      params.property.updateOptions(properties);
      params.aggregatePair.setPairValues(aggregateProperties);
    }

    this.isValid = function(){
      return this.params && !!(this.params.property.value() && this.params['aggregatePair'].isValid() && this.params.restrictRatioWith.value().length > 0);
    };

    this.values = function(){
      if(!this.isEnabled()) return {};

      $.extend(this._values , {
        'restrictRatioWith': this.params.restrictRatioWith.value()
      });
      return this._values;
    };

  };
})(jQuery);
