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
(function ($) {
  "use strict";

  window.MingleUI = window.MingleUI || {};
  MingleUI.grid = MingleUI.grid || {};

  function CardWall(grid, strategy, allowDragging) {
    var avatarRemovalTray = $("#deletion-tray");
    var self = this;

    if ("undefined" === typeof allowDragging) {
      allowDragging = true;
    }

    this.enableLanes = function enableLanes(allowDragging) {
      this.grid.find(".grid-row").each(function visitRow(i, el) {
        var row = $(el);
        var cards = row.find(".card-icon").mingleTeamList("Assignable").iconDroppable({
          accept: ".avatar",
          slotContainer: ".avatars",
          deletionTray: avatarRemovalTray
        });

        // need to set z-index when opening avatar popover or else
        // it is hidden behind adjacent cards and cells
        row.on("popover:open", ".full-team-list", function(e) {
          var teamList = $(e.currentTarget);
          teamList.closest(".card-icon").css("z-index", 1);
        }).on("popover:close", ".full-team-list", function(e) {
          var teamList = $(e.currentTarget);
          teamList.closest(".card-icon").css("z-index", "auto");
        });

        self.strategy.activateRow(self, row, cards, allowDragging);
      });
    };

    this.grid = grid;
    this.strategy = strategy || MingleUI.grid.RankedStrategy;

    if (allowDragging) {
      this.enableLanes(allowDragging);
    }
    this.setupHeaderAggregates();
  }

  $.extend(CardWall.prototype, MingleUI.grid.CardServicesMixin);
  $.extend(CardWall.prototype, MingleUI.grid.AggregateMixin);

  // exports for public use and testing
  $.extend(MingleUI.grid, {
    start: function ensureCardWall(allowDragging) {
      var grid = $(".touchable-wall");

      if (grid.length === 0) return;

      this.instance = new CardWall(grid, this.activatedStrategy(), allowDragging);

      $(document).off("mingle:relayout", this.adjustForSize).
        on("mingle:relayout", this.adjustForSize).
        trigger("mingle:relayout");
    },

    adjustForSize: function adjustForSize() {
      var grid = MingleUI.grid.instance.grid, firstColumn = grid.data("first-column");

      if (!firstColumn) {
        firstColumn = grid.find("thead").find(".lane_header:first");
        grid.data("first-column", firstColumn); // cache this to save on DOM access during resize
      }

      var size = firstColumn.width();

      if (size < 96) {
        grid.addClass("tiny-cards");
      } else {
        grid.removeClass("tiny-cards");
      }
    },

    activatedStrategy: function resolveStrategy() {
      return $("input[name='rank_is_on']").is(":checked") ? MingleUI.grid.RankedStrategy : MingleUI.grid.UnrankedStrategy;
    },

    CardWall: CardWall
  });

})(jQuery);
