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

var PropertyDefinition = Class.create();
PropertyDefinition.ANY = '(any)';
PropertyDefinition.IGNORE = ':ignore';
PropertyDefinition.NOT_SET = '(not set)';
PropertyDefinition.EMPTY = '';
PropertyDefinition.NOT_SET_NAME_VALUE_PAIR = [PropertyDefinition.NOT_SET, PropertyDefinition.EMPTY];
PropertyDefinition.IGNORED_NAME_VALUE_PAIR = [PropertyDefinition.ANY, PropertyDefinition.IGNORE];
PropertyDefinition.equalByName = function(propertyDefinitions, definition){
  return propertyDefinitions.any(function(pd){
    return pd.name.toLowerCase() == definition.name.toLowerCase();
  });
};

PropertyDefinition.isPLV = function(value) {
  return (/^\(.*\)$/).test(value);
};

PropertyDefinition.prototype = {
  initialize: function(name, operators, nameValuePairs, appendedActions, options, tooltip){
    this.name = name;
    this.tooltip = tooltip;
    this.operators = operators;
    this.isTypeDefinition = false;
    this.options = options;
    this.hideCardTypeFilter = false;
    nameValuePairs.unshift(PropertyDefinition.IGNORED_NAME_VALUE_PAIR);
    this.nameValuePairs = nameValuePairs;
    this.appendedActions = appendedActions || $A();
  },

  isDatePropertyDefinition: function(){
    return this.options == null ? false : this.options.isDatePropertyDefinition;
  },

  isUserPropertyDefinition: function() {
    return this.options == null ? false : this.options.isUserPropertyDefinition;
  },

  dateFormat: function(){
    return this.options.dateFormat;
  },

  lookupOperatorValueByName: function(value){
    return this.operators.detect(function(operator){
      return operator[1].toLowerCase() == value.toLowerCase();
    }.bind(this));
  },

  lookupFilterValueByName: function(value){
    var filterValue = this.nameValuePairs.detect(function(nameValuePair){
      return nameValuePair[1].toLowerCase() == value.toLowerCase();
    }.bind(this));
    if (filterValue == null && this.isDatePropertyDefinition()){
      filterValue = [value, value];
    }
    return filterValue;
  }
};

var CardType = Class.create();
CardType.prototype = {
  initialize: function(name, availablePropertyDefinitions){
    this.name = name;
    this.propertyDefinitions = availablePropertyDefinitions.collect(function(hash){
      return new PropertyDefinition(hash.name, hash.operators, hash.nameValuePairs, hash.appendedActions, hash.options, hash.tooltip);
    }.bind(this));
  }
};

var CardTypeDefinition = Class.create();
CardTypeDefinition.Name = 'Type';

CardTypeDefinition.prototype = {
  initialize: function(name, operators, cardTypes, ignoreAny, parameterName){
    this.name = name;
    this.operators = operators;
    this.cardTypes = cardTypes;
    this.nameValuePairs = this.cardTypes.collect(function(cardType){
      return [cardType.name, cardType.name];
    });
    if(!ignoreAny) {
      this.nameValuePairs.unshift(PropertyDefinition.IGNORED_NAME_VALUE_PAIR);
    }
    this.isTypeDefintion = true;
    this.parameterName = parameterName || "filters[]";
  },

  isDatePropertyDefinition: function(){
    return false;
  },
  isUserPropertyDefinition: function(){
    return false;
  },

  dateFormat: function(){
    return null;
  },

  cardTypeNamed: function(name){
    return this.cardTypes.detect(function(cardType){
      return cardType.name == name;
    });
  },

  globalPropertyDefinitions: function(){
    return Array.findIntersection(this.cardTypes.collect(function(cardType){
      return cardType.propertyDefinitions;
    }), PropertyDefinition.equalByName);
  },

  lookupOperatorValueByName: function(value){
    return this.operators.detect(function(operator){
      return operator[1].toLowerCase() == value.toLowerCase();
    }.bind(this));
  },

  lookupFilterValueByName: function(value){
    return this.nameValuePairs.detect(function(nameValuePair){
      return nameValuePair[1].toLowerCase() == value.toLowerCase();
    }.bind(this));
  }
};

