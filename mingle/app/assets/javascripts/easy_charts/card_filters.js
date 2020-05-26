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
MingleUI.EasyCharts = (MingleUI.EasyCharts || {});

(function ($) {
  MingleUI.EasyCharts.CardFilters = function (selector, project, options) {
    var self = this, filters = [], index = 1, cardTypeFilter,
        filtersContainer = $('<div>', {id: 'card_filters_container'}), propertyDefinitions = [],
        onUpdate, _initialFilters, includeCardTypeFilter, selectedCardTypes;

    function addFilter(filterParams) {
      var filter = new MingleUI.EasyCharts.CardFilter(index++, 'card_filter', filterParams);
      filtersContainer.append(filter.htmlContainer);
      return filter;
    }

    function initialFilters() {
      if (options.initialData && options.initialData.length && !_initialFilters) {
        _initialFilters = {property: []};
        options.initialData.each(function (filter) {
          if (filter.property === 'Type')
            _initialFilters.card = filter;
          else
            _initialFilters.property.push(filter);
        });
      }
      _initialFilters = _initialFilters || {card: {}, property: []};
      return _initialFilters;
    }

    function addPropertyFilter(_propertyDefinitions, initialData) {
      if (filters.last() && !filters.last().isValid()) {
        return;
      }
      propertyDefinitions = _propertyDefinitions || propertyDefinitions;
      propertyDefinitions = new PropertyDefinitionFilter(options.propertyDefinitionFilters).apply(propertyDefinitions);
      var filterParams = {
        project: {identifier: project.identifier, dateFormat: project.dateFormat},
        propertyDefinitions: propertyDefinitions,
        onUpdate: propertyFilterUpdated,
        onRemove: propertyFilterRemoved,
        initialData: initialData,
        enableThisCardOption: options.enableThisCardOption,
        disableProjectVariables: options.disableProjectVariables,
        disabled: options.disabled
      };
      filters.push(addFilter(filterParams));
    }

    function getCardTypes() {
      var cardTypes = project.cardTypeNames;
      if(options.allowedCardTypes)
        cardTypes = options.allowedCardTypes.intersect(project.cardTypeNames);
      return cardTypes;
    }

    function addCardTypeFilter() {
      selectedCardTypes = initialFilters().card.values || [];
      cardTypeFilter = new MingleUI.EasyCharts.CardTypeFilter(index++, 'card_filter', {
        cardTypes: getCardTypes(),
        selectedCardTypes: selectedCardTypes,
        onUpdate: cardTypeUpdated
      });
      filtersContainer.append(cardTypeFilter.htmlContainer);
      selectedCardTypes = cardTypeFilter.value.value();
      selectedCardTypes.length && project.fetchCommonPropertyDefinitionDetails(selectedCardTypes, addInitialPropertyFilters);
    }

    function addInitialPropertyFilters(_propertyDefinitions) {
      initialFilters().property.each(function(filter) {
        addPropertyFilter(_propertyDefinitions, filter);
      });
      addPropertyFilter(_propertyDefinitions);
    }

    function cardTypeUpdated() {
      if(filters.length) {
        filters.each(function(filter) { filter.remove(); });
        filters = [];
      }
      var selectedCardTypes = cardTypeFilter.value.value();
      selectedCardTypes.length && project.fetchCommonPropertyDefinitionDetails(selectedCardTypes, addPropertyFilter);
      filtersUpdated(true);
    }

    function propertyFilterRemoved(filter) {
      var index = filters.indexOf(filter), isLast = index === filters.length - 1;
      filters.splice(index, 1);
      (!filters.length || isLast) && addPropertyFilter();
      filter.isValid() && filtersUpdated();
    }

    function propertyFilterUpdated(filter) {
      if(filters.last() === filter && filter.isValid()) addPropertyFilter();
      filtersUpdated();
    }

    function filtersUpdated(cardTypesUpdated) {
      onUpdate && onUpdate(self, cardTypesUpdated || false);
    }

    function initFilters(selectedProperty) {
      filtersContainer.html('');
      index = 1;
      filters = [];
      if(selectedProperty)
        addPropertyFilter(project.fetchCommonPropertyDefinitionDetails(selectedCardTypes, selectedProperty));
      else
        includeCardTypeFilter ? addCardTypeFilter() : project.fetchCommonPropertyDefinitionDetails(selectedCardTypes, addInitialPropertyFilters);
    }

    function initialize(selectedProperty) {
      self.name = options.name;
      onUpdate = ensureFunction(options.onUpdate);
      includeCardTypeFilter = !options.withoutCardTypeFilter;
      selectedCardTypes = options.selectedCardTypes || [];
      self.htmlContainer = $(selector);
      self.htmlContainer.empty();
      self.htmlContainer.append(filtersContainer);
      initFilters(selectedProperty);
    }

    this.value = function () {
      var validFilters = includeCardTypeFilter && cardTypeFilter.isValid() ? [cardTypeFilter] : [];
      filters.each(function (filter) {
        filter.isValid() && validFilters.push(filter);
      });
      return validFilters;
    };

    this.reset = function (projectData, updatedOptions) {
      project = projectData;
      if (!$.isEmptyObject(updatedOptions)) {
        delete updatedOptions.name;
        options = $.extend(options, updatedOptions);
        initialize(updatedOptions.selectedProperty);
      } else {
        initialize();
      }
    };

    this.isDisabled = function() {
      return self.htmlContainer.find('.disabled').length > 0;
    };

    this.isCardTypeSelected =  function() {
      return includeCardTypeFilter ? cardTypeFilter.isValid() : true;
    };

    this.getCardTypes = function() {
      return includeCardTypeFilter ? cardTypeFilter.value.value() : selectedCardTypes;
    };

    this.hide = function(){
      self.htmlContainer.parent().hide();
    };

    this.show = function(){
      self.htmlContainer.parent().show();
    };

    initialize();
  };
})(jQuery);
