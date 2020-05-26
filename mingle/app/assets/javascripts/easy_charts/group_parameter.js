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

MingleUI.EasyCharts.GroupParameter = function (container, groupDefinition, options) {
  var self= this;

  function initialize() {
    self.name = groupDefinition.name.toCamelCase('-');
    self.htmlContainer = $j(container);
    self.params = MingleUI.EasyCharts.SectionHelpers.addParameters.call(self, groupDefinition.param_defs, options);

    if(groupDefinition.vertical)
      self.htmlContainer.find('.section-params-container').addClass('vertical-parameter');
  }

  this.value = function(){
    var values =  {};
    for(var param in this.params){
      values[param] = this.params[param].value ? this.params[param].value() : '';
    }
    return values;
  };
  initialize();
};
