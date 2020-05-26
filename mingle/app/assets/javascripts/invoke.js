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
if ("undefined" === typeof window.MingleUI) {
  window.MingleUI = {};
}

(function($) {

  MingleUI.cmd = {
    platform: navigator.platform.indexOf("Win") === -1 ? "mac" : "win",
    track: function track(action) {
      mixpanelTrack("hotkey", {"action": action, "platform": MingleUI.cmd.platform, "site": window.location.hostname.split(".").shift()});
    },
    saveOnKeyHandler: function saveOnKeyHandler(event) {
      if ((event.metaKey || event.ctrlKey) && event.keyCode === jQuery.ui.keyCode.ENTER) {
        MingleUI.cmd.saveEditor();
      }
    },
    saveEditor: function saveEditor() {
      // basically, go down the list of candidates
      // and find a save button to click
      $.each([
        "#lightbox .edit-mode .save-content.primary",
        "#add_card_form .save-content",
        "#card-edit-form .save",
        "#page_form .save",
      ], function(i, sel) {
        var save = $(sel);
        if (save.size() > 0) {
          save.click();
          return false; // break loop
        }
      });
    }
  };

  $(document).ready(function() {
    var invoker = $("#invoke");
    if (invoker.size() === 0) {
      return;
    }

    var help = $("#keyboard-help");
    var grid = $(".swimming-pool");

    if (MingleUI.cmd.platform !== "win") {
      var helpContent = help.find(".keys");
      helpContent.html(helpContent.html().replace(/ctrl/g, "&#8984;"));
    }

    function closeHelp(e) {
      if (!e) { // programmatically called
        help.hide();
      } else {
        // clicking anywhere outside the help should close
        if (e.type === "click" && $(e.target).closest(".keys").addBack(".keys").length === 0) {
          help.hide();
          return false;
        }

        // if bound to keystroke and is visible, hide. assume keystroke combo defined elsewhere
        if (/key/.test(e.type) && help.is(":visible")) {
          help.hide();
          return false;
        }
      }
    }

    function toggleHelp() {
      help.toggle();
      MingleUI.cmd.track("help");
    }

    MingleUI.cmd.toggleHelp = toggleHelp;
    MingleUI.cmd.closeHelp = closeHelp;
    help.on("click", MingleUI.cmd.closeHelp);

    function updateGridContext(grid) {
      // when this is uninitialized, we probably updated the wall
      if (grid.size() !== 0 && "undefined" === typeof grid.data("card-order")) {
        var cards = $.map(grid.find(".card-summary-number"), function(el, i) {
          return parseInt($(el).text().replace("#", ""), 10);
        });
        grid.data("card-order", cards);
        invoker.data("grid-context", cards);
      }
    }

    // when in grid view, follow the visual card order which is not always == card-context order
    updateGridContext(grid);

    function go(direction) {
      var cardShow = $("#card_show_lightbox_content");
      if (cardShow.size() > 0 && $("#add_card_popup").size() === 0) {
        var current = cardShow.find(".inline-edit-form").data("card-number");
        var key = "card-context", context;

        grid = $(".swimming-pool");

        if (grid.size() !== 0) {
          key = "grid-context";
          updateGridContext(grid);
        }
        context = invoker.data(key);

        var position = context.indexOf(current);

        if (position === -1) {
          context.push(current);
          position = context.indexOf(current);
          invoker.data(key, context);
        }

        // only make a request if there are other cards to navigate
        if (context.length > 1) {
          var last = (context.length - 1);

          // start over when hitting the last element
          var next = position === last ? 0 : position + 1;

          // go to the end when hitting first element
          var prev = position === 0 ? last : position - 1;

          var index = (direction === "fwd") ? next : prev;

          InputingContexts.clear();
          MingleUI.cards.showPopup(context[index]);
        }

        MingleUI.cmd.track("nav card " + direction);
      }
    }

    Mousetrap.bindGlobal("mod+shift+c", function keyQuickAdd(e) {
      $.Event(e).preventDefault();
      MingleUI.cmd.closeHelp();

      var addCard = $("#add_card_with_defaults");
      if (addCard.size() > 0 && $("#add_card_popup").size() === 0) {
        if (!!MagicCard.instance) {
          var firstRow = $(".swimming-pool tbody").find("tr:first");
          var firstCell = firstRow.find("td:first");
          var lane = firstCell.attr("lane_value");
          var row = firstRow.attr("row_value");

          MagicCard.instance.revealPopup(lane, row);
        } else {
          addCard.click();
        }
      }
      MingleUI.cmd.track("quick add card");
    });

    Mousetrap.bindGlobal("mod+]", function keyNextCard(e) {
      $.Event(e).preventDefault();
      MingleUI.cmd.closeHelp();

      go("fwd");
    });

    Mousetrap.bindGlobal("mod+[", function keyPrevCard(e) {
      $.Event(e).preventDefault();
      MingleUI.cmd.closeHelp();

      go("bck");
    });

    Mousetrap.bindGlobal("mod+/", function keyShowHelp(e) {
      $.Event(e).preventDefault();
      MingleUI.cmd.toggleHelp();
    });

    Mousetrap.bindGlobal("esc", function processEscapeKeyQueue(e) {
      $.each(MingleUI.cmd.escapeKeyQueue, function(i, fn) {
        if (fn(e) === false) {
          e.stopPropagation();
          e.preventDefault();
          return false;
        }
      });
    });

    // pipeline for handling escape key event
    // any function explictly returning false (exactly false,
    // not falsey values) exits the pipeline
    MingleUI.cmd.escapeKeyQueue = [
      MingleUI.cmd.closeHelp,
      MingleUI.omni.hide,
      InputingContexts.escapeKeyHandler,
      MingleUI.projectMenu.close
    ];

    Mousetrap.bindGlobal("shift shift", function(e) {
      $.Event(e).preventDefault();
      MingleUI.cmd.closeHelp();

      // invoker.show();
    });
  });
})(jQuery);