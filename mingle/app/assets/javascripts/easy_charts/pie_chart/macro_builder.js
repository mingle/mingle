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

MingleUI.EasyCharts.PieChart.MacroBuilder = function (chartData, isForChartBuilder) {
  var macroParams = {};

  function buildDataMql() {
    macroParams.data = new MQLBuilder({
      property: chartData.property,
      aggregateType: chartData.aggregate,
      aggregateProp: chartData.aggregateProperty,
      cardTypes: [],
      project: chartData.project,
      additionalConditions: chartData.cardFilters,
      tags: chartData.tags
    }).build();
  }

  this.build = function() {
    buildDataMql();
    if(chartData.project) macroParams.project = chartData.project;
    if(chartData.chartTitle) macroParams.title = chartData.chartTitle;
    if(chartData.chartSize) macroParams['chart-size'] = chartData.chartSize;
    if(chartData.labelType) macroParams['label-type'] = chartData.labelType;
    if(chartData.legendPosition) macroParams['legend-position'] = chartData.legendPosition;
    return {
      'pie-chart': macroParams
    };
  };

  this.buildCardCountMql = function() {
    var cardCountMql = 'Select count(*)', whereClause = new MQLBuilder({
      additionalConditions: chartData.cardFilters,
      tags: chartData.tags
    }).buildConditionsClause();
    whereClause && (cardCountMql += ' where ' + whereClause);
    return  cardCountMql;
  };
};