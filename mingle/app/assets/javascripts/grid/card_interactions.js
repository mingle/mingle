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

  function AbstractCardInteraction() {}
  $.extend(AbstractCardInteraction.prototype, {
    highlightClass: "cell-highlighted",

    onDropCard: function onDropCard(instance, card, cell) {
      var self = this;
      var originalPosition = card.data("starting-position"); // cache here for usage in asynchronous callback
      var childCards = instance.findDescendantsOfCard(card).addClass("operating");

      // only fire if we ultimately moved to a new place
      if (originalPosition !== this.getPosition(card, cell)) {
        $.ajax({
          url: cell.attr("set_value_for_url"),
          type: "POST",
          data: this.params(card),
          dataType: "script",
          beforeSend: function() {
            card.removeData("force-revert");
            $("#flash").empty();
            setTimeout(function() { card.addClass("operating"); }, 0);
          }
        }).done(function(data, textStatus, jqXHR) {
          function handleResult() {
            // immediately unbind so we only ever fire once. basically the same
            // as using jQuery.one(), but one() can be easily misread as on(). this
            // lets other devs know that this was meant to be triggered only once.
            card.off("grid:transition");

            // even when the response is 200, the eval'ed script may indicate a failure
            // state by setting the force-revert data property on the card (e.g. deny
            // transition on property)
            if (!!card.data("force-revert")) {
              self.revertPosition(instance, card, originalPosition);
            }

            // Success from here on.
            var targetLaneValue = cell.attr("lane_value");
            childCards.each(function(i, el) {
              var childCard = $(el);
              var targetCell = childCard.closest(".grid-row").find(".cell[lane_value=" + JSON.stringify(targetLaneValue) + "]");
              if (!$.contains(targetCell[0], childCard[0])) {
                self.insertIntoSortedPosition(childCard, targetCell);
              }
            });

            card.removeClass("operating").
              removeData("force-revert").
              removeData("defer-to-lightbox");
            childCards.removeClass("operating");

            if ("function" === typeof instance.onUpdateCard) instance.onUpdateCard(card);
          }

          // some responses will generate a lightbox (e.g. transitions) waiting for a user
          // action, which can result in a revert or success
          if (!!card.data("defer-to-lightbox")) {
            card.on("grid:transition", handleResult);
          } else {
            handleResult();
          }
        }).fail(function(jqXHR, textStatus, errorThrown) {
          self.revertPosition(instance, card, originalPosition);
          card.removeClass("operating").
            removeData("force-revert").
            removeData("defer-to-lightbox");
          childCards.removeClass("operating");
        });
      }

      card.removeData("starting-position");
    },

    revertPosition: function revertPosition(instance, card, originalPosition) {
      var revertTo = JSON.parse(originalPosition);
      var startingCell = instance.grid.find(".grid-row[row_value=" + JSON.stringify(revertTo.row) + "]").find(".cell[lane_value=" + JSON.stringify(revertTo.cell) + "]");

      if (!startingCell.length) { console.log("could not find cell at row [" + revertTo.row + "], col [" + revertTo.cell + "]"); return; }

      this.relocateCardToCell(card, startingCell, revertTo);

      if ("undefined" !== typeof card[0].style.animation) {
        // most browsers (Chrome, FF, IE 10+, Safari)
        card.addClass("animated wobble").on("animationend", function(e) { card.removeClass("animated wobble"); });
      } else {
        // legacy browsers - should be rare these days
        if ("function" === typeof card.effect) {
          card.effect("shake", 500);
        }
      }
    },

    getPosition: function getPosition(card, cell) { // outputs a stable, comparable identifier for a card's logical location
      return JSON.stringify({
        row: cell.closest(".grid-row").attr("row_value"),
        cell: cell.attr("lane_value"),
        params: this.params(card)
      });
    },

    insertIntoSortedPosition: function insertIntoSortedPosition(card, cell) {
      for (var candidate, i = 0, existingCards = cell.find(".card-icon").get(), len = existingCards.length; i < len; i++) {
        candidate = $(existingCards[i]);

        if (MingleUI.live.View.sortPositionComparator(card, candidate) < 0) {
          card.insertBefore(candidate).show();
          return;
        }
      }

      // either this card's index is the greatest or the cell is empty
      cell.append(card);
    },

    dimensionHighlight: function dimensionHighlight(e, ui) {
      var cell = $(e.target);
      var row = cell.closest(".grid-row");
      // because we only allow drags within rows, we don't need to be specific about which header
      row.find("th").addClass(this.highlightClass);
      var columnHeaders = cell.closest("table").find("thead").find("th");
      columnHeaders.filter("." + this.highlightClass).removeClass(this.highlightClass);

      // implicitly takes care of -1; note this syntax differs from get() as get() accepts negative indices!
      $(columnHeaders[row.children().index(cell)]).addClass(this.highlightClass);
    },

    stopHighlight: function stopHighlight(e, ui) {
      $(e.target).closest("table").find("th." + this.highlightClass).removeClass(this.highlightClass);
    }
  });

  function showHalloweenBats(element) {
    if ($j(document.body).data("show-holiday-fun") && $j(document.body).data("holiday-name") &&  $j(document.body).data("holiday-name").includes("Halloween")) {
      $j(element).createBats();
    }
  }

  var RankedStrategy = $.extend(Object.create(AbstractCardInteraction.prototype), {
    name: "ranked",
    activateRow: function enableRankableRow(instance, row, cards, allowDragging) {
      var scope = row.attr("id"); // arbitrary string, may as well use ID
      var self = this;

      // this is the "glue" to the common onDropCard interface
      function rankedAdapter(e, ui) {
        var cell = $(e.target);
        var card = $(ui.item);
        var helper = $(ui.helper);

        if ($.contains(cell[0], card[0])) {
          // only fire on the cell that receives the card, not the cell that lost the card
          self.onDropCard(instance, card, cell);
        }
      }

      function recordInitialPosition(e, ui) {
        /*
         * it's possible to fire a request when card moves around to other cells, but
         * then returns to its original position. thus, record starting position as a stable
         * JSON string that will always pass object equivalence tests
         */
        var card = $(ui.item);
        card.data("starting-position", self.getPosition(card, $(e.target)));
      }

      function startDrag(e, ui) {
        showHalloweenBats(e.target);
        recordInitialPosition(e, ui);
      }

      return row.find(".cell").sortable({
        disabled: !allowDragging,
        items: ".card-icon",
        cancel: ".operating,.full-team-list",

        /*
         * "connectWith" and "dropOnEmpty" allows moving cards to other cells, empty or not.
         * And no, doing row.sortable({dropOnEmpty: true}) does not work with empty cells.
         */
        dropOnEmpty: true,
        connectWith: "#" + scope + " .cell",

        helper: "clone", // this prevents the click propogated through drag from firing other events (e.g. avatar list)
        placeholder: "ui-state-highlight card-rank-placeholder",
        tolerance: "pointer", // mimics the old behavior
        opacity: 0.5,
        revert: 50,
        start: startDrag,
        update: rankedAdapter
      }).droppable({
        /*
         * this is the only reliable way to get hover working *exactly* like before.
         * one can *almost* get it right on sortable() with a combination of start, stop,
         * over, and out events but it's not terribly reliable
         */
        hoverClass: self.highlightClass,
        over: $.proxy(self.dimensionHighlight, self),
        deactivate: $.proxy(self.stopHighlight, self),
        accept: "#" + scope + " .card-icon" // ensure highlights are disabled over other rows
      });
    },

    relocateCardToCell: function relocateCardToRankedCell(card, cell, position) { // only used by revertPosition(), currently.
      var leadingCardNumber = position.params["rerank[leading_card_number]"],
          followingCardNumber = position.params["rerank[following_card_number]"];
      var leadingCard, followingCard;

      function cardByNumberInCell(cell, cardNumber) {
        return cell.find(".card-icon[data-card-number=\"" + parseInt(cardNumber, 10) + "\"]");
      }

      if ("undefined" !== typeof leadingCardNumber && (leadingCard = cardByNumberInCell(cell, leadingCardNumber)).length) {
        leadingCard.after(card);
      } else if ("undefined" !== typeof followingCardNumber && (followingCard = cardByNumberInCell(cell, followingCardNumber)).length) {
        followingCard.before(card);
      } else {
        cell.append(card);
      }
    },

    ensureCardInitialized: function ensureCardInitialized(card) {
      card.closest(".cell").sortable("refresh");
    },

    params: function cardParams(card) {
      var q = {
        card_number: card.data("card-number")
      };

      var leadingCard = card.prev(".card-icon");
      if (!!leadingCard.length) {
        q["rerank[leading_card_number]"] = leadingCard.data("card-number");
      }

      var followingCard = card.nextAll(".card-icon:first"); // can't use next() because it only matches the placeholder
      if (!!followingCard.length) {
        q["rerank[following_card_number]"] = followingCard.data("card-number");
      }

      return q;
    }
  });

  var UnrankedStrategy = $.extend(Object.create(AbstractCardInteraction.prototype), {
    name: "unranked",
    activateRow: function enableDroppableRow(instance, row, cards, allowDragging) {
      var scope = row.attr("id"); // arbitrary string, may as well use ID
      var self = this;

      function startDrag(e, ui) {
        showHalloweenBats(e.target);
        var card = $(e.target).hide();
        card.data("starting-position", self.getPosition(card, card.closest(".cell")));
      }

      function stopDrag(e, ui) {
        $(e.target).show();
      }

      // this is the "glue" to the common onDropCard interface
      function unrankedAdaper(e, ui) {
        var cell = $(e.target);
        var card = $(ui.draggable);
        var helper = $(ui.helper);
        self.insertIntoSortedPosition(card, cell);
        self.onDropCard(instance, card, cell);
      }

      if (!self.dragOptions) {
        self.dragOptions = {
          disabled: !allowDragging,
          stack: ".card-icon",
          cancel: ".operating,.full-team-list",
          helper: "clone", // this prevents the click propogated through drag from firing other events (e.g. avatar list)
          revert: "invalid",
          revertDuration: 50,
          opacity: 0.5,
          start: startDrag,
          stop: stopDrag
        };
      }

      cards.draggable($.extend({}, self.dragOptions, {scope: scope}));

      return row.find(".cell").droppable({
        accept: "#" + scope + " .card-icon",
        scope: scope,
        hoverClass: self.highlightClass,
        over: $.proxy(self.dimensionHighlight, self),
        deactivate: $.proxy(self.stopHighlight, self),
        drop: unrankedAdaper
      });
    },

    relocateCardToCell: function relocateCardToUnrankedCell(card, cell, position /* not used in this implementation */) {
      this.insertIntoSortedPosition(card, cell);
    },

    ensureCardInitialized: function ensureCardInitialized(card) {
      card.draggable($.extend({}, this.dragOptions, {scope: card.closest(".grid-row").attr("id")}));
    },

    params: function cardParams(card) {
      return {
        card_number: card.data("card-number")
      };
    }
  });

  $.extend(MingleUI.grid, {
    AbstractCardInteraction: AbstractCardInteraction,
    RankedStrategy: RankedStrategy,
    UnrankedStrategy: UnrankedStrategy
  });

})(jQuery);
