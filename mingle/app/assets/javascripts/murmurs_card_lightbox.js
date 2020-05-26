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

  $.fn.cardMurmurs = function() {
    var element = this;
    var content = element.find(".content");
    var ul = content.find("ul");

    element.on("click", ".title", function(e) {
      element.find("textarea").val("");
      togglePanel();
    });

    var togglePanel = function(state, initializing) {
      if(state !== undefined) {
        if(state) {
          expandPanel(initializing);
        } else {
          collapsePanel(initializing);
        }
        return;
      }
      if(isPanelExpanded()) {
        collapsePanel(initializing);
      } else {
        expandPanel(initializing);
      }
    };

    function isPanelExpanded() {
      return element.data("expand");
    }

    function expandPanel(initializing) {
      content.show();
      element.parents('.lightbox').addClass("sidebar-attached");
      element.find('[autofocus="true"]').focus();
      MingleUI.lightbox.loadMurmurs(element);
      element.data("expand", true);
      if(!initializing) {
        MingleUI.updateUserPreference("card_flyout_display", "murmurs");
      }
    }

    function collapsePanel(initializing) {
      content.hide();
      element.parents('.lightbox').removeClass("sidebar-attached");
      element.data("expand", false);
      if(!initializing) {
        MingleUI.updateUserPreference("card_flyout_display", "");
      }
    }

    element.on("keydown", "textarea", function(e) {
      var input = $(this);
      var form = input.closest("form");
      if (!(e.shiftKey || e.metaKey || e.ctrlKey) && e.which == $.ui.keyCode.ENTER) {
        e.preventDefault();
        var updatedText = $.trim(input.val());
        if ("" !== updatedText) {
          form.submit();
          input.val("");
        }
      }
    });

    element.on("submit", ".content form", function(e) {
      e.preventDefault();
      var form = $(this);

      $.ajax({
        url: form.attr("action"),
        data: form.serialize(),
        dataType: "json",
        type: form.attr("method").toUpperCase(),
        beforeSend: function(xhr, settings) {
          element.find(".murmurs-loading").slideDown();
        }
      }).always(function(data, status) {
        element.find("textarea").val("");
        element.find("input[name='comment[replying_to_murmur_id]']").val("");
        MingleUI.lightbox.loadMurmurs(element);
      });
    });

    element.on("click", ".murmur-reply", function(e) {
      e.preventDefault();
      var user = $(this).data("reply-to");
      var murmurId = $(this).parents(".murmur-panel").data("murmur-id");

      if(!/^version-/.test(murmurId)) { // if start with version means  it is a old style comment instead of a murmur
        element.find("input[name='comment[replying_to_murmur_id]']").val(murmurId);
      }
      element.find("textarea").focus().val(user + ' ');
    });

    if (0 === element.closest("[data-panel-name='murmurs']").length) {
      togglePanel(element.data("expand"), true);
    }

    return this;
  };
})(jQuery);
