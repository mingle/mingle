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
var ProjectDataStore;
(function ($) {
  var ajaxCallCount = 0, ajaxStopCallback, ajaxStopCallbackEnabled;

  function completeCallback() {
    ajaxCallCount--;
    if (ajaxCallCount <= 0 && ajaxStopCallbackEnabled && ajaxStopCallback) ajaxStopCallback();
  }

  function beforeSendCallback() {
    ajaxCallCount++;
  }

  function ProjectData(initialData) {
    var self = this;
    function indexByName(data, transformation) {
      return data.reduce(function (obj, datum) {
        var processedDatum = (transformation && transformation(datum) || datum);
        obj[datum.name] = processedDatum;
        return obj;
      }, {});
    }

    function processData(data) {
      return indexByName(data, function (cardType) {
        var _cardType = $.extend(true, {}, cardType);
        _cardType.propertyDefinitions = indexByName(_cardType.propertyDefinitions);
        return _cardType;
      });
    }

    function initialize() {
      self.identifier = initialData.identifier;
      self.name = initialData.name;
      self.mqlData = {};
      self.propDefsValues = {};
      self.dateFormat = initialData.dateFormat;
      self.cardTypes = processData(initialData.cardTypes || []);
      self.cardTypeNames = Object.keys(self.cardTypes);
      self.tags = initialData.tags || [];
      self.team = initialData.team.reduce(function (team, teamMember) {
        team[teamMember.login] = teamMember;
        return team;
      },{}) || {};
      self.colors = initialData.colors || [];
    }

    function fetchCardTypeDetails(cardTypeName) {
      var cardType = self.cardTypes[cardTypeName];
      if (!cardType) return false;
      var propertyDefinition = Object.values(cardType.propertyDefinitions)[0];
      if (propertyDefinition && !propertyDefinition.operatorOptions) {
        return $.ajax({
          type: 'GET',
          url: UrlHelper.cardTypeJsonUrl(self.identifier, cardType.id),
          data: {include_property_values: true},
          success: function (data) {
            data.propertyDefinitions = indexByName(data.propertyDefinitions);
            self.cardTypes[cardTypeName] = data;
          },
          beforeSend: beforeSendCallback,
          complete: completeCallback
        });
      }
      return  $.Deferred().resolve();
    }

    function fetchPropertyDefinitionDetails(cardTypes, callback) {
      $.when.apply($, cardTypes.collect(fetchCardTypeDetails)).done(function () {
        callback && callback(commonPropertyDefinitions(cardTypes));
      });
    }

    function commonPropertyDefinitions(selectedCardTypes, property) {
      if (selectedCardTypes.empty())
        return {};
      var allCommonProperties = selectedCardTypes.reduce(function (propertyDefinitions, cardTypeName) {
        var cardTypeParameterDefs = self.cardTypes[cardTypeName].propertyDefinitions;
        var commonProperties = {};
        for (var propertyDef in propertyDefinitions) {
          if (cardTypeParameterDefs.hasOwnProperty(propertyDef))
            commonProperties[propertyDef] = propertyDefinitions[propertyDef];
        }
        return commonProperties;
      }, self.cardTypes[selectedCardTypes[0]].propertyDefinitions);

      var propertyDefinitions = {};
      propertyDefinitions[property] = allCommonProperties[property];
      return property ? propertyDefinitions : allCommonProperties;
    }

    this.fetchCommonPropertyDefinitionDetails = function (selectedCardTypeNames, receiver) {
      if (typeof receiver === 'function')
        fetchPropertyDefinitionDetails(selectedCardTypeNames, receiver);
      else
        return commonPropertyDefinitions(selectedCardTypeNames, receiver);
    };

    this.getDisplayNameFor = function (memberLogin) {
      var member = self.team[memberLogin];
      return member ? member.name : memberLogin ;
    } ;

    this.getCommonHomogeneousProperties = function (selectedCardTypeNames, selectedPropertyDefinition, callBack) {
      fetchPropertyDefinitionDetails(selectedCardTypeNames, function(propertyDefinitions) {
        var propertyType = selectedPropertyDefinition ? selectedPropertyDefinition.dataType : '';
        var filteredPropertyDefinitions = Object.keys(propertyDefinitions).reduce(function (_propertyDefinitions, propertyDef) {
          if (propertyDefinitions[propertyDef].dataType === propertyType)
            _propertyDefinitions.push(propertyDefinitions[propertyDef]);
          return _propertyDefinitions;
        }, []);
        callBack(filteredPropertyDefinitions);
      });
    };

    this.executeMql = function (mql, callback) {
      if (self.mqlData[mql]) {
        callback(self.mqlData[mql]);
      } else {
        $.ajax({
          method: 'GET',
          url: UrlHelper.executeMqlJsonUrl(self.identifier),
          data: {mql: mql}
        }).done(function (data) {
          self.mqlData[mql] = data;
          callback(data);
        }).fail(function (error) {
          console.log("Error executing mql:", error);
        });
      }
    };

    this.propertyDefinitionValues = function (propertyDefinitionId, callback) {
      if (self.propDefsValues[propertyDefinitionId]) {
        callback(self.propDefsValues[propertyDefinitionId]);
      } else {
        $.ajax({
          method: 'GET',
          url: UrlHelper.propertyDefinitionsValuesUrl(self.identifier, propertyDefinitionId)
        }).done(function (data) {
          self.propDefsValues[propertyDefinitionId] = data.values;
          callback(data.values);
        }).fail(function (error) {
          console.log("Error fetching  property values:", error);
        });
      }
    };

    initialize();
  }

  ProjectDataStore = function() {
    var dataStore = {}, _accessibleProjects=[], initialProjectData = Array.prototype.slice.call(arguments);

    function initialize() {
      if(initialProjectData.length > 0) {
        initialProjectData.forEach(function(projectDatum) {
          dataStore[projectDatum.identifier] = new ProjectData(projectDatum);
        });
      }
    }

    function fetchProjectData(projectIdentifier, callback) {
      if (dataStore[projectIdentifier])
        callback(dataStore[projectIdentifier]);
      else {
        $.ajax({
          type: 'GET',
          url: UrlHelper.chartDataJsonUrl(projectIdentifier),
          beforeSend: beforeSendCallback,
          complete: completeCallback,
          success: function (data) {
            dataStore[projectIdentifier] = new ProjectData(data);
            callback(dataStore[projectIdentifier]);
          }
        });
      }
    }

    this.dataFor = function (projectIdentifier, callback) {
      if (typeof callback === 'function')
        fetchProjectData(projectIdentifier, callback);
      else
        return dataStore[projectIdentifier];
    };

    function fetchAccessibleProjects(callback) {
      if (_accessibleProjects.empty()) {
        $.ajax({
          type: 'GET',
          url: UrlHelper.projectsJsonUrl(),
          data: {exclude_requestable: true},
          beforeSend: beforeSendCallback,
          complete: completeCallback
        }).done(function (projects) {
          _accessibleProjects = projects;
          callback(projects);
        });
      } else {
        callback(_accessibleProjects);
      }
    }

    this.accessibleProjects = function (callback) {
      if (typeof callback === 'function') {
        fetchAccessibleProjects(callback);
      } else {
        return _accessibleProjects;
      }
    };
    initialize();
  };

  ProjectDataStore.setAjaxStopCallback = function (callback) {
    ajaxStopCallback = callback;
    ProjectDataStore.enableGlobalCallbacks();
  };

  ProjectDataStore.enableGlobalCallbacks = function () {
    ajaxStopCallbackEnabled = true;
  };

  ProjectDataStore.disableGlobalCallbacks = function () {
    ajaxStopCallbackEnabled = false;
  };
})(jQuery);