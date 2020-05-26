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
// Prototype 1.6 encodes parameters according to the application/x-www-form-urlencoded standard
// which means that spaces are encoded as "+" rather than "%20". Until we upgrade rack and rails
// and (possibly ruby to 1.9 which has URI.decode_www_form_component), we try to preserve the old
// 1.6 behavior.
Hash.prototype.toQueryString = Hash.prototype.toQueryString.wrap(function(original) {
  return original().replace(/\+/g, "%20");
});

Form.originalSerializeElements = Form.serializeElements;
Form.serializeElements = function(elements, options) {
  var results = Form.originalSerializeElements(elements, options);
  if(typeof results === "string") {
    return results.replace(/\+/g, "%20");
  } else {
    return results;
  }
};
