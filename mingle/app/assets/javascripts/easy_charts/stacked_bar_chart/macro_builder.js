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
MingleUI.EasyCharts.StackedBarChart = (MingleUI.EasyCharts.StackedBarChart || {});

MingleUI.EasyCharts.StackedBarChart.MacroBuilder = function (chartData, isForChartBuilder) {
  var macroParams = {}, dummySeriesParameter = {
    'Series 1': new MingleUI.EasyCharts.DummySeries(chartData.xLabelProperty, chartData.cardFilters)
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

    var xLabelFilters = chartData.xLabelFilters || [];
    macroParams.labels = 'SELECT DISTINCT "{property}" {whereClause}'.supplant({
      property: chartData.xLabelProperty || "property",
      whereClause: xLabelFilters.length ? "WHERE " + new MQLBuilder({additionalConditions: xLabelFilters}).buildConditionsClause() : ''
    }).trim();
    macroParams.cumulative = chartData.hasOwnProperty('cumulative') ? chartData.cumulative : true;
    if (chartData.project) macroParams.project = chartData.project;
    if (chartData.firstXLabel) macroParams['x-label-start'] = chartData.firstXLabel;
    if (chartData.lastXLabel) macroParams['x-label-end'] = chartData.lastXLabel;
    macroParams['x-label-step'] = chartData.xLabelInterval || '1';
    if (chartData.chartTitle) macroParams.title = chartData.chartTitle;
    if (chartData.chartSize) macroParams['chart-size'] = chartData.chartSize;
    if (chartData.labelFontAngle) macroParams['label-font-angle'] = chartData.labelFontAngle;
    if (chartData.xAxisTitle) macroParams['x-title'] = chartData.xAxisTitle;
    if (chartData.yAxisTitle) macroParams['y-title'] = chartData.yAxisTitle;
    if (chartData.legendPosition) macroParams['legend-position'] = chartData.legendPosition;
    macroParams['show-guide-lines'] = chartData.showGuideLines;
    if ($j.isEmptyObject(chartData.seriesParameter) && isForChartBuilder) chartData.seriesParameter = dummySeriesParameter;
    this.addSeriesParameter(chartData.seriesParameter,macroParams);

    return {
      'stacked-bar-chart': macroParams
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
      seriesMql.hidden = series.hidden;
      seriesMql.combine = series.combine;
      if(series.project) seriesMql.project = series.project;
      macroParams.series = macroParams.series || [];
      macroParams.series.push(seriesMql);
    }
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
