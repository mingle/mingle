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
var TimelineStatus = Class.create({
  initialize: function() {
    this.actions = ['not-ready'];
  },

  isReady: function() {
    return this.actions.length == 0;
  },

  start: function(action) {
    if (this.actions[0] == 'not-ready') {
	  this.actions.pop();
	}
	
	if (this.actions[action]) {
      this.actions[action] += 1;
    } else {
      this.actions[action] = 1;
    }
  },
  
  end: function(action) {
    if (!this.actions[action]) {
		return;
	}
	
	this.actions[action] -= 1;
	if (this.actions[action] == 0) {
		var index = this.actions.indexOf(action);
		if (index >= 0) {
			this.actions.splice(index, 1);
		}
	}
  },
  
  // scrolling is started many times for each stop, so to keep it simple we can just cancel all of them
  endAll: function(action) {
    this.actions = this.actions.without(action);
  }
});

TimelineStatus.instance = new TimelineStatus();
