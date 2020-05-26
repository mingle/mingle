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
Timeline.Objective.Popup = Class.create({
  initialize: function(element, parentElement) {
    this.element = element;

    // stop propagation of mousedown events so we don't accidentally
    // trigger popups when clicking on the popup itself
    Event.observe(element, "mousedown", function(e) {
      if (Event.element(e).tagName.toLowerCase() !== "input") {
        Event.stop(e);
        return false;
      }
    });

    this.parentElement = parentElement;
    this.ARROW_WIDTH = 30; //we can't easily determine this dynamically :(
    this.popup = {width: this.element.getWidth(), height: this.element.getHeight()};
  },

  showNear: function(elementToShowNear, options) {
     var elementOffset = elementToShowNear.positionedOffset();
     var clickPoint = {x: elementOffset.left, y: elementOffset.top, distanceToObjectiveEnd: elementToShowNear.getWidth(), objectiveHeight: elementToShowNear.getHeight()};
     this.showAt(clickPoint, options);
  },

  showAt: function(clickPoint, options) {

    var offset = this._offset(clickPoint, options);

    this.element.down('.bottom_left').hide();
    this.element.down('.bottom_right').hide();
    this.element.down('.top_left').hide();
    this.element.down('.top_right').hide();

    offset.arrow.element = this.element.down('.' + offset.arrow.position + '_' + offset.arrow.horizontalPosition);
    offset.arrow.element.show();

    this.element.setStyle({
      left: offset.left + 'px',
      top: offset.top + 'px',
      display: 'block'
    });


    Timeline.PopupManager.instance.registerPopup(this);
  },

  _offset: function(clickPoint, options) {
    var offset_options = options || {};
    var result = { arrow: {} };
    this._calculateLeft(result, clickPoint, offset_options);
    this._calculateTop(result, clickPoint);

    return result;
  },

  _calculateTop: function(result, clickPoint) {
    result.top = clickPoint.y - this.popup.height;
    if (result.top < Timeline.Objective.Popup.UPPER_VERTICAL_LIMIT) {
      result.top = clickPoint.y + clickPoint.objectiveHeight;
      result.arrow.position = 'top';
    } else {
      result.arrow.position = 'bottom';
    }
  },

  _calculateLeft: function(result, clickPoint, options){
    this.distanceFromTipToPopupEdge = this._distanceFromTipToPopupEdge(result.arrow);
    this.distanceFromTipToObjectiveEdge = this._distanceFromTipToObjectiveEdge(this.distanceFromTipToPopupEdge, clickPoint.distanceToObjectiveEnd);

    result.arrow.horizontalPosition = options.align;

    if(options.align == 'left'){
      this._alignLeft(clickPoint, result, options);
    } else {
      result.left = this._offsetWithRightAlignment(clickPoint);
      if (options.alignTipToEdge) {
        result.left -= this.distanceFromTipToObjectiveEdge;
      }
      if (result.left < 0) {
        result.arrow.horizontalPosition = 'left';
        result.left = this._offsetWithLeftAlignment(clickPoint);
      }
    }
    if(this._willPopupExceedShowOnElementRightEdge(clickPoint)){
      result.arrow.horizontalPosition = 'right';
      result.left = clickPoint.x - this.popup.width + this.distanceFromTipToPopupEdge + this.distanceFromTipToObjectiveEdge;
      if (options.alignTipToEdge) {
        result.left -= this.distanceFromTipToObjectiveEdge;
      }
      if (this._willPopupExceedShowOnElementRightEdge(result)) {
        result.left = this.parentElement.getWidth() - this.popup.width;
      }
    }

    if (result.left < 0) {
      result.left = 0;
    }

  },

  _alignLeft: function(clickPoint, result, options) {
    result.left = this._offsetWithLeftAlignment(clickPoint);
    if (options.alignTipToEdge) {
      result.left -= this.distanceFromTipToPopupEdge;
    }
  },

  _offsetWithRightAlignment: function(clickPoint) {
    return clickPoint.x + clickPoint.distanceToObjectiveEnd - this.popup.width;
  },

  _offsetWithLeftAlignment: function(clickPoint) {
    var offset = clickPoint.x;
    if (clickPoint.distanceToObjectiveEnd < this.distanceFromTipToPopupEdge/2) {
      offset -= this.distanceFromTipToObjectiveEdge;
    }
    return offset;
  },

  _distanceFromTipToObjectiveEdge: function(tipOffset, objectiveWidth){
    return Math.min((tipOffset * 2), (objectiveWidth / 2));
  },

  _distanceFromTipToPopupEdge: function(arrow){
    return (this.ARROW_WIDTH / 2) + 20;
  },

  _willPopupExceedShowOnElementRightEdge: function(clickPoint){
    return (clickPoint.x + this.popup.width) > this.parentElement.getWidth();
  },

  close: function() {
    this.element.hide();
  }

});

