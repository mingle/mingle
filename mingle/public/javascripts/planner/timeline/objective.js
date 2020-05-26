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
Timeline.Objective = Class.create({

  initialize: function(objectiveData, mainViewContent) {
    this.mainViewContent = mainViewContent;
    this.refreshFromJson(objectiveData);
  },

  toJson: function() {
    return {  name: this.name,
              id: this.objectiveId,
              vertical_position: this.verticalPosition,
              start_at: this.startDate,
              end_at: this.endDate,
              url_identifier : this.urlIdentifier,
              total_work : this.total_work,
              work_done : this.work_done,
              late: this.late,
              start_delayed: this.startDelayed,
              sync_finished: this.syncFinished
            };
  },

  refreshFromJson: function(data) {
    this.name = data.name || "";
    this.objectiveId = data.id;
    this.verticalPosition = data.vertical_position;
    this.startDate = Timeline.DateUtils.toDate(data.start_at);
    this.endDate = Timeline.DateUtils.toDate(data.end_at);
    this.urlIdentifier = data.url_identifier;
    this.total_work = data.total_work;
    this.work_done = data.work_done;
    this.late = data.late;
    this.startDelayed = data.start_delayed;
    this.syncFinished = data.sync_finished;
  },

  remove: function() {
    this.element.model = null;
    this.element.remove();
    this.editor.dispose();
  },

  render: function(readonlyMode){
    this.objectiveDetailsPopup = new Timeline.Objective.DetailsPopup($("objective_popup_panel"), this);
    this.element = this._buildObjectiveElement();
    this.mainViewContent.objectiveContainer.appendChild(this.element);
    this._updateElementPosition();
    if(!readonlyMode) {
      this._addObjectiveEditor();
    }else {
      this.disableEditor();
    }

    this.pollUntilSyncComplete();
    this._setObjectiveNameMargin();
  },

  pollUntilSyncComplete: function() {
    if (this.syncFinished) {
      return;
    }

    setTimeout(function () {
      ObjectivesController.timelineObjective(this, function (json) {
        this.refreshFromJson(json);

        if (!this.syncFinished) {
          this.pollUntilSyncComplete();
        } else {
          this.updateWorkCount($('work_' + this.urlIdentifier));
          this.updateAlertSymbol();
        }
      }.bind(this));
    }.bind(this), 3000);
  },

  updateWorkCount: function (workCountDiv) {
    workCountDiv.addClassName('card_count').update(this.work_done + " / " + this.total_work);
    this._setObjectiveNameMargin();
  },

  onMove: function() {
    var position = this.element.cumulativeOffset();
    this.verticalPosition = this.mainViewContent.findRowByMousePointerY(position[1]);
    var daysApart = this.durationInDays() - 1;

    var startsAt = this.mainViewContent.findDateAndColumnByPointerX(position[0]);

    this.startDate = startsAt.date;
    this.endDate = Timeline.DateUtils.addDays(this.startDate, daysApart);
  },

  snap: function(x, y, draggable) {
    var gridEdgeOffset = this.mainViewContent.visibleOffsetFromLeftGrid();
    var adjustedCoordinates = this._limitToContainer(x, y, draggable, gridEdgeOffset);

    var snapped_x = Math.round(adjustedCoordinates.x / this.mainViewContent.getSnapGridWidth()) * this.mainViewContent.getSnapGridWidth();
    var snapped_y = Math.round(adjustedCoordinates.y / this.mainViewContent.rowHeight) * this.mainViewContent.rowHeight;

    return [snapped_x, snapped_y];
  },

  _limitToContainer: function(x, y, draggable, gridEdgeOffset) {
    var verticalLimit = (Timeline.ROWS - 1) * this.mainViewContent.rowHeight;

    if (draggable) {
      var containerWidth = this.mainViewContent.objectiveContainer.getWidth();
      var horizontalLimit = containerWidth - this.element.getWidth();

      if (x > horizontalLimit) {
        x = horizontalLimit;
      }
    } else {
		  x = x + gridEdgeOffset;
	}

    if (y > verticalLimit) {
      y = verticalLimit;
    }
    if (x < 0) {
      x = 0;
    }
    if (y < 0) {
      y = 0;
    }

    return {x: x, y: y};
  },

  durationInDays: function() {
    // we add 1 day because we are inclusive of the endDate. for example, if we created
    // a objective that started and ended on the same day, we would expect the duration to
    // be one day, not zero days as differenceInDays() would return.
    return Timeline.DateUtils.differenceInDays(this.startDate, this.endDate) + 1;
  },

  _updateElementPosition: function() {
    var startColumn = this.mainViewContent.findViewColumnByDate(this.startDate);
    var startDateColumnOffset = this._offsetFromColumnStart(startColumn);

    // calculate position and dimensions accounting for column snap
    var startColumnLeft = $(startColumn.index + '_column').positionedOffset()[0];
    var left = startColumnLeft + startDateColumnOffset;
    var width = this.mainViewContent.getDaysInPixels(this.durationInDays());

    // account for 1px borders on the left and right to make getWidth() return what we expect
    var accountForBorderWidth = 2;

    this.element.setStyle({
      left: left + 'px',
      top:  (this.verticalPosition * this.mainViewContent.rowHeight) + 'px',
      width: (width - accountForBorderWidth) + 'px'
    });
  },

  updateAlertSymbol: function() {
    if (this.late || this.startDelayed) {
      if (!this.symbolsContainer.down('.late')) {
        var alert = new Element('span');
        alert.addClassName('late');
        Tooltip(alert, "May not complete before " + Timeline.DateUtils.formatDateString(this.endDate));
        this.symbolsContainer.insert({"top": alert});
      }
    } else {
      var lateSymbol = this.symbolsContainer.down('.late');
      if (lateSymbol) {
        lateSymbol.remove();
      }
    }
    this._setObjectiveNameMargin();
  },

  updateDateTooltip: function(text, alignment, pointer) {
    var quickTip = this.mainViewContent.quickTip;
    quickTip.content.update(text);

    var coords = this.element.positionedOffset();
    var dimensions = quickTip.getDimensions();

    alignment = alignment || "left";

    var style = {
      display: "block",
      top: coords[1] + "px"
    };

    switch(alignment) {
      case "right":
        style.left = (coords[0] + this.element.getWidth() - dimensions.width) + "px";
        break;

      case "center":
        var tooltipMidpoint = Math.round(quickTip.getWidth() / 2);
        var limit = this.mainViewContent.getWidth() - tooltipMidpoint;
        var position = (pointer.x - this.mainViewContent.element.cumulativeOffset()[0] - tooltipMidpoint);

        if (position > limit) {
          position = limit;
        }

        style.left = position + "px";
        break;

      default:
        style.left = coords[0] + "px";
        break;
    }

    quickTip.anchor.className = "quick_tip_anchor anchor_" + alignment;
    quickTip.setStyle(style);
  },

  _offsetFromColumnStart: function(column) {
    var daysFromColumnStart = column.dateRange.daysAfterStart(this.startDate);
    return this.mainViewContent.getDaysInPixels(daysFromColumnStart);
  },

  _addObjectiveEditor: function() {
    this.editor = new Timeline.ObjectiveEditor(this.mainViewContent.mainView, this, this.element);
  },

  disableEditor: function() {
    if (this.editor) {
      this.editor.dispose();
    }
    this.editor = { dispose: function() {}};
  },

  _setObjectiveNameMargin: function () {
    if (!this.syncFinished || this.total_work > 0 || this.late) {
      var margin = $(this.symbolsContainer).getWidth() + 14;
      $j(this.objectiveName).css({"margin-right": margin + 'px'});
    } else {
      $j(this.objectiveName).removeAttr("style");
    }
  },

  _buildObjectiveElement: function() {
    var objective = new Element('div', { id: 'objective_' + this.urlIdentifier}).addClassName("objective").addClassName('moveable');
    this.objectiveName = new Element('span').addClassName('name').update(this.name.escapeHTML());
    var objectiveWorksInfo;

    var leftHandle = new Element('span').addClassName('left_handle');
    var rightHandle = new Element('span').addClassName('right_handle');

    var objectReference = this;
    this.leftHandleTooltip = Tooltip(leftHandle, function () { return Timeline.DateUtils.format(objectReference.startDate); }, {gravity: "sw"});
    this.rightHandleTooltip = Tooltip(rightHandle, function () { return Timeline.DateUtils.format(objectReference.endDate); }, {gravity: "se"});

    objective.appendChild(leftHandle);
    objective.appendChild(this.objectiveName);

    this.symbolsContainer = new Element('span');
    this.symbolsContainer.addClassName("symbols");
    if (!this.syncFinished) {
      objectiveWorksInfo = new Element('span', {id: 'work_' + this.urlIdentifier}).update('<img class="spinner" src="' + Images.path_for('spinner.gif') + '" />');
      Tooltip(objectiveWorksInfo, 'Synching...');
    } else if (this.total_work > 0) {
      objectiveWorksInfo = new Element('span', {id: 'work_' + this.urlIdentifier});
      this.updateWorkCount(objectiveWorksInfo);
      this.updateAlertSymbol();
    }
    if (objectiveWorksInfo) {
      this.symbolsContainer.appendChild(objectiveWorksInfo);
    }

    objective.appendChild(this.symbolsContainer);
    objective.appendChild(rightHandle);

    var disableLinkIfDragging = function(e) {
      if (objective.preventLink) {
        Event.stop(e);
        return false;
      } else {
        this.disablePopups();
      }
    }.bind(this);

    objective.select("a").each(function(el) {
      el.observe("click", disableLinkIfDragging);
    });

    objective.allowPopup = true;
    objective.preventLink = false;

    objective.observe('click', function(e) {
      objective.fire('objective:show_popup', { x: Event.pointerX(e), y: Event.pointerY(e) });
    });

    objective.observe('objective:show_popup', this._showPopup.bindAsEventListener(this, false));

    // it's useful to be able to reference the objective model,
    // particularly for testing
    objective.model = this;
    return objective;
  },

  enablePopups: function() {
    this.element.allowPopup = true;
  },

  disablePopups: function() {
    this.element.allowPopup = false;
  },

  disableLinks: function() {
    this.element.preventLink = true;
  },

  enableLinks: function() {
    this.element.preventLink = false;
  },

  _showPopup: function(event, alerts_only) {
    if (this.element.allowPopup && this.syncFinished) {
      this.objectiveDetailsPopup.show(new Pointer(event.memo.x, event.memo.y), alerts_only);
    }
  }
});

Timeline.PlaceholderObjective = Class.create(Timeline.Objective, {

  initialize: function($super, objectiveData, mainViewContent, options) {
    $super(objectiveData, mainViewContent, options);
  },

  _buildObjectiveElement: function(){
    return new Element('div').addClassName('objective objective-place-holder');
  },

  remove: function() {
    this.element.remove();
  },

  render: function(){
    this.element = this._buildObjectiveElement();
    this.mainViewContent.objectiveContainer.appendChild(this.element);
    this._updateElementPosition();
  }

});
