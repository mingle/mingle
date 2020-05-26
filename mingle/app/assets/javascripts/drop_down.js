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

function DropDownAccessibilityOption(content, action, options) {
  options = options || {};
  return {
    callbacks: {
      action: action,
      setup: options.setup
    },
    htmlParams: {
      text: content,
      class: options.class ? 'accessibility-option ' + options.class : 'accessibility-option',
      title: content
    },
    isFirstOption: function () {
      return options.position === 'top';
    }
  };
}

(function ($) {

  function DropDownOption(args, initialValue) {
    function isCurrentValue(_initialValue) {
      return value.toString().toLowerCase() === _initialValue.toString().toLowerCase();
    }

    function isSelected() {
      if(!initialValue) return false;

      if (initialValue.constructor === Array) {
        return initialValue.any(function(v) {
          var _initialValue = v.constructor === Array ? v[1] : v;
          return _initialValue && isCurrentValue(_initialValue);
        });
      }

      return isCurrentValue(initialValue);
    }

    var text, value, styleClass;
    if (args.constructor === Array) {
      text = args[0];
      value = args[1];
    } else if (args.constructor === Object) {
      text = args.text;
      value = args.value;
      styleClass = args.styleClass;
    } else {
      text = value = args;
    }
    return {
      text: text.toString(),
      value: value.toString(),
      isSelected: isSelected(),
      styleClass: styleClass
    };
  }

  DropDownOption.selected = function(option) {
    return option.isSelected;
  };
  DropDownOption.text = function(option) {
    return option.text;
  };
  DropDownOption.value = function(option) {
    return option.value;
  };
  DropDownOption.reset = function (option) {
    option.isSelected = false;
  };

  MingleUI.DropDown = Class.create({
    initialize: function (name, dropDownContainerSelector, values, options) {
      options = options || {};
      this.htmlContainer = $(dropDownContainerSelector);
      this.htmlContainer.addClass('drop-down-container');
      this.name = name;
      this._initializeContainers();
      this._defaultOption = options.defaultOption || '(not set)';
      this._options = [];
      this.isMultiSelect = !!options.multiSelect;
      this.displayTextAsValue = options.displayTextAsValue || false;
      this.updateOptions(values, options.initialValue);
      this._initializeValueUpdater();
      !options.disabled && this._addToggleHandler();
      this._onValueChange = ensureFunction(options.onValueChange);
      this.setAccessibilityOption(options.accessibilityOption);
      options.disabled && this.disable();
    },

    _initializeContainers: function() {
      this._toggleHandle = this.htmlContainer.find('div.drop-down-toggle');
      if(!this._toggleHandle.length) this._addContainers();
      this._valueContainer = this._toggleHandle.find('.selected-value');
      this._optionsContainer = this.htmlContainer.find('ul.options-container');
      this._optionsContainer.hide();
    },

    _addContainers: function() {
      var toggleHandle = $('<div>',{class: 'drop-down-toggle'});
      var valueContainer = $('<span>',{class: 'selected-value'});
      toggleHandle.append(valueContainer);

      var optionsContainer = $('<ul>',{class: 'options-container'});
      this.htmlContainer.empty();
      this.htmlContainer.append(toggleHandle);
      this.htmlContainer.append(optionsContainer);
      this._toggleHandle = this.htmlContainer.find('div.drop-down-toggle');
    },

    _getAllowedOptions: function (values, initialValues) {
      if (values === undefined || values.empty())
        return [];
      return values.collect(function (value) { return  new DropDownOption(value, initialValues, this.isMultiSelect); }.bind(this));
    },

    updateOptions: function (values, initialValue) {
      this._optionsContainer.empty();
      this._accessibilityOption = undefined;
      this._options = this._getAllowedOptions(values, initialValue);
      this._updateValueContainer();
      this._addDefaultValueIfNeeded(initialValue);
      this._options.forEach(function (option) {
        this._createOption(option);
      }.bind(this));
    },

    setAccessibilityOption: function (accessibilityOption) {
      if(!accessibilityOption)
        return;
      this._accessibilityOption = accessibilityOption;
      this._optionsContainer.find('.accessibility-option').remove();
      var accessibilityOptionHtml = $('<div>', accessibilityOption.htmlParams);
      if(accessibilityOption.isFirstOption())
        this._optionsContainer.prepend(accessibilityOptionHtml);
      else
        this._optionsContainer.append(accessibilityOptionHtml);
      accessibilityOption.callbacks.setup && accessibilityOption.callbacks.setup(accessibilityOptionHtml[0]);
      accessibilityOptionHtml.on('click', accessibilityOption.callbacks.action);
    },

    addOption: function (optionName, optionValue, isSelected, keepOptionsOpen, silently) {
      this.keepOptionsOpen = keepOptionsOpen;
      if (!this._options.any(function (option) { return option.value === optionValue; }))  {
        var dropDownOption = new DropDownOption([optionName, optionValue], isSelected && optionValue);
        this._options.push(dropDownOption);
        this._createOption(dropDownOption);
        isSelected && this._updateValue(optionValue, isSelected, silently);
      } else if (isSelected && !this._options.any(function (option) { return option.value === optionValue && option.isSelected; })) {
        this._updateOption(this._optionsContainer.find('li#{0}_{1}'.supplant([this.name, optionValue.toSnakeCase()])), isSelected, silently);
      }
    },

    _addDefaultValueIfNeeded: function (initialValue) {
      if (this._options.empty() || !initialValue)
        this._valueContainer.html(this._defaultOption);
    },

    _hideOtherDropDownOptionContainers: function() {
      $('div.drop-down-container .options-container').each(function (idx, optionsContainer) {
        optionsContainer !== this._optionsContainer[0] && $(optionsContainer).hide();
      }.bind(this));
    },

    _showDropDown: function () {
      this._hideOtherDropDownOptionContainers();
      this._optionsContainer.slideToggle('fast', function () {
        $(this).scrollintoview({duration: 'fast', direction: 'vertical'});
      });
    },

    _addToggleHandler: function () {
      function closeDropDown(event) {
        if (!(this._optionsContainer.filter(event.target).length > 0 || this._optionsContainer.has(event.target).length > 0)) {
            this.keepOptionsOpen? this._optionsContainer.show() : this._optionsContainer.hide();
        }
        this.keepOptionsOpen = false;
      }

      function toggleHandler(event) {
        event.preventDefault();
        event.stopPropagation();
        if (this._disabled) return;
        if (this._optionsContainer.is(':visible'))
          closeDropDown.call(this, event);
        else
          this._showDropDown();
      }

      this._toggleHandle.on('click', toggleHandler.bind(this));
      $(document).on('click', closeDropDown.bind(this));
    },

    _createOption: function (option) {
      var optionHtml = $('<li></li>', {id: '{name}_{value}'.supplant({name: this.name, value: option.value.toSnakeCase()}), selected: option.isSelected});
      var label = $('<span></span>', {title: option.value, text: option.text, class: option.styleClass});
      optionHtml.append(label);
      if (this.isMultiSelect) {
        var checkBox = $('<input>', {type: 'checkbox', value: option.value, checked: option.isSelected});
        optionHtml.prepend(checkBox);
      }
      if(this._accessibilityOption && !this._accessibilityOption.isFirstOption())
        this._optionsContainer.find('.accessibility-option').before(optionHtml);
      else
        this._optionsContainer.append(optionHtml);
      return optionHtml;
    },

    value: function () {
      var values = this._options.filter(DropDownOption.selected).collect(DropDownOption.value);
      return this.isMultiSelect ? values : values[0];
    },

    _updateValue: function (value, isSelected, silently) {
      this._options.forEach(function (option) {
        option.isSelected = option.value === value ? isSelected : (this.isMultiSelect && option.isSelected);
      }.bind(this));
      this._updateValueContainer();
      !this._disabled && !silently && this._onValueChange && this._onValueChange(this);
    },

    _updateValueContainer: function() {
      var selectedOptions = this._options.filter(DropDownOption.selected);
      this._updateValueContainerOption(selectedOptions);
    },

    _updateValueContainerOption: function (selectedOptions) {
      var values = selectedOptions.collect(DropDownOption.text).join(', ');
      this._valueContainer.html(values || this._defaultOption);
      this._valueContainer.prop('title', values);
      if (!this.isMultiSelect) {
        var style = selectedOptions.first() && selectedOptions.first().styleClass;
        this._valueContainer.prop('class', 'selected-value ' + style);
      }
    },

    reset: function () {
      this._options.forEach(DropDownOption.reset);
      this._valueContainer.html(this._defaultOption);
      this._valueContainer.prop('class', 'selected-value');
      this._optionsContainer.empty();
    },

    clear: function () {
      this.updateOptions();
    },

    _updateOption: function(option, isSelected) {
      option.attr('selected', isSelected);
      option.find('input').prop('checked', isSelected);
      this._updateValue(option.find('span').attr('title'), isSelected);
    },

    _selectionHandler: function (event) {
      var option = $(event.currentTarget);
      if(!this.isMultiSelect) {
        this._optionsContainer.hide();
        if (option.attr('selected')) return;
        option.siblings('li').attr('selected', false);
      }

      this._updateOption(option, !option.attr('selected'));
    },

    _initializeValueUpdater: function () {
      this._optionsContainer.on('click', 'li', this._selectionHandler.bind(this));
    },

    disable: function () {
      this._disabled = true;
      this._optionsContainer.hide();
      this.htmlContainer.addClass('disabled');
    },

    enable: function () {
      this._disabled = false;
      this._optionsContainer.show();
      this.htmlContainer.removeClass('disabled');
      this._addToggleHandler();
    },

    hasValue: function () {
      return this.isMultiSelect ? this.value().length > 0 : !!this.value();
    },

    text: function() {
      var values = this._options.filter(DropDownOption.selected).collect(DropDownOption.text);
      return this.isMultiSelect ? values : values[0];
    }
  });
})(jQuery);
