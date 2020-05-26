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

function ActionTrackerClass() {
  var MACRO_CREATED_DATA_KEY = 'macro_created_events';

  function eventName(macroType, action) {
    return 'easy_charts_{macroType}_{action}'.supplant({
      macroType: macroType.toSnakeCase(),
      action: action
    });
  }

  function findEventDataElement() {
    if ($j('#content-panel-container').length > 0)
      return $j('#content-panel-container');
    else if ($j('.card-content-container').length > 0)
      return $j('.card-content-container');
    else if ($j('.edit-card-defaults').length > 0)
      return $j('.edit-card-defaults');
    else if ($j('#card-description').length > 0)
      return $j('#card-description');
    return null;
  }
  function recordCreateEvent(macroType, createdUsingMqlEditor) {
    var element = findEventDataElement();
    if (!element) return;

    var macroCreatedEvents = element.data(MACRO_CREATED_DATA_KEY) || [];
    macroCreatedEvents.push([macroType, createdUsingMqlEditor]);
    element.data(MACRO_CREATED_DATA_KEY, macroCreatedEvents);
  }

  function postCreateEvent() {
    var element = findEventDataElement();
    if (!element) return;

    var macroCreatedEvents = element.data(MACRO_CREATED_DATA_KEY) || [];

    macroCreatedEvents.each(function (eventDetails) {
      mixpanelTrack(eventName(eventDetails[0], 'created'), {
        project_name: $j('#header .header-name').text(),
        created_using_mql_editor: eventDetails[1]
      });
    });
  }

  function resetRecordedEvents() {
    $j('#content-panel-container').data(MACRO_CREATED_DATA_KEY, []);
    $j('.card-content-container').data(MACRO_CREATED_DATA_KEY, []);
    $j('.edit-card-defaults').data(MACRO_CREATED_DATA_KEY, []);
  }

  function postClickedEvent(macroType) {
    mixpanelTrack(eventName(macroType, 'clicked'), {
      project_name: $j('#header .header-name').text()
    });
  }

  return {
    recordCreateEvent: recordCreateEvent,
    postCreateEvents: postCreateEvent,
    resetRecordedEvents: resetRecordedEvents,
    postClickedEvent: postClickedEvent
  };
}

MingleUI.EasyCharts.ActionTracker = new ActionTrackerClass();