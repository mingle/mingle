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
ParamsController = {
  update: function(params) {
    this.listeners().values().each(function(listener) {
      listener.update(params);
    });
  },
  
  register: function(listener) {
    var previousListener = this.listeners().get(listener.listenerKey());
    if(previousListener) { previousListener.destroy(); }
    this.listeners().set(listener.listenerKey(), listener);
  },
  
  listeners: function() {
    if(!this._listeners) {
      this._listeners = $H();
    }
    return this._listeners;
  }
};

