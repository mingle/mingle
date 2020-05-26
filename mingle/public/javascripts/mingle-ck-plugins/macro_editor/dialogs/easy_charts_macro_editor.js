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
CKEDITOR.dialog.add('easyChartsMacroEditorDialog', function (editor) {
  var dialog;

  function removeBracesFrom(text) {
    return text.replace("{{", "").replace("}}", "").strip();
  }

  function insertMacroHtml(dialog, response) {
    var element = $j(response)[0];
    element = new CKEDITOR.dom.element(element);

    if (dialog.existingMacroElement) {
      dialog.existingMacroElement.insertBeforeMe(element);
      dialog.existingMacroElement.remove();
    } else {
      editor.insertElement(element);
      editor.insertHtml('<br/>');
    }
    dialog.hide();
    return element.$;
  }

  function replaceMacro(response) {
    var macroElement = insertMacroHtml(dialog, response);
    CKEDITOR.Mingle.MacroEditor.moveCursorToEndOfCurrentMacro(editor, macroElement);
    CKEDITOR.Mingle.MacroEditor.currentMacroElement = null;
    CKEDITOR.Mingle.MacroEditor.macroData = null;
  }


  function openEasyChartEditor(data) {
    var element = this.getContentElement('tab-edit', 'macro_editor').getElement().$;
    var container = $j('<div>', {id: 'chart_builder_wizard_container'});
    $j(element).html(container);
    data.macro = removeBracesFrom(CKEDITOR.Mingle.MacroEditor.macroData.content);
    data.chartData.initialProject = data.initialProject;
    this.easyChartsWizard = new MingleUI.EasyCharts.EasyChartsWizard(container, CKEDITOR.Mingle.MacroEditor.macroData.type, data);
  }

  function requestRenderedMacro() {
    $j("#macro_preview").empty();
    $j.ajax({
      url: editor.element.data("ckeditor-mingle-macro-data-generate-url"),
      type: "post",
      data: dialog.easyChartsWizard.getChartData(),
      async: false,
      success: replaceMacro,
      error: function (response) {
        if (response.status === 422) {
          $j('#macro_preview').html(response.responseText);
        } else {
          $j('#macro_preview').html("Failed to insert chart. Please try again with valid chart properties.");
        }
      }
    });
  }

  return {
    title: 'Macro Editor',
    width: 600,
    height: 400,
    resizable: CKEDITOR.DIALOG_RESIZE_NONE,
    contents: [{
      id: 'tab-edit',
      label: 'Edit',
      elements: [{
        id: 'macro_editor',
        type: 'html',
        html: ''
      }]
    }],
    onShow: function () {
      dialog = this;
      $j(dialog.parts.footer.$).find('.cke_dialog_footer_buttons').addClass('shift-left');
      var element = CKEDITOR.Mingle.MacroEditor.currentMacroElement || CKEDITOR.Mingle.MacroEditor.findEnclosingMacro(editor.getSelection().getStartElement().$),
          macro;
      if (element && !CKEDITOR.Mingle.MacroEditor.macroData) {
        macro = decodeURIComponent($j(element).attr('raw_text'));
        CKEDITOR.Mingle.MacroEditor.macroData = {
          content: macro,
          type: macro.match(/{{\s*(?:(\S*)?|(?:\S*)):?([^}]*)}}/m)[1]
        };
      }

      this.existingMacroElement = new CKEDITOR.dom.element(element);
      $j.ajax({
        type: 'get',
        url: editor.element.data('ckeditor-mingle-macro-edit-params-url'),
        data: {macro: CKEDITOR.Mingle.MacroEditor.macroData.content || macro},
        async: false,
        success: openEasyChartEditor.bind(this)
      });
    },
    onCancel: function () {
      $j(dialog.getElement().$).find("#macro_preview").empty();
      CKEDITOR.Mingle.MacroEditor.moveCursorToEndOfCurrentMacro(editor);
      CKEDITOR.Mingle.MacroEditor.currentMacroElement = null;
      CKEDITOR.Mingle.MacroEditor.macroData = null;
    },
    buttons: [
      {
        id: 'insert',
        type: 'button',
        label: 'Save',
        className: 'cke_dialog_ui_button_ok',
        onClick: requestRenderedMacro
      },
      CKEDITOR.dialog.cancelButton
    ]
  };
});
