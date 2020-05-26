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
Timeline.MainViewContent = Class.create({
  
  initialize: function(element, plan, today) {
    if (!today) {
      today = new Date();
    }
    this.today = Timeline.DateUtils.resetDay(Timeline.DateUtils.toDate(today));
    this.rowHeight = 30;
    this.element = element;
    this.objectiveContainer = $("objective_container");
    this.planCalendar = new Timeline.PlanCalendar(plan);
    this.addObjectivePanel = $$('.add_objective_panel')[0];
    this.objectives = [];
    this.informingMessageBox = $('informing_message_box');
    this.initQuickTip();
  },

  updateObjective: function(objectiveJson) {
    var objectiveToUpdate = this.objectives.find(function (objective) { return objective.objectiveId == objectiveJson.id; });
    objectiveToUpdate.refreshFromJson(objectiveJson);
    objectiveToUpdate.updateAlertSymbol();
  },

  firstDay: function() {
    return this.viewColumns[0].dateRange.start;
  },

  lastDay: function() {
    return this.viewColumns.last().dateRange.end;
  },

  initQuickTip: function() {
    var quickTip = $("quick_info");
    quickTip.content = $("tip_content");
    quickTip.anchor = $("tip_anchor");

    quickTip.content.update("");
    quickTip.setStyle({display: "none"});

    Event.observe(document, "mouseup", function(event) {
      quickTip.hide();
    }.bind(this));

    this.quickTip = quickTip;
  },

  clearObjectives: function() {
    var existingObjectives = this.objectives;
    existingObjectives.invoke('remove');
    this.objectives = [];
    return existingObjectives.invoke('toJson');
  },

  addObjectivesFromJSON: function(objectives, readonlyMode) {
    objectives.each(function(objective){
      this.addObjective(objective, readonlyMode);
    }.bind(this));
  },

  setMainView: function(mainView) {
    this.mainView = mainView;
  },

  distanceToViewColumn: function(viewColumn) {
    if (viewColumn) {
      var columnInView = this.findViewColumnByDate(viewColumn.dateRange.start);
      if (columnInView) {
        return $(columnInView.index + "_column").positionedOffset()[0];
      }
    }
    return 0;
  },

  getPrecision: function() {
    return Timeline.PRECISION[this.currentGranularity];
  },

  getSnapGridWidth: function() {
    return Timeline.GRID_SIZE[this.currentGranularity];
  },

  getDaysInPixels: function(days) {
    return days * this.getSnapGridWidth();
  },

  _makeKey: function(positionX) {
    var direction = positionX < 0 ? -1 : 1;
    var base = Math.abs(positionX);
    var key = (base - (base % 1000)) * direction;
    return key;
  },

  // indexes a column based on its horizontal position
  storeColumn: function (positionX, column) {
    if (!this.columnLookup) {
      this.columnLookup = $H();
    }

    var key = this._makeKey(positionX);

    if (!this.columnLookup[key]) {
      this.columnLookup[key] = $A();
    }
    this.columnLookup[key].push(column);
  },

  // retrieves a column based on its horizontal position
  retrieveColumn: function (positionX) {
    if (!this.columnLookup) {
      this.columnLookup = $H();
    }

    var key = this._makeKey(positionX);
    var previousKey = key - 1000;

    if (!this.columnLookup[key]) {
      return undefined;
    }

    var select = function(col) {
      var el = $(col.index + '_column');
      var left = el.positionedOffset()[0];
      var right = left + el.getWidth();
      return positionX >= left && positionX < right;
    };

    var result = this.columnLookup[key].find(select);

    // worst case, search previous column if exists
    if (!result) {
      if (this.columnLookup[previousKey]) {
        result = this.columnLookup[previousKey].find(select);
      }
    }

    return result;
  },

  buildViewColumns: function(granularity) {
    this.currentGranularity = granularity;
    this.columnLookup = $H();
    this.viewColumns = this.planCalendar[granularity]().collect(function(value, index) {
      return {label: value.formatAs(granularity), index: index, dateRange: value};
    });

    var dates = "";
    var totalWidth = 0;
    var gridSize = this.getSnapGridWidth();
    var uniformColumnSize = granularity !== "months";

    // break this out into a function that takes a starting date, and a number of columns to create
    // while this seems like a weird way to build elements, it's the YUI team's recommendation
    // to batch element creation as a objective and set with innerHTML to reduce unnecessary DOM
    // manipulation costs
    for (var i = 0; i < this.viewColumns.length; i++) {
      var style = "";

      var viewColumn = this.viewColumns[i];
      var days = viewColumn.dateRange.durationInDays() + 1;

      var colWidth = days * gridSize;
      this.storeColumn(totalWidth, viewColumn);
      totalWidth += colWidth;

      if (!uniformColumnSize) {
        style = " style='width: " + (colWidth - 1) + "px' ";
      }

      dates += '<li id="' + i + '_column"' + style + '>' + this.viewColumns[i].label + '</li>';
    }
    $('date_header').update(dates);

    // in non-uniform column views, this errs on the larger side for safety
    var totalDays = Timeline.DateUtils.differenceInDays(this.viewColumns.first().dateRange.start, this.viewColumns.last().dateRange.end);
    totalWidth = (totalDays + 1)  * gridSize +"px";
    var totalHeight = (Timeline.ROWS * this.rowHeight) + "px";
    
    this.element.setStyle({width: totalWidth, height: 0});
    $('date_header').setStyle({width: totalWidth});
    this.objectiveContainer.setStyle({width: totalWidth, height: totalHeight});

    // setting this class should set the column backgrounds and heading widths
    this.element.className = granularity;

    this.addTodayMarker();
  },

  addTodayMarker: function() {
    if (this.planCalendar.range.contains(this.today)) {
      var markerDiv = $('today_marker');
      if (!markerDiv) {
        markerDiv = new Element('div', { id: "today_marker" });
        this.element.appendChild(markerDiv);
      }
      markerDiv.setStyle({
        width: this.getSnapGridWidth() + "px",
        height: this.objectiveContainer.getHeight() + "px",
        left: this.findTodayLocationOnTimeline() + "px"
      });
    }
  },

  // calculates an exact date (not just column bounds) and provides the view column
  // given an x-coordinate on the screen
  findDateAndColumnByPointerX: function(pointerX) {
    // adjust x to account for the relative position of the content container, in the case
    // that we've scrolled the objectives.
    var x = pointerX - this.element.cumulativeOffset()[0];
    var column = this.retrieveColumn(x);

    if (!column) {
      // assume we want the last one if we can't find it.
      // may have to adjust this when we lazy load columns
      column = this.viewColumns.last();
    }

    // find pixels from the column starting edge
    // we'll use this to figure out how many days
    // from the starting edge we are
    var element = $(column.index + "_column");
    var elementXOffset = element.positionedOffset()[0];
    var xOffset = x - elementXOffset;
    var offsetMax = element.getWidth() - this.getSnapGridWidth();
    if (xOffset > offsetMax) {
      xOffset = offsetMax;
    }

    var dayOffset = Math.floor(xOffset / this.getSnapGridWidth());
    
    var date = Timeline.DateUtils.addDays(column.dateRange.start, dayOffset);
    return {date: date, column: column};
  },

  findTodayColumn: function() {
    var column = this.findViewColumnByDate(this.today);
    if (!column) {
      return null;
    }
    return {"element": $(column.index + "_column"), "column": column};
  },

  findTodayLocationOnTimeline: function() {
    var today = this.findTodayColumn();
    var offset = this.getDaysInPixels(today.column.dateRange.daysAfterStart(this.today));

    return today.element.positionedOffset()[0] + offset;
  },

  findViewColumnByDate: function(value) {
    return this.viewColumns.detect(function(column) {

      return column.dateRange.contains(value);
    });
  },
  
  findRowByMousePointerY: function(pointerY) {
    var offsetTop = this.objectiveContainer.cumulativeOffset()[1];
    result = Math.floor((pointerY - offsetTop) / this.rowHeight);
    if (result < 0) {
      result = 0;
    }
    if (result > Timeline.ROWS) {
      result = Timeline.ROWS;
    }

    return result;
  },

  observeContentBody: function(eventName, handler) {
    Event.observe(this.objectiveContainer, eventName, handler);
  },

  // finds the width between the leftmost grid's lower edge and
  // the left edge of the viewport, for which we need to account
  // when snapping to dates after scrolling the content container
  visibleOffsetFromLeftGrid: function() {
    var contentX = -this.element.positionedOffset()[0];
    var leftMostGridLowerEdge = Math.floor(contentX / this.getSnapGridWidth()) * this.getSnapGridWidth();
    return contentX - leftMostGridLowerEdge;
  },

  cumulativeOffsetLeft: function() {
    return this.objectiveContainer.cumulativeOffset()[0];
  },

  cumulativeOffsetTop: function() {
    return this.objectiveContainer.cumulativeOffset()[1];
  },

  getWidth: function() {
    return this.element.getWidth();
  },

  moveTo: function(pointerX, finishCallback) {
    if (this.movingEffect) {
      this.movingEffect.cancel();
    }
    this.movingEffect = new Effect.Move(this.element, { x: pointerX, mode: 'absolute', duration: 0, afterFinish: function(effect) {
      var distance = effect.originalLeft - effect.element.positionedOffset()[0];
      finishCallback(distance);
    }});
  },

  renderInformingMessage: function() {
    this.objectives.size() == 0 ? this.showInformingMessageBox() : this.removeInformingMessageBox();
  },

  showInformingMessageBox: function() {
    if (this.informingMessageBox) {
      this.informingMessageBox.show();
    }
  },

  hideInformingMessageBox: function() {
    if (this.informingMessageBox) {
      this.informingMessageBox.hide();
    }
  },

  removeInformingMessageBox: function() {
    if (this.informingMessageBox) {
      this.informingMessageBox.remove();
      this.informingMessageBox = null;
    }
  },

  addObjective: function(objectiveJson, readonlyMode) {
    var objective = new Timeline.Objective(objectiveJson, this);
    this.objectives.push(objective);
    objective.render(readonlyMode);
  },

  updatePlan: function(planJson){
    this.planCalendar = new Timeline.PlanCalendar(planJson);
  }
});
