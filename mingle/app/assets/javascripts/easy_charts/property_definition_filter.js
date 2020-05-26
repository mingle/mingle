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
PropertyDefinitionFilter = function(filterNames) {
  var FILTERS = {
    aggregate: function (propDefs) {

      function isAggregate(propDef) {
        return (propDef.treeSpecial && propDef.dataType !== 'card');
      }

      var filteredPropertyDefinitions = {};
      for (var propDefName in propDefs) {
        var propDef = propDefs[propDefName];
        if (!isAggregate(propDef)) {
          filteredPropertyDefinitions[propDefName] = propDef;
        }
      }
      return filteredPropertyDefinitions;
    }
  };

  this.apply = function(propDefs) {
    $j.each(filterNames, function (_, filterName) {
      FILTERS[filterName] && (propDefs =  FILTERS[filterName](propDefs));
    });
    return propDefs;
  };
};
