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

MingleUI.EasyCharts.RatioBarChart.MacroBuilder = function (chartData) {
  var macroParams = {};

  function buildDataMql() {
    macroParams.totals = new MQLBuilder({
      property: chartData.property,
      aggregateType: chartData.aggregate,
      aggregateProp: chartData.aggregateProperty,
      cardTypes: [],
      project: chartData.project,
      additionalConditions: chartData.cardFilters,
      tags: chartData.tags
    }).build();

  }

  function buildRestrictionsClause(restrictions) {
    return restrictions.
    map(function(condition){
      return condition.getMql();}).
    join(' AND ');
  }

  this.build = function() {
    buildDataMql();
    if( chartData.project ) macroParams.project = chartData.project;
    macroParams['restrict-ratio-with'] = "WHERE {clause}".supplant({clause: buildRestrictionsClause(chartData.restrictRatioWith || [] )});
    macroParams['show-guide-lines'] = chartData.showGuideLines;
    if(chartData.chartTitle) macroParams.title = chartData.chartTitle;
    if(chartData.chartSize) macroParams['chart-size'] = chartData.chartSize;
    if(chartData.labelFontAngle) macroParams['label-font-angle'] = chartData.labelFontAngle;
    if(chartData.xAxisTitle) macroParams['x-title'] = chartData.xAxisTitle;
    if(chartData.yAxisTitle) macroParams['y-title'] = chartData.yAxisTitle;
    if(chartData.color) macroParams.color = chartData.color;
    return {
      'ratio-bar-chart': macroParams
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