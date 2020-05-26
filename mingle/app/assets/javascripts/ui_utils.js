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
UIUtils = function() {
  var withinOrIs = function (element, container) {
    return $j(container).filter(element).length > 0 || $j(container).has(element).length > 0;
  };

  var outsideClick = function(panel, onClickOutsideCallback){
    return function (event) {
      if (1 !== event.which) return; // not left click
      var panelClasse = $j('.'+panel.prop('class').split(" ").join('.'));
      if (!withinOrIs(event.target, panelClasse)) {
        onClickOutsideCallback();
      }
    };
  };

  return {
    onClickOutside: outsideClick
  };
};