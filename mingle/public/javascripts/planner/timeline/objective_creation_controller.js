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
Timeline.ObjectiveCreationController = Class.create({
  initialize: function(mainView, readonlyMode) {
    this.mainView = mainView;
    this.onMouseMoveEventHandler = this.onMouseMove.bindAsEventListener(this);
    if(!readonlyMode) {
      this.mainView.content.observeContentBody('mousedown', this.onMouseDown.bindAsEventListener(this));
    }
    Event.observe(document, 'keyup', this.onKeyUp.bindAsEventListener(this));
    Event.observe(document, 'mouseup', this.onMouseUp.bindAsEventListener(this));
  },
  
  showError: function(objective, errors) {
    if (this.objectiveCreation) {
      this.objectiveCreation.showError(objective, errors);
    }
  },

  onMouseUp: function(e) {
    this.mainView._releaseCaptureForIE(this.mainView.content.objectiveContainer);
    this.endCreation(Pointer.Methods.fromEvent(e));
  },

  onMouseDown: function(e) {
    if (!Event.isLeftClick(e) || Event.element(e).tagName.toLowerCase() == 'input') {
      return;
    }

    this.mainView._setCaptureForIE(this.mainView.content.objectiveContainer);
    this.startCreation(Pointer.Methods.fromEvent(e));
  },

  onMouseMove: function(e) {
    this.dragTo(Pointer.Methods.fromEvent(e));
  },

  onKeyUp: function(e) {
    if(e.keyCode == Event.KEY_ESC) {
      this.clear();
      return;
    }
    return true;
  },

  startCreation: function(pointer) {
    if (this.objectiveCreation) {
      this.objectiveCreation.clear();
      this.objectiveCreation = null;
    }
    this.mainView.observeScroll(this.dragTo.bind(this));
    this.objectiveCreation = new Timeline.ObjectiveCreation(this.mainView.content);
    this.objectiveCreation.startOn(pointer);

    Event.observe(document, 'mousemove', this.onMouseMoveEventHandler);
  },

  endCreation: function(pointer) {
    this.mainView.stopObservingScroll();
    if (!this.objectiveCreation || this.objectiveCreation.isDropped) {
      return;
    }
    
    Event.stopObserving(document, 'mousemove', this.onMouseMoveEventHandler);
    this.objectiveCreation.dropOn(pointer);
  },

  dragTo: function(pointer) {
    var objective = this.objectiveCreation.placeHolderObjective;
    var relativePointer = pointer.relativeTo(this.mainView.element);
    var snappedCoords = objective.snap(relativePointer.x, 0);

    var dateCol = objective.mainViewContent.findDateAndColumnByPointerX(snappedCoords[0] - objective.mainViewContent.getSnapGridWidth());

    if (dateCol.date < objective.startDate) {
      return;
    }

    objective.endDate = dateCol.date;
    objective._updateElementPosition();
    var text = Timeline.DateUtils.format(objective.startDate) + " - " + Timeline.DateUtils.format(objective.endDate);
    objective.updateDateTooltip(text, "right");
  },

  clear: function() {
    Event.stopObserving(document, 'mousemove', this.onMouseMoveEventHandler);
    if (this.objectiveCreation) {
      this.objectiveCreation.clear();
      this.objectiveCreation = null;
    }
  }
});
