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
  function TextBox (containerSelector, options) {
    options = options || {};
    var self = this, initialVal = options.initialValue || '', onValueChange = options.onValueChange,
        isMultiValued = options.multiValued, separator = options.separator || ',', lastValue = initialVal,
        isNumeric = options.numeric, input, onCancel = options.onCancel, isDate = options.isDate, enabled = true, datePickerOpened = false;

    options.config = options.config || {};
    function setupCalendar() {
      input.datepicker($.extend({onSelect: handleValueChange, onClose: datePickerClosed, beforeShow: datePickerOpen}, options.config.date));
      // ensure datepicker is positioned correctly even on window resize https://forum.jquery.com/topic/jquery-ui-datepicker-window-resize-issue
      $(window).resize(function() {
        if (input.datepicker("widget").is(":visible") && datePickerOpened) {
          console.log(input[0]);
          input.datepicker('hide').datepicker('show');
        }
      });
    }

    function datePickerClosed() {
      datePickerOpened = false;
    }

    function datePickerOpen() {
      datePickerOpened = true;
    }

    function handleValueChange(e) {
      var currentValue = input.val();
      if (currentValue !== lastValue) {
        onValueChange(self, self.value());
        lastValue = currentValue;
      }
      e && e.relatedTarget && e.relatedTarget.click();
    }

    function initInput() {
      if(!input.length) {
        input = $('<input>', {name: self.name, type: 'text'});
        self.htmlContainer.html(input);
      }
      input.val(initialVal);
      var placeholder = self.name || '';
      input.prop('placeholder', options.placeholder || placeholder.capitalize());
    }

    function ensureNumericValues() {
      var numericRegex = new RegExp('\\d+|[\\.{separator}]'.supplant({separator: isMultiValued ? separator : ''}), 'g');
      function removeTextValues(text) {
        return $A(text.match(numericRegex)).join('').replace(/\.+/g,'.');
      }
      input.on('keypress', function(event) {
        var key = event.key;
        if(!((key >= '0' && key <= '9') || (key === '.')||( key === '-') || (isMultiValued && key === separator))) {
          $(this).tipsyFlash('Only numeric values allowed');
          event.preventDefault();
          event.stopImmediatePropagation();
        }
      });

      input.bind('paste', function (event) {
        var pastedText = event.originalEvent.clipboardData.getData('text/plain');
        event.preventDefault();
        var ele = event.target;
        var currentValue = ele.value;
        ele.value = currentValue.slice(0, ele.selectionStart) + removeTextValues(pastedText) + currentValue.slice(ele.selectionEnd);
        return false;
      });
    }

    function bindOnCancel() {
      if(onCancel && (typeof onCancel === 'function')) {
        input.on('keydown', function (event) {
          if(event.keyCode === 27) {
            onCancel(lastValue);
            return false;
          }
        });
      }
    }

    function bindOnValueChange() {
      if (onValueChange && (typeof onValueChange === 'function')) {
        input.on('keyup', function(event) {
          ((isMultiValued && event.key === separator) || event.keyCode === 13) && handleValueChange();
        });
        input.on('blur', handleValueChange);
      }
    }

    function valueOf(val) {
      return val.trim();
    }

    this.htmlContainer = $(containerSelector);
    this.name = options.name;
    input = self.htmlContainer.is('input') ? self.htmlContainer : self.htmlContainer.find('input[type="text"]');
    initInput();
    bindOnValueChange();
    bindOnCancel();
    if(isNumeric) {
      ensureNumericValues();
    } else if (isDate) {
      setupCalendar();
    }

    this.value = function () {
      return isMultiValued ? input.val().split(separator).collect(valueOf) : valueOf(input.val());
    };

    this.reset = function () {
      this.update('');
    };

    this.disable = function () {
      enabled = false;
      input.prop('disabled', true);
      this.reset();
    };

    this.disabled = function () {
      return !enabled;
    };

    this.enable = function () {
      enabled = true;
      input.prop('disabled', false);
    };

    this.restrictDateRange = function(start, end) {
      input.datepicker("option", {
        minDate: start && $.datepicker.formatDate('d, M, yy', start),
        maxDate: end && $.datepicker.formatDate('d, M, yy', end),
        dateFormat: 'd, M, yy'
      });
    };

    this.update = function (value) {
      lastValue = value;
      input.val(value);
    };
  }

  MingleUI.TextBox = TextBox;
})(jQuery);
