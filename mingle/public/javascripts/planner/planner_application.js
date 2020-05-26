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
// Place your application-specific JavaScript functions and classes here
// This file is automatically included by javascript_include_tag :defaults

Element.MethodExts = {
  cumulativeRectangle: function(element){
    var offset = element.cumulativeOffset();
    return new Rectangle({left : offset[0], width: element.getWidth(), top: offset[1], height: element.getHeight()});
  },
  positionedRectangle: function(element){
    var offset = element.positionedOffset();
    return new Rectangle({left : offset[0], width: element.getWidth(), top: offset[1], height: element.getHeight()});
  }
};

Element.addMethods(Element.MethodExts);

ElementHelper = {
  createClearFloatDiv: function() {
    var element = new Element('div');
    element.addClassName('clear-float');
    return element;
  }
};

Rectangle = Class.create({
  initialize: function(raw){
    this.left = raw.left;
    this.top = raw.top || 0;
    this.width = raw.width || 0;
    this.height = raw.height || 0;
    this.right = this.left + this.width;
    this.bottom = this.top + this.height;
    this.xAxis = new Line(this.left, this.width);
    this.yAxis = new Line(this.top, this.height);
  },
  

  distance: function(rect) {
    return {
      x: this.xAxis.sub(rect.xAxis),
      y: this.yAxis.sub(rect.yAxis)
    };
  }
});

Line = Class.create({
  initialize: function(startPoint, length) {
    this.startPoint = startPoint;
    this.length = length;
    this.endPoint = this.startPoint + this.length;
  },

  sub: function(line) {
    if (line.startPoint < this.startPoint && line.endPoint > this.endPoint) {
      throw 'Could not sub a line that contains current line';
    }
    if (line.startPoint < this.startPoint) {
      return line.startPoint - this.startPoint;
    } 
    if (line.endPoint > this.endPoint) {
      return line.endPoint - this.endPoint;
    }
    return 0;
  }
});


Pointer = Class.create({
  initialize: function(x, y) {
    this.x = x;
    this.y = y;
  },

  inspect: function() {
    return "x: " + this.x + ", y: " + this.y;
  },

  equals: function(pointer) {
    if (!pointer) {
      return false;
    }
    return this.x == pointer.x && this.y == pointer.y;
  },

  relativeTo: function(element) {
    var newPointer = Object.clone(this);
    var offset = $(element).cumulativeOffset();

    newPointer.x = this.x - offset[0];
    newPointer.y = this.y - offset[1];

    return newPointer;
  },
  snapDelta: function(element, toLeftBorder) {
    return Pointer.Methods.snapDelta(this, element, toLeftBorder);
  }
});

Pointer.Methods = {
  snapDelta: function(pointer, element, toLeftBorder) {
    var relativePoint = pointer.relativeTo(element);
    if (toLeftBorder) {
      return -relativePoint.x;
    } else {
      return element.getWidth() - relativePoint.x;
    }
  },
  fromEvent: function(e) {
    var x = Event.pointerX(e);
    var y = Event.pointerY(e);
    return new Pointer(x, y);
  }
};
