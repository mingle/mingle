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
/*
 * A resource-conscious, throttled viewport resize handler
 */
(function($) {
  $(document).ready(function() {

    var timer; // for browsers that don't support requestAnimationFrame
    var running = false; // semaphore

    var win = $(window);
    var curX = win.width(), curY = win.height();

    function fire() {
      $(document).trigger("mingle:relayout");
      curX = win.width(), curY = win.height();
      timer = null;
      running = false;
    }

    function throttledResizeDispatch(e) {
      if (!!running) return; // throttle if already executing
      if (curX === win.width() && curY === win.height()) return; // no need to fire if delta is zero

      running = true;
      if ("function" === typeof win.requestAnimationFrame) {
        win.requestAnimationFrame(fire);
      } else {
        if (!timer) {
          timer = setTimeout(fire, 66); // no faster than 15 fps
        }
      }
   }

   win.on("resize", throttledResizeDispatch);
  });
})(jQuery);