var Filters = Class.create();
Filters.prototype = {
  initialize: function(cardTypeDefinition, formId, filterContainerId, removeIconPath, calendarIconPath){
    this.removeIconPath = removeIconPath;
    this.calendarIconPath = calendarIconPath;
    this.filterContainerId = filterContainerId;
    this.cardTypeDefinition = cardTypeDefinition;
    this.form = $(formId);
    this.filters = [];
    this.hideCardTypeFilter = false;
    this.groupElements = $A([this._createNotSetFilterGroupElement()]);
  },

  addEmptyFilter: function() {
    var filter = Filter.emptyFilter(this, this.removeIconPath, this.calendarIconPath);
    this._show(filter);
  },

  addFirstTypeFilter: function() {
    var filter = Filter.firstTypeFilter(this, this.removeIconPath, this.calendarIconPath);
    this._show(filter);
  },

  addNewFilter: function() {
    if (!this.hideCardTypeFilter && this._isEmpty()) {
      this.addFirstTypeFilter();
    } else {
      this.addEmptyFilter();
    }
  },

  addFilters: function(newFilters) {
    if (!this.hideCardTypeFilter) {
      this._addTypeFilters(newFilters);
    }
    newFilters.each(function(filter){
      if (filter.property.toLowerCase() != CardTypeDefinition.Name.toLowerCase()){
        this.addFilter(filter.property, filter.operator, filter.value, filter.valueValue, true);
      }
    }.bind(this));
  },

  _addTypeFilters: function(newFilters) {
    var typeFilterFound = false;
    newFilters.each(function(filter){
      if (filter.property.toLowerCase() == CardTypeDefinition.Name.toLowerCase()){
        typeFilterFound = true;
        this.addFilter(filter.property, filter.operator, filter.value, filter.valueValue, this.filters.length > 0);
      }
    }.bind(this));

    if (!typeFilterFound){
      this.addNewFilter();
    }
  },

  addFilter: function(filterProperty, filterOperator, filterValue, filterValueValue, isRemovable){
    if (Object.isUndefined(isRemovable)) {
      isRemovable = true;
    }
    var selectedFilterProperty = this._lookupDefinitionByName([filterProperty, filterProperty]);
    var selectedFilterOperator = selectedFilterProperty.lookupOperatorValueByName(filterOperator);
    var selectedFilterValue = filterValueValue;
    var filter = new Filter(this.propertyDefinitions(), this, {
      property: [selectedFilterProperty.name, selectedFilterProperty.name],
      operator: selectedFilterOperator,
      value: selectedFilterValue
    }, isRemovable, this.removeIconPath, this.calendarIconPath);
    this._show(filter);
  },

  parameterName: function(){
    return this.cardTypeDefinition.parameterName;
  },

  reorder: function() {
    this.filters.each(function(filter){
      if (filter.belongsToIncorrectGroup()){
        filter.moveTo(this._groupElementForProperty(filter.propertyDefinitionName()));
      }
    }.bind(this));
  },

  propertyDefinitions: function(){
    var commonPropertyDefinitions;
    if (this._selectedCardTypes().length == 0){
      commonPropertyDefinitions = this._cardTypeFiltersWithValuePresent() ? [] : this.cardTypeDefinition.globalPropertyDefinitions();
    } else {
      commonPropertyDefinitions = Array.findIntersection(this._selectedCardTypes().collect(function(cardType){
        return cardType.propertyDefinitions;
      }.bind(this)), PropertyDefinition.equalByName);
    }
    if (this.hideCardTypeFilter){
      commonPropertyDefinitions = commonPropertyDefinitions.reject(function(pd){
        return pd.name == CardTypeDefinition.Name;
      });
    } else {
      commonPropertyDefinitions.unshift(this.cardTypeDefinition);
    }
    return commonPropertyDefinitions.flatten().uniq();
  },

  propertyOptions: function(){
    return this.propertyDefinitions.collect(function(propertyDefinition){
      return [propertyDefinition.name, propertyDefinition.name, propertyDefinition.tooltip];
    });
  },

  operatorsFor: function(propertyNameValuePair, selectedValue){
    var selectedDefintion = this._lookupDefinitionByName(propertyNameValuePair);
    if (selectedDefintion == null){
      return [['is', 'is']];
    }
    if ($A(selectedValue).last() == PropertyDefinition.EMPTY){
      return $A(selectedDefintion.operators).reject(function(operator){
        return this._supportsFilteringByNotSet(operator[1]);
      }.bind(this));
    } else {
      return selectedDefintion.operators;
    }
  },

  valuesFor: function(propertyNameValuePair, selectedOperator){
    var selectedDefinition = this._lookupDefinitionByName(propertyNameValuePair);
    if (selectedDefinition == null){
      return [PropertyDefinition.IGNORED_NAME_VALUE_PAIR];
    }
    if (this._supportsFilteringByNotSet($A(selectedOperator).first())){
      return $A(selectedDefinition.nameValuePairs).reject(function(nameValuePair){
        return nameValuePair[1] == PropertyDefinition.EMPTY;
      });
    } else {
      return selectedDefinition.nameValuePairs;
    }
  },

  _supportsFilteringByNotSet: function(operator){
    if (operator == null){
      return false;
    }
    return $A(['is greater than', 'is less than', 'is before', 'is after']).any(function(rangeLikeOperator){
      return rangeLikeOperator.toLowerCase() == operator.toLowerCase();
    });
  },

  onChange: function(){
    $j(this.form).submit();
  },

  clearInvalidFilters: function() {
    var groupsToRemove = this.groupElements.select(function(groupElement) {
      var isValid = this.propertyDefinitions().any(function(propertyDefinition){
        return groupElement.readAttribute('propertyDefinition') == propertyDefinition.name;
      });
      return !isValid;
    }.bind(this));
    groupsToRemove.each(function(groupElement) {
      this._deleteFilterGroup(groupElement);
    }.bind(this));
  },

  _deleteFilterGroup: function(filterGroupElement){
    if (filterGroupElement.readAttribute('propertyDefinition') == ''){
      return;
    }
    for(var i = this.filters.length - 1; i > 0; i--){
      if (this.filters[i].container.up() == filterGroupElement){
        this.filters.splice(i, 1);
      }
    }
    this.groupElements.splice(this.groupElements.indexOf(filterGroupElement), 1);
    filterGroupElement.remove();
  },

  remove: function(filterToRemove){
    var filterIndex = this.filters.collect(function(filter, index){
      if (filter.index == filterToRemove.index){
        return index;
      }
    }.bind(this)).compact();

    this.filters.splice(filterIndex, 1);
    if (filterToRemove.belongsToGroup) {
      var groupElementForFilter = this._groupElementForProperty(filterToRemove.propertyDefinitionName());
      if (groupElementForFilter.childElements().length == 1){
        this._deleteFilterGroup(groupElementForFilter);
      }
    }
  },

  updateAvailablePropertyDroplistOptions: function() {
    this.filters.each(function(filter) {
      filter.updatePropertyDefinitions(this.propertyDefinitions());
    }.bind(this));
  },

  filterIdPrefix: function() {
    return this.filterContainerId == 'filter-widget' ? 'cards_filter_' : this.filterContainerId + '_cards_filter_';
  },

  _nextIndex: function() {
    if (this._isEmpty()){
      return 0;
    }
    var currentLargestIndex = this.filters.max(function(filter){
      return parseInt(filter.index, 10);
    });
    return currentLargestIndex + 1;
  },

  _show: function(filter){
    var nextIndex = this._nextIndex();
    this.filters.push(filter);
    filter.render(nextIndex, this._groupElementForProperty(filter.propertyDefinitionName()));
  },

  _isEmpty: function() {
    return this.filters.length == 0;
  },

  _isValid: function(filter){
    return this.propertyDefinitions().any(function(definition){
      return definition.name == filter.propertyDefinitionName();
    }.bind(this));
  },

  _groupElementForProperty: function(propertyDefinitionName){
    if (propertyDefinitionName == null){
      propertyDefinitionName = '';
    }

    var result = this.groupElements.detect(function(groupElement){
      return (groupElement.readAttribute('propertyDefinition') == propertyDefinitionName);
    }.bind(this));

    if (result == null){
      result = Builder.node('div', {id : this._groupElementForPropertyId(propertyDefinitionName), propertyDefinition: propertyDefinitionName});
      this.groupElements.push(result);
      $(this.filterContainerId).appendChild(result);
      if (propertyDefinitionName != ''){
        $(this.filterContainerId).appendChild($(this._groupElementForPropertyId('')).remove());//remove and add it again; so it is at the end
      }
    }
    return result;
  },

  _createNotSetFilterGroupElement: function(){
    var notSetFilterGroup = Builder.node('div', {id : this._groupElementForPropertyId(''), propertyDefinition: ''});
    $(this.filterContainerId).appendChild(notSetFilterGroup);
    return notSetFilterGroup;
  },

  _groupElementForPropertyId: function(propertyDefinitionName){
    return this.filterIdPrefix() + propertyDefinitionName + '_filter_group';
  },

  _lookupDefinitionByName: function(propertyNameValuePair){
    if (propertyNameValuePair.compact().length == 0){
      return null;
    }
    if (propertyNameValuePair[1].toLowerCase() == this.cardTypeDefinition.name.toLowerCase()){
      return this.cardTypeDefinition;
    }
    return this.propertyDefinitions().detect(function(definition){
      return (definition.name.toLowerCase() == propertyNameValuePair[0].toLowerCase());
    }.bind(this));
  },

  _cardTypeFiltersWithValuePresent: function(){
    return this.filters.any(function(filter){
      return filter.isTypeFilterWithValue();
    });
  },

  _selectedCardTypes: function(){
    var isNotCardTypeNames = this.filters.collect(function(filter){
      return (filter.isTypeFilter() && filter.operator() == 'is not')  ? filter.propertyDefinitionValues() : null;
    });
    isNotCardTypeNames = Array.findIntersection(isNotCardTypeNames.compact()).flatten();

    var isCardTypeNames = this.filters.collect(function(filter){
      return (filter.isTypeFilter() && filter.operator() == 'is') ? filter.propertyDefinitionValues() : null;
    });

    var selectedCardTypeNames = isCardTypeNames.concat(isNotCardTypeNames).uniq();

    return selectedCardTypeNames.collect(function(cardTypeName){
      return this.cardTypeDefinition.cardTypeNamed(cardTypeName);
    }.bind(this)).compact();
  }
};

