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

(function ($) {
  function SingleCheckbox(containerSelector, options) {
    options = options || {};
    var self = this, lastValue = options.checked, initialVal = options.checked || false,
        onValueChange = options.onValueChange,
        input;

    function handleValueChange() {
      var currentValue = self.value();
      if (currentValue !== lastValue) {
        onValueChange(self, self.value());
        lastValue = currentValue;
      }
    }

    function initInput() {
      input = self.htmlContainer.is('input') ? self.htmlContainer : self.htmlContainer.find('input[type="checkbox"]');
      if (!input.length) {
        input = $('<input>', {
          name: options.name,
          type: 'checkbox',
          checked: options.checked,
          class: 'single-checkbox-input'
        });
        self.htmlContainer.append(input);
      }
      input.val(initialVal);
    }

    function bindOnValueChange() {
      if (onValueChange && (typeof onValueChange === 'function')) {
        input.on('click', handleValueChange);
      }
    }

    this.htmlContainer = $(containerSelector);
    this.name = options.name.toCamelCase('-');
    initInput();
    bindOnValueChange();

    this.value = function () {
      return input.prop('checked');
    };

    this.disable = function () {
      input.attr('disabled', true);
    };

    this.enable = function () {
      input.removeAttr('disabled');
    };

    this.unselect = function () {
      input.prop('checked', false);
      lastValue = false;
    };
  }

  MingleUI.SingleCheckbox = SingleCheckbox;
})(jQuery);
