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
MingleUI.EasyCharts.DailyHistoryChart = (MingleUI.EasyCharts.DailyHistoryChart || {});

MingleUI.EasyCharts.DailyHistoryChart.MacroBuilder = function (chartData, isForChartBuilder) {
  var macroParams = {};
  var dummySeriesParameter = {'series1': {
      filters: chartData.cardFilters,
      label: 'Series 1'
  }};

  function chartConditions(filters) {
    return new MQLBuilder({
      additionalConditions: filters
    }).buildConditionsClause() || '"Type" = "card_type"';
  }


  this.build = function () {
    if (chartData.chartTitle) macroParams.title = chartData.chartTitle;
    macroParams['chart-conditions'] = chartConditions(chartData.cardFilters);
    macroParams.aggregate = new MQLBuilder({aggregateType: chartData.aggregate, aggregateProp: chartData.aggregateProperty}).buildAggregate() || 'aggregate';
    macroParams['start-date'] = chartData.startDate || 'dd mmm yyyy';
    macroParams['end-date'] = chartData.endDate || 'dd mmm yyyy';
    macroParams['x-labels-step'] = chartData.xLabelInterval || 7;
    if (chartData.chartSize) macroParams['chart-size'] = chartData.chartSize;
    if (chartData.labelFontAngle) macroParams['label-font-angle'] = chartData.labelFontAngle;
    if (chartData.xAxisTitle) macroParams['x-title'] = chartData.xAxisTitle;
    if (chartData.yAxisTitle) macroParams['y-title'] = chartData.yAxisTitle;
    if (chartData.legendPosition) macroParams['legend-position'] = chartData.legendPosition;
    macroParams['show-guide-lines'] = chartData.showGuideLines === undefined? true : chartData.showGuideLines;
    addForecastingOptions();
    if ($j.isEmptyObject(chartData.seriesParameter) && isForChartBuilder) chartData.seriesParameter = dummySeriesParameter;
    addSeriesParameter(chartData.seriesParameter);
    return {
      'daily-history-chart': macroParams
    };
  };

  function addForecastingOptions() {
    var forecastingOptions = chartData.forecastingParameter;
    if ( $j.isEmptyObject(forecastingOptions) ) return;
    if (forecastingOptions.scopeSeries) macroParams['scope-series'] = forecastingOptions.scopeSeries;
    if (forecastingOptions.completionSeries) macroParams['completion-series'] = forecastingOptions.completionSeries;
    if (forecastingOptions.targetReleaseDate) macroParams['target-release-date'] = forecastingOptions.targetReleaseDate;

  }

  function addSeriesParameter(seriesParameter) {
    for (var name in seriesParameter) {
      var seriesMql = {};
      var series = seriesParameter[name];
      seriesMql.conditions = chartConditions(series.filters);
      if (series.label) seriesMql.label = series.label;
      if (series.color) seriesMql.color = series.color;
      macroParams.series = macroParams.series || [];
      macroParams.series.push(seriesMql);
    }
  }

  this.buildCardCountMql = function () {
    var cardCountMql = 'Select count(*)';
    if (chartData.cardFilters && chartData.cardFilters.length) {
      var whereClause = chartConditions(chartData.cardFilters);
      whereClause && (cardCountMql += ' where ' + whereClause);
    }
    return cardCountMql;
  };
};
