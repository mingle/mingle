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
Timeline.ObjectiveEditor = Class.create({
  initialize: function(mainView, objective, objectiveElement) {
    this.mainView = mainView;

    this.objective = objective;
    this.objectiveElement = objectiveElement;

    this.onMouseMoveEventHandler = this.onMouseMove.bindAsEventListener(this);
    this.onMouseUpEventHandler = this.onMouseUp.bindAsEventListener(this);

    this.objectiveElementCursor = this.objectiveElement.getStyle('cursor');
    this.rightHandle = this.objectiveElement.down('.right_handle');
    this.leftHandle = this.objectiveElement.down('.left_handle');

    Event.observe(this.rightHandle, 'mousedown', this.onMouseDown.bindAsEventListener(this));
    Event.observe(this.leftHandle, 'mousedown', this.onMouseDown.bindAsEventListener(this));
    Event.observe(this.rightHandle, 'click', this._doNothing.bindAsEventListener(this));
    Event.observe(this.leftHandle, 'click', this._doNothing.bindAsEventListener(this));

    this.draggable = new Draggable(this.objectiveElement, {
      onStart: this.onStartDragObjective.bind(this),
      onDrag: this.onUpdatePosition.bind(this),
      onEnd: function(draggable) {
        this.objective.onMove();
        this.onEndDragObjective();
      }.bind(this),
      snap: this.objective.snap.bind(this.objective)
    });
  },

  _doNothing: function (e) {
    Event.stop(e);
    return false;
  },

  onStartDragObjective: function(draggable) {
    this.objective.disablePopups();
    this.objective.disableLinks();
    this.mainView._setCaptureForIE(this.objectiveElement);

    Timeline.PopupManager.instance.closeAll();
    this.mainView.startDragItem('move', function(lastPointer) {
      draggable.draw([lastPointer.x, lastPointer.y]);
    }.bind(this));
  },

  onUpdatePosition: function(draggable, event) {
    var objective = this.objective;
    objective.onMove();
    var text = Timeline.DateUtils.format(objective.startDate) + " - " + Timeline.DateUtils.format(objective.endDate);
    this.objective.updateDateTooltip(text, "center", Pointer.Methods.fromEvent(event));
  },
  
  onEndDragObjective: function() {
    this.mainView._releaseCaptureForIE(this.objectiveElement);
    this.mainView.stopDragItem();
    this.saveObjective();
    setTimeout(function () {
      this.objective.enablePopups();
      this.objective.enableLinks();
    }.bind(this), 200);
  },

  onMouseDown: function(e) {
    Event.stop(e);
    if (!Event.isLeftClick(e)) {
      return false;
    }
    this.objective.disablePopups();
    this.objective.disableLinks();

    this.draggingHandle = e.element();
    var cursor;

    this.mainView._setCaptureForIE(this.draggingHandle);
    Timeline.PopupManager.instance.closeAll();

    if (this.draggingHandle == this.leftHandle) {
      cursor = 'w-resize';
    } else {
      cursor = 'e-resize';
    }

    this.snapDelta = Pointer.Methods.fromEvent(e).snapDelta(this.draggingHandle, this.draggingHandle == this.leftHandle);
    this.mainView.startDragItem(cursor, this._dragHandleTo.bind(this));

    Event.observe(document, 'mousemove', this.onMouseMoveEventHandler);
    Event.observe(document, 'mouseup', this.onMouseUpEventHandler);
  },

  onMouseUp: function(e) {
    this.mainView._releaseCaptureForIE(this.draggingHandle);

    this.mainView.stopDragItem();

    this.objectiveElement.setStyle({ cursor: this.objectiveElementCursor });
    Event.stopObserving(document, 'mousemove', this.onMouseMoveEventHandler);
    Event.stopObserving(document, 'mouseup', this.onMouseUpEventHandler);
    this.saveObjective();
    this.objective.enablePopups();
    this.objective.enableLinks();
  },

  onMouseMove: function(e) {
    this._dragHandleTo(Pointer.Methods.fromEvent(e));
  },

  _dragHandleTo: function(pointer) {
    var objective = this.objective;
    objective.disablePopups();
    var relativePointer = pointer.relativeTo(this.mainView.element);
    var dateCol, snappedCoords;

    if (this.draggingHandle == this.rightHandle) {
      snappedCoords = objective.snap(relativePointer.x + this.snapDelta, 0);
      dateCol = objective.mainViewContent.findDateAndColumnByPointerX(snappedCoords[0] - objective.mainViewContent.getSnapGridWidth());
      if (dateCol.date < objective.startDate || dateCol.date > this.mainView.content.lastDay()) {
        return;
      }
      objective.endDate = dateCol.date;
      objective._updateElementPosition();

      objective.rightHandleTooltip.updatePosition();
    }

    if (this.draggingHandle == this.leftHandle) {
      snappedCoords = objective.snap(relativePointer.x + this.snapDelta, 0);
      dateCol = objective.mainViewContent.findDateAndColumnByPointerX(snappedCoords[0]);
      if (dateCol.date > objective.endDate) {
        return;
      }
      objective.startDate = dateCol.date;
      objective._updateElementPosition();

      objective.leftHandleTooltip.updatePosition();
    }
  },

  saveObjective: function() {
    ObjectivesController.update(this.objective);
  },

  dispose: function() {
    this.rightHandle.stopObserving();
    this.leftHandle.stopObserving();
    this.draggable.destroy();
  }
});
