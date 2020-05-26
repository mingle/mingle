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
CKEDITOR.plugins.add('macro_builder',{
  init: function(editor) {
    CKEDITOR.dialog.add( 'macroBuilderDialog', this.path + 'dialogs/macro_builder.js?rev=' + CKEDITOR.mingleRevision);
    CKEDITOR.dialog.add( 'easyChartsMacroBuilderDialog', this.path + 'dialogs/easy_charts_macro_builder.js?rev=' + CKEDITOR.mingleRevision);
    var plugin = this;

    CKEDITOR.Mingle.MacroBuilder = {
      easyChartEnabled: function (editor, internalName) {
        return ['pie-chart','ratio-bar-chart','stacked-bar-chart', 'data-series-chart', 'cumulative-flow-graph', 'daily-history-chart'].include(internalName);
      }
    };
    var commandFor = function(internalName, humanizedName) {
      return {
        exec: function(editor) {
          var macroEditorDialog = CKEDITOR.Mingle.MacroBuilder.easyChartEnabled(editor, internalName) ? 'easyChartsMacroBuilderDialog' : 'macroBuilderDialog';
          editor.openDialog(macroEditorDialog, function(dialog) { dialog.macroType = internalName; dialog.macroName = humanizedName; });
        }
      };
    };

    var addMacroBuilderButton = function(name) {
      var commandName = 'open' + name + 'Builder';
      var humanizedName = name.replace(/-/g, ' ').replace(/\b([a-z])/g, function(entireMatch, $1) { return $1.toUpperCase(); });
      editor.addCommand(commandName, commandFor(name, humanizedName));
      editor.ui.addButton( name + '_macro_button', {
          label: 'Insert ' + humanizedName,
          command: commandName,
          icon: plugin.path + 'icons/' + name + '.png'
      });

    };

    editor.addCommand('openProjectBuilder', {
      exec: function(editor) {
        var request = $j.ajax({
            url: editor.element.data("ckeditor-mingle-macro-data-render-url"),
            type: "post",
            data: {macro: '{{ project }}'},
            async: false,
            success: function(response, textStatus, jqXHR) {
              var element = $j(response)[0];
              editor.insertElement(new CKEDITOR.dom.element(element));

              editor.insertHtml("<br/>");
            }
        });
      }
    });
    editor.ui.addButton('project_macro_button', {
        label: 'Insert Project',
        command: 'openProjectBuilder',
        icon: plugin.path + 'icons/project.png'
    });


    addMacroBuilderButton('project-variable');

    addMacroBuilderButton('average');
    addMacroBuilderButton('value');
    addMacroBuilderButton('table-query');
    addMacroBuilderButton('table-view');
    addMacroBuilderButton('pivot-table');
    addMacroBuilderButton('cumulative-flow-graph');
    addMacroBuilderButton('stacked-bar-chart');
    addMacroBuilderButton('data-series-chart');
    addMacroBuilderButton('daily-history-chart');
    addMacroBuilderButton('ratio-bar-chart');
    addMacroBuilderButton('pie-chart');

  }
});
