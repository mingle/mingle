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

var Tree = Class.create({
  initialize: function(treeStructure, addChildrenCallback, popupLoader, expandNodes, expandTreeNodeFunction, collapseTreeNodeFunction) {
    this.nodesToggle = new NodesToggle(expandNodes, expandTreeNodeFunction, collapseTreeNodeFunction);
    this.parser = new TreeNodesParser(SearchableNodeBehavior, DragdroppableNodeBehavior, PopupNodeBehavior, VerticalTreeNode, CollapsibleNode,ChangingTwistyBehaviour, RememberingCollapsibleStateBehavior);
    this.root = this.parseNode(treeStructure);
    this.root.initExpandStatus(expandNodes);
    this.containerElement = $('tree');

    this.popupLoader = popupLoader;
    this.popups = new CardPopups(this.popupLoader);
    this.addChildrenCallback = addChildrenCallback;

    Droppables.drops.clear();
    this.registerBehaviorsFor(this.root);
  },

  //TODO: Should be renamed to re-layout for root node or some other meaningful method name
  draw: function(canvas) {
    this.rememberRootNodeSize();
    var sum_width = 0;
    var columns = $$('.vtree-column');
    columns.each(function(col, index){
      if(index == (columns.size() - 1) && col.hasClassName('last-column')){
        // use card width instead of column width for last column, make the layout balanced
        sum_width += col.select('.vtree-card').first().offsetWidth;
      } else {
        sum_width += col.offsetWidth;
      }
    });

    $('vtree-root').setStyle({width: sum_width + 'px'});

    if(columns.size() == 1){
      $('vtree-root').addClassName('only-has-one-child');
    } else if (columns.size() > 1 && $('vtree-root').hasClassName('only-has-one-child')){
      $('vtree-root').removeClassName('only-has-one-child');
    }
    // Fix the IE6 root link position issues, because IE will extend the root width even we set the width property
    if(Prototype.Browser.IE && columns.size() > 1){
      if($('node_0').getWidth() > sum_width){
        $('vtree-root').addClassName('fix-root-link-position-break-when-tree-is-narrow-than-root');
      }else{
        $('vtree-root').removeClassName('fix-root-link-position-break-when-tree-is-narrow-than-root');
      }
    }
  },

  destroy: function() {
    this.popups.clear();
  },

  rememberRootNodeSize: function(){
    var root = $('node_0');
    var rootDimension;
    if(!TreeView.oringinalRootDimension){
      rootDimension = root.getDimensions();
      TreeView.oringinalRootDimension = rootDimension;
    } else {
      rootDimension = TreeView.oringinalRootDimension;
    }
    root.setStyle({
      width: rootDimension.width + 'px',
      height: rootDimension.height + 'px'
    });
  },

  onStartDrag: function(draggable) {
   var draggingNode = this.root.findNodeByNumber(draggable.element.getAttribute("number"));
   draggingNode.onStartDrag(draggable);
  },

  setOperating: function(number, state) {
    if(state) {
      this.spinnerOf(number).show();
    } else {
      this.spinnerOf(number).hide();
    }
  },

  spinnerOf: function(number) {
   var element = $("spinner_" + number);
   return element;
  },

  addToRoot: function(jsons) {
    var nodes = jsons.collect(function(json) {
     return this.addNode(this.root, json, true, true);
    }.bind(this));
    this.root.children = this.root.children.smartSortBy("cardName");
    this.root.refreshChildColumnsClass();
    this.refreshPopups(nodes);
  },

  addNodesToCollapsedNode: function(parentNumber, jsons){
    var parent = this.root.findNodeByNumber(parentNumber);
    jsons.each(function(json){
      var node = this.parseNode(json);
      parent.addChildToCollapsedNode(node);
    }.bind(this));
    this.refreshPopups([parent].concat(parent.ancestors()));
  },

  addNode: function(parent, json, skipPopupUpdate, skipRefresh) {
    var node = this.parseNode(json);
    node.isRoot = function() {return false; };
    this.registerBehaviorsFor(node);
    parent.addChild(node, skipRefresh);

    if(!skipPopupUpdate) {
     this.refreshPopups([node].concat(node.ancestors()));
    }
    return node;
  },

  removeNode: function(number, andChildren) {
    var node = this.root.findNodeByNumber(number);
    var ancestors = node.ancestors();
    var descendants = node.descendants();
    var outOfUpdates = null;
    if(andChildren) {
      this.popupLoader.remove(descendants.concat([node]).pluck('number'));
      outOfUpdates = ancestors;
    } else {
      this.popupLoader.remove(node.number);
      outOfUpdates = ancestors.concat(descendants);
    }
    node.removeFromParent(andChildren);

    this.refreshPopups(outOfUpdates);
    this.refreshCardExplorerSearchResult();
  },
  // TODO:these are copy from hierarchy view
  toggleNode: function(number){
    this.root.findNodeByNumber(number).toggle();
  },

  parseNode: function(json) {
    var node = this.parser.parse(json);
    node.setRemoteService(this.nodesToggle);
    node.setExpandingStateStorage(this.nodesToggle);
    return node;
  },

  initPopups: function(popupLoader, root){
    var popups = new CardPopups(popupLoader);
    root.setPopupCollection(popups);
    return popups;
  },

  replaceSubtree: function(subtreeJson) {
    var newSubtreeRoot = this.parseNode(subtreeJson);
    var parent = this.root.findNodeByNumber(newSubtreeRoot.number);
    if(!parent) { return; } // if parent's parent can be already collapsed
    parent.replace(newSubtreeRoot);
    parent.children.each(this.registerBehaviorsFor.bind(this));
    var ancestors = [parent].concat(parent.ancestors());
    this.refreshPopups(ancestors);
  },

  registerBehaviorsFor: function(node){
    node.setAddChildrenCallback(this.addChildrenCallback);
    node.registerDraggableForMovingWithinTree(this);
    node.setPopupCollection(this.popups);
  },

  openCard: function(event, cardLink) {
    var form = $('open_card_with_context_numbers_form');
    form.down('#context_numbers').value = this.currentCardContext();
    form.down('#redirect_url').value = cardLink.href;
    form.submit();
  },

  currentCardContext: function() {
    return this.root.deepFirstTravelCollect().pluck('number').without(0).join(',');
  },

  refreshPopups: function(nodes){
    nodes = nodes.without(this.root);
    this.popupLoader.requestCardsPopups(nodes.pluck('number'));
  },

  search: function(text) {
    return this.root.search(text);
  },

  findNodeByNumber: function(number){
    return this.root.findNodeByNumber(number);
  },

  dragAndDropCardInTreeForSelenium: function(droppableNodeNumber, draggingNodeNumber){
    this.root.findNodeByNumber(droppableNodeNumber)._onMovingWithinTheTree(this.root.findNodeByNumber(draggingNodeNumber).element);
  }
});

