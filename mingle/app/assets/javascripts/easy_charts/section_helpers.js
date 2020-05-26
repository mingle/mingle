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

MingleUI.EasyCharts.SectionHelpers = {
  addTitle: function (number, titleText) {
    var titleContainer = $j('<div>', {class: 'section-title-container'}),
        sectionNumber = $j('<span>', {class: 'section-number', text: number}),
        title = $j('<span>', {class: 'section-title', text: titleText});

    titleContainer.append(sectionNumber, title);
    this.htmlContainer.append(titleContainer);
  },
  addParameters: function (parameterDefinitions, options) {
    var params = {}, paramsContainer = options.paramsContainer  || $j('<div>', {class: 'section-params-container'});
    parameterDefinitions.each(function (paramDef) {
      var parameter = new MingleUI.EasyCharts.Parameter(this.name.toSnakeCase(), paramDef, options);
      params[parameter.name] = parameter.param;
      paramsContainer.append(parameter.htmlContainer);
    }.bind(this));
    this.htmlContainer.append(paramsContainer);
    return params;
  },
  getInitialData: function (sectionData) {
    var _initialData = $j .extend({}, sectionData.initialData);
    for(var paramName in _initialData) {
      if (!sectionData.paramNames.include(paramName))
        delete _initialData[paramName];
    }
    return _initialData;
  },
  transformProjects:  function (projects) {
    return (projects || []).map(function (project) {
      return [project.name, project.identifier];
    });
  }
};