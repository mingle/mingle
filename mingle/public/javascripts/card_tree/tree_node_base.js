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

TreeNodeBase = {
  moduleIncluded: function() {
    this.element = $(this.html_id);
  },
  
  cardName: function() {
    if(!this.element) {
      return this.number.toString();
    }
    
    if(this._cardName) {return this._cardName;}
    var nameElement = $(this.element).select('.card-name').first();
    if(!nameElement) {return "";}
    
    this._cardName = nameElement.innerHTML.escapeHTML();
    return this._cardName;
  },
  
  color: function() {
    if(!this.element) { return; }
    return this.element.down('.node-content').style.borderLeftColor;
  },
  
  innerElement: function(){
    // TODO: need to be clear after vertical tree works
    if(this.isRoot()){
      return this.element;
    }
    if(this._card_element_cache){
      return this._card_element_cache;
    }
    var card_element = $(this.html_id + "_inner_element");
    card_element = Object.extend(card_element, {
      nodeOffsetLeft: function(){
        return $(card_element).viewportOffset()[0] - TreeView.tree.containerElement.viewportOffset()[0];
      },
      nodeOffsetTop: function(){
        return $(card_element).viewportOffset()[1] - TreeView.tree.containerElement.viewportOffset()[1];
      }
    });
    this._card_element_cache = card_element;
    return card_element;
  },
  
  ancestors: function() {
    var result = $A();
    if (this.isRoot()) {return result;}
    var temp = this.parent;
    while (temp) {
      result.push(temp);
      temp = temp.parent;
    } 
    return result;
  },
  
  descendants: function() {
    return this.collect().without(this);
  },
  
  findNode: function(condition) {
    if (condition(this)) {return this;}
    var result = null;
    this.children.each(function(child) {
      result = child.findNode(condition);
      if(result) {
        throw $break;
      }
    });
    return result;
  },
  
  findNodeByNumber: function(number) {
    return this.findNode(function(node) {
      return node.number == number;
    });
  },
  
  collect: function(condition) {
    if(!condition) {condition = function() { return true; };}
    
    var ret = $A();
    if(condition(this)) {ret.push(this);}
    this.children.each(function(child){
      ret = ret.concat(child.collect(condition));
    });
    return ret;
  },
  
  deepFirstTravelCollect: function() {
    var ret = [this];
    this.children.each(function(child) {
      ret.push.apply(ret, child.deepFirstTravelCollect());
    });
    return ret;
  },
    
  eachDescendant: function(iterator, includeNode) {
    if (includeNode) {
      iterator(this);
    }
    return this.children.invoke('eachDescendant', iterator, true);
  }, 
  
  invokeDescendants: function(method, includeNode) {
    var args = $A(arguments).slice(2);
    return this.eachDescendant(function(node) {
      node[method].apply(node, args);
    }, includeNode);
  },

  isRoot: function() {
    return this.parent == null;
  },
  
  hasChildren: function(){
    return this.children && this.children.length != 0;
  },
  
  removeElement: function() {
    if(this.element && this.element.parentNode) {this.element.remove();}
    if(this.element && this.parent.isRoot()){
      var column = this.element.up('.vtree-column');
      if(column) { column.remove();}
    }
  },
    
  rootNode: function() {
    var node = this;
    while(!node.isRoot()) {
      node = node.parent;
    }
    return node;
  },
  
  addChild: function(childNode, skipRefresh) {
    if(childNode.parent) {
      childNode.parent._decreaseAllCardCount(childNode.subtreeSize());
      childNode.parent.children = childNode.parent.children.without(childNode);
    }
    if(!this.findNodeByNumber(childNode.number)) {
      this.children.push(childNode);
      if(!skipRefresh){
        this.children = this.children.smartSortBy("cardName");
      }
      this.incrementAllCardCount(childNode.subtreeSize());
    }
    childNode.parent = this;
    this.refreshTwisty();
  },
  
  replace: function(subTree){    
    var allCardCountDelta = subTree.allCardCount - this.allCardCount;
    var descendantCountDelta = subTree.descendantCount - this.descendantCount;
    
    this.allCardCount = subTree.allCardCount;
    this.descendantCount = subTree.descendantCount;
    this.expanded = subTree.expanded;
    
    this.ancestors().each(function(node){
      node.allCardCount += allCardCountDelta;
      node.descendantCount += descendantCountDelta;
      node.refreshTwisty();
    });
    
    this.refreshTwisty();
        
    this.destroyAllDescandants();
    this.children = subTree.children;
    this.children.each(function(child) {
      child.parent = this;
    }.bind(this));
  },
    
  addChildToCollapsedNode: function(node){
    this.incrementAllCardCount(node.subtreeSize());
    this.refreshTwisty();
  },
  
  addFilteredNodesToCollapsedNode: function(numberOfNodes){
    this.ancestors().concat(this).each(function(node){
      node.allCardCount += numberOfNodes;
    });
  },
  
  incrementAllCardCount: function(count){
    this.ancestors().concat(this).each(function(node){
      node.allCardCount += count;
      node.descendantCount += count;
      node.refreshTwisty();
    });
  },
    
  _decreaseAllCardCount: function(count){
    this.ancestors().concat(this).each(function(node){
      node.allCardCount -= count;
      node.descendantCount -= count;
      node.refreshTwisty();
    }); 
  },
  
  refreshTwisty: function(){
    var twistyElement = $("twisty_for_card_" + this.number);
    if(!twistyElement) { return; }
    
    if(this.descendantCount > 0) {
      twistyElement.show();
      var countSpan = twistyElement.down('.twisty span');
      if(!countSpan) { return; }
      countSpan.update(this.descendantCount);
      this.expanded ? this.changeTwistyToExpand() : this.changeTwistyToCollapse();
    }else {
      twistyElement.hide();
    } 

  },
  
  subtreeSize: function(){
    return this.allCardCount + 1;
  },
  
  destroy: function() {
    this.removeElement();
    this.parent = null;
  },
  
  bottomUpTraveling: function(iterator){
    this.children.each(function(child){
      child.bottomUpTraveling(iterator);
    });
    iterator(this);
  },
  
  destroyAllDescandants: function() {
    this.bottomUpTraveling(function(node) {
      if(node !== this) {
        node.destroy();
      }
    }.bind(this));
  },
  
  removeFromParent: function(andChildren) {
    if(!this.parent) { return; }
    
    if(andChildren) { 
      this.parent._decreaseAllCardCount(this.subtreeSize());
      this.destroyAllDescandants();
    } else {
      // since the node's element maybe removed in the UI, so we
      // need remove this node from children first, than we start
      // to add node's children to current node, because while adding
      // child to current node, #addChild will try
      // to sort children by card name which is get from html element.
      this.children.each(function(child) {
        this.parent.addChild(child);
      }.bind(this));
      this.parent._decreaseAllCardCount(1);      
    }

    this.parent.children = this.parent.children.without(this);    
    this.parent.refreshTwisty();
    this.destroy();
  },
  
  highlight: function(){
    this.innerElement().addClassName('searching-matched');
  }
};