var RefreshCardExplorerSearchResultModule = {
  refreshCardExplorerResults: function(){
    this.refreshCardExplorerFilterResult();
    this.refreshCardExplorerSearchResult();
  },
  refreshCardExplorerFilterResult: function(){
    if(window.mingle_filters){
      window.mingle_filters.onChange();
    }
  },
  refreshCardExplorerSearchResult: function(){
    var searchQuery = $('card-explorer-q');
    if(searchQuery && !searchQuery.value.empty()){
      $('card_explorer_search_form').onsubmit();
    }
  }
};

Module.mixin(Tree.prototype, RefreshCardExplorerSearchResultModule);


var TreeView = {
  bindDroppableHack: function() {
    if(typeof(Droppables.showWithoutTreeViewValidation) == 'function') {
      return;
    }
    Droppables.showWithoutTreeViewValidation = Droppables.show;
    Droppables.show = function(point, element) {
      if(TreeView.tree && TreeView.isOutSide(point)) {
        if(this.last_active) {
          this.deactivate(this.last_active);
        }
        return;
      }
      this.showWithoutTreeViewValidation(point, element);
    }.bind(Droppables);
  },

  initTreeZoomHandler: function(zoomHandler, zoomTracker) {
    if(this.zoomRange){
      this.zoom(this._zoomLevel);
    } else {
      this.zoomRange = $R(1, 10);
      this._zoomLevel = 6;
      $(document.body).writeAttribute('class', 'zoom-level-5');
    }

    this.zoomController = new Control.Slider(zoomHandler, zoomTracker, {
      axis: 'vertical',
      range: this.zoomRange,
      increment: 6.5,
      sliderValue: this._zoomLevel,
      onSlide: this.zoom.bind(TreeView),
      onChange: this.zoom.bind(TreeView)
    });
    this.zoomInButton = new Button($("zoom-out-button"), this.zoomOut.bind(this), '+');
    this.zoomOutButton = new Button($("zoom-in-button"), this.zoomIn.bind(this), '_');
    HotKey.register('0)', this._zoomWithMovingZoomController.bind(this, 6));
  },

  zoom: function(zoomValue){
    this._zoomLevel = zoomValue;
    $(document.body).writeAttribute('class', 'zoom-level-' + Math.round(11 - zoomValue));
  },

  zoomIn: function() {
    this._zoomWithMovingZoomController(this._zoomLevel + 1);
  },

  zoomOut: function() {
    this._zoomWithMovingZoomController(this._zoomLevel - 1);
  },

  _zoomWithMovingZoomController: function(zoomValue) {
    if(this.zoomRange.include(zoomValue)){
      this.zoom(zoomValue);
      this.zoomController.setValue(zoomValue);
      TreeView.tree.draw();
    }
  },

  initWidget: function(overviewId, overviewButtonId) {
    if(this.resizeHandler) {
      $j(document).off("mingle:relayout", this.resizeHandler);
    }

    var configOverview = this.configOverview = $(overviewId);
    var configOverviewButton = this.configOverviewButton = $(overviewButtonId);

    configOverviewButton.observe('click', function(event) {
      configOverview.toggle();
      this.configOverview.clonePosition(this.configOverviewButton, {offsetTop: this.calculateHowManyPixelsPerEm() * 3});
    }.bind(this));

    this.onResize();

    // seems mousedown/click would be hided when clicking on the tree view card node
    document.observe('mouseup', function(event){
      var isOpeningOverview = event.element().id == overviewButtonId;
      var isInsideOverview = configOverview.isFiredInside(event);
      if(isOpeningOverview || isInsideOverview) {
        return;
      }
      if(configOverview.visible()) {
        configOverview.hide();
      }
    });
    this.resizeHandler = this.onResize.bindAsEventListener(this);
    $j(document).on("mingle:relayout", this.resizeHandler);
  },

  onResize: function(){
    if(this.configOverview && this.configOverviewButton){
      try {
        this.configOverview.clonePosition(this.configOverviewButton, {offsetTop: this.calculateHowManyPixelsPerEm() * 3});
      } catch(e) {
        // clonePosition could fail on ie when resizing window and refresh tree view at same time
      }
    }
  },

  // the following 2 arrays should not be cleared when register new tree
  // see #3559
  draggables: $A(),
  prefixes: $A(),
  register: function(tree, canvas) {
    this.bindDroppableHack();
    if (this.tree != null) {
      this.tree.destroy();
    }
    this.tree = tree;
    this.canvas = canvas;
    this.redraw();
    this.canvas.initWithRootNode(this.tree.root);
    this.hideTreeSpinner();
  },

  isUsingTree: function(){
    return this.tree != undefined;
  },

  isNodeExpanded: function(cardNumber){
    return this.tree.root.findNodeByNumber(cardNumber).expanded;
  },

  parentNodeNumber: function(cardNumber){
    var node = this.tree.root.findNodeByNumber(cardNumber);
    return node.isRoot() ? '' : node.parent.number;
  },

  getTree: function(){
    return this.tree;
  },

  expandedNodesString: function(){
    return this.tree.nodesToggle.expandNodesString();
  },

  centralizeOn: function(ele) {
    this.canvas.draggableMap.centralizeOn(ele);
  },

  toggleNode: function(number){
    this.tree.toggleNode(number);
    this.resetSearchSession();
  },

  showQuickAdd: function(cardElement, quickAddElement) {
    cardElement = $(cardElement);
    quickAddElement = $(quickAddElement);
    quickAddElement.show();
    MingleUI.align.cumulativeAlign(cardElement, quickAddElement, {left: cardElement.getWidth() + 2});
    quickAddElement.down('.card-name-input').focus();
  },

  addToRoot: function(jsons) {
    this.tree.addToRoot(jsons);
    if(jsons.length > 0) {
      this.redraw();
    }
  },

  addNodesToCollapsedNode: function(parentNumber, jsons) {
    if (parentNumber == null) {
      parentNumber = this.tree.root.number;
    }
    this.tree.addNodesToCollapsedNode(parentNumber, jsons);
    if(jsons.length > 0) {
      this.redraw();
    }
  },

  addFilteredNodesToCollapsedNode: function(parentNumber, numberOfNodes){
    var parent = this.tree.root.findNodeByNumber(parentNumber);
    parent.addFilteredNodesToCollapsedNode(numberOfNodes);
  },

  removeCardAction: function(number, removeSingleCardAction, removeCardAndItsChildrenAction) {
    var node = this.tree.root.findNodeByNumber(number);
    RemoveFromTree.removeCardInTree(node, removeSingleCardAction, removeCardAndItsChildrenAction);
  },

  removeNode: function(number, andChildren) {
    if (number == null) {
      return;
    }
    this.tree.removeNode(number, andChildren);
    this.redraw();
  },

  redraw: function() {
    this.tree.draw(this.canvas);
  },

  isOutSide: function(point) {
    return this.canvas.draggableMap.isOutside({x: point[0], y: point[1]});
  },

  beforeAddChildrenTo: function(parentNumber) {
    this.tree.spinnerOf(parentNumber).show();
    window.docLinkHandler.disableLinks();
    this.expandParentNodeIfNecessary(parentNumber);
  },

  expandParentNodeIfNecessary: function(parentNumber){
    if(this.isUsingTree()) {
      var parentNode = this.tree.root.findNodeByNumber(parentNumber);
      this.tree.nodesToggle.rememberingStateForExpanding(parentNode);
    }
  },

  onAddChildrenComplete: function(parentNumber) {
    this.tree.spinnerOf(parentNumber).hide();
    this.hideNoCardsHint();
    window.docLinkHandler.enableLinks();

    if(this.nodesOutOfUpdates) {
      var nodes = this.nodesOutOfUpdates;
      this.nodesOutOfUpdates = null;
      this.tree.refreshPopups(nodes);
    }
  },

  hideNoCardsHint: function(){
    var hint = $('no-children-hint');
    if(hint) {hint.hide();}
  },

  registerPrefix: function(prefix) {
    if (!this.prefixes.member(prefix)) {
      this.prefixes.push(prefix);
    }
  },

  registerDraggable: function(prefix, cardNumber) {
    this.registerPrefix(prefix);
    var elementId = this.getElementId(prefix, cardNumber);
    if($(elementId) == null) {return;}
    $(elementId).prefixId = prefix;
    $(elementId).addClassName("card-child-candidate").removeClassName("card-child-disabled");
    var draggable = new SubsDraggable(elementId, {dragelement: this.cloneDraggableElements.bind(this)});
    if(Prototype.Browser.IE) {
      draggable.element.undoPositioned();//Fix IE6 relative position overlap bugs
    }
    this.draggables.push(draggable);
    this.refreshSelectPanelVisiblity();
  },

  registerAllDraggable: function(cardNumbers) {
    $(cardNumbers).each(function(cardNumber) {
      this.prefixes.each(function(prefix){
        this.registerDraggable(prefix, cardNumber);
      }.bind(this));

      var checkbox = $(this.getCheckBoxId(cardNumber));
      if(checkbox) {checkbox.disabled = false;}
    }.bind(this));
  },

  unregisterDraggable: function(cardNumber) {
    this.prefixes.each(function(prefix){
      var elementId = this.getElementId(prefix, cardNumber);
       if ($(elementId)){
         this.unregisterDraggableWithId(elementId);
       }
    }.bind(this));
    var checkbox = $(this.getCheckBoxId(cardNumber));
    if(!checkbox) {return;}
    checkbox.checked = false;
    checkbox.disabled = true;
    this.refreshSelectPanelVisiblity();
  },

  unregisterDraggableWithId: function(draggableId) {
    this.disableDraggableElement(draggableId);
    var draggable = this.draggableFor(draggableId);
    this.draggables = this.draggables.without(draggable);
    draggable.destroy();
  },

  getElementId: function(prefix, cardNumber) {
    return prefix + "_card_child_candidate_" + cardNumber;
  },

  getCheckBoxId: function(cardNumber){
    return "checkbox["+ cardNumber +"]";
  },

  cloneDraggableElements: function(selectedElement) {
    this.selectedElement = selectedElement;
    var originalContainer = $(selectedElement.prefixId + '_results_for_tree');
    var draggableElements = originalContainer.getElementsBySelector('input.draggable');
    var selectedCheckBoxes = draggableElements.select(function(element) {
      return element.checked && !element.disabled;
    });
    var checkedElements = selectedCheckBoxes.collect(function(checkedElement){
      return $(this.getElementId(this.selectedElement.prefixId, checkedElement.value));
    }.bind(this));

    var draggableElement;
    var container = $('filter_results_for_tree');
    if (checkedElements.size() > 0 && checkedElements.include(selectedElement)) {
      draggableElement = this.cloneDraggableElement(originalContainer, container, false);
      this.stackCards(checkedElements, selectedElement, draggableElement);
      draggableElement.removeClassName('search-results-container');
      draggableElement.addClassName('search-results-container-clone');
    } else {
      draggableElement = this.cloneDraggableElement(selectedElement, container, true);
      draggableElement.addClassName('single-card-on-dragging');
    }
    // mark ele as 'isOutside' for draggable_map
    draggableElement.isOutside = true;
    draggableElement.setOpacity(0.4);
    return draggableElement;
  },

  cloneDraggableElement: function(element, container, cloneChildren) {
    var newElement = element.cloneNode(cloneChildren);
    Module.mixin(newElement, CancelPreviousEffectMoving);

    newElement.id = newElement.id + '_draggable_clone';
    newElement.addClassName('on-dragging');
    container.appendChild(newElement);
    Position.absolutize(newElement);
    Position.clone(element, newElement);

    if (Prototype.Browser.IE){
      var offset = parseInt(newElement.getStyle("top")) + $('filter_results_for_tree').scrollTop;
      newElement.setStyle({top: offset +  "px"});
    }

    newElement.style.zIndex = 10000;
    return newElement;
  },

  disableDraggableElement: function(elementId) {
    $(elementId).addClassName("card-child-disabled").removeClassName("card-child-candidate");
    var input = $(elementId).getElementsBySelector("input[type=checkbox]").first();
    if(input) {input.disabled = true;}
  },

  disableCandidatesContainer: function(){
    var disableMark = new Element('div', {style: 'position: absolute;background-color: white;opacity: 0.25', id: 'mask_candidate'});
    document.body.appendChild(disableMark);
    Position.clone($('card_drag_candidates_container'), disableMark);
  },

  enableCandidatesContainer: function(){
    $('mask_candidate').remove();
  },

  refreshSelectPanelVisiblity: function() {
    this.prefixes.each(function(prefix) {
      if(!$('card_drag_candidates_container')) { return; }
      var panel = $('card_drag_candidates_container').select("." + prefix + '-select-none-all-panel').first();
      var resultContainer = $(prefix + '_results_for_tree');
      var allDragCandidatesDisabled = resultContainer.select('.card-child').all(function(li){
        return li.hasClassName('card-child-disabled');
      });
      allDragCandidatesDisabled ? panel.hide() : panel.show();
    });
  },

  draggableFor: function(elementId) {
    return this.draggables.find(function(d){ return d.element == $(elementId);}.bind(this));
  },

  stackCards: function(elements, selectedElement, container) {
    var startZ = 1000;
    var topCardOnStack = this.cloneDraggableElement(selectedElement, container, true);
    topCardOnStack.addClassName('top-card-on-stack');
    topCardOnStack.style.zIndex = startZ;
    var width = topCardOnStack.getWidth();
    var height = topCardOnStack.getHeight();
    var top = parseInt(topCardOnStack.getStyle('top'));
    var left = parseInt(topCardOnStack.getStyle('left'));
    elements.without(selectedElement).each(function(element, index) {
      index++;
      var offset = index * 3;
      var newElement = Builder.node('div', {className: 'card-div-copy on-dragging', 'style': 'width: ' + width + "px; height: " + height + "px;", 'number': element.getAttribute('number')});
      container.appendChild(newElement);
      var newTop = top + offset;
      var newLeft = left + offset;
      newElement.style.zIndex = startZ - index;
      newElement.style.top = newTop + 'px';
      newElement.style.left = newLeft + 'px';
    }.bind(this));
    this.fixStackCardsContainerWidth(container);
  },

  fixStackCardsContainerWidth: function(container) {
    if(Prototype.Browser.IE){
      container.setStyle({width: '400px', overflow: 'visible'});
    }
  },
  hideTreeSpinner: function(){
    $('tree-loading-spinner') && $('tree-loading-spinner').hide();
  }
};

