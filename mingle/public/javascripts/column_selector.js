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
var MultipleColumnsSelector = Class.create(ParamsChangeListener, {
  initialize: function($super, container, openLink, url, server) {
    $super(container);
    this.url = url;
    this.container = $(container);
    this.spinner = this.container.down('.spinner');
    this.selectAllCheckBoxesGroup = this._createSelectAllCheckBoxesGroup();
    this.applyButton = this.container.select('input[type=button]').first();
    this.eventStore = new EventHandlerStore();

    this._registerApplyButtonCallbacks();
    this._registerDocumentClickCallback();
    this.server = server || new AjaxServer();
    this.lastParams = new RailsParams({});

    this.nonselectableColumns = ['Number', 'Name'];
    this.slideDownPanel = new SlideDownPanel(this.container, openLink, MingleUI.align.alignRight, { 'afterShow': this.selectAllCheckBoxesGroup.setupScrollBar.bind(this.selectAllCheckBoxesGroup) });
  },

  _registerApplyButtonCallbacks: function() {
    this.eventStore.observe(this.applyButton, 'click', this._onApplyButtonClicked.bindAsEventListener(this));
  },

  _registerDocumentClickCallback: function() {
    var listener = new GlobalClickListener([this.container], this.selectAllCheckBoxesGroup.reset.bind(this.selectAllCheckBoxesGroup));
    this.eventStore.observe(document.body, 'click', listener.onGlobalClick.bindAsEventListener(listener));
  },

  _onApplyButtonClicked: function(event) {
    this.spinner.show();

    var queryString = this._createParams().toQueryString();

    var url = this.url;
    if(!queryString.blank()) { url += "?" + queryString; }

    this.server.request(url, {'method': 'GET'});
    Event.stop(event);

    this.selectAllCheckBoxesGroup = this._createSelectAllCheckBoxesGroup();

    return false;
  },

  _createSelectAllCheckBoxesGroup: function() {
    var selectAllCheckBox = this.container.select('input[type=checkbox][name=selectAll]').first();
    var checkboxElements = this.container.select('input[type=checkbox][name=columns]');
    return new SelectAllCheckBoxesGroup(selectAllCheckBox, checkboxElements, $('options-container'));
  },

  _createParams: function() {
    var columns = this.selectAllCheckBoxesGroup.checkedValues();
    columns = this._reorderColumns(columns);
    var params = this.lastParams.merge({'columns' : RoundtripJoinableArray.joinFromArray(columns)});
    params = params.exclude(['all_cards_selected']);
    var sortParameter = this.lastParams.get('sort');
    if (!this.nonselectableColumns.ignoreCaseInclude(sortParameter) && !columns.ignoreCaseInclude(sortParameter)) {
      params = params.exclude(['sort']);
    }

    return params;
  },

  _reorderColumns: function(columns){
    var lastColumnNames = RoundtripJoinableArray.fromStr(this.lastParams.get('columns'));
    var newColumns = $A();
    var oldColumns = $A();
    lastColumnNames.each(function(lastColumn){
      if(columns.ignoreCaseInclude(lastColumn)) {oldColumns.push(lastColumn);}
    });

    columns.each(function(column){
      if(!lastColumnNames.ignoreCaseInclude(column)) {newColumns.push(column);}
    });
    return oldColumns.concat(newColumns);
  },

  onParamsUpdate: function(params) {
    this.lastParams = params;
    if (!params.get('columns')) {return;}
    var columnNames = RoundtripJoinableArray.fromStr(params.get('columns'));
    this.selectAllCheckBoxesGroup.checkMultipleItems(columnNames);
  },

  destroy: function(){
    this.eventStore.stopObserving();
    this.slideDownPanel.destroy();
    this.selectAllCheckBoxesGroup.destroy();
  }
});

