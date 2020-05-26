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

var HierarchyView = {
  attach: function(jsonTree, expandNodes, remoteExpandFunction, remoteCollapseFunction) {
    this.nodesToggle = new NodesToggle(expandNodes, remoteExpandFunction,remoteCollapseFunction);
    this.parser = new TreeNodesParser(CollapsibleNode, ChangingTwistyBehaviour, RememberingCollapsibleStateBehavior);
    this.root = this.parseNode(jsonTree);
  },
  
  openCard: function(event, cardLink) {
    event = Event.extend(event);
    if(event.element() && event.element().hasClassName('twisty')) {
      return true;
    }
    var form = $('open_card_with_context_numbers_form');
    form.down('#context_numbers').value = this.currentCardContext();
    form.down('#redirect_url').value = cardLink.href;
    form.submit();
  },
  
  currentCardContext: function() {
    return this.root.deepFirstTravelCollect().pluck('number').without(0).join(',');
  },
  
  toggle: function(cardNumber) {
    this.root.findNodeByNumber(cardNumber).toggle();
  },
  
  parseNode: function(json) {
    var node = this.parser.parse(json);
    node.setRemoteService(this.nodesToggle);
    node.setExpandingStateStorage(this.nodesToggle);
    return node;
  },
  
  replaceSubtree: function(subtreeJson) {
    var newSubtreeRoot = this.parseNode(subtreeJson);
    var parent = this.root.findNodeByNumber(newSubtreeRoot.number);
    if(!parent) { return; } // if parent's parent can be already collapsed
    parent.replace(newSubtreeRoot);
  }
};
