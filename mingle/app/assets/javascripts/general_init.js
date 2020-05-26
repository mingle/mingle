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
  $(function() {
    MingleUI.currentProject = $("[data-project]").data("project");

    $('#ft .team-list').mingleTeamList("Draggable");
    $('.popover').popover();

    $(document).on('click', '.lightbox-close-button', function() {
      InputingContexts.pop();
    });

    $(document.body).on("mouseleave", "[data-clipboard-text]", function(e) {
      var el = $(e.currentTarget);
      el.tipsy("hide");
      if (el.attr("original-title") !== "") {
        el.attr("title", el.attr("original-title"));
      }
    });

    var clipboard = new Clipboard("[data-clipboard-text]");
    clipboard.on("success", function(e) {
      var el = $(e.trigger);
      el.tipsy({
        trigger: "manual",
        title: function() { return "Copied"; }
      });
      el.tipsy("show");
    });

    clipboard.on("error", function(e) {
      var el = $(e.trigger);
      el.tipsy({
        trigger: "manual",
        title: function() {
          return MingleUI.cmd.platform === "mac" ? "Press Cmd-C to copy" : "Press Ctrl-C to copy";
        }
      });
      el.tipsy("show");
    });

    $(".fb-badge").firebaseBadger();

    $(document).ready(function() {
      if (!Notification) {
        return;
      }
      if (Notification.permission !== "granted") {
        Notification.requestPermission();
      }
    });

  });
})(jQuery);
