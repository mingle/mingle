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
DropList.View.Layout = {
  fix: function() {
    $$('.properties_widget').each(DropList.View.Layout.fixSingleDiv);
  },

  refix: function(){
    this._cleanHeight();
    this.fix();
  },

  _cleanHeight: function(){
    $$('.properties_widget').each(function(widget){
      widget._droplist_layout_fixed = false;
      widget.select('.drop-list-panel').each(function(panel){
        panel.style.height = '';
      });
    });
  },

  fixSingleDiv: function(div) {
    if(div._droplist_layout_fixed) {return;}
    var dropListPanels = $(div).select('.drop-list-panel');
    var maxHeight = dropListPanels.max(Element.getHeight);
    if(maxHeight == 0) {return;}
    dropListPanels.each(function(panel) {
      var layoutOffset = 5;
      panel.style.height = maxHeight + layoutOffset + 'px';
    });
    div._droplist_layout_fixed = true;
  }
};
