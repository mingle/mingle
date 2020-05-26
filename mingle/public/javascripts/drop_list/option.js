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
DropList.Option = Class.create({
  initialize: function(name, value, tooltip, icon) {
    this.name = name;
    if(value == null || value == undefined) {
      this.value = "";
    } else {
      this.value = value;
    }
    this.tooltip = tooltip || name;
    this.hidden = false;
    this.icon = icon;
  },

  appendTo: function(parent) {
    if (this.icon) {
      parent.appendChild(this._createAvatar());
    }
    var text = new Element('text');
    text.update(this.name.escapeHTML());
    parent.appendChild(text);
  },

  toggle: function() {
    if(this.hidden){
      this.element.hide();
    } else {
      this.element.show();
    }
  },

  show: function() {
    this.hidden = false;
  },

  hide: function() {
    this.hidden = true;
  },

  filter: function(token) {
    var matched = this.name.toLowerCase().indexOf(token.toLowerCase());
    if(token.length != 0) {
      if(matched == -1){
        this.hidden = true;
      }else{
        this.hidden = false;
        this._highlight(token);
      }
    } else {
      this.reset();
    }
  },

  reset: function(){
    this.hidden = false;
    this._updateText(this.name.escapeHTML());
  },

  _highlight: function(token) {
    var value = this.name;
    var startPosition = value.toLowerCase().indexOf(token.toLowerCase());
    var endPosition = startPosition + token.length;
    var pre = value.substring(0, startPosition);
    var matched = value.substring(startPosition, endPosition);
    var post = value.substring(endPosition, value.length);
    this._updateText(pre.escapeHTML() + '<strong>' + matched.escapeHTML() + '</strong>' + post.escapeHTML());
  },

  _updateText: function(text) {
    this.element && this.element.select('text')[0].update(text);
  },

  _createAvatar: function() {
    return new Element('img', {class: 'avatar',
                               src: this.icon['src'],
                               style: 'background-color: ' + this.icon['color']});
  }
});
