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
DropList.prototype = Object.extend(CallbackInterpreter, {

  initialize: function(options){
    options = options || {};
    this.htmlIdPrefix = options.htmlIdPrefix;
    this.model = new DropList.Model(options.selectOptions, options.numeric, options.checkDuplication);

    //todo: kind of dirty, need to be removed after clean up the htmlIdPrefix stuff
    options.generateId = function(original) {
      return this.htmlIdPrefix + '_' + original;
    };

    options.dropLink = $(options.dropLink || options.generateId("drop_link"));
    var panel = $j(options.dropLink).parent()[0];
    panel.propertyEditor = this;

    this.onchange = this.interpretCallback(options.onchange, panel, ['e']);
    this.before = this.interpretCallback(options.before);

    if (options.dropLinkStyle != null){
      options.dropLink.addClassName(options.dropLinkStyle);
    }

    this.controller = new DropList.BasicController(this.model, options);

    this.controller.dropLink.element.observe('click', this.before );

    this.model.observe('dropDownBlur', this.interpretCallback(options.onblur));

    if (options.supportInlineEdit) {
      this.controller.appendAction(new DropList.InlineEditAction(this.model, this.controller, options.inlineAddOptionActionTitle, options));

    }

    if (options.supportFilter) {
      this.controller.appendAction(new DropList.FilterAction(this.model, this.controller, options.filterAction));
      this.model.observe('filterValueChanged', this.controller.onFilterChanged.bindAsEventListener(this.controller));
    }

    if (options.appendedActions) {
      options.appendedActions.each(function(action){
        if(Object.isString(action)) {
          action = eval(action);
        }
        this.controller.appendAction(action);
      }.bind(this));
    }

    this.controller.render();
    if(options.prompt) {
        this.controller.dropLink.setPrompt(options.prompt);
    } else {
        this.model.initSelection(options.initialSelected);
    }
    this.model.observe('changeSelection', function() {
      DropList.View.Layout.refix();
      this.onchange(this.model.selection);
    }.bind(this));
  },

  getSelectedName: function() {
    return this.model.selection.name;
  },

  getSelectedValue: function() {
    return this.model.selection.value;
  },

  getField: function() {
    return this.controller.getField();
  },

  replaceOptions: function(selectOptions, selection) {
    this.model.replaceOptions(selectOptions);
    this.model.initSelection(selection);
  },

  removeOption: function(removingOption) {
    this.model.removeOption(removingOption);
  },

  addOption: function(dropListOption) {
    this.model.addOption(dropListOption);
  },

  replaceSelectedOption: function (selection) {
    this.model.initSelection(selection);
  }
});

DropList.GlobalHotKeyController = HotKey;

PropertyEditor = {
  Init: {
    ondemand: function(event) {
      // normalize native event object with jQuery
      var e = $j.event.fix(event);
      var element = e.target;
      var datePicker = null;

      if ($j(element).hasClass("date-picker")) {
        datePicker = element;
        element = $j(element).siblings(".property-value-widget").get(0);
      }

      if ($j(element).hasClass("property-value-widget") && !element.handler) {
        var displayValue = $j.trim($j(element).text());
        var fieldValue = $j(element).data("value");
        fieldValue = null === fieldValue ? "" : fieldValue.toString();

        var options = {
          htmlIdPrefix: element.id,
          dropLink: element.id,
          initialSelected: [displayValue, fieldValue]
        };

        $j.map($j(element).data(), function(value, key) {
          options[$j.camelCase(key)] = value;
        });

        var isUserProp = $j(element).parent('.drop-list-panel').hasClass("user_property_definition");
        if (isUserProp) {
          MingleUI.initUserSelector(options, 'id');
        }

        if (options.inlineTextEditor) {
          PropertyEditor.Init.initTextEditor(element, options);
        } else {
          PropertyEditor.Init.initDropList(element, datePicker, options, event);
        }
      }
    },

    initTextEditor: function(element, options) {
      element.handler = new TextPropertyEditor(element.id, element.id + "_field", options.initialSelected[1], "(not set)", options);
      element.handler._onEditLinkClick();
    },

    initDropList: function(element, datePicker, options, event) {
      element.handler = new DropList(options);

      PropertyEditor.Init.createDatePicker(element, options);

      if (null === datePicker) {
        // pass event to dropdown
        element.handler.controller.onDropLinkClicked(event);
        return;
      }

      // if the user clicked on the date picker icon, only show date picker
      // instead of the dropdown
      datePicker.onclick();
    },

    createDatePicker: function(element, options) {
      if ($j(element).closest(".date_property_definition").size() === 0) {
        return;
      }

      var field = $j("#" + element.id + "_field");
      var datePicker = new DatePropertyEditor(element.id, field.val(), '(not set)', null, 'field', options);

      Calendar.setup(
        {
          inputField  : field.attr("id"),
          ifFormat    : options.dateFormat,
          displayArea : element.id,
          daFormat    : options.dateFormat,
          button      : element.id + "_calendar",
          align       : "Br",
          electric    : false,
          showOthers  : true,
          weekNumbers : false,
          firstDayOfWeek : 0,
          onUpdate    : function(calendar) {
            datePicker._onUpdateFromCalendarWidget(calendar);
          },
          cache       : true
        }
      );
    }
  }
};
