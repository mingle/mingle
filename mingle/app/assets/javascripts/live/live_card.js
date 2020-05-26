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

  function LiveCard(json) {
    var keymap = {}, cardElement, inner, self = this;
    var selector = ".card-icon[data-card-number='" + json.Number + "']";
    var WIP_PROPERTY_PREFIX = "wip.";

    for (var prop in json) {
      if (json.hasOwnProperty(prop)) {
        keymap[prop.toLowerCase()] = prop;
      }
    }

    this.number = function number() {
      return json.Number;
    };

    this.name = function name() {
      return json.Name;
    };

    this.tags = function tags() {
      return json["&tags"] || [];
    };

    this.rank = function rank() {
      return json["&rank"];
    };

    this.updateSortPosition = function updateSortPosition(view, forceMarkAndSort) {
      var sortValue = Big(getSortValue(this, view));
      var current = Big(inner.attr("data-sort-pos"));

      if (!sortValue.eq(current)) {
        inner.attr("data-sort-pos", sortValue).removeData("sort-pos");

        if (!cardElement.is(".live-updated")) {
          cardElement.addClass("live-updated");
        }

        view.refreshSorting(cardElement);
      } else if (!!forceMarkAndSort) {
        if (!cardElement.is(".live-updated")) {
          cardElement.addClass("live-updated");
        }

        view.refreshSorting(cardElement);
      }
    };

    this.displayedUserProperties = function displayedUserProperties() {
      return json["&displayedUserProperties"] || [];
    };

    this.element = function element() {
      if (!(cardElement && cardElement.length)) {
        cardElement = $(selector);
        inner = cardElement.find(".card-inner-wrapper");
      }

      return cardElement;
    };

    this.allowedByFilters = function allowedByFilters(compiledFn) {
      return compiledFn(json);
    };

    this.getPropertyValue = function getPropertyValue(field) {
      field = keymap[field.toLowerCase()];
      var value, raw = json[field], type, sortValue, user;

      if (raw instanceof Array) {
        value = raw[0];
        type = raw[1];
        sortValue = raw[2];
      } else {
        value = raw;
      }

      if ("user" === type) {
        if (value) {
          user = deserializeUser(JSON.parse(value));
          value = user.id;
        }
      }

      return {
        value: value,
        type: type,
        user: user,
        sortValue: sortValue
      };
    };

    this.refreshName = function refreshName() {
      var name = this.name();
      if (name !== cardElement.find(".card-name").text()) {
        cardElement.find(".card-name").text(name);
      }
    };

    this.refreshTags = function refreshTags() {
      var tags = this.tags().join(",");
      if (inner.attr("data-tags") !== tags) {
        inner.removeData("tags").attr("data-tags", tags).tag_stripe();
      }
    };

    this.updateAggregateProperties = function updateAggregateProperties(view) {
      if (view.aggregateProperties()) {
        $.each(view.aggregateProperties(), function(dim, property) {
          var value = self.getPropertyValue(property).value;
          setAggregateProperty(inner, property, value);
        });
      }
    };

    this.updateWipProperties = function updateWipProperties() {
      var wipProps = inner.data("card-properties") || {};
      if (wipProps != {}) {
        for(var prop in wipProps) {
          if(prop.startsWith(WIP_PROPERTY_PREFIX)) {
            var propertyName = prop.substring(WIP_PROPERTY_PREFIX.length);
            var value = self.getPropertyValue(propertyName).value;
            setAggregateProperty(inner, prop, value);
          }
        }
      }
    };

    this.updateColor = function updateColor(view) {
      if (view.colorBy()) {
        var value = this.getPropertyValue(view.colorBy()).value;
        inner.attr("color_for", encodeURIComponent(value));
      }
    };

    this.setUserIcon = function setUserIcon(property, user) {
      var slots = cardElement.find(".avatars").data("slot-ids");
      if (slots.indexOf(property) === -1) {
        return;
      }

      var slotContainer = cardElement.find(".avatars");
      var slot = MingleUI.icon.findOrCreateSlotWithId(slotContainer, property);

      if (user) {
        if (userAlreadySet(slot, user)) {
          d("user " + user.name + " is already in slot \"" + property + "\"");
          return;
        }

        var icon = $("<img>").
          attr("src", user.url).
          attr("title", property + ": " +  user.name).
          attr("class", "avatar").
          attr("data-name", user.name).
          attr("data-value-identifier", user.id).
          css("background", user.color);
        slot.empty().prepend(icon);
        icon.setupDraggableIcon($("#deletion-tray"));
      } else {
        slot.empty();
      }

      MingleUI.icon.cleanupSlots(cardElement);
    };

    this.buildCard = function buildCard(view) {
      cardElement = outerCardDiv(self, view);
      inner = innerWrapper(self, view);
      cardElement.
        append(inner).
        append(avatars(self));

      this.updateAggregateProperties(view);
      this.updateColor(view);

      initializeBehaviors(cardElement);

      return cardElement;
    };

    this.raw = function raw(field) {
      return json[field];
    };

  }

  function anyAvatarsSet(card) {
    var set = false;
    $.each(card.displayedUserProperties(), function(i, u) {
      set = set || card.raw(u)[0];
    });
    return set;
  }

  function outerCardDiv(card, view) {
    var number = card.number();
    return $("<div/>").attr({
      "class": "card-icon",
      "id": "card_" + number,
      "index_in_card_list_view": 0,
      "ancestor_numbers": "",
      "data-card-number": number,
      "data-value-update-url": view.updateUrl(number)
    });
  }

  function avatars(card) {
    var userProps = card.displayedUserProperties();
    var panel = $("<div/>").attr({
      "class": "avatars",
      "data-slot-ids": JSON.stringify(userProps)
    });

    if (userProps.length) {
      if (anyAvatarsSet(card)) {
        $.each(userProps, function(i, prop) {
          var user = card.getPropertyValue(prop).user;
          if (!user) {return;}
          var slot = $("<div/>").attr({
            "class": "slot",
            "data-slot-id": prop
          });
          slot.append($("<img/>").attr({
            "src": user.url,
            "alt": user.name,
            "class": "avatar",
            "title": prop + ": " + user.name,
            "data-name": user.name,
            "data-value-identifier": user.id
          }).css("background-color", user.color));
          panel.append(slot);
        });
      } else {
        panel.append($("<div/>").attr({
          "class": "slot",
          "data-slot-id": userProps[0],
          "title": "Assign a team member"
        }));
      }
    }

    if($(".card-icon-placeholder-toggle").data("value")) {
      var teamList = $("<div/>").
        attr("id", "card_assigned_users_" + card.number()).
        attr("data-invites-enabled", $("#content-simple").data("invites-enabled").toString()).
        addClass("full-team-list").
        append(panel).
        append($('<div class="content" hidden="hidden"></div>'));
      return teamList;
    }

    return panel;
  }

  function innerWrapper(card, view) {
    var number = card.number();
    var inner = $("<div/>").attr({
      "class": "card-inner-wrapper clearfix",
      "id": "card_inner_wrapper_" + number,
      "color_for": "",
      "unselectable": "on",
      "data-popup-url": view.popupUrl(number),
      "data-tags": card.tags().join(","),
      "data-sort-pos": getSortValue(card, view),
      "data-card-properties": ""
    }).append(
      $("<span class='card-summary-number'/>").append(
        $("<a/>").text("#" + number).attr({
          "href": view.showUrl(number),
          "id": "card_show_link_" + number,
          "title": "Click to go directly to this card"
        })
      )
    ).append($("<div class='card-name'/>").text(card.name()));

    inner.tag_stripe();
    return inner;
  }

  function initializeBehaviors(element) {
    element.iconDroppable({
      accept: ".avatar",
      slotContainer: ".avatars",
      deletionTray: $("#deletion-tray")
    });
    element.mingleTeamList("Assignable");
  }

  function getSortValue(card, view) {
    var field = view.sortBy();
    if (field) {
      return "number" === field ? card.number() : card.getPropertyValue(field).sortValue;
    } else {
      return card.rank();
    }
  }

  function setAggregateProperty(element, field, value) {
    var aggr = element.data("card-properties") || {};
    aggr[field] = value;
    element.attr("data-card-properties", JSON.stringify(aggr)).removeData("card-properties");
  }

  function deserializeUser(user) {
    return {
      id: user[0],
      url: user[1],
      color: user[2],
      login: user[3],
      name: user[4]
    };
  }

  function userAlreadySet(slot, user) {
    var current = slot.find("img.avatar");
    if (!current.length) {
      return false;
    }

    return (String(user.id) === String(current.attr("data-value-identifier")));
  }

  function d(message) {
      (console && "function" === typeof console.log) && console.log(message);
  }

  MingleUI.live = $.extend(MingleUI.live || {}, {
    LiveCard: LiveCard
  });

})(jQuery);
