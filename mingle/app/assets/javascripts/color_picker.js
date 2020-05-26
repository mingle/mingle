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
var MingleUI = (MingleUI || {});
NOT_APPLICABLE_COLOR = '#eeeeee';

(function ($) {
    function ColorPicker(containerSelector, options) {
        options = options || {};
        var self = this, currentColor = options.initialColor, onValueChange = options.onValueChange,
            colorPickerToggle;

        function handleValueChange(selectedColor) {
            if (currentColor !== selectedColor) {
                if (selectedColor == null){
                    selectedColor = NOT_APPLICABLE_COLOR;
                }
                colorPickerToggle.css('background-color', selectedColor);
                currentColor = selectedColor;
                if (onValueChange && (typeof onValueChange === 'function')) {
                  onValueChange(self, currentColor);
                }
            }
        }

        function initInput() {
            colorPickerToggle = $('<div>', {class: 'color-picker-toggle'});
            self.htmlContainer.append(colorPickerToggle);
            colorPickerToggle.css('background-color', currentColor);
            colorPickerToggle.colorSelector({onColorSelect: handleValueChange, zIndex: 10200});
        }

        this.htmlContainer = $(containerSelector);
        this.name = options.name;
        this.value = function () {
            return currentColor;
        };
        initInput();
    }

    MingleUI.ColorPicker = ColorPicker;
})(jQuery);
