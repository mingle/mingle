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
CKEDITOR.dialog.add( 'macroBuilderDialog', function ( editor ) {
  var insertMacroPreview = function (response, textStatus, jqXHR){
    var element = dialog.getContentElement('tab-builder', 'content_area').getElement().$;
    $j(element).html(response);
  };

  var requestRenderedMacro = function(){
    var request = $j.ajax({
      url: editor.element.data("ckeditor-mingle-macro-data-generate-url"),
      type: "post",
      data: $('macro_editor_preview_form').serialize(),
      async: false,
      success: insertMacro.bind(this),
      error: function(response, textStatus, jqXHR) {
        $j('#macro_preview').html(response.responseText);
        window.macroEditor.scrollToPreview();
      }
    });
  };

  var insertMacro = function (response, textStatus, jqXHR){
    var element = $j(response)[0];
    editor.insertElement(new CKEDITOR.dom.element(element));

    editor.insertHtml("<br/>");
    this.dialog.hide();
  };

  return {
    title: 'Macro',
    width: 600,
    height: 400,
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
    onShow: function() {
      dialog = this;
      $j(dialog.getElement().$).find('.cke_dialog_title').text('Build ' + dialog.macroName + ' Macro');
      var request = $j.ajax({
        url: editor.element.data("ckeditor-mingle-macro-data-editor-url"),
        data: {'macro_type': dialog.macroType},
        type: "get",
        async: false,
        success: insertMacroPreview.bind(this)
      });
    },
    buttons: [
      {
        type: 'button',
        label: 'Insert',
        className: 'cke_dialog_ui_button_ok',
        onClick: requestRenderedMacro.bind(this)
      },
      {
        type : 'button',
        id : 'preview_macro',
        className: 'cke_dialog_ui_button_cancel',
        label : 'Preview',
        title : 'My title',
        onClick : function() {
          $('macro_editor_preview_form').onsubmit();
        }
      },
      CKEDITOR.dialog.cancelButton
    ]
  };
});
