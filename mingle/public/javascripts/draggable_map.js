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

var DragTracker = Class.create();
DragTracker.prototype = {
  initialize: function(element, options) {
    this.element = $(element);
    this.mouseMoveListener = this.updateDrag.bindAsEventListener(this);
    Event.observe(this.element, 'mousedown', this.startDrag.bindAsEventListener(this));
    Event.observe(document.body, 'mouseup', this.endDrag.bindAsEventListener(this));
    this.options = Object.extend({
      onStart: Prototype.emptyFunction,
      onUpdate: Prototype.emptyFunction
    }, options || {});
  },

  startDrag: function(event) {
    if(this.dragExempted(event.element())) {return;}
    this.startX = Event.pointerX(event);
    this.startY = Event.pointerY(event);
    Event.observe(this.element, 'mousemove', this.mouseMoveListener, false);
    this.options.onStart(this.deltaX, this.deltaY);
  },

  updateDrag: function(event) {
    this.deltaX = Event.pointerX(event) - this.startX;
    this.deltaY = Event.pointerY(event) - this.startY;
    this.options.onUpdate(this.deltaX, this.deltaY);
    Event.stop(event);
    return false;
  },

  dragExempted: function(element) {
    if(!element) {return true;}
    return element.hasClassName('draggable-exemption') ||
      element.ancestors().any(function(ancestor) {
        return ancestor.hasClassName('draggable-exemption');
      });
  },

  endDrag: function(event) {
    Event.stopObserving(this.element, 'mousemove', this.mouseMoveListener);
  }
};

var BorderPatrol = Class.create({
  initialize: function(options) {
    this.top = options.top || 0;
    this.left = options.left || 0;
    this.height = options.height || 0;
    this.width = options.width || 0;
  },

  outsideDo: function(point, action) {
    if(this.isOutside(point)) {
      action(this, point);
    }
  },

  isOutside: function(point) {
    var x = point.x - this.left;
    var y = point.y - this.top;
    return x > this.width || y > this.height || x < 0 || y < 0;
  }
});

var AutoScrollWithDraggable = Class.create({
  initialize: function(map) {
    this.delta = 80;//px
    this.map = map;
    Draggables.addObserver({onDrag: this.onDragEvent.bind(this), onEnd: this.stopScrolling.bind(this)});
  },

  onDragEvent: function(eventName, draggable, event) {
    if(draggable.element.isOutside || !draggable.element.mapShouldFollowOnDrag) {
       return;
    }
    var point = {x: Event.pointerX(event), y: Event.pointerY(event)};

    this.needScrolling = false;
    this.autoScrollingDelay = 0.8;//sec

    this.map.outerBorder().outsideDo(point, function() {this.needScrolling = true;}.bind(this));

    if(!this.needScrolling) {
      this.stopScrolling();
      return;
    }

    if(!this.scrolling) {
      this.scrolling = true;
      this.moveDuration = null;
      this.map._onMapDragStart();
    }

    var newMoveDuration = Math.min(this.autoScrollingDelay - 0.1, 0.5);
    if(this.moveDuration != newMoveDuration) {
      this.moveDuration = newMoveDuration;
      if(this.pe) {this.pe.stop();}
      this.pe = new PeriodicalExecuter(function(pe) {
        if(!Draggables.activeDraggable) {
          this.stopScrolling();
          return;
        }
        this.centralizeOnActiveDraggableElement();
      }.bind(this), this.autoScrollingDelay);
    }
  },

  centralizeOnActiveDraggableElement: function() {
    Draggables.activeDraggable.element._autoscrolled = true;
    this.map.centralizeOn(Draggables.activeDraggable.element, this.movingAction.bind(this), this.moveDuration);
  },

  stopScrolling: function() {
    if(!this.scrolling) {return;}

    this.scrolling = false;
    if(this.pe) {this.pe.stop();}
  },

  movingAction: function(element, options) {
    element.effectMove(options);
  }
});

var Direction = {
  left: { ratioX: 1, ratioY: 0 } ,
  right: { ratioX: -1, ratioY: 0 },
  up: { ratioX: 0, ratioY: 1 },
  down: { ratioX: 0, ratioY: -1 }
};

