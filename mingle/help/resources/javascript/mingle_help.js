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
function toggleCollapse(heading_element) {
	if (heading_element.hasClassName('collapsed-heading')) {
		heading_element.removeClassName('collapsed-heading');
		heading_element.addClassName('collapsible-heading');
		heading_element.nextSiblings()[0].removeClassName('collapsed');
	} else {
		heading_element.removeClassName('collapsible-heading');
		heading_element.addClassName('collapsed-heading');
		heading_element.nextSiblings()[0].addClassName('collapsed');
	}
}

function onLoadExpandElement () {
	var element = $(window.location.hash.gsub('#', ''));
	if (element && element.hasClassName('collapsed-heading')) {
		toggleCollapse(element);
	}
}

document.observe('dom:loaded', onLoadExpandElement);

function openNav() {
  $('nav').setStyle({display: 'block'});
}
