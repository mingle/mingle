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
  var SECTIONS = {
    'pie-chart':{
      data: MingleUI.EasyCharts.Sections.DataSection,
      buildChart: MingleUI.EasyCharts.PieChart.Sections.BuildChartSection,
      customizeChart: MingleUI.EasyCharts.PieChart.Sections.CustomizeChartSection,
      macroBuilder: MingleUI.EasyCharts.PieChart.MacroBuilder
    },
    'ratio-bar-chart':{
      data: MingleUI.EasyCharts.Sections.DataSection,
      buildChart: MingleUI.EasyCharts.RatioBarChart.Sections.BuildChartSection,
      customizeChart: MingleUI.EasyCharts.RatioBarChart.Sections.CustomizeChartSection,
      macroBuilder: MingleUI.EasyCharts.RatioBarChart.MacroBuilder
    },
    'stacked-bar-chart':{
      data: MingleUI.EasyCharts.Sections.DataSection,
      buildChart: MingleUI.EasyCharts.StackedBarChart.Sections.BuildChartSection,
      customizeChart: MingleUI.EasyCharts.StackedBarChart.Sections.CustomizeChartSection,
      macroBuilder: MingleUI.EasyCharts.StackedBarChart.MacroBuilder
    },
    'data-series-chart':{
      data: MingleUI.EasyCharts.Sections.DataSection,
      buildChart: MingleUI.EasyCharts.DataSeriesChart.Sections.BuildChartSection,
      customizeChart: MingleUI.EasyCharts.DataSeriesChart.Sections.CustomizeChartSection,
      macroBuilder: MingleUI.EasyCharts.DataSeriesChart.MacroBuilder
    },
    'cumulative-flow-graph':{
      data: MingleUI.EasyCharts.Sections.DataSection,
      buildChart: MingleUI.EasyCharts.CumulativeFlowGraph.Sections.BuildChartSection,
      customizeChart: MingleUI.EasyCharts.CumulativeFlowGraph.Sections.CustomizeChartSection,
      macroBuilder: MingleUI.EasyCharts.CumulativeFlowGraph.MacroBuilder
    },
    'daily-history-chart': {
      data: MingleUI.EasyCharts.DailyHistoryChart.Sections.DataSection,
      buildChart: MingleUI.EasyCharts.DailyHistoryChart.Sections.BuildChartSection,
      customizeChart: MingleUI.EasyCharts.CumulativeFlowGraph.Sections.CustomizeChartSection,
      macroBuilder: MingleUI.EasyCharts.DailyHistoryChart.MacroBuilder
    }
  };

  MingleUI.EasyCharts.ChartBuilder = function (chartType, initialData, callbacks) {
    var self = this, dataSection, buildChartSection, customizeChartSection, oldCardTypes = [],
        chartData = {project: initialData.project}, generatePreview = ensureFunction(callbacks.preview),
        displayCardCount = ensureFunction(callbacks.updateCardCount),
        initialized = ensureFunction(callbacks.initialized),
        resetPreview = ensureFunction(callbacks.resetPreview),
        projectDataStore, sectionUpdateHandlers = {};

    function initialize() {
      var htmlContainerId = chartType.toSnakeCase()+'_builder_container';
      self.htmlContainer = $j('<div>', {id: htmlContainerId, class: 'chart-builder-form-container'});
      projectDataStore = new ProjectDataStore();
      ProjectDataStore.setAjaxStopCallback(function () {
        $.extend(chartData, dataSection.values());
        ProjectDataStore.disableGlobalCallbacks();
        self.htmlContainer.show();
        initialized && initialized();
        updatePreview();
      });
      projectDataStore.dataFor(initialData.project, initSections);
      self.htmlContainer.hide();
      updateCardCount();
    }

    function handleBuildChartSectionError(errorMessage) {
      self.buildChartSectionError = errorMessage;
      callbacks.onError && callbacks.onError(errorMessage, true);
    }

    function buildChartSectionUpdateHandler() {
      self.buildChartSectionError = '';
    }

    function initSections() {
      customizeChartSection = new SECTIONS[chartType].customizeChart(initialData, {onUpdate: handleUpdate});
      buildChartSection = new SECTIONS[chartType].buildChart(initialData, {
        onComplete: enableSection.bind(customizeChartSection),
        onUpdate: handleUpdate,
        onError: handleBuildChartSectionError
      }, projectDataStore);
      sectionUpdateHandlers[buildChartSection.name] = buildChartSectionUpdateHandler;
      initDataSection();
      self.htmlContainer.append(buildChartSection.htmlContainer);
      self.htmlContainer.append(customizeChartSection.htmlContainer);
    }

    function initDataSection() {
      var dataSectionName = chartType.toCamelCase()+'DataSection';
      dataSection = new SECTIONS[chartType].data(dataSectionName, projectDataStore, initialData, {
        onComplete: enableSection.bind(buildChartSection),
        onUpdate: handleDataUpdate
      });
      oldCardTypes = dataSection.selectedCardTypes();
      self.htmlContainer.append(dataSection.htmlContainer);
    }

    function enableSection() {
      this.enableWith.apply(this, arguments);
      $.extend(chartData, this.values());
    }

    function handleDataUpdate(section, change) {
      self.buildChartSectionError = '';
      switch (change.targetType) {
        case 'project':
          resetChartAndCustomizeSections();
          oldCardTypes = [];
          break;
        case 'cardFilters':
          if (!change.target.getCardTypes().equals(oldCardTypes)) {
            resetChartAndCustomizeSections();
            oldCardTypes = change.target.getCardTypes();
          } else {
            buildChartSection.updateSelectedFilters && buildChartSection.updateSelectedFilters(change.target.value(), 'filters');
          }
          break;
        case 'tagsFilter':
          buildChartSection.updateSelectedFilters && buildChartSection.updateSelectedFilters(change.target.getTags(), 'tags');
          break;
      }
      handleUpdate(section);
    }

    function updateCardCount() {
      var macroBuilder = new SECTIONS[chartType].macroBuilder(chartData);
      displayCardCount((chartData.project||initialData.project), macroBuilder.buildCardCountMql());
    }

    function updatePreview() {
      canGeneratePreview() ? generatePreview(chartMacro()) : updateCardCount();
    }

    function handleUpdate(section) {
      $.extend(chartData, section.values());
      sectionUpdateHandlers[section.name] && sectionUpdateHandlers[section.name].call(self);
      if(!self.buildChartSectionError) updatePreview();
    }

    function canGeneratePreview() {
      return dataSection && dataSection.isValid() && buildChartSection && buildChartSection.isValid();
    }

    function chartMacro() {
      var macroBuilder = new SECTIONS[chartType].macroBuilder(chartData, self.htmlContainer.is(':visible'));
      return macroBuilder.build();
    }

    function resetChartAndCustomizeSections() {
      chartData = {};
      buildChartSection.isEnabled() && buildChartSection.disable();
      customizeChartSection.isEnabled() && customizeChartSection.disable();
    }

    this.getMacroValue = function () {
      chartData = {};
      $.extend(chartData, dataSection.values());
      buildChartSection.isEnabled() && $.extend(chartData, buildChartSection.values());
      $.extend(chartData, customizeChartSection.values());
      return chartMacro();
    };

    this.disable = function () {
      self.htmlContainer.hide();
      canGeneratePreview() || resetPreview();
    };

    this.enable = function () {
      self.htmlContainer.show();
      if(self.buildChartSectionError)
        callbacks.onError(self.buildChartSectionError, true);
      else
        updatePreview();
    };

    this.enableInsert = function () {
      return this.isEnabled() ? buildChartSection.enableInsert() : true;
    };

    this.isEnabled = function () {
      return self.htmlContainer.is(':visible');
    };

    initialize();

  };
})(jQuery);