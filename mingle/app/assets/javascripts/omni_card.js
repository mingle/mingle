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
(
  function($) {

    $.widget( "mingle.omniCard", $.ui.autocomplete, {
      _renderItem: function( ul, item ) {
        var number = $("<span class='number'/>").css("border-left-color", MingleUI.cardTypeColors[item.type] || "transparent");
        var name = $("<span class='name'/>");

        if (item.stats && item.stats.number.length > 0) {
          number.html(MingleUI.fuzzy.highlight(item.value, item.stats.number));
        } else {
          number.text(item.value);
        }

        if (item.stats && item.stats.name.length > 0) {
          name.html(MingleUI.fuzzy.highlight(item.label, item.stats.name));
        } else {
          name.text(item.label);
        }

        return $("<li>").
          append($("<a>").attr("onclick", "return false;").
          append(number).append(name)).
          appendTo(ul);
      },
      _close: function(e) {
        if (e && "blur" === e.type) {
          e.preventDefault();
          return;
        }

        this._superApply(arguments);
      },
      _suggest: function(items) {
        this._superApply(arguments);
        if (items.length === 1) {
          this.menu.next();
        }
      }
    });

    MingleUI.omni = {
      hide: $.noop,
      show: $.noop
    };

    $(document).ready(function() {
      var omni = $("#find-any");
      if (omni.size() === 0) {
        return;
      }

      var storage;
      var throttle;
      var form = omni.find("form").submit(function(e){ e.preventDefault(); });
      var field = form.find("input[type='text']");

      function hideOmni(e) {
        var returnValue;

        // assume keystroke combo defined elsewhere
        if (!!e && /key/.test(e.type) && omni.is(":visible")) {
          returnValue = false;
        }

        omni.hide();
        field.val('');
        field.prop("disabled", true);
        field.omniCard("close");

        return returnValue;
      }

      function showOmni() {
        MingleUI.cmd.closeHelp();

        // need to show before doing height calculation
        omni.show();
        var limit = $(window).height() - (form.offset().top + form.height() + 40);
        omni.find(".ui-autocomplete").css("max-height", limit + "px");

        field.omniCard("close");
        field.prop("disabled", false);
        field.focus();
      }

      MingleUI.omni.hide = hideOmni;
      MingleUI.omni.show = showOmni;

      Mousetrap.bindGlobal("mod+shift+\\", function(e) {
        $.Event(e).preventDefault();
        // populate cache from localStorage the first time for perceptual speed
        if (!storage) {
          storage = JSON.parse(localStorage.getItem(omni.data("namespace") + ".es.fuzzyCache")) || [];
        }

        var diff = 0;
        if (!throttle || (diff = new Date() - throttle) > 5000) {
          $.ajax({
            url: omni.data("url"),
            dataType: "json",
            type: "GET"
          }).done(function(data) {
            storage = data;
            localStorage.setItem(omni.data("namespace") + ".es.fuzzyCache", JSON.stringify(storage));
          });
        } else {
          omni.data("throttle", diff);
        }

        throttle = new Date();
        showOmni();
        MingleUI.cmd.track("fuzzy find card");
      });

      field.on("blur", hideOmni);

      field.omniCard({
        minLength: 0,
        delay: 0,
        appendTo: field.closest(form),
        focus: function(e, ui) {
          e.preventDefault();
          return false;
        },
        source: function(request, response) {
          var matches = MingleUI.fuzzy.cardFinder(storage, request.term.toString());

          response(matches.slice(0, 25));
        },
        select: function(e, ui) {
          hideOmni();
          InputingContexts.clear();
          MingleUI.cards.showPopup(ui.item.value);
        }
      });

  });
})(jQuery);
