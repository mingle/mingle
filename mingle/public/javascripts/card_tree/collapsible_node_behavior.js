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

var CollapsibleNode = {
  aliasMethodChain: [['destroy', 'cancelOnGoingRequest']],
  
  toggle: function() {
    this.expanded ? this.collapse() : this.expand();
  },
  
  expand: function() {
    this.expanded = true;
    this.cancelOnGoingRequest();
    this.onGoingRequest = this.remoteService.remoteExpand(this);
  },
  
  collapse: function() {
    this.expanded = false;
    this.destroyAllDescandants();
    this.children = $A();
    this.cancelOnGoingRequest();
    this.onGoingRequest = this.remoteService.remoteCollapse(this);
  },
  
  destroyWithCancelOnGoingRequest: function() {
    this.cancelOnGoingRequest();
    this.destroyWithoutCancelOnGoingRequest();
  },

  setRemoteService: function(remoteService){
    this.remoteService = remoteService;
    this.children.each(function(child) { child.setRemoteService(remoteService); } );
  },
  
  cancelOnGoingRequest: function() {
    if(this.onGoingRequest) {
      this.onGoingRequest.transport.abort();
      this.onGoingRequest = null;
    }
  },
  
  spinnerId: function(){
    return "spinner_" + this.number;
  }
};

// depends on CollapsibleBehavior
ChangingTwistyBehaviour =  {
  expandWithTwisty: function() {
    if (!this.isRoot()) {
      this.changeTwistyToExpand();
    }
    this.expandWithoutTwisty();
  },
  
  collapseWithTwisty: function() {
    this.changeTwistyToCollapse();
    this.collapseWithoutTwisty();
  },
  
  aliasMethodChain: [['expand', 'twisty'], ['collapse', 'twisty']],
  
  changeTwistyToExpand: function () {
    var linkElement = this.element.down('.twisty');
    if(!linkElement) {return;}
    linkElement.removeClassName('collapsed');
    linkElement.addClassName('expanded');
  },
  
  changeTwistyToCollapse: function() {
    var linkElement = this.element.down('.twisty');
    if(!linkElement) {return;}
    linkElement.removeClassName('expanded');
    linkElement.addClassName('collapsed');
  }
};

var RememberingCollapsibleStateBehavior = {
  aliasMethodChain: [['expand', 'rememberingState'], ['collapse', 'rememberingState']],
  
  initExpandStatus: function(expandNodes){
    if(!expandNodes) {return;}
    if (expandNodes.include(this.number) || this.isRoot()){
      this.expanded = true;
    } 
    this.children.each(function(child){ child.initExpandStatus(expandNodes);});
  },

  expandWithRememberingState: function() {
    this.stateStorage.rememberingStateForExpanding(this);
    this.expandWithoutRememberingState();
  },

  collapseWithRememberingState: function() {
    this.stateStorage.rememberingStateForCollapsing(this);
    this.collapseWithoutRememberingState();
  },

  setExpandingStateStorage: function(stateStorage){
    this.stateStorage = stateStorage;
    this.children.each(function(child) { child.setExpandingStateStorage(stateStorage); } );
  } 
};

var NodesToggle = Class.create({
  initialize: function(expandNodes, remoteExpandFunction, remoteCollapseFunction){
    this.expandNodes = expandNodes;
    this.remoteExpandFunction = remoteExpandFunction;
    this.remoteCollapseFunction = remoteCollapseFunction;
  },

  expandNodesString: function(){
    return this.expandNodes.without(0).join(',');
  },

  rememberingStateForCollapsing: function(node) {
    this.expandNodes = this.expandNodes.without(node.number);
  },

  rememberingStateForExpanding: function(node) {
    this.expandNodes.push(node.number);
  },

  remoteExpand: function(node) {
    return this.remoteExpandFunction(this.expandNodesString(), node.number, node.spinnerId());
  },

  remoteCollapse: function(node) {
    return this.remoteCollapseFunction(this.expandNodesString(), node.number, node.spinnerId());
  }
});