Module.mixin(TreeView, PixelsPerEmCalculatorModule);


var CardPopupLoader = Class.create({
  initialize: function(url) {
    this.url = url;
    this.data = $H();
  },

  getData: function(cardNumber) {
    cardNumber = parseInt(cardNumber, 10);
    return this.data.get(cardNumber);
  },

  requestCardsPopups: function(cardNumbers, success) {
    if ("function" !== typeof success) {
      success = this._updateData.bind(this);
    }

    this.remove(cardNumbers);
    return this._refreshCardDataCache(cardNumbers, success);
  },

  remove: function(cardNumbers) {
    $A(cardNumbers).each(function(number){ this.data.unset(number); }.bind(this));
  },

  _refreshCardDataCache: function(cardNumbers, success) {
    return new Ajax.Request(this.popupUrl(cardNumbers), {method: 'get', onSuccess: success});
  },

  popupUrl: function(cardNumbers) {
    var url = this.url;
    return url + (url.include('?') ? '&' : '?') + 'numbers=' + encodeURIComponent(cardNumbers.join(','));
  },

  _updateData: function(response) {
    var popupData = null;
    try {
      popupData = eval("(" + response.responseText + ")");
    } catch (e) {
      return;
    }

    for(var cardNumber in popupData) {
      this.data.set(cardNumber, popupData[cardNumber]);
    }
  }
});

