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
(function($){

  function showMessageOnElement(elements, message, options) {
    elements.each(function(i, element) {
      var el = $(element);
      el.attr("title", message).tipsy($.extend({
        trigger: "manual",
        gravity: "s",
        fade: true
      }, options));
      el.tipsy("show");

      setTimeout(function() {
        el.tipsy("hide");

        var original = $.trim(el.attr("original-title") || "");
        if (original.length) {
          el.attr("title", original);
        } else {
          el.removeAttr("title");
        }
      }, 5000);
    });
  }


  $.fn.tipsyFlash = function(message, options) {
    if (!options) {
      options = {};
    }
    showMessageOnElement(this, message, options);
  };


})(jQuery);
