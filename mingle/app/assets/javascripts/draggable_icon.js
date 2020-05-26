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
// draggable behavior extened with assigment semantic:
//   * add 'selected' to nearest slot when entering droppables
//   * show tipsy for selected slot
// requirment for droppables:
//   * need set hoverClass 'icon-hover'
//   * need have multiple visible child element with class 'slot'

(function($) {

  function distanceSquare(offset1, offset2) {
    return Math.pow((offset1.left  - offset2.left), 2) +
      Math.pow((offset1.top - offset2.top), 2);
  }

  function minBy(array, functor) {
    var ret = null;
    var retVal = null;
    for(var i=0; i < array.length; i++) {
      var element = array[i];
      var val = functor(element);
      if(ret === null || val < retVal ) {
        ret = element;
        retVal = val;
      }
    }
    return ret;
  }


  $.fn.draggableIcon = function(options) {
    options = $.extend({}, $.fn.draggableIcon.defaults, options);
    var lastSelectedSlot; // for optimization

    return $(this).draggable({
      helper: 'clone',
      appendTo: "body",
      refreshPositions: true,
      cancel: '.moustache',

      start: function(event, ui) {
        lastSelectedSlot = null;
        options.startDragging.apply(this);
        // title will keep showing while dragging
        // which is quite annoying.
        $(this).data('ui-droppable-dropped', false);
        ui.helper.attr('title', null);
        if (options.consuming) {
          $(this).hide();
        }
      },

      stop: function(event, ui) {
        options.stopDragging.apply(this);
        if (options.consuming && !$(this).data('ui-droppable-dropped')) {
          $(this).show();
        }
      },

      drag: function(event, ui) {
        var slots = $('div.icon-hover div.slot').not(".error");
        if (slots.length > 0 ) {
          var neareast = minBy(slots, function(slot) {
            return distanceSquare(ui.offset, $(slot).offset());
          });

          if(neareast && neareast !== lastSelectedSlot) {
            lastSelected = neareast;
            $(neareast).addClass("selected").tipsy('show');
          }

          slots.each(function() {
            if (this !== neareast) {
              $(this).removeClass('selected').tipsy('hide');
            }
          });
        }
      }
    });
  };

  $.fn.draggableIcon.defaults = {
    startDragging: function() {},
    stopDragging: function() {},
    consuming: false
  };

})(jQuery);
