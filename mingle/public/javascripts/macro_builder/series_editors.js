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
if (typeof MacroBuilder === 'undefined') {
  MacroBuilder = {};
}

MacroBuilder.SeriesEditors = Class.create({
  initialize: function(macroEditorElement, macroType, seriesParamDefs, addNewSeriesUrl, ajaxServer) {
    this.macroEditorElement = macroEditorElement;
    this.seriesParamDefs = seriesParamDefs;
    this.macroType = macroType;
    this._attachObservers();
    this.seriesControllers = $A();
    this.addNewSeriesUrl = addNewSeriesUrl;
    this.ajaxServer = ajaxServer || new AjaxServer();
    this.seriesNumberCounter = -1;
  },
  
  chartPanel: function() {
    return $(this.macroType + '_macro_panel');
  },
  
  count: function(chartElement){
    return $(chartElement).select('.series-container').size();
  },
  
  createInitialSeriesContainers: function() {
    if (this.seriesParamDefs) {
      this._addNew({});
      this._addNew({});
    }
  },
  
  addAdditionalOptionalParameterElements: function(){
    this.seriesControllers.each(function(controller){
      controller._addAdditionalOptionalParameterElement();
    });
  },
  
  _attachObservers: function(){
    this.chartPanel().observe(this.macroType + ':add-series', this._addNew.bindAsEventListener(this));
    this.chartPanel().observe(this.macroType + ':remove-series', this._remove.bindAsEventListener(this));
  },
  
  _seriesContainerElement: function(){
    return this.chartPanel().select('.series-editors').first();
  },
  
  _seriesContainers: function(){
    return this.chartPanel().select('.series-editors .series-container');
  },
  
  _addNew: function(clickEvent) {
    var seriesNumber = this._nextSeriesNumber();
    this.ajaxServer.request(this.addNewSeriesUrl, { method: 'GET', onSuccess: this._createNewSeries.bind(this), parameters: { 'seriesNumber': seriesNumber, 'macroType': this.macroType } });
  },
  
  _createNewSeries: function(response) {
    var seriesData = eval("(" + response.responseText + ")");
    var seriesDiv = this._createDiv(seriesData['html']);
    
    var seriesContainerElement = this._seriesContainerElement();
    seriesContainerElement.appendChild(seriesDiv);
    
    var seriesEditor = new MacroBuilder.SeriesEditor(this.macroType, seriesData['number'], this.seriesParamDefs);
    this.seriesControllers.push(seriesEditor);
    seriesEditor.show();
    this._enableSeriesRemoval();
  },
  
  _createDiv: function(innerHTML) {
    var result = Builder.node('div');
    if (innerHTML) {
      result.innerHTML = innerHTML;
    }
    return result;
  },
  
  _remove: function(clickEvent){
    var seriesContainerToRemove = $(clickEvent.target).up('.series-container');
    var removedSeriesNumber = this._seriesNumberForContainer(seriesContainerToRemove);
    seriesContainerToRemove.remove();
    this._disableSeriesRemovalForLastSeries();
    this._removeSeriesController(removedSeriesNumber);
  },
  
  _removeSeriesController: function(seriesNumber) {
    var remainingSeriesControllers = $A();
    this.seriesControllers.each(function(controller) {
      if (controller.seriesNumber != seriesNumber) {
        remainingSeriesControllers.push(controller);
      }
    });
    this.seriesControllers = remainingSeriesControllers;
  },
  
  _nextSeriesNumber: function() {
    this.seriesNumberCounter += 1;
    return this.seriesNumberCounter;
  },
  
  _seriesNumberForContainer: function(seriesContainer) {
    return seriesContainer.id.match(new RegExp('series-container-(\\d)+'))[1];
  },
  
  _enableSeriesRemoval: function(){
    if (this._seriesContainers().size() > 1){
      this._seriesContainers().each(function(series){
        series.select('.remove_series_link').first().show();
      });
    }  
  },

  _disableSeriesRemovalForLastSeries: function(){
    if (this._seriesContainers().size() == 1){
      this._seriesContainers().each(function(series){
        series.select('.remove_series_link').first().hide();
      });
    }
  }
  
});
