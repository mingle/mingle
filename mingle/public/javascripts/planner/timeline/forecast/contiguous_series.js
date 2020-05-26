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
Timeline.Forecast.ContiguousSeries = Class.create({
  name: "",
  data: [],
  
  initialize: function(name, data, color) {
    this.name = name;
    this.data = data;
    this.color = color;
  },
  
  getData: function()  {
    var seriesData = {
      name: this.name,
      color: this.color
    };
    var lastDataElementPosition = this.data.length - 1;
    this.data[lastDataElementPosition] = { 
        dataLabels: {
          enabled: true,
          backgroundColor: "white",
          padding: 0,
          style: {
            fontWeight: 'bold'
          },
          color: 'black'
        },
        y: this.data[lastDataElementPosition].y,
        x: this.data[lastDataElementPosition].x
     };
    seriesData.data = this.data;
    return seriesData;
  } 
  
});