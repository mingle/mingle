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
var ScreenFurniture = Class.create(ParamsChangeListener, {
  id : 'screenFurniture',

  initialize: function($super, maximizeLinkDomId, restoreLinkSelector, linkNavigator) {
    $super(this);
    this.maximizeLinkDomId = maximizeLinkDomId;
    this.restoreLinkSelector = restoreLinkSelector;
    this.linkNavigator = linkNavigator;
  },

  restore: function() {
    this.linkNavigator.navigateTo($$(this.restoreLinkSelector)[0].href);
  },

  remove: function() {
    this.shouldShowSidebar = Sidebar.visible();
    this._remove(true);
    ParamsController.update(this._lastParams.merge({ maximized : true }).params);
  },

  _remove: function(hideSidebar) {
    $$(this.restoreLinkSelector).invoke('show');
    if ($(this.maximizeLinkDomId)){
      $(this.maximizeLinkDomId).hide();
    }
    $$('.hide-on-maximized').invoke("hide");
    this.refreshUi();
    if (hideSidebar) {
      Sidebar.hide();
    }
  },

  refreshUi: function() {
    $j(document).trigger("mingle:relayout");
    document.fire("listview:uncheckAllCards");
  },

  onParamsUpdate: function(params) {
    var hideSidebar = params.get('maximized') && !(this._lastParams || new RailsParams({})).get('maximized');
    this._lastParams = params;
    if (params.get('maximized')) {
      this._remove(hideSidebar);
    }
  }
});

Object.extend(ScreenFurniture, {
  attach : function(maximizeLinkDomId, restoreLinkSelector, linkNavigator) {
    this.instance = new ScreenFurniture(maximizeLinkDomId, restoreLinkSelector, linkNavigator);
    this.restoreListener = this.restoreOnEscape.bindAsEventListener(this);
    this.eventHandlerStore = new EventHandlerStore();
    return this.instance;
  },

  remove: function() {
    this.instance.remove();
  },

  restore: function() {
    this.instance.restore();
    this.stopMonitoringKeyDown();
  },

  stopMonitoringKeyDown: function() {
    this.eventHandlerStore.stopObserving();
  },

  monitorKeyDown: function() {
    this.eventHandlerStore.observe(document, 'keydown', this.restoreListener);
  },

  restoreOnEscape: function(event) {
    if (event.keyCode == Event.KEY_ESC) {
      Event.stop(event); // must stop event or else window.location= does not work
      this.restore();
    }
  }
});

