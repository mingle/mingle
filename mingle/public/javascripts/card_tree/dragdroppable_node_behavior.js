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

DragdroppableNodeBehavior = {
  moduleIncluded: function() {
    Module.mixin(this, CancelPreviousEffectMoving);
    if(this.element) {
      Object.extend(this.element, {
        effectMove: function(options) {
          options.afterFinish = Prototype.emptyFunction;
          this.effectMove(options);
        }.bind(this),
        
        mapShouldFollowOnDrag: true
      });
    }
  },

  // the callback should take arguments: parentNumber, childNumbers and return nothing
  setAddChildrenCallback: function(callback){
    this.addChildrenCallback = callback;
    this.children.each(function(child){ child.setAddChildrenCallback(callback);});
  },

  registerDraggableForMovingWithinTree: function(tree) {
    if(this.addChildrenCallback == null) {return;}
    
    var innerElement = this.innerElement();
    Droppables.removeDropableByElementId(innerElement.id);
    
    Droppables.add(innerElement, Object.extend({
      accept: (this.acceptableChildCardTypes || []).concat(['search-results-container-clone']),
      hoverclass: 'nodedrop',
      onDrop: this.onDrop.bind(this)
    }, PuffDroppables));
    
    this.children.each(function(child){ child.registerDraggableForMovingWithinTree(tree);});

    if(this.isRoot()) {
      return;
    }

    var options = new CardDragOptions(tree);
    options = Object.extend(options, {
      starteffect: function(element) {
        if(this.allCardCount > 0){
          this.showStackedCardsNumber(element);
        }
        element._opacity = Element.getOpacity(element);
        Draggable._dragging[element] = true;//this make dragdrop.js work
        Draggable._dragging[element.id] = true;//Draggable._dragging[element] has problem with key of html element, should use id to identify the element
        if(!Prototype.Browser.LessOrEqualIE6){//see application.rhtml
          new Effect.Opacity(element, {duration:0.2, from:element._opacity, to:0.7});
        }
      }.bind(this),
      
      revert: function(element) {
        this.revertEffect();
        this.hideStackedCardsNumber(element);
        if(element._isDragging && element._autoscrolled) {
          element._autoscrolled = false;
          TreeView.centralizeOn(element);
        }
      }.bind(this),
      
      endeffect: this.endDragAndDropEffectWithChildren.bind(this),
      
      change: this.onDragging.bind(this),
      
      dragElement: function(element){
        return this.element;
      }.bind(this)
    });
    new Draggable(this.innerElement(), options);
  },
  
  onDrop: function(dropElement, lastActiveElement, event) {
    if(TreeView.isOutSide([Event.pointerX(event), Event.pointerY(event)])) {
      $(dropElement).revertStatus = 'revert';
      return;
    }
    PuffDroppables.onDeactivate(this.element);
    if(dropElement.isOutside) {
      this._onDropCardFromCardExplorer(dropElement);
    }else {
      this._onMovingWithinTheTree(dropElement);
    }
  },

  _onDropCardFromCardExplorer: function(dropElement) {
    if(dropElement.hasClassName("search-results-container-clone")) {
      var childNumbers = dropElement.childElements().collect(function(element) { return element.getAttribute('number'); });
      this.addChildrenCallback(this.number,this.expanded, childNumbers.join(','), 'new_cards');
    }else {
      this.addChildrenCallback(this.number,this.expanded, dropElement.getAttribute('number'), 'new_cards');
    }
  },
  
  _onMovingWithinTheTree: function(childElement) {
    this.fixIEZindexBugsRecursively(childElement.firstChild, '');
    var childNode = this.rootNode().findNodeByNumber(childElement.getAttribute('number'));
    if(this.children.include(childNode)) {
      childElement.revertStatus = "revert";
      return;
    }
    childNode.invokeDescendants('cancelMovingEffect');
    var oldParentNodes = childNode.ancestors();
    this.addChild(childNode);
    
    TreeView.redraw();
    
    var outOfUpdates = oldParentNodes.concat(this).concat(this.ancestors()).concat([childNode]).concat(childNode.descendants());      
    
    if(TreeView.nodesOutOfUpdates) {
      TreeView.nodesOutOfUpdates = TreeView.nodesOutOfUpdates.concat(outOfUpdates);
    }else {
      TreeView.nodesOutOfUpdates = outOfUpdates;
    }
    this.addChildrenCallback(this.number, this.expanded, childElement.getAttribute('number'), null, childNode.subtreeSize());
  },
  
  endDragAndDropEffectWithChildren: function(element) {
    this.eachElementWithoutConnector(this.endDragAndDropEffect.bind(this));
  },
  
  endDragAndDropEffect: function(element) {
    var toOpacity = Object.isNumber(element._opacity) ? element._opacity : 1.0;
    new Effect.Opacity(element, {duration:0.2, from:0.7, to:toOpacity, 
      afterFinish: function(){ 
        Draggable._dragging[element] = false;
        Draggable._dragging[element.id] = false;
      }
    });
  },
  
  onDragging: function(draggable) {
  },

  onStartDrag: function(draggable) {
    draggable.delta = draggable.currentDelta();
    draggable.element.setStyle({zIndex: '1000'});
    this.fixIEZindexBugsRecursively(draggable.element, '999');
    this.startEffect(draggable);
    TreeView.redraw.bind(TreeView).delay(0.1);
  },
  
  startEffect: function(draggable) {
    this.element._autoscrolled = false;
    if(draggable.element == this.element) {return;}
    draggable.options.starteffect(this.element);
  },
  
  revertEffect: function() {
    this.element.setStyle({left: '', top: ''});
    this.cancelMovingEffect();
    TreeView.redraw.bind(TreeView).delay(0.1);
  },
  
  cancelMovingEffectWithResetZIndex: function() {
    this.cancelMovingEffectWithoutResetZIndex();
    this.fixIEZindexBugsRecursively(this.element, '');
    this.element.setStyle({zIndex: ''});
  },
  
  fixIEZindexBugsRecursively: function(nodeElement, zIndexValue) {
    if(Prototype.Browser.IE){
      Element.ancestors(nodeElement).select(function(element){
        return Element.hasClassName(element, 'vtree-node');
      }).each(function(nodeElement){
        nodeElement.setStyle({zIndex: zIndexValue});
      });
    }
  },
  
  showStackedCardsNumber: function(element) {
    var numberPanel = Builder.node('span', {className: 'stacked-card-number'});
    
    numberPanel.innerHTML = '<span>' + (this.subtreeSize()) + '</span>';
    
    element.stackedCardNumberPanel = numberPanel;
    element.appendChild(numberPanel);
    element.addClassName('multiple-node-on-dragging');
  },
  
  hideStackedCardsNumber: function(element) {
    if(element.stackedCardNumberPanel){
      element.stackedCardNumberPanel.remove();
      element.stackedCardNumberPanel = null;
      element.removeClassName('multiple-node-on-dragging');
    }
  },
  
  
  aliasMethodChain: [['cancelMovingEffect', 'resetZIndex']],
  
  eachElementWithoutConnector: function(action) {
    action(this.element);
    this.children.each(function(child) {child.eachElementWithoutConnector(action);});
  }
};

