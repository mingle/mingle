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
Timeline.Forecast.Mark = Class.create({
  initialize: function(name, color, symbol) {
    this.name = name;
    this.color = color;
    this.symbol = symbol;
  },

  seriesData: function(startPoint, endPoint) {
    return {
      name: this.name,
      data: [{
        marker: {
            radius: 0
        },
        y: startPoint.y,
        x: startPoint.x
      },
      {
        y: endPoint.y,
        x: endPoint.x,
        dataLabels: {
          enabled: true,
          backgroundColor: "white",
          padding: 0,
          y: -10,
          formatter: function() {
            return Highcharts.dateFormat('%e %b %Y', this.x);
          },
          style: {
            fontWeight: 'bold',
            fontSize: '12px'
          },
          color: "black"
        }
      }],
      color: this.color,
      dashStyle: 'dash',
      lineWidth: 1,
      marker: {
        enabled: true,
        symbol: this.symbol,
        radius: 5
      }
    };
  }
});