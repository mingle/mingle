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

PopupNodeBehavior = {
  CLICK_MOVE_THRESHOLD: 9, //How far the mouse move still makes us think that user is clicking, not dragging, in px

  spinner: function() {
    return $(this.element).select('.spinner').first();
  },

  setPopupCollection: function(popups) {
    if(!this.isRoot()) {
      this.popups = popups;
      var observee = this.innerElement();
      observee.observe('click', this.showPopup.bindAsEventListener(this));
      observee.observe('mousedown', this.onMousedown.bindAsEventListener(this));
    }
    this.children.each(function(child){ child.setPopupCollection(popups); });
  },

  onMousedown: function(event) {
    this.startX = Event.pointerX(event);
    this.startY = Event.pointerY(event);
  },

  popupOwner: function(){
    return this.innerElement();
  },

  /* jshint ignore:start */
  /*jsl:ignore*/
  showPopup: function(event) { with(this) {
    if(this._offsetDistance(event) > CLICK_MOVE_THRESHOLD || this.element._isDragging) {return true;}
    if (this.element.ignoreOnClick) {
      this.element.ignoreOnClick = false;
      return true;
    }
    popups.show(this, event);
  }},
  /*jsl:end*/
  /* jshint ignore:end */

  _offsetDistance: function(mouseEvent) {
    var deltaX = Event.pointerX(mouseEvent) - this.startX;
    var deltaY = Event.pointerY(mouseEvent) - this.startY;
    return Math.sqrt(deltaX * deltaX + deltaY * deltaY);
  }
};