var SelectAllCheckBoxesGroup = Class.create({
  initialize: function(selectAllCheckBox,checkboxElements, optionsContainer){
    this.selectAllCheckBox = selectAllCheckBox;
    this.checkboxElements = checkboxElements;
    this.optionsContainer = optionsContainer;
    this.initialValues = this.checkedValues();
    this.eventStore = new EventHandlerStore();
    this._registerSelectAllCheckboxCallbacks();
    this._registerUncheckSelectAllCallbacks();
    this._checkSelectAllIfAllCheckboxElementsWereSelected();
  },

  setupScrollBar: function() {
    var optionsPanelElementStyles = $H();
    if(this.optionsContainer.offsetHeight > SelectAllCheckBoxesGroup.MAX_HEIGHT) {
      optionsPanelElementStyles.set('overflowY', 'auto');
      optionsPanelElementStyles.set('height', SelectAllCheckBoxesGroup.MAX_HEIGHT + 'px');
    }

    optionsPanelElementStyles.set('width', this.optionsContainer.getWidth() + 10 + 'px');
    this.optionsContainer.setStyle(optionsPanelElementStyles.toObject());
  },

  _registerSelectAllCheckboxCallbacks: function() {
    this.eventStore.observe(this.selectAllCheckBox, 'click', this._onSelectAllCheckboxClicked.bindAsEventListener(this));
  },

  _onSelectAllCheckboxClicked: function(event) {
    this.checkboxElements.each(function(checkBox) {
      checkBox.checked = this.selectAllCheckBox.checked;
    }.bind(this));
  },

  _registerUncheckSelectAllCallbacks: function() {
    this.checkboxElements.each(function(checkbox){
      this.eventStore.observe(checkbox, 'click', this._onClickCheckboxElement.bindAsEventListener(this, checkbox));
    }.bind(this));
  },

  _onClickCheckboxElement: function(event, checkbox){
    if(!checkbox.checked){
      this.selectAllCheckBox.checked = false;
    }
  },

  reset: function(){
    this.checkMultipleItems(this.initialValues);
  },

  checkedValues: function(){
    var checkedItems = this.checkboxElements.select(function(checkBox) {
      return checkBox.checked;
    });
    var values = checkedItems.map(function(item) {
      return item.value;
    });
    return values;
  },

  checkMultipleItems: function(values){
    this.checkboxElements.each(function (checkbox) {
      if (values.ignoreCaseInclude(checkbox.value)) {
        checkbox.checked = true;
      }else{
        checkbox.checked = false;
      }
    });
    this.initialValues = this.checkedValues();
    this._checkSelectAllIfAllCheckboxElementsWereSelected();
  },

  _checkSelectAllIfAllCheckboxElementsWereSelected: function(){
    var isAllSelected = this.checkboxElements.all(function(checkbox){ return checkbox.checked;});
    this.selectAllCheckBox.checked = isAllSelected;
  },

  destroy: function(){
    this.eventStore.stopObserving();
  }
});

SelectAllCheckBoxesGroup.MAX_HEIGHT = 285;

SelectAllCheckBoxesGroup.instance = null;
SelectAllCheckBoxesGroup.attach = function(selectAllCheckBox,checkboxElements, optionsContainer){
  SelectAllCheckBoxesGroup.instance = new SelectAllCheckBoxesGroup(selectAllCheckBox, checkboxElements, optionsContainer);
  return SelectAllCheckBoxesGroup.instance;
};


// TODO: Identical duplication with MultipleColumnsSelector is left here
var LaneSelector = Class.create(ParamsChangeListener, {
  initialize: function($super, container, openLink) {
    $super(container);
    this.container = $(container);
    this.openLink = $(openLink);
    this.eventStore = new EventHandlerStore();
    this.selectAllCheckBoxesGroup = this._createSelectAllCheckBoxesGroup();
    this._registerDocumentClickCallback();
    this.slideDownPanel = new SlideDownPanel(this.container, this.openLink, MingleUI.align.alignRight, { 'afterShow': this.selectAllCheckBoxesGroup.setupScrollBar.bind(this.selectAllCheckBoxesGroup) });
  },

  onParamsUpdate: function() { },

  destroy: function() {
    this.eventStore.stopObserving();
    this.slideDownPanel.destroy();
    this.selectAllCheckBoxesGroup.destroy();
  },

  _createSelectAllCheckBoxesGroup: function() {
    var selectAllCheckBox = this.container.select('input[type=checkbox][name=selectAll]').first();
    var checkboxElements = this.container.select('input[type=checkbox][name=lane_check_box]');
    return SelectAllCheckBoxesGroup.attach(selectAllCheckBox, checkboxElements, $('options-container'));
  },

  _registerDocumentClickCallback: function() {
    var listener = new GlobalClickListener([this.container, this.openLink], this.selectAllCheckBoxesGroup.reset.bind(this.selectAllCheckBoxesGroup));
    this.eventStore.observe(document.body, 'click', listener.onGlobalClick.bindAsEventListener(listener));
  }

});
