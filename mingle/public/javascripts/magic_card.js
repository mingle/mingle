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
// MagicCard is depending on swimming pool to clean up droppables
MagicCard = Class.create({
  initialize: function(id) {
    // checkout this with css, need to be same
    this.cardBorderWidths = 0;
    this.cardMargins = 0;

    this.element = $(id);
    this.originalDimensions = this.element.getDimensions();
    this.draggingFromPointer = this.element.cumulativeOffset();
    this.effects = [];
    this.element.observe("mousedown", this.refuseIfNotDraggable.bind(this));
    this.droppable = false;
  },

  initDroppables: function(tableId) {
    this.destroyDraggable();
    if (!$(tableId)) { return; }
    var droppableOption = {
      accept      : 'magic_card_droppable',
      hoverclass  : 'cell-highlighted',
      onDrop      : this.onMagicCardDrop.bind(this),
      //the following events handlers add/move/remove place holder in lane if the place holder was specified
      onHover     : this.onLaneHover.bind(this),
      onActivate  : this.onCardEnter.bind(this),
      onDeactivate: this.onCardExit.bind(this)
    };
    var hasDroppable = false;
    $(tableId).select('td').each(function(cell) { hasDroppable = true; Droppables.add(cell, droppableOption); });
    if (hasDroppable) {
      this.makeElementDraggable();
    }
  },

  makeElementDraggable: function() {
    this.draggable = new Draggable(this.element, {
      revert: true,
      reverteffect: this.revertEffect.bind(this),
      onStart: this.onDragStart.bind(this),
      change: this.onChange.bind(this)
    });
  },

  destroy: function() {
    this.clearEffects();
    this.destroyDraggable();
  },

  destroyDraggable: function() {
    if (this.draggable) {
      this.draggable.destroy();
      this.draggable = null;
    }
  },

  onDragStart: function(draggable, event) {
    this.revertTo = this.doRevertEffect.bind(this);
  },

  onChange: function(draggable, event) {
    var pointer = this.element.cumulativeOffset();
    var elementHeight = this.element.getHeight();
    // here 4 is for having a gap between resize and revert size, so that MagicCard won't resize a lot when user drags slowly.
    if (pointer.top > (this.draggingFromPointer.top - elementHeight/4)) {
      this.markUndroppable();
    } else if (pointer.top < this.draggingFromPointer.top - elementHeight) {
      this.markDroppable();
    }
  },

  markUndroppable: function() {
    if (!this.droppable) {
      return;
    }
    this.droppable = false;
    this.element.removeClassName('magic_card_droppable');
    this.clearEffects();
    this.revertSize();
  },

  markDroppable: function() {
    if (this.droppable) {
      return;
    }
    this.droppable = true;
    this.element.addClassName('magic_card_droppable');
    this.resizeForDragging();
  },

  onMagicCardDrop: function(draggableElement, cell, event) {
    this.revertTo = this.rememberRevertPosition.bind(this);
    this.runEffects([new Effect.Fade(this.element, { duration: 1, onCancel: this.showElement.bind(this)})]);
    var lane = cell.getAttribute("lane_value");
    var row = cell.parentNode.getAttribute("row_value");
    this.revealPopup(lane, row);
  },

  revealPopup: function(lane, row) {
    var parameters = {};
    this.setCardProperty(parameters, this.laneName, lane);
    this.setCardProperty(parameters, this.rowName, row);
    this.request(Object.toQueryString(parameters));
  },

  setCardProperty: function(parameters, name, value) {
    if(name) {
      parameters['card_properties['+ name +']'] = value;
    }
  },

  revertEffect: function(element, top_offset, left_offset) {
    this.revertTo(element, top_offset, left_offset);
  },

  rememberRevertPosition: function(element, top_offset, left_offset) {
    this.revertToPosition = [element, top_offset, left_offset];
  },

  doRevertEffect: function(element, top_offset, left_offset) {
    if (element.visible()) {
      this.runEffects([new Effect.Move(element, { duration: 0.5, x: -left_offset, y: -top_offset})]);
    } else {
      this.runEffects([
        new Effect.Move(element, { duration: 0, x: -left_offset, y: -top_offset}),
        new Effect.Appear(element, {duration: 1, onCancel: this.showElement.bind(this)})
      ]);
    }
    this.revertSize();
  },

  resizeForDragging: function() {
    var cardSize = this.getDroppingCardDimensions();
    var scale = cardSize.width / this.element.getWidth() * 100;
    var fixDimensions = function(){
      var width = this.convertToStyleWidth(cardSize.width);
      var height = this.convertToStyleHeight(cardSize.height);
      this.element.setStyle({width: width + 'px', height: height + 'px'});
    }.bind(this);
    this.runEffects([new Effect.Scale(this.element, scale, {
      transition: Effect.Transitions.spring,
      duration: 0.5,
      afterFinish: fixDimensions,
      onCancel: fixDimensions
    })]);
  },

  revertSize: function(cancelEffects) {
    var dimensions = this.originalDimensions;
    var width = this.convertToStyleWidth(dimensions.width);
    var height = this.convertToStyleHeight(dimensions.height);
    this.element.setStyle({
      width: width + 'px',
      height: height + 'px'
    });
  },

  revert: function() {
    if (this.revertToPosition) {
      this.doRevertEffect(this.revertToPosition[0], this.revertToPosition[1], this.revertToPosition[2]);
      this.revertToPosition = null;
    }
  },

  convertToStyleWidth: function(width) {
    return width - this.cardBorderWidths - this.cardMargins;
  },
  convertToStyleHeight: function(height) {
    return height - this.cardBorderWidths - this.cardMargins;
  },
  showElement: function() {
    this.element.setOpacity(1);
    this.element.show();
  },

  clearEffects: function() {
    this.effects.each(function(effect) {
      if (effect.state != 'finished') {
        if (effect.options.onCancel) {
          effect.options.onCancel();
        }
        effect.cancel();
      }
    });
    this.effects = [];
  },

  runEffects: function(effects) {
    this.clearEffects();
    this.effects = effects;
  },

  refuseIfNotDraggable: function() {
    if (this.draggable) { return; }
    new Effect.Shake(this.element, {duration: 0.3, distance: 5});
  },

  onLaneHover: function(draggable, droppable) {
    if (!this.placeHolder) { return; }
    this.placeHolder.show(droppable, this.element);
  },

  onCardEnter: function(droppable) {
    if (!this.placeHolder) { return; }
    this.placeHolder.moveInto(droppable);
  },
  onCardExit: function(droppable) {
    if (!this.placeHolder) { return; }
    this.placeHolder.hide();
  }
});

