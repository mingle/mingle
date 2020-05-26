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
Program.NameEditor = {
  initializeNameEditor: function(selector) {
    var menuItems = $j(selector).closest(".program-title-container").find(".program_menu_items");
    menuItems.find('.rename_program_action').click(function(event) {
      Program.NameEditor.showRenameInput(event.target);
      DropDownMenu.hideAll();
      return false;
    });
  },

  showRenameInput: function(element) {
    var programDiv = $j(element).closest('.program');
    var form = programDiv.find('form');
    var program_menu = programDiv.find('.program_menu');

    program_menu.hide();
    form.show();
    input = form.find('input.program-name-editor').focus().select(); // focus() and select() required for IE7

    input.on("keydown blur", function(e) {
      if (e.keyCode === $j.ui.keyCode.ESCAPE || e.type === 'blur') {
        Program.NameEditor.hideRenameInput(program_menu, form);
      }
    });
  },

  hideRenameInput: function(program_menu, form) {
    form.hide();
    program_menu.show();
  },

  enableNameEditor: function(programId, content) {
    content = $j("<div class=\"program program-panel\" id=\"program_details_" + programId +"\"></div>").html(content);
    $j('.program_list').prepend(content);
    Program.NameEditor.initializeNameEditor('#program_details_' + programId + ' .program_menu');
    Program.NameEditor.showRenameInput($j('#program_' + programId + '_link'));
  }
};