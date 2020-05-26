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

  $.fn.colorSelector = function(opts) {
    this.off('click');
    return this.on('click', function(event) {
      event.stopPropagation();
      InputingContexts.push(new LightboxInputingContext(null, {closeOnBlur: true, contentStyles: { width: '530px', zIndex: opts.zIndex}}));
      var colorSelector = $("<div />").attr("class", "color-selector");

      $.each(window.MingleColorPalette, function(index, color) {
        var block = $("<div />").
          attr("class", "color_block").
          css("background-color", color).
          on('click', function(event) {
            opts.onColorSelect(color);
            InputingContexts.pop();
          });
        colorSelector.append(block);
      });

      var unset = $("<div />").
        text('N/A').
        attr("class", "color_block").
        on('click', function(event) {
          opts.onColorSelect(null);
          InputingContexts.pop();
        });
      colorSelector.append(unset);

      InputingContexts.top().update(colorSelector[0]);

      return false;
    });
  };
}(jQuery));
