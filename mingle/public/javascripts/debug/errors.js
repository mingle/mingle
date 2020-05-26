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
window.onerror = function(msg, file, line) {
  var errors = document.getElementById("javascript-errors");
  var errorMessage = file + "(" + line + "): " + msg;

  if (!errors) {
    if (!document.body) { // dom not ready yet
      console && ("function" === typeof console.log) && console.log(errorMessage);
      return;
    }

    var first = document.body.children[0];

    errors = document.createElement("ol");
    errors.setAttribute('id', "javascript-errors");
    errors.innerHTML = "JavaScript errors: <a href=\"javascript:void(0)\" onclick=\"document.getElementById('javascript-errors').style.display = 'none'; return false\">hide this console</a>";

    document.body.insertBefore(errors, first);
  }

  errors.style.display = "block";
  errors.innerHTML += "<li>" + errorMessage +  "</li>";
};