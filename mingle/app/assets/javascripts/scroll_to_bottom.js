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
  var hitBottom = false;
  $.fn.scrollToBottom = function(callback) {
    $(this).on('scroll', function(e) {
      if(this.scrollTop + $(this).innerHeight() + 5 >= this.scrollHeight) {
        if (hitBottom) {
          return;
        }
        hitBottom = true;
        callback(e);
        setTimeout(function() {
          hitBottom = false;
        }, 200);
      }
    }).on('mousewheel DOMMouseScroll', function(e) {
      // The following hack is for prevent Browser window scrolling
      // when scrolling inside an div element.
      // It does not work well on Firefox
      if (Prototype.Browser.Gecko) {
        return;
      }
      var scrollTo = null;
      if (e.type == 'mousewheel') {
        scrollTo = (e.originalEvent.wheelDelta * -1);
      } else if (e.type == 'DOMMouseScroll') {
        scrollTo = 40 * e.originalEvent.detail;
      }

      if (scrollTo) {
        e.preventDefault();
        $(this).scrollTop(scrollTo + $(this).scrollTop());
      }
    });
  };
})(jQuery);
