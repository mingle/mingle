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

  var ReorderTabs = (function tabReorderingModule() {
    var tabReorderStatus = {
      succeeded: "succeeded",
      failed: "failed"
    };

    function reorderTabs(element, newOrder) {
      var url = element.data("tab-reorder-url");

      $.ajax({
        url: url,
        dataType: "json",
        data: {"new_order": newOrder},
        type: "PUT"
      }).done(function(data) {
        element.data("reorder-status", tabReorderStatus.succeeded);
      }).fail(function(data) {
        element.data("reorder-status", tabReorderStatus.failed);
      });
    }

    function setupTabReordering(element) {
      var sortableTabs = element.find("[data-reorderable='true']");

      sortableTabs.sortable({
        beforeStop: function(event, ui) {
          $(ui.item).removeClass("draggable-tab");
        },
        stop: function(event, ui) {
          var newOrder = $.map(sortableTabs.find("li"), function(tab) {
            return $(tab).data("tab-id");
          });
          reorderTabs(sortableTabs, newOrder);
        },
        start: function(event, ui) {
          sortableTabs.data("reorder-status", tabReorderStatus.unknown);
          $(ui.helper).addClass("sortable-helper");
        },
        placeholder: "sortable-placeholder",
        forcePlaceholderSize: true,
        forceHelperSize: true,
        helper: "clone",
        opacity: 1,
        containment: "#hd-nav",
        cursor: "move",
        delay: 0,
        tolerance: "pointer",
        distance: 5,
        cancel: ".tab-drop-down,.tab-drop-down *",
        cursorAt: {left: 5}
      });
    }

    return {
      setup: setupTabReordering,
      status: tabReorderStatus
    };

  })();

  var RenameTabs = (function tabRenamingModule() {
    var throttle, guard, panel, scrollable, reorderable;

    function initTabRenaming(element) {
      panel = element.siblings(".tab-drop-down");
      if (panel.length === 0) return;

      scrollable = element.find(".sortable-tabs");
      reorderable = element.find('[data-reorderable="true"]');
      var trigger = element.find(".tab-edit-icon");
      var content = panel.find(".content");
      var deltaOffset = element.position();
      var centerOffset = addPos({left: trigger.outerWidth() / 2, top: trigger.outerHeight()}, {left: -8, top: 8} /* account for margins */);

      trigger.off("click");
      teardown();

      trigger.on("click", function(e) {
        if (1 !== e.which) return; // not left click

        e.preventDefault();
        e.stopPropagation();

        if (content.is(":hidden")) {
          setup(element);

          content.css(addPos(addPos(deltaOffset, trigger.position()), centerOffset));
          panel.addClass("open");

          var form = content.find("form");
          var textInput = form.find("input[type=text]");
          form.get(0).reset();
          textInput.val(element.find(".current-menu-item").data("tab-name"));
          textInput.focus();

          handleTabRename(form, content);
        } else {
          hide();
        }
      });
    }

    function setup(element) {
      if (element.is("[data-scrolling='true']")) {
        guard = false;

        // performance-conscious scroll handling
        throttle = setInterval(closeRenamePopoverOnScroll, 250);
        scrollable.on("scroll", throttleGuard);
        reorderable.on("sort", throttleGuard);
      }

      $(document).on("click", new UIUtils().onClickOutside(panel, hide));
    }

    function teardown() {
      if ("number" === typeof throttle) {
        clearInterval(throttle);
        throttle = null;
      }
      guard = false;

      scrollable.off("scroll", throttleGuard);
      reorderable.off("sort", throttleGuard);
      $(document).off("click", new UIUtils().onClickOutside(panel, hide));
    }

    function hide() {
      teardown();
      panel.removeClass("open");
    }

    function throttleGuard(e) {
      guard = true;
    }

    function closeRenamePopoverOnScroll() {
      if (guard) {
        hide();
        guard = false;
      }
    }

    function outsideClick(e) {
      if (1 !== e.which) return; // not left click

      if (!withinOrIs(e.target, panel)) {
        e.stopPropagation();
        e.preventDefault();
        hide();
      }
    }

    function addPos(a, b) {
      return {
        left: a.left + b.left,
        top: a.top + b.top
      };
    }

    function handleTabRename(form, dropdown) {
      if (!form.data("inited")) {
        form.withProgressBar({attachTo: form.find("input[type=submit]")});

        form.submit(function(e) {
          e.preventDefault();
          $.ajax({
            url: form.attr("action"),
            dataType: "json",
            data: form.serialize(),
            type: "PUT"
          }).done(function(data) {
            // the easiest thing to do is to load the page. otherwise, there
            // are so much to update on the page (all the links, all the hidden
            // inputs in forms, all inline javascript, sidebar objects, etc),
            // and that would require a lot of rigorous testing to ensure confidence.
            window.location = data["link"];
          }).fail(function(jqXHR, textStatus, errorThrown) {
            var reason = $.parseJSON(jqXHR.responseText)["message"];
            var errorMsg = $('<div class="tab-error-message"/>').html(reason);
            dropdown.prepend(errorMsg);
            setTimeout(function() { errorMsg.remove(); }, 5000);
          });
        });

        form.data("inited", true);
      }
    }

    return {
      setup: initTabRenaming
    };

  })();

  var ScrollingTabs = (function tabScrollingModule() {
    function detectPaging(element) {
      if (!element.is("[data-scrolling='true']")) return;

      var viewable = element.width();
      var total = element.find(".sortable-tabs")[0].scrollWidth;

      if (total - viewable > 10) {
        element.addClass("paged");
      } else {
        element.removeClass("paged");
      }
    }

    function ensureCurrentTabInView(viewable, scrollable) {
      var tab = scrollable.find(".current-menu-item");
      var tabWidth = tab.outerWidth();
      var viewableWidth = viewable.width();
      var buttonWidth = parseInt(scrollable.css("padding-right"), 10) || 0;

      if (tab.length) {
        // theoretically we should first test if tab.width() > viewable.width() before anything else,
        // and then center the tab in the viewable area, but our CSS does not allow this situation to happen.

        // use position relative to document to calculate delta for scroll distance
        var leftEdge = tab.position().left - scrollable.position().left;
        var rightEdge = leftEdge + tabWidth;

        // tab is too far to the right
        if ((rightEdge + buttonWidth) > viewableWidth) {
          scrollable.animate({
            scrollLeft: (scrollable.scrollLeft() + (rightEdge + buttonWidth - viewableWidth))
          }, 250);
        }

        // tab is too far to the left; this really shouldn't happen since tabs either
        // come from fresh page load or ajax replace (both of which reset the scrollLeft to zero)
        if ((leftEdge - buttonWidth) < 0) {
          scrollable.animate({
            scrollLeft: scrollable.scrollLeft() + leftEdge - buttonWidth
          }, 250);
        }
      }
    }

    function setupScrolling(element) {
      if (!element.is("[data-scrolling='true']")) return;

      var scrollable = element.find(".sortable-tabs");

      ensureCurrentTabInView(element, scrollable);

      element.on("click", ".page-prev,.page-next", function(e) {
        var pageSize = element.width();
        var current = scrollable.scrollLeft(), max = scrollable[0].scrollWidth - pageSize;
        var button = $(e.currentTarget);

        if (button.hasClass("page-next")) {
          if (current < max) {
            scrollable.animate({scrollLeft: Math.min(current + pageSize, max)}, 250);
          }
        } else {
          if (current > 0) {
            scrollable.animate({scrollLeft: Math.max(0, current - pageSize)}, 250);
          }
        }
      });

      detectPaging(element);
    }

    return {
      setup: setupScrolling,
      detectPaging: detectPaging,
      ensureCurrentTabInView: ensureCurrentTabInView
    };

  })();

  $(document).on("mingle:relayout", function() {
    var tabs = $(".tab-nav[data-scrolling='true']");

    if (tabs.length === 0) return;

    ScrollingTabs.detectPaging(tabs);
    ScrollingTabs.ensureCurrentTabInView(tabs, tabs.find(".sortable-tabs"));
  });

  MingleUI.readyOrAjaxComplete(function initNavigationalTabs() {
    var tabs = $(".tab-nav");

    if (tabs.length === 0) return;

    ReorderTabs.setup(tabs);
    RenameTabs.setup(tabs);
    ScrollingTabs.setup(tabs);
  });

})(jQuery);
