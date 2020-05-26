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
(function($) {

  if (typeof(CKEDITOR.Mingle) === "undefined") { CKEDITOR.Mingle = {}; }

  CKEDITOR.Mingle.MacroEditor = {
    findEnclosingMacro: function(element) {
      if (element) {
        var triggered = $(element);
        var jQueryMacroElement = triggered.closest(".macro");
        if (jQueryMacroElement.size() > 0) {
          return jQueryMacroElement[0];
        }
      }
      return null;
    },
    moveCursorToEndOfCurrentMacro: function(editor, macroElement) {
      if (!macroElement) {
        return;
      }

      editor.getSelection().selectElement(new CKEDITOR.dom.element(macroElement));
      var range = editor.getSelection().getRanges()[0];
      range.collapse(false);
      range.select();
    },
    easyChartsMacroEditorEnabledFor: function(editor, macroType) {
      CKEDITOR.Mingle.MacroEditor.easyChartFormEnabledFor = CKEDITOR.Mingle.MacroEditor.easyChartFormEnabledFor || (editor.element.data('easy-charts-macro-editor-enabled-for') || '').split(',');
      return CKEDITOR.Mingle.MacroEditor.easyChartFormEnabledFor.include(macroType);
    }
  };

  CKEDITOR.plugins.add( 'macro_editor', {
    init: function( editor ) {
      if ("dependency[description]" === $(editor.element.$).attr("name")) {
        return;
      }

      CKEDITOR.dialog.add( 'macroEditorDialog', this.path + 'dialogs/macro_editor.js?rev=' + CKEDITOR.mingleRevision );
      CKEDITOR.dialog.add( 'easyChartsMacroEditorDialog', this.path + 'dialogs/easy_charts_macro_editor.js?rev=' + CKEDITOR.mingleRevision );

      editor.addCommand( 'macroEditorDialog', new CKEDITOR.dialogCommand( 'macroEditorDialog' ) );
      editor.addCommand( 'easyChartsMacroEditorDialog', new CKEDITOR.dialogCommand( 'easyChartsMacroEditorDialog' ) );
      editor.ui.addButton( 'macro_editor', {
        label: 'Insert Macro',
        command: 'macroEditorDialog',
        icon: "/images/macro_editor.png"
      });

      if ( editor.contextMenu ) {
        editor.addMenuGroup( 'mingleGroup' );
        editor.addMenuItem( 'macroEditorDialog', {
          label: 'Edit Macro',
          icon: "/images/macro_editor.png",
          command: 'macroEditorDialog',
          group: 'mingleGroup'
        });
        editor.contextMenu.addListener( function( element ) {
          var enclosingMacro = CKEDITOR.Mingle.MacroEditor.findEnclosingMacro(element.$);
          if (enclosingMacro) {
            CKEDITOR.Mingle.MacroEditor.currentMacroElement = enclosingMacro;
            return { macroEditorDialog: CKEDITOR.TRISTATE_ON };
          } else {
            CKEDITOR.Mingle.MacroEditor.currentMacroElement = null;
          }
        });
      }

    }
  });

})(jQuery);
