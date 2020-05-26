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
  var PARAMETER_DEFINITIONS = [
    {
      name: 'label',
      initial_value: 'Series 1',
      input_type: 'textbox',
      label: 'What is this series called?'
    }, {
      name: 'project',
      input_type: 'dropdown',
      initial_value: '',
      label: 'Which project does data for this series come from?',
      allowed_values: []
    },
    {
      name: 'filters',
      input_type: 'card-filters',
      label: 'Which cards make up the series data?',
      allowed_values: []
    },
    {
      name: 'tags-filter',
      input_type: 'tags-filter',
      label: 'Tagged with:'
    },
    {
      name: 'property',
      input_type: 'dropdown',
      initial_value: 'property 1',
      label: 'Which property should this series be based on?',
      allowed_values: []
    },
    {
      input_type: 'pair-parameter',
      label: 'What determines the actual height of the bars?',
      connecting_text: 'of',
      name: 'aggregate-pair',
      param_defs: [
        {
          name: 'aggregate',
          initial_value: 'count',
          allowed_values: [['Number of cards', 'count'], ['Sum', 'sum'], ['Average', 'avg']],
          multiple_values_allowed: false,
          input_type: 'dropdown'
        }, {
          name: 'aggregate-property',
          initial_value: null,
          allowed_values: [],
          multiple_values_allowed: false,
          input_type: 'dropdown'
        }
      ]
    },
    {
      name: 'group',
      label: 'Customize this series',
      labelDisplayProperty: 'bold',
      input_type: 'group-parameter',
      vertical: true,
      param_defs: [

        {
          name: 'series-type',
          input_type: 'dropdown',
          initial_value: 'Bar',
          allowed_values: [{text: 'Bar', value: 'Bar', styleClass: 'fa-bar-chart'},
            {text: 'Line', value: 'Line', styleClass: 'fa-line-chart'},
            {text: 'Area', value: 'Area', styleClass: 'fa-area-chart'}],
          label: 'Type of series',
          displayProperty: 'inline-parameter'
        },
        {
          name: 'combine',
          input_type: 'dropdown',
          initial_value: 'overlay-bottom',
          allowed_values: [['Overlay bottom', 'overlay-bottom'], ['Overlay top', 'overlay-top'], ['Total', 'total']],
          label: 'Combine',
          displayProperty: 'inline-parameter'
        },
        {
          name: 'color',
          input_type: 'color-picker',
          label: 'Color',
          initialColor: '',
          displayProperty: 'inline-parameter'
        }
      ]
    },{
      name: 'burn-down',
      input_type: 'single-checkbox',
      label: 'Make this a burn-down series',
      displayProperty:'inline-parameter'
    },
    {
      name: 'trend-line',
      label: '',
      input_type: 'trend-line-parameter',
      param_defs: [
        {
          name: 'trend-customization',
          label: '',
          input_type: 'group-parameter',
          vertical: true,
          displayProperty:'left-padded-parameter',
          param_defs: [

            {
              name: 'scope',
              input_type: 'dropdown',
              initial_value: 'All',
              allowed_values: ['All',2,3,4,5,6,7,8,9,10],
              label: 'Trend scope',
              displayProperty: 'inline-parameter'
            },
            {
              name: 'ignore',
              input_type: 'dropdown',
              initial_value: 'zeroes-at-end-and-last-value',
              allowed_values: [['None','none'], ['Zeroes at end','zeroes-at-end'], ['Zeroes at end and last value','zeroes-at-end-and-last-value']],
              label: 'Ignore',
              displayProperty: 'inline-parameter'
            },
            {
              name: 'style',
              input_type: 'dropdown',
              initial_value: 'Dash',
              allowed_values: [{text:'Solid',value:'solid', styleClass:'prepend-solid'}, {text:'Dashed',value:'dash', styleClass:'prepend-dashed'}],
              label: 'Style',
              displayProperty: 'inline-parameter'
            },
            {
              name: 'color',
              input_type: 'color-picker',
              label: 'Color',
              initialColor: '',
              displayProperty: 'inline-parameter'
            }
          ]
        }

      ]
    },
    {
      name: 'hidden',
      input_type: 'single-checkbox',
      label: 'Hide this series?',
      displayProperty: 'inline-parameter'
    }
  ], SERIES_TYPE_CUSTOMIZATION_PARAMETER = [
    {
      name: 'line-style',
      input_type: 'dropdown',
      initial_value: 'solid',
      allowed_values: [{text:'Solid',value:'solid', styleClass:'prepend-solid'}, {text:'Dashed',value:'dash', styleClass:'prepend-dashed'}],
      label: 'Style',
      displayProperty: 'inline-parameter'
    },
    {
      name: 'data-point-symbol',
      input_type: 'dropdown',
      initial_value: 'None',
      allowed_values: [
        {text: 'None', value: 'None'},
        {text: 'Circle', value: 'Circle',styleClass:'fa fa-circle'},
        {text: 'Diamond', value: 'Diamond',styleClass:'prepend-diamond'},
        {text: 'Square', value: 'Square', styleClass:'fa fa-square'}
      ],
      label: 'Datapoint',
      displayProperty: 'inline-parameter'
    },
    {
      name: 'data-labels',
      input_type: 'single-checkbox',
      label: 'Show datapoint labels',
      displayProperty: 'inline-parameter'
    }
  ];

  MingleUI.EasyCharts.Series = function (options, callBacks, isDeletable) {
    var self = this,
        onError = ensureFunction(callBacks.onError),
        onDelete = ensureFunction(callBacks.onDelete),
        onUpdate = ensureFunction(callBacks.onUpdate),
        seriesParameterUpdateHandlers = {project: projectUpdated, property: propertyUpdated, filters: filtersUpdated, seriesType: seriesTypeUpdated},
        wasValid = false,
        shouldContinueCallbackChain = true,
        currentSelectedPropertyDefinition = {},
        titleContainer,
        paramsContainer = $('<div>', {class: 'series-params-container'}),
        seriesTypeCustomizationParams,
        seriesTypeCustomizationContainer = $('<div>', {class: 'series-type-customization-params-container left-padded-parameter'}),
        config = options.config || {};
    self._values = {};

    function seriesTypeUpdated(target){
      if (shouldInitializeSeriesTypeCustomization())
        initSeriesTypeCustomizationParameter();
      else
        removeSeriesTypeCustomizationParameter();
    }

    function updateAggregateProperty() {
      var aggregateProperties = [];
      var cardTypes = self.params.filters.getCardTypes();
      Object.values(self.projectData.fetchCommonPropertyDefinitionDetails(cardTypes)).forEach(function (property) {
        property.isNumeric && aggregateProperties.push(property.name);
      });

      self.params.aggregatePair.setPairValues(aggregateProperties);
    }

    function aggregateUpdated(aggregateDropDown) {
      if (aggregateDropDown.value().toLowerCase() !== 'count') {
        self.params.aggregatePair.showPairParameter();
      }
      else
        self.params.aggregatePair.hidePairParameter();
    }

    var paramCustomizer = {label:labelParamCustomizer, project:projectParamCustomizer, group:groupParamCustomizer, color:colorParamCustomizer,aggregate:aggregateParamCustomizer,aggregateProperty:aggregatePropertyParamCustomizer};

    function projectParamCustomizer(paramDefinition,initiallySelectedProjectIdentifier){
      paramDefinition.initial_value = initiallySelectedProjectIdentifier;
      paramDefinition.allowed_values = MingleUI.EasyCharts.SectionHelpers.transformProjects(options.projectDataStore.accessibleProjects());
    }

    function aggregateParamCustomizer(paramDefinition){
      var prefix = self.name.replace(' ', '-');
      paramDefinition.name = prefix + "-" + paramDefinition.name;
      seriesParameterUpdateHandlers[paramDefinition.name.toCamelCase('-')] = aggregateUpdated;
    }

    function aggregatePropertyParamCustomizer(paramDefinition){
      var prefix = self.name.replace(' ', '-');
      paramDefinition.name = prefix + "-" + paramDefinition.name;
    }

    function groupParamCustomizer(paramDefinition){
      paramDefinition.name = paramDefinition.name + '-' + options.number;
    }

    function labelParamCustomizer(paramDefinition, _, __, initialLabel){
      paramDefinition.initial_value = initialLabel || self.name;
    }

    function colorParamCustomizer(paramDefinition, _, initialColor){
      paramDefinition.initialColor = initialColor || assignRandomColor(options.colors);
    }

    function customizeParameterDefinitions(paramDefinitions, config, initiallySelectedProjectIdentifier, initialColor, initialLabel){
      var requiredParamDefinitions = [];
      paramDefinitions.forEach(function(paramDefinition){
        var customizer = paramCustomizer[paramDefinition.name.toCamelCase('-')];
        var paramConfig = config[paramDefinition.name] || {} ;
        if(!config.hasOwnProperty(paramDefinition.name) || config[paramDefinition.name].isRequired ) {
          customizer && customizer(paramDefinition, initiallySelectedProjectIdentifier, initialColor, initialLabel);
          if(paramConfig.initialValue) paramDefinition.initial_value = paramConfig.initialValue ;
          $.extend(paramDefinition, paramConfig);
          if(paramDefinition.hasOwnProperty('param_defs'))
            paramDefinition.param_defs = customizeParameterDefinitions(paramDefinition.param_defs,(paramConfig.values || {}), initiallySelectedProjectIdentifier, initialColor, initialLabel);
          requiredParamDefinitions.push(paramDefinition );
        }
      });
      return requiredParamDefinitions;
    }

    function generateParamDefs(initiallySelectedProjectIdentifier, initialColor, initialLabel) {
      var paramDefinitions = JSON.parse(JSON.stringify(PARAMETER_DEFINITIONS));
      return customizeParameterDefinitions(paramDefinitions, config, initiallySelectedProjectIdentifier, initialColor, initialLabel);
    }

    function assignRandomColor(colors){
      return colors[Math.floor(Math.random()*colors.length)];
    }

    function validityChanged() {
      var validityHasChanged = (wasValid !== self.isValid());
      wasValid = self.isValid();
      return validityHasChanged;
    }

    function fetchCommonCardTypes(cardTypeNames, selectedCardTypeNames) {
      return cardTypeNames.filter(function (cardType) {
        return selectedCardTypeNames.include(cardType);
      });
    }

    function projectUpdated(project) {
      var projectIdentifier = project.value();
      shouldContinueCallbackChain = false;
      options.projectDataStore.dataFor(projectIdentifier, function(projectData) {
        self.projectData = projectData;
        var selectedCardTypeNames = options.cardFilters[0].values;
        var commonCardTypes  = fetchCommonCardTypes(self.projectData.cardTypeNames, selectedCardTypeNames);
        initSeriesParameters(projectIdentifier, commonCardTypes, self._values.color, self._values.label);
        if (commonCardTypes.empty()) {
          self.params.property.updateOptions([]);
          onError && onError(buildErrorMessage(self.projectData.name, "Filtered card type(s) '" + selectedCardTypeNames + "' don't exist."));
        } else {
          onUpdate && onUpdate(self);
        }
      });
    }

    function propertyUpdated(propertyParam) {
      currentSelectedPropertyDefinition = getPropertyDefinition(propertyParam.value());
    }

    function updateSelectedCardTypes() {
      self.selectedCardTypes = self.params.filters.getCardTypes();
      if (self.params.property) updatePropertyDropDown(self.params.filters.getCardTypes());
      delete self._values.property;
    }

    function filtersUpdated(_, cardTypesUpdated) {
      if (cardTypesUpdated && self.params.property) {
        updateSelectedCardTypes();
        updateAggregateProperty();
      }
    }

    function buildErrorMessage(projectName, errorMessage){
      return 'Error in macro using ' + projectName +' project: ' + errorMessage;
    }

    function invokeHandler(target){
      var handler = seriesParameterUpdateHandlers[target.name];
      if(handler) {
        handler.apply(self, arguments);
      }
    }

    function handleUpdate(target) {
      shouldContinueCallbackChain = true;
      if (target) {
        self._values[target.name] = target.value();
        invokeHandler.apply(self, arguments);
      }
      shouldContinueCallbackChain && (validityChanged() || self.isValid()) && onUpdate && onUpdate(self);
    }

    function getPropertyDefinition(propertyName, cardTypes) {
      var cardType = self.projectData.cardTypes[(cardTypes || self.params.filters.getCardTypes())[0]];

      return cardType ? cardType.propertyDefinitions[propertyName] : {};
    }

    function initialize() {
      self.projectData = options.projectDataStore.dataFor(options.currentProject);
      self.name = 'Series ' + options.number;
      self.htmlContainer = $('<div>', {id: self.name.toSnakeCase(), class: 'series'});

      titleContainer = $('<div>', {class: 'series-title-container'});
      var title = $('<span>', {class: 'series-title', text: self.name});
      titleContainer.append(title);
      self.htmlContainer.append(titleContainer);
      var selectedCardTypes = options.cardFilters[0].values;
      currentSelectedPropertyDefinition = getPropertyDefinition(options.property, selectedCardTypes);
      if (isDeletable) self.addDeleteButton();
      initSeriesParameters(options.currentProject, selectedCardTypes);
    }

    function shouldInitializeSeriesTypeCustomization() {
      var seriesType = self.params['group' + options.number ].value().seriesType || '';
      return seriesType.match(/Line|Area/) && config.enableSeriesTypeCustomization;
    }

    function initSeriesParameters(projectIdentifier, allowedCardTypes, initialColor, initialLabel) {
      paramsContainer.empty();

      self.params = MingleUI.EasyCharts.SectionHelpers.addParameters.call(self, generateParamDefs(projectIdentifier, initialColor, initialLabel), {
        projectData: self.projectData,
        onUpdate: handleUpdate,
        sectionName: self.name,
        paramsContainer: paramsContainer,
        initialData: {
          filters: options.cardFilters
        },
        allowedCardTypes: allowedCardTypes
      });
      updateSelectedCardTypes();
      if (self.params.aggregatePair) updateAggregateProperty();
      if (self.params.aggregatePair && !self.params.aggregatePair.isValid()) self.params.aggregatePair.hidePairParameter();
      initializeParamValues();
      if(shouldInitializeSeriesTypeCustomization())
          initSeriesTypeCustomizationParameter();
      if (isDeletable) self.addDeleteButton();
    }

    function initializeParamValues() {
      for (var param in self.params) {
        var target = self.params[param];
        if (!target.name.match(/group\d+|aggregate-pair/))
          self._values[target.name] = target.value();
        else
          self._values = $.extend(self._values, target.value());
      }
    }

    function removeSeriesTypeCustomizationParameter() {
      self._values.lineStyle = null;
      delete self.params.lineStyle;
      seriesTypeCustomizationContainer.empty();
      seriesTypeCustomizationContainer.remove();
    }

    function getSeriesTypeCustomizationParameters() {
      var seriesTypeCustomizationParameters = SERIES_TYPE_CUSTOMIZATION_PARAMETER;
      if (self._values.seriesType === 'Area')
        seriesTypeCustomizationParameters = SERIES_TYPE_CUSTOMIZATION_PARAMETER.slice(1);
      return seriesTypeCustomizationParameters;
    }

    function initSeriesTypeCustomizationParameter() {
      removeSeriesTypeCustomizationParameter();
      seriesTypeCustomizationParams = MingleUI.EasyCharts.SectionHelpers.addParameters.call({
        name: self.name,
        htmlContainer: seriesTypeCustomizationContainer
      }, getSeriesTypeCustomizationParameters(), {
        projectData: self.projectData,
        onUpdate: handleUpdate,
        sectionName: 'series-type-customization'
      });
      self.params['group' + options.number].htmlContainer.find('#group' + options.number + '_series_type_parameter').after(seriesTypeCustomizationContainer);
      $j.extend(self.params,seriesTypeCustomizationParams);
      initializeParamValues();
    }


    this.addDeleteButton = function () {
      var removeIcon = $('<span>', {class: 'delete-series-icon'}).on('click',function(){
        self.htmlContainer.remove();
        onDelete && onDelete(self);
      });

      var removeSeries = $('<span>', {class: 'delete-series'});
      removeSeries.append(removeIcon).append($('<span>', { class:'delete-series-text', text:'Delete series' }));

      if(titleContainer.find('.delete-series').length < 1)
        titleContainer.append(removeSeries);
    };

    this.removeDeleteButton = function (){
      titleContainer.find('.delete-series').remove();
    };

    function updatePropertyDropDown(selectedCardTypes) {
      selectedCardTypes = selectedCardTypes || self.selectedCardTypes;
      self.projectData.getCommonHomogeneousProperties(selectedCardTypes, currentSelectedPropertyDefinition, function (values) {
        self.params.property.updateOptions(values.map(function (val) {
          return val.name;
        }));
      });
      self._values.property = self.params.property.value();
    }

    initialize();

    this.isValid = function () {
      if (self.params.property || self.params.aggregatePair) {
        return !!self._values.property && self.params.aggregatePair.isValid() ;
      }
      return true;
    };

    this.updateProperty = function (selectedProperty) {
      currentSelectedPropertyDefinition = getPropertyDefinition(selectedProperty);
      updatePropertyDropDown();
    };

    this.value = function () {
      if (self._values.project === options.currentProject) delete self._values.project;
      return self._values;
    };
  };
})(jQuery);

