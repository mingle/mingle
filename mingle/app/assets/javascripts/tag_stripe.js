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

  $.fn.tag_stripe = function() {
    return this.each(function() {
      var tagdata = $(this).data("tags");
      var tags = tagdata ? tagdata.toString().split(',') : [];
      var colored_tag = $.grep(tags, function(tag) {
        return MingleUI.tags.current().colorFor(tag);
      })[0];

      $(this).find(".colored-tags").remove();

      if (colored_tag) {
        var stripe = $('<div class="colored-tags tag-color-selector" />').
          text(colored_tag).
          css('background-color', MingleUI.tags.current().colorFor(colored_tag)).
          css('color', MingleUI.tags.current().textColorFor(colored_tag));
        stripe.colorSelector({
          onColorSelect: function(color) {
            MingleUI.tags.current().setColor(stripe.text(), color);
          }
        });
        $(this).prepend(stripe);
      }
    });
  };


  function refreshAllStripes() {
    $("[data-tags]").tag_stripe();
  }

  $(function() {
    var tagStorage = MingleUI.tags.current();
    if (tagStorage != null) {
      tagStorage.registerObserver({
        afterColorChange: refreshAllStripes
      }, refreshAllStripes);
    }
  });

  $j(document).ajaxComplete(refreshAllStripes);

  Ajax.Responders.register({ onComplete: refreshAllStripes});


}(jQuery));
