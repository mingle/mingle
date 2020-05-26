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
var MingleUI = (MingleUI || {});
MingleUI.EasyCharts = (MingleUI.EasyCharts || {});

(function ($) {
  MingleUI.EasyCharts.SeriesParameter = function (selector, projectDataStore, options) {
    var self = this,
        allSeries = {},
        addSeriesButton = $('<button>', {class: 'add-a-series', text: 'Add a series'}),
        enabled = false,
        seriesCount = 0,
        callBacks = options.callBacks;
    self.buttonContainer = $('<div>', {class: 'button-container inline-parameter'});

    function nextSeriesNumber() {
      return ++seriesCount;
    }

    function createSeriesData(currentProject, selectedProperty) {
      return {
        config: options.seriesConfig,
        number: nextSeriesNumber(),
        currentProject: currentProject,
        projectDataStore: projectDataStore,
        cardFilters: options.cardFilters,
        property: selectedProperty,
        colors: getSeriesColorsFor(currentProject)
      };
    }

    function getSeriesColorsFor(currentProject) {
      return projectDataStore.dataFor(currentProject).colors;
    }

    function handleSeriesUpdate() {
      callBacks.onUpdate && callBacks.onUpdate(self);
    }

    function init() {
      var name = 'series-parameter';
      self.name = name.toCamelCase('-');
      self.htmlContainer = $('<div>', {class: name});
      selector.append(self.htmlContainer);
    }

    init();

    function add(selectedProperty) {
      var deletableSeries = false;
      if (self.getSeriesCount() > 0)
        deletableSeries = true;
      var series = new MingleUI.EasyCharts.Series(createSeriesData(options.currentProject, selectedProperty), {
        onUpdate: handleSeriesUpdate,
        onDelete: handleSeriesDeletion,
        onError: callBacks.onError
      }, deletableSeries);

      self.buttonContainer.before(series.htmlContainer);
      var seriesColorElement = '.color-picker';
      scroll(series.htmlContainer, seriesColorElement);
      allSeries[series.name] = series;
      callBacks.onAdd();
      addSeriesButton.text('Add another series');
      addDeleteSeriesButton();
    }

    function handleSeriesDeletion(series) {
      delete allSeries[series.name];
      if (self.getSeriesCount() < 2)
        allSeries[Object.keys(allSeries)[0]].removeDeleteButton();
      callBacks.onUpdate && callBacks.onUpdate(self);
    }

    function addDeleteSeriesButton() {
      if (self.getSeriesCount() > 1)
        for (var seriesName in allSeries) {
          allSeries[seriesName].addDeleteButton();
        }
    }

    this.enable = function (selectedProperty) {
      self.selectedProperty = selectedProperty;
      addSeriesButton.on('click', function () {
        add(self.selectedProperty);
      });
      self.buttonContainer.append(addSeriesButton);
      self.htmlContainer.append(self.buttonContainer);
      enabled = true;
    };

    function scroll(container, element) {
      var elementToScroll = container.find(element);
      elementToScroll.scrollintoview && elementToScroll.scrollintoview({direction: 'vertical'});
    }

    this.isEnabled = function () {
      return enabled;
    };

    this.update = function (selectedProperty) {
      Object.keys(allSeries).forEach(function (seriesName) {
        var series = allSeries[seriesName];
        series.updateProperty(selectedProperty);
      });
      self.selectedProperty = selectedProperty;
    };

    this.value = function () {
      var seriesValues = {};
      Object.keys(allSeries).forEach(function (seriesName) {
        var series = allSeries[seriesName];
        if (series.isValid())
          seriesValues[series.name] = series.value();
      });
      return seriesValues;
    };

    this.isValid = function () {
      return Object.keys(allSeries).any(function (seriesName) {
        var series = allSeries[seriesName];
        return series.isValid();
      });
    };

    this.getSeriesCount = function () {
      return Object.keys(allSeries).length;
    };

    this.getSeriesNames = function () {
      return Object.values(allSeries).collect(function (series) {
        return [series.value().label, series.name];
      });
    };
  };
})(jQuery);
