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
MingleJavascript = {
  env: 'production',
  _actions: $A(),
  isInAjaxMode: false,
  
  register: function(action) {
    if(this.isInAjaxMode) {
      action.apply();
    } else {
      this._actions.push(action);
    }
  },
  
  onDomLoaded: function() {
    this.executeAll();
    this.isInAjaxMode = true;
  },
  
  executeAll: function() {
    // setTimeout( function(){
      while(this._actions.length > 0 ){
        this._actions.shift().apply();
      }
    // }.bind(this), 10);
  }
};

document.observe('dom:loaded', function() {
  MingleJavascript.onDomLoaded();
});