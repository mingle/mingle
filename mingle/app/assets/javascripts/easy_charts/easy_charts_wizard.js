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
var CHART_TYPE_MAPPING = {
  'stack-bar-chart':'stacked-bar-chart'
};
  MingleUI.EasyCharts.EasyChartsWizard = function (container, chartType, data) {
    MingleUI.EasyCharts.chartType = chartType;
    var self = this, previewGenerator, previewContainer, macroEditor, enableMacroEditorButton, chartBuilder;
    chartType = CHART_TYPE_MAPPING[chartType] || chartType ;


    function generatePreviewForChartBuilder(macro, macroType) {
      previewGenerator.generate(macro, macroType);
      if (chartBuilder && !chartBuilder.enableInsert()) {
        disableInsertButton();
      }
    }

    function generatePreviewForMacroEditor(macro, macroType) {
      previewGenerator.generate(macro, macroType);
    }

    function displayError(message, shouldFormat) {
      previewContainer.displayErrorMessage(message, shouldFormat);
      disableInsertButton();
    }

    function enableInsertButton() {
      if ((typeof CKEDITOR !== 'undefined') && CKEDITOR.dialog.getCurrent() && chartBuilder ? chartBuilder.enableInsert() : true)  {
        CKEDITOR.dialog.getCurrent().enableButton('insert');
      }
    }

    function disableInsertButton() {
      if ((typeof CKEDITOR !== 'undefined') && CKEDITOR.dialog.getCurrent()) {
        CKEDITOR.dialog.getCurrent().disableButton('insert');
      }
    }

    function initPreviewContainer() {
      previewContainer = new MingleUI.EasyCharts.PreviewContainer(data.macroHelpUrls[chartType]);
      self.htmlContainer.append(previewContainer.htmlContainer);
    }

    function initPreviewGenerator() {
      previewGenerator = new MingleUI.EasyCharts.PreviewGenerator(previewContainer, {
        chartType: chartType,
        projectIdentifier: data.chartData.initialProject,
        contentProvider: data.contentProvider
      }, {
        onSuccess: enableInsertButton,
        onError: disableInsertButton
      });
      if (data.supportedInEasyCharts) previewGenerator.disable();
    }

    function resetPreview() {
      previewContainer.reset();
      disableInsertButton();
    }

    function updateCardCount(projectIdentifier, cardCountMql) {
      previewGenerator.updateCardCountPreview(projectIdentifier, cardCountMql);
      disableInsertButton();
    }

    function initMacroEditor() {
      macroEditor = new MingleUI.EasyCharts.MacroEditor({
        macro: data.macro,
        macroType:chartType,
        hasAssociatedChartBuilder: data.supportedInEasyCharts
      }, {
        preview: generatePreviewForMacroEditor,
        onUpdate: resetPreview,
        onCancel: enableChartBuilder,
        onError: displayError
      });
      self.htmlContainer.append(macroEditor.htmlContainer);
      if (data.supportedInEasyCharts) macroEditor.disable();
    }

    function enableChartBuilder() {
      chartBuilder.enable();
      enableMacroEditorButton.show();
    }

    function enableMacroEditor() {
      chartBuilder.disable();
      enableMacroEditorButton.hide();
      macroEditor.enableWith(chartBuilder.getMacroValue());
    }

    function initMacroEditorToggle() {
      var macroEditorToggleContainer = $('<div>', {class: 'show-macro-editor-container'});
      enableMacroEditorButton = $('<button>', {class: 'show-macro-editor', text: 'Customize with MQL'});
      enableMacroEditorButton.on('click', enableMacroEditor);
      macroEditorToggleContainer.append(enableMacroEditorButton);
      self.htmlContainer.append(macroEditorToggleContainer);
    }

    function initChartBuilder() {
      chartBuilder = new MingleUI.EasyCharts.ChartBuilder(chartType, data.chartData, {
        preview: generatePreviewForChartBuilder,
        updateCardCount: updateCardCount,
        resetPreview: resetPreview,
        onError: displayError,
        initialized: function () {
          previewGenerator.enable();
          initMacroEditorToggle();
        }
      });
      self.htmlContainer.append(chartBuilder.htmlContainer);
    }

    function initialize() {
      self.htmlContainer = $(container);
      initPreviewContainer();
      initPreviewGenerator();
      self.htmlContainer.addClass('chart-builder-wizard');
      if (data.supportedInEasyCharts) initChartBuilder();
      initMacroEditor();
      disableInsertButton();
    }

    this.getChartData = function () {
      var macroProvider = chartBuilder && chartBuilder.isEnabled() ? chartBuilder : macroEditor;
      return previewGenerator.buildData(macroProvider.getMacroValue());
    };

    initialize();
  };
})(jQuery);