var DraggableMap = Class.create({
  initialize: function(viewPortElement, mapElement) {
    this.startOffsetLeft = 0;
    this.startOffsetTop = 0;
    this.viewPortElement = $(viewPortElement);
    this.mapElement = $(mapElement);
    this.fixViewPortSize();
    this._makeMapDraggable();
    $j(document).on("mingle:relayout", this.fixViewPortSize.bindAsEventListener(this));
    this.topDelta = 30;
  },

  outerBorder: function() {
    var viewportPosition = this.viewPortElement.getScreenPosition();
    return new BorderPatrol({top: viewportPosition.top, left: viewportPosition.left, height: this.viewPortElement.offsetHeight, width: this.viewPortElement.offsetWidth});
  },

  isOutside: function(point) {
    return this.outerBorder().isOutside(point);
  },

  fixViewPortSize: function() {
    var contentElement = $(this.viewPortElement.parentNode);
    if(contentElement){
      contentElement.setStyle({height: this._mapHeight()});
      Position.clone(contentElement, this.viewPortElement);
    }
  },

  //  |------l1----------|
  //  *******************|***************
  //  * viewport         |              *
  //  *      ************|**********************
  //  * left *     ******|******        *  map *
  //  *----- *  l3 * centraed  *        *      *
  //  *      *-----* element   *        *      *
  //  *      *     ******|******        *      *
  //  *      *     |-l2--|              *      *
  //  *      *           |              *      *
  //  *******************|***************      *
  //         ************|**********************
  //                     |
  //  l1 = half of viewport's width
  //  l2 = half of centraed element's width
  //  l3 = centraed element to offset left to map
  //  because element is in the middle of view port
  //    left + l2 + l3 = l1
  //    left = l1 - l2 - l3
  //  simular with top calculation
  centralizeOn: function(element, moving, moveDuration, top) {
    moveDuration = moveDuration || 0.5;
    var element_offset_top = Object.isFunction(element.nodeOffsetTop) ? element.nodeOffsetTop() : element.offsetTop;
    var element_offset_left = Object.isFunction(element.nodeOffsetLeft) ? element.nodeOffsetLeft() : element.offsetLeft;
    var left = 0.5 * (this.viewPortElement.offsetWidth - element.offsetWidth) - element_offset_left;
    top = top || (0.5 * (this.viewPortElement.offsetHeight - element.offsetHeight) - element_offset_top);
    if(this.lastMovement) {this.lastMovement.cancel();}
    var newLeft = left - this.mapElement.offsetLeft;
    var newTop = top - this.mapElement.offsetTop;

    if(moveDuration && moveDuration < 0.01){
      this.mapElement.setStyle({left: left + 'px', top: top + 'px'});
    } else {
      this.lastMovement = new Effect.Move(this.mapElement, {x: newLeft, y: newTop, duration: moveDuration });
    }

    if(moving) {
      moving(element, {x: -(left - this.mapElement.offsetLeft), y: -(top - this.mapElement.offsetTop), duration: moveDuration });
    }
  },

  viewportCenter: function() {
    var x = this.viewPortElement.getWidth()/2 - this.mapElement.offsetLeft;
    var y = this.viewPortElement.getHeight()/2 - this.mapElement.offsetTop;
    return [x, y];
  },

  toplizeOn: function(element) {
    this.centralizeOn(element, false, 0.000001, this.topDelta);
  },

  toplize: function(x, y, width, height) {
    var left = x + width/2 - this.viewPortElement.offsetWidth/2;
    var top = y - 1 - this.topDelta;
    this._onMapDragging(-left, -top);
  },

  moveViewPort: function(direction) {
    var stepDistance = 40;
    var deltaX = direction.ratioX * stepDistance;
    var deltaY = direction.ratioY * stepDistance;
    this.mapElement.setStyle({
      left: this.mapElement.offsetLeft + deltaX + 'px',
      top: this.mapElement.offsetTop + deltaY + 'px'
    });
    EventCenter.trigger('viewportMove', {x: deltaX, y: deltaY});
    return this;
  },

  _mapHeight: function() {
    var reasonable = document.viewport.getHeight() * 0.75;
    return Math.max(reasonable, 570) + "px";
  },

  _makeMapDraggable: function() {
    new DragTracker(this.viewPortElement,
                    {onStart: this._onMapDragStart.bind(this), onUpdate: this._onMapDragging.bind(this)});
  },

  _onMapDragStart: function() {
    this.startOffsetLeft = this.mapElement.offsetLeft;
    this.startOffsetTop = this.mapElement.offsetTop;
  },

  _onMapDragging: function(deltaX, deltaY) {
    this.mapElement.style.left = this.startOffsetLeft + deltaX + 'px';
    this.mapElement.style.top = this.startOffsetTop + deltaY + 'px';
  }
});
var KeepDraggablePositionWhenViewportMoving = Class.create({
  initialize: function(map) {
    this.map = map;
    Draggables.addObserver({onStart: this.onStart.bind(this), onEnd: this.onEnd.bind(this)});
    this.onViewportMoveListener = this.onViewportMove.bind(this);
  },

  onStart: function(eventName, draggable, event){
    EventCenter.addListener('viewportMove', this.onViewportMoveListener);
    this.draggingObject = draggable;
  },

  onEnd: function(eventName, draggable, event){
    EventCenter.removeListener('viewportMove');
    this.draggingObject = null;
  },

  onViewportMove: function(eventName, parameters){
    var draggable = this.draggingObject;
    if(draggable){
      draggable.element.setStyle({
        left: parseInt(draggable.element.getStyle('left')) - parameters.x + 'px',
        top: parseInt(draggable.element.getStyle('top')) - parameters.y + 'px'
      });
    }
  }
});
