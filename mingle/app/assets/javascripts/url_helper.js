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
var UrlHelper = {}, AbsoluteUrlHelper = {};


function apiUrlFor(url, format) {
  format = format || 'xml';
  return '/api/v2' + url + '.' + format;
}

UrlHelper.projectsUrl = function () {
  return  '/projects';
};

UrlHelper.projectsJsonUrl = function () {
  return apiUrlFor(UrlHelper.projectsUrl(), 'json');
};

UrlHelper.projectUrl = function (projectIdentifier) {
  return  UrlHelper.projectsUrl() + '/' + projectIdentifier;
};

UrlHelper.macroPreviewUrl = function (projectIdentifier) {
  return UrlHelper.projectUrl(projectIdentifier) + '/macro_editor/preview';
};

UrlHelper.cardTypesUrl = function (projectIdentifier) {
  return UrlHelper.projectUrl(projectIdentifier) + '/card_types';
};

UrlHelper.cardTypesJsonUrl = function (projectIdentifier) {
  return apiUrlFor(UrlHelper.cardTypesUrl(projectIdentifier), 'json');
};

UrlHelper.cardTypeJsonUrl = function (projectIdentifier, cardTypeId) {
  return apiUrlFor(UrlHelper.cardTypesUrl(projectIdentifier) + '/' + cardTypeId, 'json');
};

UrlHelper.showUserSelectorUrl = function (projectIdentifier) {
  return UrlHelper.projectUrl(projectIdentifier) + '/team/show_user_selector';
};

UrlHelper.showCardSelectorUrl = function (projectIdentifier) {
  return UrlHelper.projectUrl(projectIdentifier) + '/card_explorer/show_card_selector';
};

UrlHelper.tagsJsonUrl = function (projectIdentifier) {
  return apiUrlFor(UrlHelper.projectUrl(projectIdentifier) + '/tags', 'json');
};

UrlHelper.cardsUrl = function (projectIdentifier) {
  return UrlHelper.projectUrl(projectIdentifier) + '/cards';
};

UrlHelper.executeMqlJsonUrl = function (projectIdentifier) {
  return apiUrlFor(UrlHelper.cardsUrl(projectIdentifier) + '/execute_mql', 'json');
};

UrlHelper.propertyDefinitionsValuesUrl = function (projectIdentifier, propertyDefinitionsId) {
  return apiUrlFor(UrlHelper.projectUrl(projectIdentifier) + '/property_definitions/values/' +propertyDefinitionsId, 'json');
};

UrlHelper.chartDataJsonUrl = function (projectIdentifier) {
  return apiUrlFor(UrlHelper.projectUrl(projectIdentifier) + '/chart_data', 'json');
};

function getOrigin() {
  return '{0}//{1}'.supplant([window.location.protocol, window.location.host]);
}


AbsoluteUrlHelper.sectorUrl = function(projectIdentifier, sectorMql) {
  return getOrigin() + UrlHelper.projectUrl(projectIdentifier) + "/cards/list?filters[mql]=" + encodeURIComponent(sectorMql);
};