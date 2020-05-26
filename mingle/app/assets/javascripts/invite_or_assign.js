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

	var assignIconToCard = function(card, icon, property) {
		var data = {};
		var propertyName = property.data("property-name");
		data["properties[" + propertyName + "]"] = icon.data("value-identifier");
                var slot = card.find(".slot[data-slot-id='"+ propertyName+"']");
                var newIcon = createAssignedIcon(icon, slot);

		$.ajax({
			url: card.data("value-update-url"),
			type: "POST",
			data: data,
			success: function() {
				refreshCardIcon(slot, propertyName, newIcon);
                                slot.show();
                                newIcon.setupDraggableIcon($("#deletion-tray"));
			},

			complete: function() {
				hideSpinner(card);
				icon.parent().removeClass("selected");
				card.find(".full-team-list").popoverClose();
			},

			beforeSend: function() {
				icon.parent().addClass("selected");
				showSpinner(card, icon);
			}
		});
	};

	var refreshCardIcon = function(slot, propertyName, newIcon) {
          slot.empty().append(newIcon);
	};

	var hideSpinner = function(card) {
		card.removeClass("operating");
	};

	var showSpinner = function(card, icon) {
		card.addClass("operating");
	};

	var createAssignedIcon = function(icon, slot) {
		var newIcon = $("<img>").
		attr("src", icon.attr("src")).
		attr('title', slot.data('slot-id') + ": " +  icon.data('name')).
		attr('class', "avatar ui-draggable").
		attr('data-name', icon.data("name")).
		attr('style', icon.attr('style')).
		attr('data-value-identifier', icon.data('value-identifier'));
		newIcon.draggableIcon();
		return newIcon;
	};

	$.fn.assignableIcon = function() {
		$(this).click(function() {
			var icon = $(this);
			var card = icon.parents(".card-icon");
			assignIconToCard(card,
				icon,
				icon.parents(".content").find(".property-to-assign-to:selected"));
		});
	};
}(jQuery));




