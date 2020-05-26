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

TreeNodesParser = Class.create(function() {
  function mixin(node, modules) {
    node.children.each(function(child) { mixin(child, modules); });
    Module.mixin.apply(Module, [node].concat(modules));
  }
  
  function setParent(parent, child) {
    child.parent = parent;
    child.children.each(function(node) { setParent(child, node); });
  }
  
  return {
    initialize: function() {
      this.behaviorMixins = [TreeNodeBase].concat($A(arguments));
    },
    
    parse: function(treeStructure) {
      if(Object.isString(treeStructure)) {
        treeStructure = treeStructure.evalJSON();
      }
      var root = treeStructure;
      setParent(null, root);
      mixin(root, this.behaviorMixins);
      return root;
    }
  };
}());
