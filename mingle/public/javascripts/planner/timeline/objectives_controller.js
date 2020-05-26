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
ObjectivesController = {
  update: function(objective) {
    var obj = {
      'objective[name]': objective.name,
      'objective[start_at]': objective.startDate,
      'objective[end_at]': objective.endDate,
      'objective[vertical_position]': objective.verticalPosition
    };
    $j.ajax({
      url: this.objectiveUrl(objective.urlIdentifier),
      type: "PUT",
      dataType: 'script',
      data: obj
    });
  },

  alert_details: function(objective, onSuccess) {
    $j.ajax({
      url: this.objectiveDetailUrl(objective.urlIdentifier) + "?alert_only=true",
      type: "GET",
      dataType: 'script',
      success: onSuccess
    });
  },

  details: function(objective, onSuccess) {
    $j.ajax({
      url: this.objectiveDetailUrl(objective.urlIdentifier),
      type: "GET",
      dataType: 'script',
      success: onSuccess
    });
  },

  objectiveUrl: function(objectiveIdentifier) {
    return ObjectivesController.objectivesUrl + '/' + objectiveIdentifier;
  },

  objectiveDetailUrl: function(objectiveIdentifier) {
    return ObjectivesController.objectiveUrl(objectiveIdentifier) + '/popup_details';
  },

  worksUrl: function(objectiveIdentifier) {
    return ObjectivesController.objectiveUrl(objectiveIdentifier) + '/work';
  },

  addWorkUrl: function(objectiveIdentifier) {
    return ObjectivesController.worksUrl(objectiveIdentifier) + '/cards';
  },

  workProgress: function(objectiveIdentifier, projectId, onSuccess) {
    var workProgressUrl = this.objectiveUrl(objectiveIdentifier) + '/work_progress?project_id=' + projectId;
    $j.ajax({
      url: workProgressUrl,
      type: "GET",
      dataType: "json",
      success: onSuccess
    });
  },

  timelineObjective: function(objective, onSuccess) {
    var workProgressUrl = this.objectiveUrl(objective.urlIdentifier) + '/timeline_objective';
    $j.ajax({
      url: workProgressUrl,
      type: "GET",
      dataType: "json",
      success: onSuccess
    });
  }
};

