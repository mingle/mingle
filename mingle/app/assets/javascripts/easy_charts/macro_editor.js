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
  function MacroEditor(data, callbacks) {
    var self = this, macroInput, macroPreviewButton, goToEasyChartsButton, initialMacro,
        generatePreview = ensureFunction(callbacks.preview), onUpdate = ensureFunction(callbacks.onUpdate), onError = ensureFunction(callbacks.onError),
        enableEasyChartsForm = ensureFunction(callbacks.onCancel), hasAssociatedChartBuilder = data.hasAssociatedChartBuilder;

    function addWarningMessage() {
      var warningContainer = $('<div>', {class: 'macro-edit-warning'});
      if (hasAssociatedChartBuilder) {
        var warning = $('<span>', {
          class: 'help-text',
          text: 'Editing here will restrict you from going back to the Easy Charts form.'
        });
        goToEasyChartsButton = $('<a>', {href: '#', text: 'Go back now', class: 'easy-chart-toggle'});
        goToEasyChartsButton.on('click', function () {
          self.disable();
          enableEasyChartsForm && enableEasyChartsForm();
        });

        warningContainer.append(warning, goToEasyChartsButton);
      }
      self.htmlContainer.append(warningContainer);
    }

    function isMacroUpdated() {
      return (initialMacro || '').trim() !== macroInput.val().trim();
    }

    function addMacroInput() {
      macroInput = $('<textarea>', {class: 'charts-macro-mql', text: data.macro});
      macroInput.on('change keyup paste', function () {
        if (hasAssociatedChartBuilder) {
          isMacroUpdated() ? goToEasyChartsButton.hide() : goToEasyChartsButton.show();
        }
        onUpdate && onUpdate();
      });
      self.htmlContainer.append(macroInput);
    }

    function addMacroPreviewButton() {
      var macroPreviewButtonContainer = $('<div>', {class: 'preview-macro-container'});
      macroPreviewButton = $('<button>', {class: 'preview-macro', text: 'Preview'});
      macroPreviewButton.on('click', function () {
        try {
          generatePreview && generatePreview(self.getMacroValue());
        } catch(err) {
          onError && onError("Invalid Macro format.");
        }
      });
      macroPreviewButtonContainer.append(macroPreviewButton);
      self.htmlContainer.append(macroPreviewButtonContainer);
    }

    function initialize() {
      self.htmlContainer = $('<div>', {id: 'charts_macro_form_container'});
      addWarningMessage();
      addMacroInput();
      addMacroPreviewButton();
      if(macroInput.val() && generatePreview) generatePreview(self.getMacroValue());
     }

    this.disable = function () {
      self.htmlContainer.hide();
    };

    this.enableWith = function (macro) {
      self.htmlContainer.show();
      generatePreview(macro);
      initialMacro = YAML.stringify(macro, 4, 2);
      macroInput.val(initialMacro);
      macroInput.focus();
    };

    this.getMacroValue = function () {
      var macroNameRegEx = new RegExp('^{macroType}\n'.supplant({macroType:data.macroType}));
      var validMacroNameInYaml = '{macroType}:\n'.supplant({macroType:data.macroType});
      return YAML.parse(macroInput.val().replace(macroNameRegEx, validMacroNameInYaml));
    };

    this.macroType = 'mql';

    initialize();
  }

  MingleUI.EasyCharts.MacroEditor = MacroEditor;
})(jQuery);
