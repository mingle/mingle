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
MingleUI.EasyCharts.Sections = (MingleUI.EasyCharts.Sections || {});

(function ($) {
  MingleUI.EasyCharts.Sections.BuildChartSection = function (sectionData, callbacks) {
    var self = this, customizeChartCallback = ensureFunction(callbacks.onComplete),
        onUpdate = ensureFunction(callbacks.onUpdate), updateHandlers = $.extend({aggregate: aggregateUpdated}, callbacks),
        customizeChartButton = $('<button>', {text: 'Proceed to Step 3'}),
        paramsContainer, aggregatePairName = (sectionData.aggregatePairName || '').toCamelCase('-');

    self._values = {};
    if (sectionData.aggregatePairName)
      self._values.aggregate = 'count';

    function aggregateUpdated(aggregateDropDown) {
      if (aggregateDropDown.value().toLowerCase() !== 'count')
        self.params[aggregatePairName].showPairParameter();
      else
        self.params[aggregatePairName].hidePairParameter();
    }

    function updateProperties(projectData, selectedCardTypes, initialData) {
      var properties = [], aggregateProperties = [];
      Object.values(projectData.fetchCommonPropertyDefinitionDetails(selectedCardTypes)).forEach(function (property) {
        properties.push(property.name);
        property.isNumeric && aggregateProperties.push(property.name);
      });

      sectionData.extensionMethods.updateProperties(self.params, properties, aggregateProperties, initialData);
    }

    function handleUpdate(target) {
      if(target){
        self._values[target.name] = target.value();
        var updateHandler = updateHandlers[target.name];
        updateHandler && updateHandler(target);
      }
      onUpdate && onUpdate(self);
    }

    function initCustomizeChartSection(event) {
      $(event.target).remove();
      customizeChartCallback && customizeChartCallback();
    }

    function initialize() {
      self.name = sectionData.name;
      self.htmlContainer = $('<div>', {id: self.name.toSnakeCase(), class: 'chart-form-section build-chart-section disabled'});
      self.initialData = sectionData.initialData || {};
      MingleUI.EasyCharts.SectionHelpers.addTitle.call(self, 2, 'Build the chart');
    }

    this.addButton = function(container) {
      if (sectionData.hasValidInitialData) {
        customizeChartCallback && customizeChartCallback();
        onUpdate && onUpdate(self);
      } else {
        customizeChartButton.on('click', initCustomizeChartSection);
        var buttonContainer = container || self.htmlContainer;
        buttonContainer.append(customizeChartButton);
      }
    };

    this.enableWith = function (projectData, selectedCardTypes, filtersSelected) {
      this.htmlContainer.removeClass('disabled');
      this.currentProject = projectData.identifier;
      this.params = MingleUI.EasyCharts.SectionHelpers.addParameters.call(this, sectionData.parameterDefinitions, {
        projectData: projectData,
        onUpdate: function(target) { (this.customUpdateHandler || handleUpdate)(target); }.bind(self),
        initialData: this.initialData,
        sectionName: this.name,
        selectedCardTypes: selectedCardTypes
      });
      this.selectedCardTypes = selectedCardTypes;
      this.dataSectionSelectedFilters = filtersSelected || {};
      paramsContainer = this.htmlContainer.find('.section-params-container');
      updateProperties(projectData, selectedCardTypes, this.initialData);
      if (this.params[aggregatePairName] && !this.params[aggregatePairName].isValid()) this.params[aggregatePairName].hidePairParameter();
      $.extend(this._values, this.initialData);

      callbacks.onEnabled ? callbacks.onEnabled() : this.addButton.call(this);
    };

    this.disable =  function () {
      this.htmlContainer.addClass('disabled');
      this.params = undefined;
      paramsContainer.remove();
      customizeChartButton.remove();
    };

    this.enableInsert = function () {
      return this.isValid();
    };

    this.isValid = function () {
      return self.params && !!(self.params.property.value() && self.params[aggregatePairName].isValid());
    };

    this.values = function () {
      return self.isEnabled() ? self._values : {};
    };

    this.isEnabled = function () {
     return !!self.params;
    };

    initialize();
  };
})(jQuery);
