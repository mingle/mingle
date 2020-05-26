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
AlsoViewing.Poller = Class.create({
  initialize: function() {
    this.options = this.getOptions();
  },

  start: function() {
    if (this.timerId || AlsoViewing.INTERVAL < 1) { return; }
    var doPoll = this.poll.bind(this);
    doPoll();
    this.timerId = setInterval(doPoll, AlsoViewing.INTERVAL * 1000);
  },

  stop: function() {
    if (this.timerId) {
      clearInterval(this.timerId);
      this.timerId = null;
    }
  },

  poll: function() {
    new Ajax.Request((AlsoViewing.CONTEXT_PATH || '') + "/also_viewing", this.options);
  },

  getOptions: function() {
    var queryParams = { currentUser: AlsoViewing.CurrentUser(), url: AlsoViewing.CurrentPath(), bypassMingleAjaxErrorHandler: true, format: 'json' };
    return { parameters: queryParams, onSuccess: this.onSuccess, onFailure: this.onFailure.bind(this) };
  },

  onFailure: function(xhr) {
    this.stop();
  },

  onSuccess: function(xhr) {
    $('notification').fire("AlsoViewing:update", xhr.responseJSON);
  }
});

AlsoViewing.CurrentUser = function () {
  return $$('#current-user span')[0] ? $$('#current-user span')[0].getText() : "Anonymous";
};

AlsoViewing.CurrentPath = function () {
  return window.location.pathname;
};
