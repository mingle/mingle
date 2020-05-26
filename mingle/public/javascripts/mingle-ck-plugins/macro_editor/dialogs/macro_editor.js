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
CKEDITOR.dialog.add( 'macroEditorDialog', function ( editor ) {

  var chunkString = function(str, chunkSize) {
    var len = str.length;
    var chunks = [];
    var words = str.split(/\b/).reverse();

    while(words.size() > 0) {
      var currentLine = "";
      while(currentLine.length <= 80 && words.size() > 0) {
        currentLine += words.pop();
      }
      chunks.push(currentLine);
    }

    return chunks;
  };

  var clearError = function(dialog) {
    var element = dialog.getContentElement('tab-edit', 'macro_error').getElement();
    var msg_element = $j(element.$);
    msg_element.empty().hide();
  };

  var showError = function(dialog, msg) {
    var element = dialog.getContentElement('tab-edit', 'macro_error').getElement();
    var msg_element = $j(element.$);
    var formattedErrMsg = msg;
    if (CKEDITOR.env.ie === true && formattedErrMsg.match(/class='error'>/)) {
      var miniDom = $j('<div/>').html(msg).contents();
      var errorMessage = miniDom.find('.error').text();
      formattedErrMsg = "<div class='error'>" + chunkString(errorMessage, 80).join("<br/>") + "</div>";
    }
    msg_element.html(formattedErrMsg);
    msg_element.fadeIn();
  };

  var insertMacroHtml = function (dialog, response) {
    var element = $j(response)[0];
    element = new CKEDITOR.dom.element(element);

    if (dialog.existingMacroElement) {
       dialog.existingMacroElement.insertBeforeMe(element);
       dialog.existingMacroElement.remove();
    } else {
      editor.insertElement(element);
      editor.insertHtml('<br/>');
    }

    return element.$;
  };

  var errorHandler = function(jqXHR, status, error){
    var message = jqXHR.responseText;
    if (message == ' ') {
      message = 'Unable to validate macro.';
    }
    showError(this, message);
  };

  var readPluginConfig = function(configName) {
    return editor.element.data("ckeditor-mingle-" + configName);
  };

  return {
      title: 'Macro Editor',
      width: 600,
      height: 400,
      resizable: CKEDITOR.DIALOG_RESIZE_NONE,
      contents: [
        {
            id: 'tab-edit',
            label: 'Edit',
            elements: [
                {
                  id: 'macro_help_top_level',
                  type: 'hbox',
                  widths : [ '90%', '10%' ],
                  children: [
                    {
                      id: 'macro_error',
                      type: 'html',
                      html: '',
                      className: "macro_editor_error"
                    },
                    {
                      id: 'macro_help_link',
                      type: 'html',
                      className: 'macro_help_tr',
                      html: '<a href="' + readPluginConfig("macro-help-url") + '" target="_blank" class="page-help-at-macro-editor">Help</a>'
                    }
                  ]
                },
                {
                  type: 'textarea',
                  id: 'macro_editor',
                  rows: 30,
                  cols: 120
                }
            ]
        }
      ],
      onShow: function() {
        var removeBracesFrom = function(text) {
          return text.replace("{{", "").replace("}}", "").strip();
        };
        var element = CKEDITOR.Mingle.MacroEditor.currentMacroElement || CKEDITOR.Mingle.MacroEditor.findEnclosingMacro(editor.getSelection().getStartElement().$);
        if (element) {
          this.setValueOf( 'tab-edit', 'macro_editor', removeBracesFrom(decodeURIComponent($j(element).attr('raw_text'))));
          this.existingMacroElement = new CKEDITOR.dom.element(element);
          $j(".cke_dialog_ui_input_textarea").hide().fadeIn('fast');
        } else {
          this.existingMacroElement = null;
        }
      },
      onOk: function() {
        var surroundWithBraces = function(text) {
          return "{{\n\t" + text + "\n}}";
        };
        var dialog = this;
        clearError(dialog);
        var macroText = $j.trim(dialog.getValueOf('tab-edit', 'macro_editor'));
        if (!macroText) {
          showError(dialog, "Please enter a macro.");
          return false;
        }
        macroTextWithBraces = surroundWithBraces(macroText);
        var request = $j.ajax({
            url: editor.element.data('ckeditor-mingle-macro-data-render-url'),
            type: "post",
            data: { macro: macroTextWithBraces },
            async: false,
            success: function(response, textStatus, jqXHR) {
              var macroElement = insertMacroHtml(dialog, response);
              CKEDITOR.Mingle.MacroEditor.moveCursorToEndOfCurrentMacro(editor, macroElement);
              CKEDITOR.Mingle.MacroEditor.currentMacroElement = null;
            },
            error: errorHandler.bind(this)
        });

        if (request.status != 200) {
          return false;
        }
      },
      onCancel: function() {
        CKEDITOR.Mingle.MacroEditor.moveCursorToEndOfCurrentMacro(editor);
        CKEDITOR.Mingle.MacroEditor.currentMacroElement = null;
        showError(this, "");
      }
  };
});
