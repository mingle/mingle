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
MingleUI.EasyCharts.Sections = (MingleUI.EasyCharts.Sections || {});

var PARAMETER_DEFINITIONS = [{
  name: 'project',
  allowed_values: [],
  multiple_values_allowed: false,
  input_type: 'dropdown',
  label: 'Which project should the chart data come from?'
}, {
  name: 'card-filters',
  input_type: 'card-filters',
  label: 'Which cards make up the chart data?'
}, {
  name: 'tags-filter',
  input_type: 'tags-filter',
  label: 'Tagged with:'
}];

MingleUI.EasyCharts.Sections.DataSection = function (sectionName, projectDataStore, data, options) {
  var initialProject = data.initialProject, projectData,
      self = this, params = {}, onUpdate = ensureFunction(options.onUpdate), buildChartButton,
      updateHandlers = {project: projectUpdated, cardFilters: cardFiltersUpdated, tagsFilter: tagsFilterUpdated}, oldCardTypes = [],
      buildChartCallback = ensureFunction(options.onComplete),
      filtered_params = PARAMETER_DEFINITIONS;
      options = options || {};

      if (!$j.isEmptyObject(options.config)) {
        filtered_params = PARAMETER_DEFINITIONS.reject(function(param) {
          return options.config[param.name] && !options.config[param.name].isRequired;
        });
      }

  function resetFilters(_projectData) {
    projectData = _projectData;
    if (params.cardFilters) params.cardFilters.reset(projectData);
    if (params.tagsFilter) params.tagsFilter.reset(projectData);
    onUpdate && onUpdate(self, {targetType: 'project', target: params.project});
  }

  function initBuildChartSection() {
    removeBuildChartButton();
    buildChartCallback(projectData, params.cardFilters.getCardTypes(), { filters: params.cardFilters.value(), tags: valueOrDefault('tagsFilter', []) });
  }

  function addBuildChartButton() {
    if (buildChartButton) return;

    buildChartButton = $j('<button>', {text: 'Proceed to Step 2'});
    buildChartButton.on('click', initBuildChartSection.bind(self));
    self.htmlContainer.append(buildChartButton);
  }

  function removeBuildChartButton() {
    buildChartButton && buildChartButton.remove();
    buildChartButton = undefined;
  }

  function projectUpdated() {
    removeBuildChartButton();
    projectDataStore.dataFor(params.project.value(), resetFilters);
  }

  function cardFiltersUpdated() {
    var updateParams;
    updateParams = {targetType: 'cardFilters', target: params.cardFilters};
    onUpdate && onUpdate(self, updateParams);
  }

  function tagsFilterUpdated() {
    var updateParams;
    updateParams = {targetType: 'tagsFilter', target: params.tagsFilter};
    onUpdate && onUpdate(self, updateParams);
  }

  function showBuildChartButtonIfRequired() {
    if (self.isValid()) {
      if (!(params.cardFilters.getCardTypes().equals(oldCardTypes))) {
        oldCardTypes = params.cardFilters.getCardTypes();
        addBuildChartButton();
      }
    } else {
      oldCardTypes = params.cardFilters.getCardTypes();
      removeBuildChartButton();
    }
  }
  function handleUpdate(updatedParam, data) {
    var updateHandler;
    var updatedParamName = updatedParam ? updatedParam.name : "cardFilters" ;
    updateHandler = updateHandlers[updatedParamName];
    updateHandler(data);
    showBuildChartButtonIfRequired();
  }

  function updateProjectDropDown(projects) {
    var projectOptions = projects.collect(function (projectData) {
      return [projectData.name, projectData.identifier];
    });
    params.project.updateOptions(projectOptions, data.project);
  }

  function initialize(_projectData) {
    projectData = _projectData;
    self.name = sectionName;
    self.htmlContainer = $j('<div>', {id: self.name.toSnakeCase(), class: 'data-section chart-form-section'});
    MingleUI.EasyCharts.SectionHelpers.addTitle.call(self, 1, 'Select data for the chart');
    params = MingleUI.EasyCharts.SectionHelpers.addParameters.call(self, filtered_params, {
      projectData: projectData,
      initialData: data,
      onUpdate: handleUpdate,
      enableThisCardOption: true,
      disableProjectVariables: options.disableProjectVariables,
      propertyDefinitionFilters: options.propertyDefinitionFilters
    });

    if (params.project) projectDataStore.accessibleProjects(updateProjectDropDown);
    oldCardTypes = params.cardFilters.getCardTypes();
    self.isValid() && buildChartCallback(projectData, params.cardFilters.getCardTypes());
  }

  this.isValid = function () {
    return params.cardFilters.isCardTypeSelected();
  };

  this.values = function () {
    var values = {
      tags: valueOrDefault('tagsFilter', []),
      cardFilters: valueOrDefault('cardFilters')
    };
    var projectVal = valueOrDefault('project', initialProject);
    if(initialProject !== projectVal)
      values.project = params.project.value();
    return values;
  };

  this.selectedCardTypes = function () {
    return params.cardFilters.getCardTypes();
  };

  function valueOrDefault(paramName, defaultValue) {
    return params[paramName] ? params[paramName].value() : defaultValue;
  }
  projectDataStore.dataFor(data.project, initialize);
};
