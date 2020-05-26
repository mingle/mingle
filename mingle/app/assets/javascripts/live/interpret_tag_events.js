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
var MingleUI = (MingleUI || {});

(function($) {

  function interpretTagEvents(liveEvent) {
    var tag = liveEvent.origin;
    var action = liveEvent.action.split("::")[1];

    function spliceTags(element, toRemove, toAdd) {
      var tags = element.data("tags") ? element.data("tags").split(",") : [];
      var start = toRemove ? tags.indexOf(toRemove) : 0;
      var del = toRemove ? 1 : 0;

      if (!~start) {return;}

      toAdd ? tags.splice(start, del, toAdd) : tags.splice(start, del);
      tags = tags.smartSort();
      element.removeData("tags").attr("data-tags", tags.join(",")).tag_stripe();
    }

    if ("deleted" === action) {
      MingleUI.tags.current().removeTag(tag.name);
      $("[data-tags]").each(function(i, el) {
        spliceTags($(el), tag.name);
      });
    }

    if ("created" === action) {
      MingleUI.tags.current().addTag(tag.name, tag.color);
      $.each(tag.cards || [], function(i, number) {
        var element = $(".card-icon[data-card-number='" + number + "'] .card-inner-wrapper");
        spliceTags(element, null, tag.name);
      });
    }

    if ("changed" === action) {
      $.each(liveEvent.changes, function(category, changes) {
        if ("name-change" === category) {
          var oldName = changes[0][1];
          MingleUI.tags.current().renameTag(oldName, tag.name);
          $.each(tag.cards || [], function(i, number) {
            var element = $(".card-icon[data-card-number='" + number + "'] .card-inner-wrapper");
            spliceTags(element, oldName, tag.name);
          });
        }

        if ("color-change" === category) {
          MingleUI.tags.current().applyColorChange(tag.name, tag.color);
        }
      });
    }
  }

  MingleUI.live = $.extend(MingleUI.live || {}, {
    interpretTagEvents: interpretTagEvents
  });
})(jQuery);
