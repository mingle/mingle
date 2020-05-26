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

MingleUI.EasyCharts.CumulativeFlowGraph.MacroBuilder = function (chartData, isForChartBuilder) {

  function buildSeriesDataMql(seriesData, aggregatePrefix) {
    return new MQLBuilder({
      property: seriesData.property,
      aggregateType: seriesData[aggregatePrefix + 'Aggregate'],
      aggregateProp: seriesData[aggregatePrefix + 'AggregateProperty'],
      cardTypes: [],
      additionalConditions: seriesData.filters,
      tags: seriesData.tagsFilter
    }).build();

  }

  MingleUI.EasyCharts.StackedBarChart.MacroBuilder.call(this, chartData, isForChartBuilder);
  var stackedBarChartMacroBuilderBuild = this.build;
  this.build = function () {
    var macroParams = Object.values(stackedBarChartMacroBuilderBuild.call(this)).first();
    delete macroParams.cumulative;
    return {
      'cumulative-flow-graph': macroParams
    };
  };

  this.addSeriesParameter = function(seriesParameter, macroParams){
    for (var name in seriesParameter) {
      var seriesMql = {};
      var series = seriesParameter[name];
      seriesMql.data = buildSeriesDataMql(series, name.toCamelCase().toLowerCase());
      seriesMql.label = series.label;
      seriesMql.color = series.color;
      seriesMql.type = series.seriesType;
      if(series.seriesType && series.seriesType.match(/line|area/i)){
        if(series.lineStyle) seriesMql['line-style'] = series.lineStyle;
        seriesMql['data-point-symbol'] = series.dataPointSymbol;
        seriesMql['data-labels'] = series.dataLabels;
      }
      seriesMql.hidden = series.hidden;
      seriesMql.combine = series.combine;
      if(series.project) seriesMql.project = series.project;
      macroParams.series = macroParams.series || [];
      macroParams.series.push(seriesMql);
    }
  };
};