var Filter = Class.create();
Filter.prototype = {
  initialize: function(propertyDefinitions, filters, selections, allowRemove, removeIconPath, calendarIconPath){
    this.removeIconPath = removeIconPath;
    this.calendarIconPath = calendarIconPath;
    this.propertyDefinitions = propertyDefinitions;
    this.propertyOptions = this.propertyDefinitions.collect(function(propertyDefinition){
      return [propertyDefinition.name, propertyDefinition.name, propertyDefinition.tooltip];
    });
    this.filters = filters;
    this.operatorsProvider = filters;
    this.valuesProvider = filters;
    this.changeHandler = filters;
    this.cardTypeChangeHandler = filters;
    this.selections = selections;
    this.allowRemove = allowRemove;
    this.belongsToGroup = false;
  },

  render: function(index, parent){
    this.index = index;
    this.id = this.filters.filterIdPrefix() + this.index;
    this.container = Builder.node('div', {id: this.id + '_filter_container', className: 'condition-container clear_float'});
    parent.appendChild(this.container);
    this.renderDroplists();
    this.renderInputField();
    if (this.allowRemove){
      this.renderRemoveLink();
    }
  },

  renderDroplists: function(){
    var droplistsToRender = [];
    for(var i = 0; i < arguments.length; i++){
      droplistsToRender.push(arguments[i]);
    }
    if (droplistsToRender.length == 0){
      droplistsToRender = this.droplists();
    }
    droplistsToRender.each(function(droplist) {
      this.container.appendChild(droplist.view);
      droplist.render();
    }.bind(this));
  },

  propertyDefinitionName: function(){
    if (this._propertiesDroplist == null){
      return this._selectedProperty()[1];
    } else {
      return this.propertiesDroplist().value();
    }
  },

  propertyDefinitionValues: function(){
    if (this._valuesDroplist == null){
      return this._selectedValue()[1];
    } else {
      if (this.operator() == 'is'){
        return this.valuesDroplist().value();
      } else {
        return this.valuesDroplist().notSelectedValues();
      }
    }
  },

  renderInputField: function(){
    this.container.appendChild(Builder.node('input', {id: this.id + '_filter_field', name: this.filters.parameterName(), type: 'hidden', value: this.value()}));
  },

  renderRemoveLink: function(){
    this._deleteLink = Builder.node('a', {id: this.id + '_delete', className: 'filter-delete-link'}, [
      Builder.node('img', {src: this.removeIconPath, alt: 'click here to delete this filter'})
    ]);
    this.container.appendChild(Builder.node('div', {className: 'condition-actions'}, [this._deleteLink]));
    Event.observe(this._deleteLink, 'click', this._onRemove.bindAsEventListener(this));
  },

  value: function(){
    if (this.propertiesDroplist().value() != null && this.operatorsDroplist().value() != null && this.valuesDroplist().value() != null ){
      return '[' + this.propertiesDroplist().value() + ']' +
      '[' + this.operatorsDroplist().value() + ']' +
      '[' + this.valuesDroplist().value() + ']';
    }
    return '';
  },

  operator: function(){
    if (this._operatorsDroplist != null && this._operatorsDroplist.value() != null){
      return this._operatorsDroplist.value();
    }
    return '';
  },

  propertiesDroplist: function(){
    if (this._propertiesDroplist == null){
      this._propertiesDroplist = new FilterDroplist(this.propertyOptions, this._selectedProperty(), {
                                                      htmlIdPrefix: this.id,
                                                      contentName: 'properties',
                                                      className: 'first-operand',
                                                      fieldName: this._selectedProperty()[1] + '_property',
                                                      onchange: this._onPropertyChange.bind(this),
                                                      clickable: this.allowRemove,
                                                      allowDatePicker: false
                                                    }, this.calendarIconPath);
    }
    return this._propertiesDroplist;
  },

  operatorsDroplist: function(){
    if (this._operatorsDroplist == null){
      this._operatorsDroplist = new FilterDroplist(this.operatorsProvider.operatorsFor(this._selectedProperty(), this._selectedValue()), this._selectedOperator(), {
                                                    htmlIdPrefix: this.id,
                                                    contentName: 'operators',
                                                    className: 'operator',
                                                    fieldName: this._selectedProperty()[1] + '_operator',
                                                    onchange: this._onOperatorChange.bindAsEventListener(this),
                                                    clickable: true,
                                                    allowDatePicker: false
                                                  }, this.calendarIconPath);
    }
    return this._operatorsDroplist;
  },

  valuesDroplist: function(){
    if (this._valuesDroplist == null){
      var selectedProperty = this._selectedProperty();
      var selectedPropertyDefinition = this.propertyDefinitions.detect(function(propertyDefinition){
        return (selectedProperty != null) && (propertyDefinition.name.toLowerCase() == selectedProperty.first().toLowerCase());
      }.bind(this));
      var appendedActions = selectedPropertyDefinition ? selectedPropertyDefinition.appendedActions : [];
      this._valuesDroplist = new FilterDroplist(this.valuesProvider.valuesFor(selectedProperty, this._selectedOperator()), this._selectedValue(), {
                                                  htmlIdPrefix: this.id,
                                                  contentName: 'values',
                                                  className: 'second-operand',
                                                  fieldName: selectedProperty[1] + '_value',
                                                  onchange: this._onValueChange.bind(this),
                                                  clickable: true,
                                                  allowDatePicker: this._allowDatePicker(),
                                                  isUserProperty: this._isUserProperty(),
                                                  dateFormat: this._dateFormat(),
                                                  form: this.filters.form,
                                                  appendedActions: appendedActions
                                                }, this.calendarIconPath);
    }
    return this._valuesDroplist;
  },

  isTypeFilter: function(){
    var filterProperty = this.propertyDefinitionName();
    if (filterProperty == null){
      return false;
    }
    return filterProperty.toLowerCase() == this.cardTypeChangeHandler.cardTypeDefinition.name.toLowerCase();
  },

  _allowDatePicker: function() {
    var propertyDefinition = this.filters._lookupDefinitionByName(this._selectedProperty());
    return (propertyDefinition == null) ? false : propertyDefinition.isDatePropertyDefinition();
  },

  _isUserProperty: function() {
    var propertyDefinition = this.filters._lookupDefinitionByName(this._selectedProperty());
    return (propertyDefinition == null) ? false : propertyDefinition.isUserPropertyDefinition();
  },

  _dateFormat: function() {
    if (this._allowDatePicker()) {
      var propertyDefinition = this.filters._lookupDefinitionByName(this._selectedProperty());
      return (propertyDefinition == null) ? null : propertyDefinition.dateFormat();
    }
    return null;
  },

  isTypeFilterWithValue: function(){
    var selectedValue = PropertyDefinition.IGNORE;
    if (this._valuesDroplist != null && this._valuesDroplist.value() != null){
      selectedValue = this._valuesDroplist.value();
    }

    return this.isTypeFilter() && selectedValue != PropertyDefinition.IGNORE;
  },

  droplists: function(){
    return [this.propertiesDroplist(), this.operatorsDroplist(), this.valuesDroplist()];
  },

  belongsToIncorrectGroup: function(){
    var currentGroupElement = this.container.up();
    return this.propertyDefinitionName() != currentGroupElement.readAttribute('propertyDefinition');
  },

  moveTo: function(groupElement){
    this.belongsToGroup = true;
    groupElement.appendChild(this.container.remove());
  },

  removeFromUI: function() {
    this.container.remove();
    this.changeHandler.onChange();
  },

  updatePropertyDefinitions: function(propertyDefinitions) {
    this.propertyDefinitions = propertyDefinitions;
    this.propertyOptions = this.propertyDefinitions.collect(function(propertyDefinition){
      return [propertyDefinition.name, propertyDefinition.name, propertyDefinition.tooltip];
    });
    this.propertiesDroplist().remove();
    this.operatorsDroplist().remove();
    this.valuesDroplist().remove();
    this._propertiesDroplist = null;
    this._operatorsDroplist = null;
    this._valuesDroplist = null;
    this.renderDroplists();
    this._redrawDeleteLink();
  },

  _onPropertyChange: function(selection){
    this.selections = {
      property: [selection.name, selection.value]
    };
    this._resetDroplists();
  },

  _onOperatorChange: function(selection){
    this.selections.operator =  [selection.name, selection.value];
    if (this.isTypeFilter()){
      this.filters.clearInvalidFilters();
      this.filters.updateAvailablePropertyDroplistOptions();
    }
    this._resetDroplists();
    this._refreshFilterField();
  },

  _onValueChange: function(selection){
    this.selections.value = [selection.name, selection.value];
    if (this.isTypeFilter()){
      this.filters.clearInvalidFilters();
      this.filters.updateAvailablePropertyDroplistOptions();
    }
    this._resetDroplists();
    this.filters.reorder();
    this._refreshFilterField();
  },

  _onRemove: function(event){
    if (event != null){
      Event.stop(event);
    }
    this.filters.remove(this);
    this.removeFromUI();
    if (this.isTypeFilter()){
      this.filters.updateAvailablePropertyDroplistOptions();
    }
    this.filters.reorder();
  },

  _resetFilterField: function(event){
    $(this.id + '_filter_field').value = null;
  },

  _refreshFilterField: function(event){
    $(this.id + '_filter_field').value = this.value();
    this.changeHandler.onChange();
  },

  _resetDroplists: function(){
    this._propertiesDroplist.remove();
    this._operatorsDroplist.remove();
    this._valuesDroplist.remove();
    this._propertiesDroplist = null;//force rebuilding it
    this._operatorsDroplist = null;//force rebuilding it
    this._valuesDroplist = null;//force rebuilding it
    this.renderDroplists();
    this._redrawDeleteLink();
  },

  _redrawDeleteLink: function(){
    if (this._deleteLink != undefined && this._deleteLink != null){
      this._deleteLink.up().remove();
      this.renderRemoveLink();
    }
  },

  _selectedProperty: function(){
    return this.selections.property;
  },

  _selectedOperator: function(){
    return this.selections.operator;
  },

  _selectedValue: function(){
    return this.selections.value;
  }
};

