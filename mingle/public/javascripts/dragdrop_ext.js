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
Draggable.isDragging = function () {
    return $H(Draggable._dragging).any(function(entry) { return entry.value; });
};


// this make an option a draggable to disable dragging for some inner element.
Module.mixin(Draggable.prototype, {
  initDragWithExcludeElement: function(event) {
    var src = Event.element(event);
    if(this.options.excludeElement && this.options.excludeElement.call(this, src)) {
      return;
    }
    this.initDragWithoutExcludeElement(event);
  },

  aliasMethodChain: [['initDrag', 'excludeElement']]
});

// This extension add onActivate onDeactivate event to Droppables
Module.mixin(Droppables, {
  show: function(point, element) {
    if(!this.drops.length) {return;}
    var drop, affected = [];

    for(var index = 0; index < this.drops.size(); index++){
      if(Droppables.isAffected(point, element, this.drops[index])){
        affected.push(this.drops[index]);
      }
    }

    if(affected.length>0){
      drop = Droppables.findDeepestChild(affected);
    }

    if(this.last_active && this.last_active != drop) {
      this.deactivate(this.last_active);
    }
    if (drop) {
      Position.within(drop.element, point[0], point[1]);

      // This following line moved from bottom to here to make sure onActivate happens before onHover
      if (drop != this.last_active) {
        Droppables.activate(drop);
      }

      if(drop.onHover){
        drop.onHover(element, drop.element, Position.overlap(drop.overlap, drop.element));
      }
    }
  },

  removeDropableByElementId: function(elementId) {
    this.drops = this.drops.reject(function(drop) {
      return drop.element.id == elementId;
    });
  },

  activateWithTriggerEvent: function(drop) {
    this.activateWithoutTriggerEvent(drop);
    if(drop.onActivate){
      drop.onActivate(drop.element);
    }
  },

  deactivateWithTriggerEvent: function(drop) {
    this.deactivateWithoutTriggerEvent(drop);
    if(drop.onDeactivate){
      drop.onDeactivate(drop.element);
    }
  },

  aliasMethodChain: [['activate', 'triggerEvent'], ['deactivate', 'triggerEvent']]
});
