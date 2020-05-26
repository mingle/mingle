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
MingleUI.EasyCharts.DailyHistoryChart = (MingleUI.EasyCharts.DailyHistoryChart || {});
MingleUI.EasyCharts.DailyHistoryChart.Sections = (MingleUI.EasyCharts.DailyHistoryChart.Sections || {});

(function ($) {

  MingleUI.EasyCharts.DailyHistoryChart.Sections.DataSection = function (sectionName, projectDataStore, data, options) {
    var dataSectionConfig = {
      config: {
        'project': {isRequired: false},
        'tags-filter': {isRequired: false}
      },
      disableProjectVariables: true,
      propertyDefinitionFilters: ['aggregate']
    };
    MingleUI.EasyCharts.Sections.DataSection.call(this, sectionName, projectDataStore, data, $.extend(options, dataSectionConfig));
  };
})(jQuery);