Filter.firstTypeFilter = function(filters, removeIconPath, calendarIconPath){
  return new Filter([filters.cardTypeDefinition], filters, {
    property: [CardTypeDefinition.Name, CardTypeDefinition.Name],
    operator: ['is', 'is']
  }, false, removeIconPath, calendarIconPath);
};

Filter.emptyFilter = function(filters, removeIconPath, calendarIconPath){
  return new Filter(filters.propertyDefinitions(), filters, {
    property: ['(select...)', PropertyDefinition.EMPTY],
    operator: ['is', 'is']
  }, true, removeIconPath, calendarIconPath);
};

var FilterDroplist = Class.create();
FilterDroplist.prototype = {
  initialize: function(selectOptions, selectedValue, options, calendarIconPath){
    this.calendarIconPath = calendarIconPath;
    this.selectOptions = $A(selectOptions);
    this.selectedValue = selectedValue;
    this.options = options;
    this.view = this._buildDropListNode();
  },

  render: function(){
    if (this.controller == null && this.options.clickable){
      this.controller = new DropList(this._droplistOptions());
      if (this.options.allowDatePicker){
        this._setupCalendar();
      }
    }
    return this.controller;
  },

  remove: function(){
    if (this.clickable){
      this.controller.deactivate();
      this.controller = null;
    }
    this.view.remove();
  },

  value: function(){
    if (this.options.clickable){
      if (this.options.allowDatePicker) {
        return $(this._inputFieldId()).value;
      } else {
        return this.controller == null ? null : this.controller.getSelectedValue();
      }
    } else {
      return this.selectOptions.first()[0];
    }
  },

  notSelectedValues: function(){
    var selectedValue = this.value();
    return this.selectOptions.collect(function(valuePair) {
      var value = valuePair[0];
      if (value != PropertyDefinition.ANY && value != selectedValue){
        return value;
      }
    }).compact();
  },

  _setupCalendar: function() {
    Calendar.setup(
      {
        inputField  : this._inputFieldId(),
        ifFormat    : this.options.dateFormat,
        displayArea : this._droplinkId(),
        daFormat    : this.options.dateFormat,
        button      : this._htmlIdPrefix() + '_date_picker',
        align       : "Br",
        electric    : false,
        showOthers  : true,
        weekNumbers : false,
        firstDayOfWeek : 0,
        onUpdate: function(){
          // ie has innerText and no text for element a
          var selectedValue = $(this._droplinkId()).text || $(this._droplinkId()).innerText;
          $(this._inputFieldId()).value = selectedValue;
          this.options.onchange({
              name: selectedValue,
              value: selectedValue
          });
        }.bind(this)
      }
    );
  },

  _buildDropListNode: function() {
    var droplistContainerChildren;
    if (this.options.clickable) {
        droplistContainerChildren = [ this._buildDropLinkNode(), this._buildDropDownNode() ];
    } else {
      droplistContainerChildren = [ this._plainTextDisplayNode() ];
    }
    return Builder.node('div', {id: this._htmlIdPrefix() + '_container'}, droplistContainerChildren);
  },

  _linkText: function(selectedValue){
    return selectedValue ? this._displayLinkTextSelectedValue(selectedValue) : PropertyDefinition.ANY;
  },

  _displayLinkTextSelectedValue: function(selectedValue){
    return selectedValue.first().truncate(55);
  },

  _buildDatePicker: function() {
    var result = Builder.node('img', { id: this._htmlIdPrefix() + '_date_picker',
      border: 0,
      style: 'padding-left: 0.25em;',
      title: 'Pick a date',
      src: this.calendarIconPath,
      alt: "Calendar picker"});
    return result;
  },

  _buildDropLinkNode: function(selectedValue) {
    var childElements = [Builder.node('a', {id: this._droplinkId()}, this._linkText(selectedValue))];
    if (this.options.allowDatePicker){
      childElements.push(this._buildDatePicker());
    }
    if (selectedValue){
      childElements.push(Builder.node('input', {name: this.options.fieldName, id: this._inputFieldId(), type: 'hidden', value: selectedValue.last()}));
    } else {
      childElements.push(Builder.node('input', {name: this.options.fieldName, id: this._inputFieldId(), type: 'hidden'}));
    }
    return Builder.node('div', {id: this._htmlIdPrefix(), className: this.options.className}, childElements);
  },

  _plainTextDisplayNode: function(){
    return Builder.node('div', {id: this._htmlIdPrefix(), className: this.options.className},[
      Builder.node('p', {id: this._htmlIdPrefix() + '_text', style: 'display:inline'}, this.selectOptions.first()[0]),
      Builder.node('input', {name: this.options.fieldName, id: this._inputFieldId(), type: 'hidden', value: this.selectOptions.first()[1]})
    ]);
  },

  _buildDropDownNode: function(){
    return Builder.node('div', {id: this._htmlIdPrefix() + '_drop_down', style: 'display: none; z-index: 9999 !important', className: 'widget-dropdown'},[
      Builder.node('ul')
    ]);
  },

  _htmlIdPrefix: function(){
    return this.options.htmlIdPrefix + '_' + this.options.contentName;
  },

  _droplinkId: function(){
    return this._htmlIdPrefix() + '_drop_link';
  },

  _inputFieldId: function(){
    return this._htmlIdPrefix() + '_input_field';
  },

  _droplistOptions: function(){
    var result = {
      container: this._htmlIdPrefix(),
      selectOptions: this.selectOptions,
      htmlIdPrefix: this._htmlIdPrefix(),
      appendedActions: this.options.appendedActions,
      checkDuplication: true,
      position: this.options.position
    };

    if (this.options.isUserProperty) {
      MingleUI.initUserSelector(result, 'login');
    }

    if (this.options.onchange != null) {
      result.onchange = this.options.onchange;
    }
    if (this.selectedValue != null) {
      result.initialSelected =  this.selectedValue;
    }
    return result;
  }
};

