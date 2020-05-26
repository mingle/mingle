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

  window.MingleUI = (window.MingleUI || {});

  MingleUI.cards = {
    popupState: function popupState(card) {
      var urlHolder = $("[data-card-popup-url-template]");
      var baseUrl = urlHolder.length ? urlHolder.data("card-popup-url-template") : MingleUI.cards.baseUrl;
      var number, url;

      if (card instanceof $) {
        number = card.data("card-number");
      } else {
        number = parseInt(card, 10);
        card = $(".card-icon[data-card-number='" + number + "']");
      }

      url = baseUrl.gsub(/number=[\d]+/, "number=" + number);

      return {
        url: url,

        setOperating: function(bool) {
          if (bool) {
            card.addClass("operating");
          } else {
            card.removeClass("operating");
          }
        },

        isOperating: function() {
          return card.hasClass("operating");
        }
      };
    },

    showPopup: function(card) {
      var state = MingleUI.cards.popupState(card);

      if (state.isOperating()) {
        return true;
      }

      state.setOperating(true);

      $.ajax({
        url: state.url,
        type: "GET",
        dataType: "script"
      }).fail(function(xhr, status, error) {
        console.log(error);
      }).always(function() {
        state.setOperating(false);
      });
    }
  };
})(jQuery);