CardPopups = Class.create({
  initialize: function(dataLoader) {
    this.visiblePopups = $A();
    this.loader = dataLoader;

    this.globalClickListener = this.onGlobalClick.bindAsEventListener(this);
    Event.observe(document, 'click', this.globalClickListener);
    this.resizeHandler = this.clear.bindAsEventListener(this);
    $j(document).on("mingle:relayout", this.resizeHandler);
    this.clickOutsideListenerIsOn = true;
    this.singlePopupRequest = null;
  },

  destroy: function() {
    this.clear();
    Event.stopObserving(document, 'click', this.globalClickListener);
    $j(document).off("mingle:relayout", this.resizeHandler);
  },

  //keep popup on windows even you click somewhere else
  keep: function() {
    this.clickOutsideListenerIsOn = false;
  },

  unKeep: function() {
    this.clickOutsideListenerIsOn = true;
  },

  onGlobalClick: function(event) {
    var element = Event.element(event);
    if(!element || !element.ancestors) {return true;}
    var isClickedOutSide = !element.ancestors().any(function(node){
      return node.hasClassName('card-popup');
    });
    if(isClickedOutSide && this.clickOutsideListenerIsOn) {
      this.clear();
    }
    return true;
  },

  clear: function() {
    this.lastCard = null;
    this.visiblePopups.each(function(popup) { popup.remove(); });
    this.visiblePopups.clear();
  },

  refreshLastVisible: function(event) {
    if(!this.lastCard) {return;}
    var card = this.lastCard;
    this.clear();
    this.loader.remove([card.number]);
    this.show(event, card);
  },

  show: function(card, event) {
    if (event !== undefined) {
      element = Event.element(event);
      if(element && element.hasClassName('no-popup')) {return true;}
    }

    var spinner = card.spinner() || {show: Prototype.emptyFunction, hide: Prototype.emptyFunction };
    spinner.show();

    var data = this.loader.getData(card.number);
    if (!data) {
      this.loader.requestCardsPopups([card.number], function(response) {
        this.loader._updateData(response);
        this._renderPopup(card, spinner);
      }.bind(this));
    } else {
      this._renderPopup(card, spinner);
    }

    if (event !== undefined) {
        Event.stop(event);
    }
  },

  _renderPopup: function(card, spinner) {
      this.clear();
      var data = this.loader.getData(card.number);
      var pop = new CardPopup(this, card, data);
      this.visiblePopups.push(pop);
      spinner.hide();
      this.lastCard = card;
  }
});

