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
  $(document).ready(function() {

    if (!$("#page-identifier-projects-delete").length) {
      return;
    }

    var dialog = $("<form class='confirm-me'>").append("<label>Please type the name of the project to confirm:<br/><input type='text' name='projectName'/></label>").append("<input type='submit' value='I understand the consequences, delete this project'/>");
    var curtains = $("<div class='curtains'>");
    curtains.append(dialog);

    function closeConfirm() {
      if ($.contains(document.body, curtains.get(0))) {
        dialog.get(0).reset();
        dialog.off("submit");
        curtains.fadeOut({
          duration: 250,
          done: function() {
            curtains.removeAttr("style").detach();
          }
        });
        return false;
      }
    }

    curtains.on("click", function(e) {
      e.stopPropagation();
      var el = $(e.target);
      if (!el.is(".confirm-me") && !el.is(".confirm-me *")) {
        closeConfirm();
      }
    });

    var index = MingleUI.cmd.escapeKeyQueue.indexOf(MingleUI.projectMenu.close);
    if (index > -1) {
      MingleUI.cmd.escapeKeyQueue.splice(index, 0, closeConfirm);
    } else {
      MingleUI.cmd.escapeKeyQueue.push(closeConfirm);
    }

    var deleteForm = $("form[data-project-name]");

    // hijack the click handler
    $(".action-bar a.ok").removeAttr("onclick").on("click", function(e) {
      e.preventDefault();
      e.stopPropagation();

      $(document.body).prepend(curtains);
      dialog.find("input").focus();

      var expected = ("" + deleteForm.data("project-name")).toLowerCase();

      dialog.on("submit", function(e) {
        e.preventDefault();

        var entered = $.trim($(e.target.projectName).val()).toLowerCase();
        if ("" === entered) {
          return;
        }

        if (expected !== entered) {
          dialog.addClass("wrong-answer").delay(400).queue(function(){
            this.reset();
            $(this).removeClass("wrong-answer").dequeue();
          });
        } else {
          deleteForm.submit();
        }
      });
    });
  });
})(jQuery);
