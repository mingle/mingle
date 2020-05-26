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

  function View(params) {

    this.tree = function tree() {
      var name = $.trim(params.tree_name);
      return !!name && name;
    };

    this.sortBy = function sortBy() {
      return params.grid_sort_by && params.grid_sort_by.toLowerCase();
    };

    this.colorBy = function colorBy() {
      return params.color_by;
    };

    this.aggregateProperties = function aggregateProperties() {
      return params.aggregates;
    };

    this.popupUrl = function popupUrl(number) {
      return params.baseUrls.popup.replace("&number=0", "&number=" + number);
    };

    this.updateUrl = function updateUrl(number) {
      return params.baseUrls.update.replace("&number=0", "&number=" + number);
    };

    this.showUrl = function showUrl(number) {
      return params.baseUrls.show.replace(":number", number);
    };

    this.groupBy = function groupBy(dimension) {
      if (params.group_by && params.group_by[dimension]) {
        return params.group_by[dimension];
      }
    };

    this.refreshSorting = function refreshSorting(cardElement) {
      var cell = $(cardElement).closest("td.cell");
      var comparator = this.sortBy() === "number" ? numberComparator : defaultComparator;
      var sortedCards = cell.children(".card-icon").sort(comparator);
      sortedCards.detach().appendTo(cell);
      setTimeout(function() { cell.find(".live-updated").removeClass("live-updated"); }, 750);
    };

    this.cellAt = function cellAt(coords) {
      var rowSelector = "tr[row-id=" + JSON.stringify(!coords.row ? "" : coords.row) + "]";
      var laneselector = "td[lane-id=" + JSON.stringify(!coords.lane ? "" : coords.lane) + "]";
      return $([rowSelector, laneselector].join(" "));
    };

    this.moveCardToCell = function moveCardToCell(card, coords) {
      var cardElement = card.element();
      var cell = this.cellAt(coords);

      if (!cell.length) {
        // cell is not visible (e.g. lane or row is not displayed)
        if (MingleUI.grid.instance) MingleUI.grid.instance.removeCard(cardElement.data("card-number"));
      } else {

        if (!$.contains(cell.get(0), cardElement.get(0))) { // only try to move card if it's not already in the target cell

          // filter out row-constraint classes
          var classes = $.trim(cardElement.attr("class") || "").split(/\s/).filter(function(cl) {
            return !(/^row_[\d]+$/.test(cl) || "" === cl);
          });

          // need to set the row scope to restrict where you can drag/drop cards
          classes.push(cell.closest("tr").attr("id"));
          cardElement.attr("class", classes.join(" "));

          if (cell.find(".inplace-add").length) {
            cell.find(".inplace-add").after(cardElement);
          } else {
            // light users don't get an inplace add element
            cell.prepend(cardElement);
          }

          if (MingleUI.grid.instance) {
            MingleUI.grid.instance.strategy.ensureCardInitialized(cardElement);
          }

          card.updateSortPosition(this, true);
        }
      }

      this.updateGridAggregates();
    };

    var noCardsFoundMessage = $("<div class='info-box'/>").append(
      $("<div id='info' class='flash-content'>").
      text("There are no cards that match the current filter - ").
      append($("<a>Reset filter</a>").attr("href", params.resetUrl))
    )[0].outerHTML;

    this.checkIfNoCardsFound = function checkIfNoCardsFound() {
      var grid = (MingleUI.grid.instance && MingleUI.grid.instance.grid);
      var firstCard = grid.find(".card-icon:not(.puff):first");

      if (firstCard.length !== 0) {
        $("#no_cards_found").empty();
      } else {
        $("#no_cards_found").html(noCardsFoundMessage);
      }
    };

    this.updateGridAggregates = function updateGridAggregates() {
      if (MingleUI.grid.instance) {
        MingleUI.grid.instance.updateAggregates();
      }

      this.checkIfNoCardsFound();
    };

  }

  function numberComparator(a, b) {
    var an = parseInt($(a).data("card-number"), 10);
    var bn = parseInt($(b).data("card-number"), 10);

    if (an < bn) return 1;
    if (an > bn) return -1;

    // really should never get here
    return 0;
  }

  function defaultComparator(a, b) {
    var da = $(a).find("[data-sort-pos]");
    var db = $(b).find("[data-sort-pos]");

    // really, only rank needs BigDecimal calculation, but no need to
    // write another comparator unless this becomes a performance issue
    var as = new Big(da.attr("data-sort-pos"));
    var bs = new Big(db.attr("data-sort-pos"));

    // first try sort position
    if (as.gt(bs)) return 1;
    if (as.lt(bs)) return -1;

    var an = parseInt($(a).data("card-number"), 10);
    var bn = parseInt($(b).data("card-number"), 10);

    // next try number as tie-breaker, descending sort
    if (an < bn) return 1;
    if (an > bn) return -1;

    // really should never get here
    return 0;
  }

  $.extend(View, {
    numberComparator: numberComparator,
    sortPositionComparator: defaultComparator
  });

  function d(message) {
      (console && "function" === typeof console.log) && console.log(message);
  }

  MingleUI.live = $.extend(MingleUI.live || {}, {
    View: View,
    toggleRankDebug: function() {
      $("#card_results").toggleClass("debug");
    }
  });

})(jQuery);