GenericPopup = Class.create({
  initialize: function(card, popupData, layoutManager, options) {
    this.options = Object.extend({
      popupArrowClass: 'popup-arrow',
      popupShadowClass: 'popup-shadow',
      popupClass: 'card-popup',
      isDraggable: true,
      colorStripeWidth: 8,
      popupContentClass: 'card-popup-content'
    }, options);

    this.popup = this._createDiv(this.options.popupClass, popupData);
    this.popupArrow = this._createDiv(this.options.popupArrowClass);
    this.popupShadow = this._createDiv(this.options.popupShadowClass);
    this.layout = layoutManager;

    this._allElements().each(function(element){
      card.ownerDocument.body.appendChild(element);
    });

    if(this.options.colorStripe) {
      this._applyColorStripe();
    }

    if (this.options.isDraggable) {
      this._setupDraggable();
    }
    this._showOnTopOf.bind(this).delay(0.2, card);
  },

  element: function() {
    return this.popup;
  },

  remove: function(){
    this._allElements().each(Element.remove);
  },

  _applyColorStripe: function() {
    var contentElement = this.popup.down('.' + this.options.popupContentClass);
    contentElement.style.borderLeft =  this.options.colorStripeWidth + "px solid " + this.options.colorStripe;
  },

  _setupDraggable: function() {
    new Draggable(this.popup, {
      handle: 'popup-handler',
      onStart: function(draggable) {
        this.popupArrow.hide();
        this.popupShadow.hide();
        this.popup.style.borderBottom = '1px solid #999';
      }.bind(this)
    });
  },

  _showOnTopOf: function(card) {
    var popupInformation = this.layout.getPopupInformation(card, this.popup);
    var popupOffsetTop = popupInformation.popupOffset[1];
    var popupOffsetLeft = popupInformation.popupOffset[0];

    this.popupArrow.writeAttribute({className: 'popup-arrow popup-arrow-' + popupInformation.position});
    var arrowOffset = [popupOffsetLeft + popupInformation.arrowOffset[0], popupOffsetTop + popupInformation.arrowOffset[1]];
    var shadowOffset = [popupOffsetLeft + 5, popupOffsetTop + this.popup.getHeight()];

    this.popup.setStyle(this._displayCss(card, popupInformation.popupOffset));
    this.popupArrow.setStyle(this._displayCss(card, arrowOffset));
    this.popupShadow.setStyle(this._displayCss(card, shadowOffset));


    this.popup.select("img").each(function(img) {
       img.onload = this._showOnTopOf.bind(this, card);
    }.bind(this));
  },

  _displayCss: function(card, offsetCoords) {
    var cardOffset = card.cumulativeOffset();
    return {
      position: "absolute",
      display: "block",
      left: (cardOffset.left + offsetCoords[0]) + "px",
      top: (cardOffset.top + offsetCoords[1]) + "px"
    };
  },

  _allElements: function() {
    return [this.popup, this.popupArrow, this.popupShadow];
  },

  _createDiv: function(htmlClass, innerHTML) {
    var result = Builder.node('div', {'class': htmlClass, style: 'display: none; position: absolute;'});
    if(innerHTML) {
      result.innerHTML = innerHTML;
    }
    return result;
  }
});