// popups should not be vertically positioned above this y-coordinate
// this allows popup to cover the date headings, which is more acceptable than
// having the bottom of the popup covered by the scrollbar.
Timeline.Objective.Popup.UPPER_VERTICAL_LIMIT = -30;


Timeline.Objective.DetailsPopup = Class.create(Timeline.Objective.Popup, {
  initialize: function($super, element, objective) {
    this.objective = objective;
    this.closeLink = $$(".objective_popup_panel .close").first();
    this.closeLink.observe('click', this.close.bindAsEventListener(this));
    $super(element, this.objective.mainViewContent.objectiveContainer);
  },

  show: function(pointer, alerts_only) {
    TimelineStatus.instance.start('objective_details_popup');
    $("objective_details_contents").update('<span class="loading_message">loading...</span>');
    this.alerts_only = alerts_only;
    var objectiveElement = this.objective.element;
    var offset = objectiveElement.positionedOffset();
    var dimensions = objectiveElement.getDimensions();

    var absolutePointerX = pointer.relativeTo(this.parentElement).x; //+ 8;
    var options = { align : 'left', alignTipToEdge: true };
    var clickPoint = { x: absolutePointerX, y: offset[1], distanceToObjectiveEnd: dimensions.width - (absolutePointerX - offset[0]), objectiveHeight: dimensions.height };
    this.showAt(clickPoint, options);
    this.element.setStyle({display: "block"});
    if (alerts_only) {
      ObjectivesController.alert_details(this.objective, function() {
        TimelineStatus.instance.end('objective_details_popup');
      }.bind(this));
    } else {
      ObjectivesController.details(this.objective, function() {
        TimelineStatus.instance.end('objective_details_popup');
      }.bind(this));
    }

    this.hideForecast();
  },

  close: function() {
    this.element.hide();
    this.hideForecast();
  },

  hideForecast: function() {
    var forecast = $("forecast");
    if (null !== forecast) {
      forecast.hide();
    }
  }

});

Timeline.Objective.Popup.PROGRESS_SCALE_DURATION = 0.75;

