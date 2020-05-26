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

MingleUI.EasyCharts.DataSeriesChart.MacroBuilder = function (chartData, isForChartBuilder) {
  var macroParams = {}, dummySeriesParameter = {
    'Series 1': new MingleUI.EasyCharts.DummySeries(chartData.dummySeriesProperty || chartData.xLabelProperty, chartData.cardFilters)
  };

  function buildDataMql() {
    macroParams.conditions = new MQLBuilder({
      project: chartData.project,
      additionalConditions: chartData.cardFilters,
      tags: chartData.tags
    }).buildConditionsClause() || '"Type" = "card_type"';

  }

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

  this.build = function () {
    buildDataMql();

    if(chartData.xLabelFilters)
      macroParams['x-labels-conditions'] = 'Type = "{property}" {andClause}'.supplant({
        property: chartData.xLabelProperty,
        andClause: chartData.xLabelFilters.length ? 'AND ' + new MQLBuilder({additionalConditions: chartData.xLabelFilters}).buildConditionsClause() :""
      }).trim();
    else
      macroParams['x-labels-property'] = chartData.xLabelProperty || "property";
    macroParams.cumulative = chartData.hasOwnProperty('cumulative') ? chartData.cumulative : true;
    if (chartData.project) macroParams.project = chartData.project;
    if (chartData.firstXLabel) macroParams['x-labels-start'] = chartData.firstXLabel;
    if (chartData.lastXLabel) macroParams['x-labels-end'] = chartData.lastXLabel;
    macroParams['x-labels-step'] = chartData.xLabelInterval || '1';
    if (chartData.chartTitle) macroParams.title = chartData.chartTitle;
    if (chartData.chartSize) macroParams['chart-size'] = chartData.chartSize;
    if (chartData.labelFontAngle) macroParams['label-font-angle'] = chartData.labelFontAngle;
    if (chartData.xAxisTitle) macroParams['x-title'] = chartData.xAxisTitle;
    if (chartData.yAxisTitle) macroParams['y-title'] = chartData.yAxisTitle;
    if (chartData.legendPosition) macroParams['legend-position'] = chartData.legendPosition;
    macroParams['show-guide-lines'] = chartData.showGuideLines;
    if ($j.isEmptyObject(chartData.seriesParameter) && isForChartBuilder) chartData.seriesParameter = dummySeriesParameter;
    for (var name in chartData.seriesParameter) {
      macroParams.series = macroParams.series || [];
      var seriesMql = {};
      var series = chartData.seriesParameter[name];
      var aggregatePrefix = name.toCamelCase().toLowerCase();
      seriesMql.data = buildSeriesDataMql(series, aggregatePrefix);
      seriesMql.label = series.label;
      seriesMql.color = series.color;
      if(series.burnDown) { seriesMql['down-from'] =  new MQLBuilder({
        aggregateType: series[aggregatePrefix + 'Aggregate'],
        aggregateProp: series[aggregatePrefix + 'AggregateProperty'],
        project: series.project
      }).buildBurnDownMql();}

        seriesMql.type = series.seriesType;
      if(series.seriesType && series.seriesType.match(/Line|Area/)){
        if(series.lineStyle) seriesMql['line-style'] = series.lineStyle;
        seriesMql['data-point-symbol'] = series.dataPointSymbol;
        seriesMql['data-labels'] = series.dataLabels;
      }
      var trend  = series.trendLine;
      seriesMql.trend = trend.addTrendLine;
      if (trend.addTrendLine) {
        seriesMql['trend-scope'] = trend.scope;
        seriesMql['trend-ignore'] = trend.ignore;
        seriesMql['trend-line-color'] = trend.color;
        seriesMql['trend-line-style'] = trend.style;
      }
      if(series.project) seriesMql.project = series.project;
      if(series.isDummySeries) seriesMql.hidden = series.hidden;
      macroParams.series.push(seriesMql);
    }
    return {
      'data-series-chart': macroParams
    };
  };


  this.buildCardCountMql = function () {
    var cardCountMql = 'Select count(*)', whereClause = new MQLBuilder({
      additionalConditions: chartData.cardFilters,
      tags: chartData.tags
    }).buildConditionsClause();
    whereClause && (cardCountMql += ' where ' + whereClause);
    return cardCountMql;
  };
};
