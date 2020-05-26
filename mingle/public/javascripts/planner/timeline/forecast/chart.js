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
Timeline.Forecast.Chart = {
  render: function(minXAxis, series) {
    return new Highcharts.Chart({
      series: series,
      chart: {
        renderTo: 'lightbox_inner',
        width: 640,
        height: 420,
        marginTop: 25
      },
      legend: {
        width: 450,
        itemWidth: 150,
        itemStyle: {
          color: '#000000'
        },
        itemHoverStyle: {
          color: '#000000'
        }
      },
      credits: {
        enabled: false
      },
      title: {
        text: ""
      },
      xAxis: {
        type: 'datetime',
        min: minXAxis,
        maxPadding: 0.07,
        dateTimeLabelFormats: {
          week: '%e %b',
          month: '%b %Y',
          day: '%e %b',
          year: '%Y'
        },
        lineWidth: 1,
        lineColor: "black",
        tickColor: 'black',
        tickWidth: 1,
        labels: {
          x: -5,
          y: 25,
          rotation: 315
        }
      },
      yAxis: {
        title: {
          text: 'Work Item Count'
        },
        min: 0,
        lineWidth: 1,
        lineColor: "black",
        tickColor: 'black',
        tickWidth: 1,
        alternateGridColor: '#F1F1F1',
        allowDecimals: false
      },
      tooltip: {
        enabled: false
      },
      plotOptions: {
        series: {
          marker: {
            enabled: false,
            states: {
              hover: {
                enabled: false
              }
            }
          },
          events: {
            legendItemClick: function(event) {
              return false;
            }
          }
        },
        line: {
          lineWidth: 1.5,
          shadow: false
        }
      }
    });
  }
};