// extentions for scriptaculous dragdrop.js
Object.extend(Class, {
    superrise: function(obj, names){
        names.each( function(n){ obj['super_' + n] = obj[n]; } );
        return obj;
    }
});

// Draggable that allows substitution of draggable element
// TODO think of a better name
var SubsDraggable = Class.create();
SubsDraggable.prototype = Object.extend({}, Draggable.prototype);
Class.superrise(SubsDraggable.prototype, ['initialize', 'initDrag', 'finishDrag']);
Object.extend( SubsDraggable.prototype , {
    initialize: function(event) {
        this.super_initialize.apply(this, arguments);
        if( typeof(this.options.dragelement) == 'undefined' ) {this.options.dragelement = false;}
    },
    initDrag: function(event) {
      document.observe('selectstart', function(event){Event.stop(event); return false;});
      if(this.isNotDraggableElement(event)){
        return;
      }
      if(Event.isLeftClick(event)) {
        this.dragging = true;
        if( this.options.dragelement ){
            this._originalElement = this.element;
            this.element = this.options.dragelement(this.element);
        }
        this.super_initDrag(event);
      }
    },
    finishDrag: function(event, success) {
      document.stopObserving('selectstart');
      this.dragging = false;
      this.super_finishDrag(event, success);

      if( this.options.dragelement){
        Element.remove(this.element);
        this.element = this._originalElement;
        this._originalElement = null;
      }
    },
    isNotDraggableElement: function(event) {
      if(Event.element(event).tagName.toLowerCase() == "input"){
        Event.stop(event);
        return true;
      }
      return false;
    }
});

Module.mixin(Droppables, {
  deactivateWithFiringEvent: function(drop) {
    this.deactivateWithoutFiringEvent(drop);
    if(drop.onDeactivate) {
      drop.onDeactivate(drop.element);
    }
  },
  
  aliasMethodChain: [['deactivate', 'firingEvent']]
});

PuffDroppables = {
  onHover: function(element, dropElement, position) {
    if(dropElement._scaling) {return;}

    dropElement._scaling = new Effect.Scale(dropElement, 115, {duration: 0.3, scaleFromCenter: true, scaleContent: true});
    // dropElement.style.zIndex = 50;
  },
  
  onDeactivate: function(dropElement) {
    if(dropElement._scaling) {
      var originalStyle = dropElement._scaling.originalStyle;
      dropElement._scaling.cancel();
      dropElement.setStyle(originalStyle);
      dropElement._scaling = null;
    }
  }
};