CardPopup = Class.create( {
  initialize: function(collection, card, popupData) {
    this.popup = new GenericPopup(card.popupOwner(), popupData, CardPopupLayoutManager.getInstance(), { colorStripe: card.color()});
    this.collection = collection;

    this.popupCloseButton = this.popup.element().down('.popup-close');
    this.popupCloseListener = this.close.bindAsEventListener(this);
    Event.observe(this.popupCloseButton, 'click', this.popupCloseListener);

    this.popupRefreshButton = this.popup.element().down('.popup-refresh');
    this.popupRefreshListener = this.refresh.bindAsEventListener(this);
    Event.observe(this.popupRefreshButton, 'click', this.popupRefreshListener);
  },

  close: function(event) {
    this.collection.clear();
  },

  refresh: function(event) {
    this.collection.refreshLastVisible(event);
  },

  remove: function() {
    Event.stopObserving(this.popupRefreshListener, 'click', this.popupRefreshListener);
    Event.stopObserving(this.popupCloseButton, 'click', this.popupCloseListener);
    this.popup.remove();
  }
});

var CardPopupLayoutManager = {
  getInstance: function(){
    if (CardPopupLayoutManager.instance == null) {
      CardPopupLayoutManager.instance = new CardPopupLayoutManager.klass();
    }
    return CardPopupLayoutManager.instance;
  }
};
CardPopupLayoutManager.klass = Class.create({
  initialize: function(){
    CardPopupLayoutManager.instance = this;
  },
  getPopupDimension: function(popup){
    if(popup.visible()){
      return popup.getDimensions();
    } else {
      popup.setStyle({visibility: 'hidden'});
      popup.setStyle({display: ''});
      var dimensions = popup.getDimensions();
      popup.setStyle({display: 'none'});
      popup.setStyle({visibility: 'visible'});
      return dimensions;
    }
  },
  getVariebles: function(card, popup){
    var canvasDimensions = $(document.body).getDimensions();
    var viewportDimensions = document.viewport.getDimensions();
    var viewportScrollOffsets = document.viewport.getScrollOffsets();

    var cardOffset = card.cumulativeOffset();
    var cardScrollOffset = card.cumulativeScrollOffset();
    var cardDimensions = card.getDimensions();

    var popupDimensions = this.getPopupDimension(popup);
    return {
      canvas: {dimensions: canvasDimensions},
      viewport: {
        dimensions: viewportDimensions,
        scrollOffset: viewportScrollOffsets
      },
      card: {
        offset: cardOffset,
        scrollOffset: cardScrollOffset,
        dimensions: cardDimensions
      },
      popup: {dimensions: popupDimensions}
    };
  },
  _calculatePositionFromViewport: function(card, popup, variebles){
    var offset_x_in_viewport = variebles.card.offset[0] - variebles.viewport.scrollOffset[0];
    var offset_y_in_viewport = variebles.card.offset[1] - variebles.viewport.scrollOffset[1];

    return this._decidePosition(offset_x_in_viewport,
      variebles.viewport.dimensions.width - offset_x_in_viewport - variebles.card.dimensions.width,
      offset_y_in_viewport,
      variebles.viewport.dimensions.height - offset_y_in_viewport - variebles.card.dimensions.height,
      variebles);
  },
  _calculatePositionFromCanvas: function(card, popup, variebles){
    var offset_x_in_canvas = variebles.card.offset[0] - variebles.card.scrollOffset[0];
    var offset_y_in_canvas = variebles.card.offset[1] - variebles.card.scrollOffset[1];

    return this._decidePosition(offset_x_in_canvas,
      variebles.canvas.dimensions.width - offset_x_in_canvas - variebles.card.dimensions.width,
      offset_y_in_canvas,
      variebles.canvas.dimensions.height - offset_y_in_canvas - variebles.card.dimensions.height,
      variebles);
  },
  calculatePosition: function(card, popup, variebles){
    var position = this._calculatePositionFromViewport(card, popup, variebles);
    if(position != 'middleMiddle'){
      return position;
    }
    position = this._calculatePositionFromCanvas(card, popup, variebles);
    if(position != 'middleMiddle'){
      return position;
    }

    //If either side has no enough space, use default topRight as result
    return 'topRight';
  },
  _decidePosition: function(leftSpace, rightSpace, topSpace, bottomSpace, variebles){
    var reviseFactor = 30;
    var width = variebles.popup.dimensions.width;
    var height = variebles.popup.dimensions.height;
    var firstPart, lastPart;

    if(rightSpace >= width){
      lastPart = 'Right';
    } else if (leftSpace >= width){
      lastPart = 'Left';
    } else {
      lastPart = 'Middle';
    }

    if(topSpace >= height + reviseFactor){
      firstPart = 'top';
    } else if (bottomSpace >= height + reviseFactor){
      firstPart = 'bottom';
    } else {
      firstPart = 'middle';
    }

    return firstPart + lastPart;
  },
  /* -------------  Positions
     | 0 | 1 | 2 |
     -------------
     | 3 | 4 | 5 |
     -------------
     | 6 | 7 | 8 |
     ------------- */
  positions: $w('topLeft topMiddle topRight middleLeft middleMiddle middleRight bottomLeft bottomMiddle bottomRight'),
  getPopupOffset: function(position, variebles) {
    var offset_x, offset_y, common_margin = Math.floor(variebles.card.dimensions.width / 4);
    switch(this.positions.indexOf(position)){
      case 0:
        offset_x = 0 - variebles.popup.dimensions.width + common_margin;
        offset_y = 0 - variebles.popup.dimensions.height - common_margin;
        break;
      case 1:
        offset_x = 0 + variebles.card.dimensions.width/2 - variebles.popup.dimensions.width/2;
        offset_y = 0 - variebles.popup.dimensions.height - common_margin;
        break;
      case 2:
        offset_x = 0 + variebles.card.dimensions.width - common_margin;
        offset_y = 0 - variebles.popup.dimensions.height - common_margin;
        break;
      case 3:
        offset_x = 0 - variebles.popup.dimensions.width - common_margin;
        offset_y = 0 + variebles.card.dimensions.height/2 - variebles.popup.dimensions.height/2;
        break;
      case 5:
        offset_x = 0 + variebles.card.dimensions.width + common_margin;
        offset_y = 0 + variebles.card.dimensions.height/2 - variebles.popup.dimensions.height/2;
        break;
      case 6:
        offset_x = 0 - variebles.popup.dimensions.width + common_margin;
        offset_y = 0 + variebles.card.dimensions.height + common_margin;
        break;
      case 7:
        offset_x = 0 + variebles.card.dimensions.width/2 - variebles.popup.dimensions.width/2;
        offset_y = 0 + variebles.card.dimensions.height + common_margin;
        break;
      case 8:
        offset_x = 0 + variebles.card.dimensions.width - common_margin;
        offset_y = 0 + variebles.card.dimensions.height + common_margin;
        break;
      default:
        //same with topRight
        offset_x = 0 + variebles.card.dimensions.width - common_margin;
        offset_y = 0 - variebles.popup.dimensions.height - common_margin;
        break;
    }

    return [offset_x, offset_y];
  },
  getArrowOffset: function(position, variebles){
    var offset_x, offset_y, common_border_width = 1;
    var popupWidth = variebles.popup.dimensions.width;
    var popupHeight = variebles.popup.dimensions.height;
    /* Those width/height pair is from card.css (.popup-arrow-topLeft etc.) */
    var arrowSizes = {
      topLeft: [59, 55],
      topMiddle: [42, 55],
      topRight: [55, 53],
      middleLeft: [52, 41],
      middleRight: [48, 42],
      bottomLeft: [59, 48],
      bottomMiddle: [41, 48],
      bottomRight: [56, 48]
    };
    var arrowWidth = arrowSizes[position][0];
    var arrowHeight = arrowSizes[position][1];

    switch(this.positions.indexOf(position)){
      case 0:
        offset_x = 0 + popupWidth - arrowWidth;
        offset_y = popupHeight - 1;
        break;
      case 1:
        offset_x = 0 + popupWidth/2 - arrowWidth/2;
        offset_y = popupHeight - 1;
        break;
      case 2:
        offset_x = 0;
        offset_y = popupHeight - 1;
        break;
      case 3:
        offset_x = 0 + popupWidth - 1;
        offset_y = 0 + popupHeight/2 - arrowHeight/2;
        break;
      case 5:
        offset_x = 0- arrowWidth + 1;
        offset_y = 0 + popupHeight/2 - arrowHeight/2;
        break;
      case 6:
        offset_x = 0 + popupWidth - arrowWidth;
        offset_y = 0 - arrowHeight + 1;
        break;
      case 7:
        offset_x = 0 + popupWidth/2 - arrowWidth/2;
        offset_y = 0 - arrowHeight + 1;
        break;
      case 8:
        offset_x = 0;
        offset_y = 0 - arrowHeight + 1;
        break;
      default:
        //same with topRight
        offset_x = 0 + popupWidth - arrowWidth;
        offset_y = 0 - arrowHeight + 1;
        break;
    }

    return [offset_x, offset_y];
  },
  getPopupInformation: function(card, popup){
    var variables = this.getVariebles(card, popup);
    var position = this.calculatePosition(card, popup, variables);
    return {
      popupOffset: this.getPopupOffset(position, variables),
      position: position,
      arrowOffset: this.getArrowOffset(position, variables)
    };
  }
});

var AggregateCardPopupLayoutManager = {
  getInstance: function(){
    if (AggregateCardPopupLayoutManager.instance == null) {
    AggregateCardPopupLayoutManager.instance = new AggregateCardPopupLayoutManager.klass();
    }
  return AggregateCardPopupLayoutManager.instance;
  }
};

AggregateCardPopupLayoutManager.klass = Class.create(CardPopupLayoutManager.klass, {
  _decidePosition: function(leftSpace, rightSpace, topSpace, bottomSpace, variebles) {
    // we always want bottom right because the popups were covering error messages on the aggregate screen
    return 'bottom' + 'Right';
  }
});
