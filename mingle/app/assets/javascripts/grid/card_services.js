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

  function setDependencyIcons(card, status) {
    var dependencyIcon = card.find(".card-dependency-icon");

    if (!dependencyIcon.length) {
      return; // toggled off, do nothing
    }

    $.each(["raised", "resolving"], function(i, type) {
      // don't update an icon that wasn't specified to be updated
      if (!status.hasOwnProperty(type)) {
        return;
      }

      var statusIcon;

      if (null === status[type]) {
        if (!dependencyIcon.find(".mng-dep-" + type + "-o").length) {
          dependencyIcon.find(".mng-dep-" + type).remove();
          statusIcon = $("<i/>").attr("class", "fa-stack-1x mng mng-dep-" + type + "-o");
          type === "raised" ? dependencyIcon.prepend(statusIcon) : dependencyIcon.append(statusIcon);
        }
      } else {
        statusIcon = dependencyIcon.find("i.mng-dep-" + type + ",i.mng-dep-" + type + "-o");
        var iconClass = ["fa-stack-1x mng", "mng-dep-" + type, status[type].toLowerCase()].join(" ");
        if (statusIcon.length) {
          statusIcon.attr("class", iconClass);
        } else {
          statusIcon = $("<i/>").attr("class", iconClass);
          type === "raised" ? dependencyIcon.prepend(statusIcon) : dependencyIcon.append(statusIcon);
        }
      }
    });

    // ensure we display states for both all the time
    if (dependencyIcon.find(".mng").length === 1) {
      if (dependencyIcon.find(".mng").attr("class").indexOf("raised") !== -1) {
        dependencyIcon.append($("<i/>").attr("class", "fa-stack-1x mng mng-dep-resolving-o"));
      } else {
        dependencyIcon.prepend($("<i/>").attr("class", "fa-stack-1x mng mng-dep-raised-o"));
      }
    }

    // and if both icons indicate there are no dependencies, no need to display at all
    if (!!dependencyIcon.find(".mng-dep-raised-o").length && !!dependencyIcon.find(".mng-dep-resolving-o").length) {
      dependencyIcon.empty();
    }
  }

  var CardServicesMixin = {
    onUpdateCard: function onUpdateCard(card) {
      // this is located in another mixin, so we cannot assume it is present; this should make test setup easier
      if ("function" === typeof this.updateAggregates) this.updateAggregates();

      if (!(card instanceof $)) {
        if ("number" === typeof card) { // number or numeric string
          card = this.cardByNumber(card);
        } else {
          // only support jQuery object, or number; don't add silly code to try to detect
          // more types than this (e.g. numeric string, selector, DOM object, etc.).
          return;
        }
      }

      if (card.length === 0) return;

      card.removeClass("operating"); // in case this hasn't been done already (e.g. update other than card drop)
    },

    cardByNumber: function cardByNumber(number) {
      if ("string" === typeof number) number = parseInt(number, 10);
      return this.grid.find(".card-icon[data-card-number='" + number + "']");
    },

    findDescendantsOfCard: function findDescendantsOfCard(card) {
      var cardNumber = card.data("card-number").toString();
      return this.grid.find(".card-icon[ancestor_numbers]").filter(function(i, el){
        return $(el).attr("ancestor_numbers").split(",").indexOf(cardNumber) > -1;
      });
    },

    syncCardName: function syncCardName(number, name) {
      var card = this.cardByNumber(number);
      if (!card.length) return;
      card.find(".card-name").text(name);
    },

    syncCardTags: function syncCardTags(number, tags) {
      var card = this.cardByNumber(number);
      if (!card.length) return;
      card.find(".card-inner-wrapper").attr("data-tags", tags.join(",")).removeData("tags").tag_stripe();
    },

    syncDependencyStatuses: function syncDependencyStatuses(statuses) {
      var cardNumbers = Object.keys(statuses);

      for (var i = 0, number, len = cardNumbers.length; i < len; i++) {
        number = cardNumbers[i];
        setDependencyIcons(this.cardByNumber(number), statuses[number]);
      }
    },

    removeCard: function removeCard(number) {
      var card = this.cardByNumber(number);
      var self = this;

      function syncRemove() {
        card.remove();
        WipPolice.enforce();
        if ("function" === typeof self.updateAggregates) self.updateAggregates();
      }

      if (!card.length) return;

      if ("undefined" !== typeof card[0].style.animation) {
        // most browsers (Chrome, FF, IE 10+, Safari)
        card.addClass("animated puff").on("animationend", syncRemove);
      } else {
        // legacy browsers - should be rare these days
        if ("function" === typeof card.effect) {
          card.effect("explode", {pieces: 4, easing: 'easeInBack'},  500, syncRemove);
        } else {
          // phantomjs tests will enter here, as long as we don't load jQueryUI (please don't, for the sake of reliability)
          syncRemove();
        }
      }
    }
  };

  // export public api
  $.extend(MingleUI.grid, {
    CardServicesMixin: CardServicesMixin
  });

})(jQuery);
