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
var TextTransforms = {
  // this is unfortunately duplicated in Project.identifier_was_generated_from_name?; change the other if you change this
  toIdentifier: function(value, prefix) {
    var identifier = value.replace(/[^a-zA-Z0-9]/g, "_").toLowerCase();
    if(identifier.match(/^\d.*/)) {
      identifier = prefix ? prefix + identifier : "project_" + identifier;
    }
    return identifier;
  },
  toPLVName: function(value) {
    value = (value === null) ? "" : value;
    return '(' + value +')';
  }
};

(function($) {
  $.fn.inputSynchronizer = function(target, textFilter, methodName) {
    var source = this;
    target = $(target);

    function synchronize(e) {
      if (e.type === "blur") {
        if ("" !== $.trim(target.val())) {
          return false;
        }
      }

      if (!textFilter) {
        textFilter = TextTransforms.toIdentifier;
      }

      var value = textFilter($.trim(source.val()));

      // need to limit the maxlength by code because ie do not validate value when it is set by javascript
      value = value.substring(0, target.prop("maxlength"));

      if (!methodName) {
        target.val(value);
      } else {
        target[methodName](value);
      }
    }

    source.on("blur change input", synchronize);

  };
})(jQuery);
