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
  function propertyName(icon) {
    return icon.parents(".content").find(".selected-property").html();
  }

  function closeTeamlistPopover(card) {
    card.find(".full-team-list .avatars").find(".slot").removeClass("current-property");
    card.find(".full-team-list").popoverClose();
  }

  $.fn.assignableIcon = function() {
    return $(this).click(function() {
      var icon = $(this);
      var card = icon.parents(".card-icon");
      $(card).iconDroppableAssign(propertyName(icon), icon, {
        deletionTray: $("#deletion-tray"),
        afterAssign: function() {
          closeTeamlistPopover(card);
        },
        slotContainer: '.avatars'
      });
    });
  };

  function doUnassign(e) {
    var link = $(e.currentTarget);
    var card = link.closest(".card-icon");
    var slot = card.find(".slot[data-slot-id='" + propertyName(link) + "']");
    card.iconDroppableUnassign(slot);
    closeTeamlistPopover(card);
  }

  $.fn.unAssignableIcon = function() {
    var self = $(this);
    self.off("click", doUnassign).on("click", doUnassign);
    return self;
  };
}(jQuery));