var FiltersForm = Class.create({
  // using last win strategy to submit filter request, additional arguments will be treat as spinners
  initialize: function(form) {
    this.form = $(form);
    this.spinners = $A(arguments).slice(1).collect(function(el){ return $(el); });
  },

  submit: function(options) {
    var spinners = this.spinners;
    var defaultOptions = {
      url          : $j(this.form).attr("action"),
      type         : 'GET',
      dataType     : 'script',
      beforeSend   : function() {
        $j(spinners).show();
        window.docLinkHandler.disableLinks();
      },
      complete     : function() {
        $j(spinners).hide();
        window.docLinkHandler.enableLinks();
      },
      data         : FiltersForm.serialize(this.form).toQueryParams()
    };

    $j.ajax($j.extend(defaultOptions, options));
    return false;
  },

  submitOnlyFiltersParam: function() {
    return this.submit({ data: Form.serializeElements(this.form.select('input[name="filters[]"]')) });
  },

  submitViaPost: function() {
    return this.submit({method: "POST", beforeSend: null, complete: null});
  }

});

FiltersForm.serialize = function(form, options) {
  var elements = Form.getElements(form);
  // #9442 for better performance on IE
  if (form.select('.inputs-group').first()) {
    elements = elements.reject(FiltersForm.isOnInvisiblePanel);
  }
  return Form.serializeElements(elements, options);
};

FiltersForm.isOnInvisiblePanel = function(el) {
  var group = el.up('.inputs-group');
  return group && !group.visible();
};

Object.extend(FiltersForm, {
});

FiltersForm.ReapplyingModule = {
  submitWithShowReapplyingPanel: function() {
    var ret = this.submitWithoutShowReapplyingPanel();
    this.form.select('.resubmit-filter').each(function(div){
      if(FiltersForm.isOnInvisiblePanel(div)) {
        div.show();
      } else {
        div.hide();
      }
    });
    return ret;
  },
  aliasMethodChain: [['submit', 'showReapplyingPanel']]
};
