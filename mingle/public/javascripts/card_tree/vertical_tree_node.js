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

var VerticalTreeNode = {
  addChildWithVertical: function(childNode, skipRefresh){
    var old_parent = childNode.parent;
    this.addChildWithoutVertical(childNode, skipRefresh);
    childNode.element.remove();
    if(this.isRoot()){
      this._insertToColumn(childNode);
    } else {
      this._insertToSubtree(childNode);
    }
    /* After drag, the dragging element has absolute position and left top values (by drag & drop.js),
    so after drop it, we should clear those style properties to make it display in correct position */
    childNode.element.setStyle({zIndex: '', width: '', height: '', left: '', top: ''});
    if(!skipRefresh){
      if (old_parent) {
        old_parent.refreshChildrenClasses();
      }
      this.refreshChildrenClasses();
    }
  },
  
  removeFromParentWithRefresh: function(andChildren){
    var oldParent = this.parent;
    this.removeFromParentWithoutRefresh(andChildren);
    oldParent.refreshChildrenClasses();
  },
  
  refreshChildrenClasses: function(){
    if(this.isRoot()){
      this.refreshChildColumnsClass();
    } else {
      this.refreshChildNodesClass();
    }
  },
  
  _insertToColumn: function(childNode){
    var column = Builder.node('div',{ className: 'vtree-column' });
    column.appendChild(childNode.element);
    if(childNode.nextNode()){
      new Insertion.Before(childNode.nextNode().element.up('.vtree-column'), column);
    }else{
      new Insertion.Before($('vtree-layout-clear'), column);
    }
  },
  
  _insertToSubtree: function(childNode){
    var sub_tree = this.element.down('.sub-tree');
    if(childNode.nextNode()){
      new Insertion.Before(childNode.nextNode().element, childNode.element);
    } else {
      sub_tree.appendChild(childNode.element);
    }
    if(sub_tree.hasClassName('no-child')){
      sub_tree.removeClassName('no-child');
    }
  },
  
  nextNode: function(){
    if(this.isRoot()){
      return null;
    }
    var neighbors = this.parent.children;
    if(neighbors.indexOf(this) < neighbors.size() - 1){
      return neighbors[neighbors.indexOf(this) + 1];
    } else {
      return null;
    }
  },
  
  aliasMethodChain: [['addChild', 'vertical'], ['removeFromParent', 'refresh']],
  
  refreshChildNodesClass: function(){
    var immediateChildNodeElements = $$('#' + this.html_id + ' > .sub-tree > .vtree-node');
    var children_count = immediateChildNodeElements.size();
    for(var index=0; index < children_count; index++){
      var nodeElement = immediateChildNodeElements[index];
      if(nodeElement.hasClassName('last')){
        nodeElement.removeClassName('last');
      }
    }
    if(children_count > 0){
      immediateChildNodeElements[children_count - 1].addClassName('last');
    }
  },
  
  refreshChildColumnsClass: function(){
    var columns = $$('#tree > .vtree-column');
    var columns_after_clean_up = $A();
    columns.each(function(column, index){
      if(column.select(".vtree-node").size() == 0) {
        column.remove();
      } else {
        column.writeAttribute({className: 'vtree-column'});
        columns_after_clean_up.push(column);
      }
    });
    
    columns = columns_after_clean_up;
    
    if(columns.size() == 1){
      columns.first().addClassName('single-column');
    } else if (columns.size() > 1){
      columns.first().addClassName('first-column');
      columns.last().addClassName('last-column');
    }
  }
};