CardPlaceHolder = Class.create({
  initialize: function(template, childrenCssSelector) {
    this.element = template;
    this.childrenCssSelector = childrenCssSelector;
  },

  moveInto:function(container) {
    container.appendChild(this.element);
    this.element.show();
    this.positionElements = container.select(this.childrenCssSelector);
    this.positionElements.push(this.element);
    this.distanceRuler = new SwimmingPool.DistanceRuler(this.positionElements.invoke('cumulativeOffset'));
  },

  show: function(container, closeToElement) {
    var positionElement = this._findClosestPositionElement(closeToElement);
    if (positionElement == null || this.positionElements.last() == positionElement) {
      container.appendChild(this.element);
    } else {
      container.insertBefore(this.element, positionElement);
    }
    this.element.show();
  },

  hide: function() {
    this.positionElements = null;
    this.distanceRuler = null;
    this.element.hide();
  },

  _findClosestPositionElement: function(target) {
    if (this.positionElements.length == 0) {
      return null;
    }
    var indexOfNearestElement = this.distanceRuler.nearestIndexToExcludingDraggable(this.cumulativeOffsetWithScrollOffsets(target), -1);
    return this.positionElements[indexOfNearestElement];
  },

  positionTop: function(element) {
    return element.cumulativeOffset()[1];
  },

  cumulativeOffsetWithScrollOffsets: function(element) {
    if (this.fixedPosition(element)) {
      var scrollOffset = document.viewport.getScrollOffsets();
      var offset = element.cumulativeOffset();
      return Element._returnOffset(offset[0] + scrollOffset[0], offset[1] + scrollOffset[1]);
    } else {
      return element.cumulativeOffset();
    }
  },

  fixedPosition: function(element) {
    do {
      if (Element.getStyle(element, 'position') == 'fixed') {
        return true;
      }
      element = element.offsetParent;
    } while (element);
    return false;
  }
});
