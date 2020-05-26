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

Module.mixin(TreeView, {
  initScrollingWidget: function(controllPanel) {
    new ScrollingWidget(this.canvas.draggableMap, controllPanel);
  }
});

var ScrollingWidget = Class.create({
  initialize: function(map, controllPanel) {
    this.map = map;
    this.controllPanel = $(controllPanel);
    var buttons = this.controllPanel.select('a');
    buttons.each(this.bindButtonBehaviour.bind(this));
  },
  
  bindButtonBehaviour: function(button){
    var directionStr = button.className;
    var hotKey = Event['KEY_' + directionStr.toUpperCase()];
    var buttonAction = function() {
      this.map.moveViewPort(Direction[directionStr]);
    }.bind(this);

    new Button(button, buttonAction, hotKey);
  }
});