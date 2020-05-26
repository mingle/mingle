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

Tabs = {
  bindTabs: function(rootClass, headerClass, contentClass) {
    $$(rootClass).each(function(tab) {
      this.bindTab(tab, headerClass, contentClass);
    }.bind(this));
  },

  bindTab: function(tab, headerCSS, contentCSS) {
    var headers = tab.select(headerCSS);
    var contents = tab.select(contentCSS);
    var selectedTabField = tab.down('input[name=tab]');
    headers.each(function(header){
      header.observe('click', this.toggleVisible.bindAsEventListener(this, header, headers, contents, selectedTabField));
    }.bind(this));
  },

  toggleVisible: function(event, header, headers, contents, selectedTabField) {
    headers.each(function(each, index) {
      if (each == header) {
        each.addClassName('current');
        contents[index].show();
        selectedTabField.value = header.getAttribute('tab_identifier');
      } else {
        each.removeClassName('current');
        contents[index].hide();
      }
    }.bind(this));
  }
};
