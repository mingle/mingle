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
Timeline.Forecast = Class.create({
  initialize: function(objective, projectId, projectName) {
    this.objective = objective;
    this.projectId = projectId;
    this.projectName = projectName;
  },

  show: function(forecastData) {
    ObjectivesController.workProgress(this.objective.id, this.projectId, function(json) {
      var progress = json.progress;
      var startDate = this.parseDate(this.objective.start_at);
      var lastDate = this.parseDate(progress.last().date);
      var series = this.convertToSeries(forecastData, startDate, lastDate, progress);
      Timeline.Forecast.Chart.render(startDate, series);
    }.bind(this));
  },

  convertProgressDataToSeries: function(progress) {
    return progress.inject({actual: [], completed: []}, function(memo, snapshot) {
        memo.actual.push({x: this.parseDate(snapshot.date), y: snapshot.actual_scope});
        memo.completed.push({x: this.parseDate(snapshot.date), y: snapshot.completed_scope});
        return memo;
    }.bind(this));
  },

  convertToSeries: function(forecastData, startDate, lastDate, progress) {
    var progressSeries = this.convertProgressDataToSeries(progress);
    var notLikelyForecast = forecastData['not_likely'];
    var series = [
      this.series('Actual Scope', progressSeries.actual, "gray"),
      this.series('Completed Scope', progressSeries.completed, "#0973B6")
    ];
    if (notLikelyForecast.no_velocity) {
      return series;
    }

    var lessLikelyForecast = forecastData['less_likely'];
    var likelyForecast = forecastData['likely'];
    series.push({
      name: 'Projected end date',
      data: [
        [lastDate, progressSeries.completed.last().y],
        this.forecastInfo(notLikelyForecast),
        this.forecastInfo(lessLikelyForecast),
        this.forecastInfo(likelyForecast)
      ],
      dashStyle: 'dash',
      color: "#0973B6",
      lineWidth: 1,
      marker: {
          enabled: false,
          radius: 0,
          hover: {
              enabled: false
          }
      }
    });
    return series.concat([
      {startDate: startDate, forecast: lessLikelyForecast, mark: new Timeline.Forecast.Mark('50% scope change', 'gray', 'triangle')},
      {startDate: startDate, forecast: likelyForecast, mark: new Timeline.Forecast.Mark('150% scope change', 'gray', 'circle')},
      {startDate: lastDate, forecast: notLikelyForecast, mark: new Timeline.Forecast.Mark('No scope change', 'gray', 'square')}
    ].map(this.markSeries()));
  },

  markSeries: function() {
    return function(item) {
      var startX = item.startDate;
      var endX = this.parseDate(item.forecast.date);
      var y = item.forecast.scope;
      return item.mark.seriesData({x: startX, y: y}, {x: endX, y: y});
    }.bind(this);
  },

  series: function(seriesName, scopeSeries, color) {
    var series = new Timeline.Forecast.ContiguousSeries(seriesName, scopeSeries, color);
    return series.getData();
  },

  forecastInfo: function(forecast) {
    return [this.parseDate(forecast.date), forecast.scope];
  },

  parseDate: function(dateString) {
    var date = dateString.split("T")[0].split("-");
    return Date.UTC(parseInt(date[0], 10), parseInt(date[1] - 1, 10), parseInt(date[2], 10));
  }

});