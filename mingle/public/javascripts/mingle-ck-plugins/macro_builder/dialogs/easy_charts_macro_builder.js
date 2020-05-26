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
CKEDITOR.dialog.add('easyChartsMacroBuilderDialog', function (editor) {
  var requestRenderedMacro = function () {
    $j("#macro_preview").empty();
    $j.ajax({
      url: editor.element.data("ckeditor-mingle-macro-data-generate-url"),
      type: "post",
      data: dialog.easyChartsWizard.getChartData(),
      async: false,
      success: insertMacro.bind(this),
      error: function (response, textStatus, jqXHR) {
        if (response.status === 422) {
          $j('#macro_preview').html(response.responseText);
        } else {
          $j('#macro_preview').html("Failed to insert chart. Please try again with valid chart properties.");
        }
      }
    });
  };

  var insertMacro = function (response, textStatus, jqXHR) {
    var createdUsingMqlEditor = $j('#charts_macro_form_container').is(':visible'),
        element = $j(response)[0];
    editor.insertElement(new CKEDITOR.dom.element(element));

    editor.insertHtml("<br/>");
    this.dialog.hide();
    MingleUI.EasyCharts.ActionTracker.recordCreateEvent(dialog.macroType, createdUsingMqlEditor);
  };

  return {
    title: 'Macro',
    width: 750,
    height: 500,
    resizable: CKEDITOR.DIALOG_RESIZE_NONE,
    contents: [
      {
        id: 'tab-builder',
        label: 'Edit',
        elements: [
          {
            id: 'content_area',
            type: 'html',
            html: ''
          }

        ]
      }
    ],

    onShow: function () {
      dialog = this;
      $j(dialog.parts.footer.$).find('.cke_dialog_footer_buttons').addClass('shift-left');
      $j(dialog.getElement().$).find('.cke_dialog_title').text('Build a ' +  dialog.macroName);
      var element = dialog.getContentElement('tab-builder', 'content_area').getElement().$;
      var container = $j('<div>', {id: 'chart_builder_wizard_container'});
      $j(element).html(container);
      var editorData = {
        supportedInEasyCharts: true,
        chartData: {
          project: editor.element.data('project-identifier'),
          initialProject: editor.element.data('project-identifier')
        },
        contentProvider: JSON.parse(editor.element.data('content-provider')),
        macroHelpUrls: JSON.parse(editor.element.data('macro-help-urls'))
      };
      dialog.easyChartsWizard = new MingleUI.EasyCharts.EasyChartsWizard(container, dialog.macroType, editorData);

    },

    onCancel: function () {
      $j(dialog.getElement().$).find("#macro_preview").empty();
    },

    buttons: [
      {
        id: 'insert',
        type: 'button',
        label: 'Insert',
        className: 'cke_dialog_ui_button_ok',
        onClick: requestRenderedMacro.bind(this)
      },
      CKEDITOR.dialog.cancelButton
    ]
  };
});