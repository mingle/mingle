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
DropList.Model = Class.create({

  initialize: function(optionsData, numeric, checkDuplication) {
    this.areEqual = numeric ? NumericComparison : StringComparison;
    this.selection = null;
    this.cursor = new DropList.Model.Cursor([]);
    this.replaceOptions(optionsData, checkDuplication);
    this.currentFilterValue = "";
  },

  replaceOptions: function(optionsData, checkDuplication) {
    this.currentFilterValue = "";
    this.options = [];
    this.addOptions(optionsData, checkDuplication);
    this.resetCursor();
  },

  getOptions: function() {
    return $A(this.options);
  },

  getVisibleOptions: function() {
    return this.options.select(function(option) { return !option.hidden; } );
  },

  initSelection: function(initialSelected) {
    if (initialSelected) {
      var included = this.getOptionByValue(initialSelected[1]);
      if(included) {
        this.changeSelection(included);
      }else {
        this.changeSelection(new DropList.Option(initialSelected[0], initialSelected[1], initialSelected[2]));
      }
    } else {
      this.changeSelection(this.firstOption());
    }
  },

  addOption: function(option, checkDuplication) {
    var optionModel = new DropList.Option(option[0], option[1], option[2], option[3]);

    if(checkDuplication){
      var included = this.getOptionByValue(optionModel.value);
      if(included) {
        return included;
      }
    }

    this.options.push(optionModel);
    return optionModel;
  },

  removeOption: function(removingOption) {
    var existingOptions = this.getOptions();
    this.options = existingOptions.reject(function(option) { return removingOption.value == option.value; });
  },

  changeSelection: function(selection) {
    var existed_selection = this.getOptionByValue(selection.value);
    if(existed_selection != null) {
      selection = existed_selection;
    }
    if(!selection) {return;}
    if(this.selection == selection) {return;}

    if(selection.name == undefined || selection.value == undefined) {
      throw 'Error, name or value is undefined, selection: ' + selection;
    }
    this.selection = selection;
    this.cursor.moveTo(this.selection);
    this.fireEvent('changeSelection', this.selection);
  },

  isSelected: function(selection){
    return this.selection && this.areEqual(this.selection.value, selection.value);
  },

  firstOption: function() {
    if(this.options.length == 0) {return null;}
    return this.options[0];
  },

  getOptionByValue: function(value) {
    value = value == null ? "" : value;
    var options = this.options;
    var areEqual = this.areEqual;
    for(var index = options.length - 1; index > -1; index--){
      if(areEqual(options[index].value, value)){
        return options[index];
      }
    }
  },

  resetCursor: function() {
    this.cursor.updateOptions(this.getOptions());
    this.cursor.moveTo(this.selection);
  },

  resetAllOptions: function() {
    this.options.invoke('reset');
  },

  filter: function(filteringValue, moveToTop) {
    if(this.currentFilterValue === filteringValue) {return;}
    var strippedValue = filteringValue.strip();
    this.currentFilterValue = strippedValue;
    this.options.invoke('filter', strippedValue);
    this.fireEvent('filterValueChanged', this.options);
    this.cursor.updateOptions(this.getVisibleOptions(), moveToTop);
  },

  clearFilter: function() {
    this.currentFilterValue = '';
  },

  addOptions: function(selectOptions, checkDuplication) {
    $A(selectOptions).each(function(option){
      this.addOption(option, checkDuplication);
    }, this);
  }
});

DropList.Model.prototype = Object.extend(DropList.Model.prototype, Object.Observer.prototype);

DropList.Model.Cursor = Class.create({
  initialize: function(options) {
    this.current = null;
    this.updateOptions(options);
  },

  option: function() {
    return this.current;
  },

  updateOptions: function(options, moveToTop) {
    this.options = options;
    if (moveToTop == true || moveToTop == undefined) {
      this.moveTo(this.options.length > 0 ? this.options[0] : null);
    }
  },

  moveTo: function(option) {
    if(Object.isUndefined(option)) {return;}
    this.current = option;
    this.fireEvent('changed', this.current);
  },

  moveNext: function() {
    var index = this.options.indexOf(this.current);
    if (index < this.options.length - 1) {
      this.moveTo(this.options[index + 1]);
    }
  },

  movePre: function() {
    var index = this.options.indexOf(this.current);
    if (index > 0) {
      this.moveTo(this.options[index - 1]);
    }
  }
});

DropList.Model.Cursor.prototype = Object.extend(DropList.Model.Cursor.prototype, Object.Observer.prototype);
