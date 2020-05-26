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
  MingleUI = window.MingleUI || {};

  $.extend(MingleUI, {
    align: {
      cumulativeAlign: function(src, target, offsets) {
        var srcCoords = $(src).offset();

        if (!offsets) {
          offsets = {top: 0, left: 0};
        }
        offsets = $.extend({top: 0, left: 0}, offsets);

        var position =  {
          position: "absolute",
          top: (srcCoords.top + offsets.top) + "px",
          left: (srcCoords.left + offsets.left) +"px"
        };

        $(target).css(position);
      },

      alignToElement: function(src, target, alignment) {
        var element = $(src);
        var dest = $(target);
        var offsetParent = element.offsetParent();
        var srcCoords = (element.offsetParent()[0] !== src.ownerDocument.body) ? element.position() : element.offset();
        var leftOffset = ("left" === alignment) ? 0 : element.outerWidth() - dest.outerWidth();

        if (offsetParent[0] !== dest.offsetParent()[0]) {
          offsetParent.prepend(target);
        }

        var position =  {
          position: "absolute",
          top: (srcCoords.top + element.outerHeight()) + "px",
          left: (srcCoords.left + leftOffset) + "px"
        };

        dest.css(position);
      },

      alignRight: function(src, target) {
        MingleUI.align.alignToElement(src, target, "right");
      },

      alignLeft: function(src, target) {
        MingleUI.align.alignToElement(src, target, "left");
      },

      fixedAncestors: function(element) {
        return $(element).parents().filter(function(i, el) {
          return "fixed" === $(el).css("position");
        });
      },

      addMarginsBackToPositionedOffset: function(offset, element) {
        // position()/positionedOffset() removes the margins from its calculation, but we want it sometimes
        element = $(element);
        offset.left += parseInt(element.css("margin-left"), 10);
        offset.top += parseInt(element.css("margin-top"), 10);

        return offset;
      }
    }
  });
})(jQuery);
