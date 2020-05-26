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

  function d(message) {
      (console && "function" === typeof console.log) && console.log(message);
  }

  $(document).ready(function() {
    MingleUI.live = $.extend(MingleUI.live || {}, {
      status: {
        on: false,
        isTree: false,
        fb: "uninitialized"
      }
    });

    if ($("#grid_view").attr("class") != "selected_view") {
      return;
    }

    var container = $("#card_results");
    var initial, view;

    function ensureInit() {
      var content = container.find("#content-simple");

      function extraParams() {
        var grid = content.find(".swimming-pool");
        var params = {
          resetUrl: content.data("view-reset-url"),
          baseUrls: {
            show: container.data("card-show-url-template"),
            update: container.data("card-update-url-template"),
            popup: container.data("card-popup-url-template")
          },
          aggregates: {}
        };

        // one cannot trust the view params because of potential character case differences,
        // but the canonical property names are set in the table element itself
        $.each(["column", "row"], function(i, dim) {
          var prop = grid.data(dim + "-aggregate-property");
          if (prop) {
            params.aggregates[dim] = prop;
          }
        });

        return params;
      }

      // the cached function will serve as a sentinel to tell us
      // whether or not we need to reinitialize after an AJAX
      // wall update or on page load
      var compiled = content.data("ast-compile");

      if ("function" !== typeof compiled) {
        initial = parseInt(content.attr("data-last-event"), 10);
        MingleUI.events.reset(initial);

        view = new MingleUI.live.View($.extend({}, content.data("view-params"), extraParams()));

        compiled = MingleUI.ast.compiler(content.data("filters"));
        content.data("ast-compile", compiled);
      }

      return compiled;
    }

    if (!container.length || !$("[data-fb-grid-endpoints]").length) {
      return;
    }

    var fbToken = JSON.parse(container.attr("data-fb-token"));
    var fbCurrentWeekUrl = JSON.parse(container.attr("data-fb-current-week"));
    var fbEndpoints = JSON.parse(container.attr("data-fb-grid-endpoints"));

    if (!fbEndpoints) {
      MingleUI.live.status.fb = "not configured";
      return;
    }

    // important to prepopulate on dom ready before processing
    // firebase events
    ensureInit();

    if (view.tree()) {
      MingleUI.live.status.isTree = true;
      return;
    }


    function updateCards(snapshot, prevChildName) {
      var liveEvent = snapshot.val();
      var type = liveEvent.action.split("::")[0];

      var fourteenDaysAgo = (new Date().getTime() - (1209600000));
      if (fourteenDaysAgo >= new Date(liveEvent.created_at).getTime()) {
        snapshot.ref().remove();
        return;
      }

      // ensure matcher is up to date
      var compiledFilters = ensureInit();

      // skip events that have already been viewed
      // we can check against initial because the view is guaranteed
      // to be up to date to that point in time represented by
      // the initial event id. in other cases
      if (parseInt(liveEvent.id, 10) <= initial || MingleUI.events.hasSeen(liveEvent.id)) {
        d("saw " + liveEvent.id + ", last was " + MingleUI.events.latest());
        return;
      }

      MingleUI.events.markAsViewed(liveEvent.id);

      if ("tag" === type) {
        MingleUI.live.interpretTagEvents(liveEvent);
        return;
      }

      var json = JSON.parse(liveEvent.origin);
      var card = new MingleUI.live.LiveCard(json);

      if ("card::deleted" === liveEvent.action) {
        if (card.element().length) {
          MingleUI.grid.instance && MingleUI.grid.instance.removeCard(card.number());
          view.updateGridAggregates();
        }
        return;
      }

      if ("card::ranked" === liveEvent.action) {
        if (card.element().length) {
          card.updateSortPosition(view);
        }
        return;
      }

      if (!card.element().length) {
        card.buildCard(view);
      }

      if (!!~["card::changed", "card::created"].indexOf(liveEvent.action)) {
        if (!card.allowedByFilters(compiledFilters)) {
          MingleUI.grid.instance && MingleUI.grid.instance.removeCard(card.number());
          view.updateGridAggregates();
          return;
        }

        $.each(liveEvent.changes, function(category, changes) {
          switch(category) {
            case "name-change":
              card.refreshName();
              break;
            case "tag-addition":
            case "tag-removal":
              card.refreshTags();
              break;
            case "card-type-change":
            case "property-change":
              $.each(changes, function(i, chg) {
                var field = chg[0];
                var propValue = card.getPropertyValue(field);

                var value = propValue.value, type = propValue.type;

                if ("user" === type) {
                  card.setUserIcon(field, propValue.user);
                }
              });
              break;
            default:
              break;
          }
        });

        card.updateAggregateProperties(view);
        card.updateColor(view);

        var coords = {};

        if (view.groupBy("lane")) {
          coords.lane = card.getPropertyValue(view.groupBy("lane")).value;
        }

        if (view.groupBy("row")) {
          coords.row = card.getPropertyValue(view.groupBy("row")).value;
        }

        view.moveCardToCell(card, coords);
        if(WipPolice.isInitialized()) {
          card.updateWipProperties();
          WipPolice.enforce();
        }
      }

    }

    var configuration = {token: fbToken, startAt: initial, federation: {endpoint: fbCurrentWeekUrl, token: fbToken}};
    MingleUI.live.liveWall = new MingleUI.live.SwitchingDatasource(fbEndpoints, updateCards, configuration);
  });
})(jQuery);
