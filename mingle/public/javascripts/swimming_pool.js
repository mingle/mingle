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
var SwimmingPool = Class.create();

SwimmingPool.DistanceRuler = Class.create({
  initialize: function(points){
    this.points = points;
  },

  nearestIndexToExcludingDraggable: function(toPoint, draggableIndex){
    var pointsExcludingDraggable = this.points.without(this.points[draggableIndex]);

    var distances = pointsExcludingDraggable.collect(function(point){
      return this._distanceBetween(toPoint, point);
    }.bind(this));

    var minDistance = distances.min();
    return distances.indexOf(minDistance);
  },

  _distanceBetween: function(point1, point2) {
    return (point1[0] - point2[0]) * (point1[0] - point2[0]) + (point1[1] - point2[1]) * (point1[1] - point2[1]);
  }
});