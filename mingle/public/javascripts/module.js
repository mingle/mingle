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

String.prototype.capitalizeFirst = function() {
  return this.charAt(0).toUpperCase() + this.substring(1);
};

Module = {
  decorate: function() {
    Module.mixin.apply(Module, arguments);
    return $A(arguments).first();
  },
  
  mixin: function(object) {
    $A(arguments).slice(1).each(function(module) {
      Object.extend(object, module);
      if (Object.isFunction(module.moduleIncluded)) {
        object.moduleIncluded();
      }
    
      if (module.aliasMethodChain) {
        var chains = module.aliasMethodChain.flatten().inGroupsOf(2);
        chains.each(function(chain) {
          Module.aliasMethodChain(object, chain[0], chain[1]);
        });
      }
    });
  },
  
  mixinOnIe: function() {
    if(Prototype.Browser.IE) { 
      Module.mixin.apply(Module, arguments);
    }
  },
  
  aliasMethodChain: function(object, method, suffix) {
    if (Object.isUndefined(object[method])) {
      throw {name: 'MethodNotFound', message: 'alias method chain failed, method: ' + method + ' must be defined on original object' };
    }
    
    suffix = suffix.capitalizeFirst();
    var withMethodName = method + "With" + suffix;
    var withoutMethodName = method + "Without" + suffix;
    if (Object.isUndefined(object[withMethodName])) {
      throw {name: 'MethodNotFound', message: 'alias method chain failed, method: ' + withMethodName + ' must be defined on the module' };
    }

    object[withoutMethodName] = object[method];
    object[method] = object[withMethodName]; 
  }
};
