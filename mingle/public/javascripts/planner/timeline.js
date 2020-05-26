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
var Timeline = Class.create({
  DEFAULT_GRANULARITY: 'months',
  
  initialize: function(timeline, viewColumns, today,readonlyMode) {
    this.mainViewContent = new Timeline.MainViewContent($('main_view_content'), viewColumns, today);
    this.mainView = new Timeline.MainView($(timeline).down('.main_view'), this.mainViewContent);
    this.mainViewContent.setMainView(this.mainView);
    this.objectiveCreationController = new Timeline.ObjectiveCreationController(this.mainView, readonlyMode);
    this.readonlyMode = readonlyMode;
    Event.observe(window, 'resize', this.updateViewport.bindAsEventListener(this));
  },
  
  updateViewport: function() {
    this.mainView.updateViewport();
  },

  moveToToday: function() {
    this.mainView.restoreViewportSlider(this.centerTimeline());
  },
  
  clearObjectiveCreation: function() {
    this.objectiveCreationController.clear();
  },

  redraw: function(granularity) {
    TimelineStatus.instance.start('redraw');
    try {
      var objectives = this.mainViewContent.clearObjectives();
      this.clearObjectiveCreation();

      Timeline.PopupManager.instance.closeAll();

      this._render(objectives, granularity);

      this.mainView.observeScroll(function() {
        this.mainView.stopObservingScroll();
        TimelineStatus.instance.end('redraw');
      }.bind(this));
  
      this.mainView.stopObservingScroll();
      this.mainView.restoreViewportSlider(this.centerTimeline());
      this.handleRedraw(granularity);
    } finally {
      TimelineStatus.instance.end('redraw');
    }
  },
  
  showPopup: function(planned_objective_name) {
    var obj = this.mainViewContent.objectives.find(function(o){ return o.name == planned_objective_name; });
    if(obj) {
      obj.objectiveDetailsPopup.show(new Pointer(obj.element.getScreenPosition().left + 25, obj.element.getScreenPosition().top));
    }
  },

  _render: function(objectives, granularity) {
	  $('timeline-spinner').hide();
    TimelineStatus.instance.start('render');
    try {
      this.mainViewContent.buildViewColumns(granularity);
      this.updateViewport();
      this.mainViewContent.addObjectivesFromJSON(objectives, this.readonlyMode);
      if (objectives.size() == 0 && !this.readonlyMode) {
        this.mainView.registerRenderTimelineCallback(this.displayCreateObjectivePopup.bind(this));
      }
    } finally {
      TimelineStatus.instance.end('render');
    }
  },
  
  objectiveCreated: function(objectiveJson, planJson) {
    this.mainViewContent.addObjectivesFromJSON([objectiveJson]);
    this.mainViewContent.updatePlan(planJson);
    this.clearObjectiveCreation();
  },
  
  objectiveCreationFailed: function(objectiveJson, errorJson) {
    this.objectiveCreationController.showError(objectiveJson, errorJson);
  },

  displayCreateObjectivePopup: function() {
    var pointer = {x: this.middleOfViewport(), y: 200};
    this.objectiveCreationController.startCreation(pointer);
    this.objectiveCreationController.endCreation(pointer);
    this.mainView.unregisterRenderTimelineCallback();
  },

  middleOfViewport: function() {
    if (this.mainViewContent.element.getWidth() < this.mainView.element.getWidth()) {
      return Math.floor(this.mainViewContent.element.getWidth() / 2);
    }
    return Math.floor(this.mainView.element.getWidth() / 2);
  },

  centerTimeline: function() {
    var today = this.mainViewContent.findTodayColumn();

    // if today is not in the range of the plan, default to the beginning
    if (null === today) {
      return 0;
    }

    var centerOfColumn = today.element.positionedOffset()[0] + (today.element.getDimensions().width / 2);
    var halfOfViewport = this.mainView.element.getDimensions().width / 2;
    var centeredPosition = Math.floor(centerOfColumn - halfOfViewport);
    this.mainViewContent.element.style.left = -centeredPosition + "px";
    return centeredPosition;
  },
  
  registerAfterLoad: function(func){
    this.afterLoad = func;
  },
  
  loadPlan: function() {
    var options = { method : 'get', onSuccess : function(data) { this._renderPlan(data); this.afterLoad(); }.bind(this) };
    new Ajax.Request(ObjectivesController.objectivesUrl + '.json', options);
  },
  
  _renderPlan: function(data) {
    var granularity = data.responseJSON.displayPreference || this.DEFAULT_GRANULARITY;
    this._render(data.responseJSON.objectives, granularity);
    this.moveToToday();
    $(granularity + '_selector').addClassName('selected');
  },

  handleRedraw: function(granularity) {
    $$(".granularity-selector .selected").first().removeClassName('selected');
    $(granularity + '_selector').addClassName('selected');
    new Ajax.Request(this.userPreferenceUrl,
      { asynchronous:true,
        evalScripts:true,
        parameters:'user_display_preference[timeline_granularity]=' + granularity });
  },

  setUserPreferenceUrl: function(url) {
    this.userPreferenceUrl = url;
  }

});

Images = {
  path_for: function(image_file_name) {
    return Images.path + image_file_name;
  }
};

Timeline.DEFAULT_VIEW_COLUMN_ROUNDING_THRESHOLD = 0.3;

// the number of rows to render
Timeline.ROWS = 14;

Timeline.GRID_SIZE = {days: 93, weeks: 24, months: 6, years: 8};

Timeline.GRIDS_PER_COLUMN = {days: 1, weeks: 7, months: 31};

// helps in rendering objective widths
Timeline.PRECISION = {days: 1, weeks: 7, months: 31};

// start with 40 date headings on initial load
Timeline.INITIAL_HEADINGS = 40;
