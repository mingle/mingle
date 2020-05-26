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
var MingleUI = (window.MingleUI || {});
(function() {
  function d(message) {
    (console && "function" === typeof console.log) && console.log(message);
  }

  function LocallyGeneratedEvents() {
    var seen = [];
    this.upperRetain = 500, this.lowerRetain = 250;

    function pluck(array, property) {
      var result = [];
      for (var i = 0, len = array.length; i < len; i++) {
        result.push(array[i][property]);
      }
      return result;
    }

    function comparator(a, b) {
      return a.event - b.event;
    }

    this.seen = function() {
      return seen.sort(comparator);
    };

    this.latest = function() {
      return this.seen()[seen.length - 1].event;
    };

    this.reset = function(initial) {
      d("resetting event tracking with initial event: " + initial);
      seen = [];

      if ("undefined" !== typeof initial) {
        this.markAsViewed(initial, "initial");
      }
    };

    this.markAsViewed = function(eventId, destination) {
      var i = "number" === typeof eventId ? eventId : parseInt(eventId, 10);
      destination = "undefined" === typeof destination ? null : destination;

      if (isNaN(i)) {
        d("Event ID \"" + eventId + "\" is invalid.");
        return;
      }

      d("Marking event " + i + " as viewed.");
      seen.push({event: i, dest: destination});
      if (seen.length > this.upperRetain) {
        // truncate to the last 250, but allow growth to 500 events
        // so we have an adequate buffer, yet we don't clean up all
        // the time
        seen = this.seen().slice(seen.length - this.lowerRetain, seen.length);
      }
    };

    this.hasSeen = function(eventId) {
      var i = "number" === typeof eventId ? eventId : parseInt(eventId, 10);

      if (isNaN(i)) {
        d("Event ID \"" + eventId + "\" is invalid.");
        return false;
      }
      return !!~pluck(seen, "event").indexOf(i);
    };
  }

  MingleUI.events = new LocallyGeneratedEvents();
})();
