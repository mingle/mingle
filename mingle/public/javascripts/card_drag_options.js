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
CardDragOptions = Class.create();
CardDragOptions.prototype = {
  CLICK_MOVE_THRESHOLD: 9, //How far the mouse move still makes us think that user is clicking, not dragging, in px

  /*
    pool interface:
     {
       attrs: popups
       events: onStartDrag
     }
  */

  initialize: function(pool) {
    this.pool = pool;
  },

  excludeElement: function(src) {
    return src.tagName.toLowerCase() === 'a' || src.hasClassName('avatar');
  },

  revert: function(element) {
    return $(element).revertStatus;
  },

  onStart: function(draggable, event) {
    if(draggable.options.dragElement && Object.isFunction(draggable.options.dragElement)){
        draggable._originalElement = draggable.element;
        draggable.element = draggable.options.dragElement(draggable.element);
    }
    this.startX = Event.pointerX(event);
    this.startY = Event.pointerY(event);

    if (this.pool.onStartDrag) {
      this.pool.onStartDrag(draggable);
    }
    draggable.element.revertStatus = true;
    draggable.element.select('a').each(function(link) {
      link._href = link.href;
      link.href = "javascript:void(0)";
    });

    draggable.element.addClassName('node-on-dragging');

  },

  // This function can *not* contain any heavily calculations...
  onDrag: function(draggable, event) {
    // if user haven't move the mouse far, we assume he/she is still to popup card content
    if(this._offsetDistance(event) > this.CLICK_MOVE_THRESHOLD) {
      if(!draggable.element._isDragging) {
        draggable.element._isDragging = true;
      }
    }

  },

  onDropped: function(element) {
    if ($(element).revertStatus === true) {
      $(element).revertStatus = 'failure';
    }
  },

  onEnd: function(draggable) {
    draggable.element.removeClassName('node-on-dragging');
    draggable.originalZ = '';
    //use the delay to make sure the popup does not happen on the end of the drag
    setTimeout(function() {
      draggable.element._isDragging = false;

      draggable.element.select("a").each(function(link) {
        link.href = link._href;
      });

      // move to setTimeOut function because of bug #4926
      if(draggable.options.dragElement && Object.isFunction(draggable.options.dragElement)){
          draggable.element = draggable._originalElement;
          draggable._originalElement = null;
      }
      draggable.element.setStyle({zIndex: ''});
    }.bind(this), 50);
  },

  _offsetDistance: function(mouseEvent) {
    if(!mouseEvent){
      //Preventing IE bug
      return 0;
    }
    var deltaX = Event.pointerX(mouseEvent) - this.startX;
    var deltaY = Event.pointerY(mouseEvent) - this.startY;
    return Math.sqrt(deltaX * deltaX + deltaY * deltaY);
  }
};
