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
AlsoViewing = {};
AlsoViewing.Updater = Class.create({
  
  initialize: function() {
    this.effectDuration = MingleJavascript.env == "test" ? 0 : 1;
    this.notificationElement = $('notification');
    Event.observe(this.notificationElement, "AlsoViewing:update", this.update.bindAsEventListener(this));
  },
  
  update: function(event) {
    this._update(event.memo.viewers, event.memo.editors);
  },

  _update: function(viewers, editors) {
    if (viewers.empty() && editors.empty()) {
      this.hide();
    } else {
      this.show(viewers, editors);
    }
  },
  
  hide: function() {
    if (this.notificationElement.visible()) {
      this.notificationElement.fade({duration:this.effectDuration, afterFinish:this.finished.bind(this)});
    }
  },
  
  show: function(viewers, editors) {
    this.notificationElement.update(this.messageTemplate(viewers, "viewing") + this.messageTemplate(editors, "<b>editing</b>")).appear({duration:this.effectDuration});
  },
  
  finished: function() {
    this.notificationElement.update(" ");
  },
  
  messageTemplate: function(users, action) {
    if (users.empty()) { return ""; }
    var prefix = null;
    if (users.size() == 1) {
      prefix = users[0] + ' is ';
    } else if (users.size() < 4) {
      var lastUser = users.pop();
      prefix = users.join(', ') + " and " + lastUser + ' are ';
    } else if(users.size() == 4) {
      prefix = users.splice(0, 3).join(', ') + " and 1 other user is ";
    } else if(users.size() > 4) {
      prefix = users.splice(0, 3).join(', ') + " and " + (users.size()) + ' other users are ';
    }
    return prefix + action + ' this page. ';
  }
});