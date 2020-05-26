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
var Tooltip = function (element, message, options) {
  element = $j(element);

  var title;

  if (typeof message === 'function') {
    title = message;
  } else {
    title = function() { return message; };
  }

  var defaults = {
    title: title,
    opacity: 0.7,
    gravity: 's'
  };

  var mergedOptions = $j.extend({}, defaults, options);
  element.tipsy(mergedOptions);

  var api = {};
  api.updatePosition = function () {
    element.tipsy('hide');
    element.tipsy('show');
  };

  return api;
};