Timeline.Objective.Progress = Class.create({

  initialize: function(progress, forecasts, objective) {
    this.progress = $H(progress);
    this.forecasts = $H(forecasts);
    this.objective = objective;
  },

  renderProgress: function(alert_only) {
    if (0 === this.progress.keys().size()) {
      return;
    }

    var composite = new Element("div").addClassName("composite-progress");
    $$(".objective_details")[0].insert(composite);
    this.progress.keys().sort().each(function(proj) {
      var notLikelyForecast = this.forecasts.get(proj)["not_likely"];

      var isProjectLate = notLikelyForecast.late;

      if (alert_only && !isProjectLate) {
         return;
      }
      var stat = this.progress.get(proj);
      var fraction = stat.done / stat.total;
      var widthPercent = Math.floor(fraction * 100);
      var bar = new Element("div", {id: "progress_" + proj});
      bar.addClassName('symbols');

      var meter = new Element("div").addClassName("meter");

      var level = new Element("div",{id: "level_" + proj}).addClassName("level");
      meter.insert(level);

      var name = new Element("div", {id: "name_" + proj}).addClassName("project-name").update(stat.name.truncate(43, "&hellip;"));
      var progress_div = new Element('div').addClassName('progress-info');
      var handler = this.showForecast.bindAsEventListener(this, proj, stat.name);

      var count = new Element("span");
      count.addClassName("count");
      count.innerHTML = stat.done + " of " + stat.total;

      composite.insert(name);
      composite.insert(bar);

      bar.insert(progress_div);
      progress_div.appendChild(meter);
      progress_div.appendChild(count);

      var chart_link = new Element("a",{id: "chart_icon_" + proj}, {'href': 'javascript:void(0)'});
      if (stat.done == 0) {
        chart_link.addClassName('chart_icon no_forecast_chart');
        Tooltip(chart_link, "No data to generate forecasts. Work has not started.");
      } else if (notLikelyForecast.no_velocity) {
        chart_link.addClassName('chart_icon no_forecast_chart');
        Tooltip(chart_link, "Insufficient data to generate forecasts.");
      } else {
        if (isProjectLate) {
          chart_link.addClassName('chart_icon forecast_chart_alert');
          Tooltip(chart_link, "May not complete before " + Timeline.DateUtils.formatDateString(this.objective.end_at));
        } else {
          chart_link.addClassName('chart_icon forecast_chart_link');
        }
        chart_link.observe('click', handler);
      }

      bar.appendChild(chart_link);

      var clearBoth = new Element("div");
      clearBoth.addClassName('clear');
      bar.appendChild(clearBoth);

      new Effect.Morph("level_" + proj, {
        style: 'width: ' + widthPercent + '%;',
        duration: Timeline.Objective.Popup.PROGRESS_SCALE_DURATION
      });

    }.bind(this));
  },

  showForecast: function(event, projectId, projectName) {
    var data = this.forecasts.get(projectId);
    var forecast = $('forecast') || new Element("div", {id: "forecast"});

    var objName = this.objective.name;
    var truncatedHeader = objName.truncate(25).escapeHTML() + ' - ' + projectName.truncate(25);
    var headerText = "<span title='" + objName.escapeHTML() + " - " + projectName + "'>" + truncatedHeader + "</span>";
    InputingContexts.push(new LightboxInputingContext(null, {closeOnBlur: true, headerText: headerText}));

    new Timeline.Forecast(this.objective, projectId, projectName).show(data);
  },

  _forecastMessage: function(project) {
    if (this._allCompleted(project)) {
      return "<div class='important'>Completed</div>";
    } else {
      var data = this.forecasts.get(project);
      return "<table>" +
      "<tr><td class='date heading'>Change in remaining scope</td><td class='date heading'>Estimated completion</td></tr>"+
      "<tr><td>No change:</td><td id='not_likely' class='date'>" + this.formatForecast(data["not_likely"]) + "</td></tr>" +
      "<tr><td>50% increase:</td><td id='less_likely' class='date'>" + this.formatForecast(data["less_likely"]) + "</td></tr>" +
      "<tr><td>150% increase:</td><td id='likely' class='date'>" + this.formatForecast(data["likely"]) + "</td></tr>" +
      "</table>";
    }
  },

  formatForecast: function(forecast){
    if(forecast.no_velocity) {
      return "No Velocity";
    } else {
      return this._formatDate(forecast.date);
    }
  },

  _formatDate: function(dateString) {
    return Timeline.DateUtils.formatDateString(dateString);
  },

  _allCompleted: function(project) {
    var data = this.progress.get(project);
    return data.total == data.done;
  }

});

Timeline.Objective.FORECAST_TOP_OFFSET = 37;
Timeline.Objective.ForecastPopup = Class.create(Timeline.Objective.Popup, {

  showAt: function(clickPoint, options) {
    this.parentElement.insert(this.element);

    this._setPositionFrom(clickPoint);
    Timeline.PopupManager.instance.registerPopup(this);
  },

  _setPositionFrom: function(clickPoint) {
    this.element.setStyle({
      left: (clickPoint.x + clickPoint.distanceToObjectiveEnd) + 'px',
      top: (clickPoint.y + Timeline.Objective.FORECAST_TOP_OFFSET) + 'px',
      display: 'block'
    });
  }
});

Timeline.PopupManager = Class.create({

  initialize: function() {
    this.popups = $A();
  },

  registerPopup: function(popup) {
    this.popups.push(popup);
  },

  closeAll: function() {
    this.popups.invoke('close');
  },

  clear: function() {
    this.popups.clear();
  }

});

Timeline.PopupManager.instance = new Timeline.PopupManager();
