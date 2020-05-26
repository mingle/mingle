// Copyright (c) 2006 Michael Daines (http://www.mdaines.com)
// 
// Permission is hereby granted, free of charge, to any person obtaining
// a copy of this software and associated documentation files (the
// "Software"), to deal in the Software without restriction, including
// without limitation the rights to use, copy, modify, merge, publish,
// distribute, sublicense, and/or sell copies of the Software, and to
// permit persons to whom the Software is furnished to do so, subject to
// the following conditions:
// 
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
// LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
// OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
// WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

// Constrain a number between two values.
Number.prototype.constrain = function(lower, upper) {
  if ( this > upper) return upper;
  else if (this < lower) return lower;
  else return this;
}

// Constrain a draggable element within its parent (give this to Draggable for snapping).
Element.constrain_within_parent = function(x, y, draggable) {
  element_dimensions = Element.getDimensions(draggable.element);
  parent_dimensions = Element.getDimensions(draggable.element.parentNode);
  
  x = new Number(x).constrain(0 - Math.round(element_dimensions.width/2) + 1, parent_dimensions.width - Math.round(element_dimensions.width/2));
  y = new Number(y).constrain(0 - Math.round(element_dimensions.height/2) + 1, parent_dimensions.height - Math.round(element_dimensions.height/2));
  
  return [x,y];
}

var ColorSelector = {
  Version: '0.5.5',
  
  selectors: $A(),
  
  options: function(element){
    element = $(element);
    return this.selectors.detect(function(s) { return s.element == element });
  },
  
  destroy: function(element){
    element = $(element);
    this.selectors = this.selectors.reject(function(s) { return s.element == element });
  },

  create: function(element) {
    var options = Object.extend({
      transforms: DefaultTransforms
    }, arguments[1] || {});

    options.element = $(element);
    
    options.dropper = $(document.createElement("DIV"));
    options.dropper.addClassName("dropper");
    options.element.appendChild(options.dropper);
    
    new Draggable(options.dropper, {
      snap: Element.constrain_within_parent,
      change: function() { ColorSelector.reflect_selected_color(options.element, null) },
      starteffect: Prototype.emptyFunction,
      endeffect: Prototype.emptyFunction});
    
    options.field = $(options.field);
    
    this.destroy(options.element);
    this.selectors.push(options);
    
    // if a value field was specified, select the value it contains, otherwise select the supplied value
    if (options.field && options.field.value)
      this.select_color(options.element, options.field.value);
    else if (options.value)
      this.select_color(options.element, options.value);
			//modified lib: a hack for disable checking nil value
			/*    else
      throw "You must supply a value or field!";*/
  },
  
  select_color: function(element, color_value) {
    var options = this.options(element);
    var color = options.transforms.value_to_color(color_value)
    var offset = options.transforms.color_to_offset(color);
    var dropper_dimensions = Element.getDimensions(options.dropper);
    
    options.dropper.style.left = offset[0] - Math.round(dropper_dimensions.width/2) + 'px';
    options.dropper.style.top = offset[1] - Math.round(dropper_dimensions.height/2) + 'px';
  
    this.reflect_selected_color(element, color);
  },
  
	//modified lib: add 'reference_color' to fix problems when element is hidden
  reflect_selected_color: function(element, reference_color) {
    var options = this.options(element);
    var pos = this.position(element);
    if(!reference_color)
			reference_color = options.transforms.offset_to_color(pos[0], pos[1]);
    
    options.dropper.style.background = options.transforms.color_to_style(reference_color);
    if (options.field) options.field.value = options.transforms.color_to_value(reference_color);
  },
  
  position: function(element) {
    var options = this.options(element);
    
    var dropper_offset = Position.cumulativeOffset(options.dropper);
    var dropper_dimensions = Element.getDimensions(options.dropper);
    var colors_offset = Position.cumulativeOffset(options.element);
    
    return [  dropper_offset[0] + Math.round(dropper_dimensions.width/2) - colors_offset[0],
              dropper_offset[1] + Math.round(dropper_dimensions.height/2) - colors_offset[1] ];
  },
  
  color: function(element) {
    var options = this.options(element);
    var position = this.position(element);
    return options.transforms.offset_to_color(position[0], position[1]);
  },
  
  value: function(element) {
    var options = this.options(element);
    return options.transforms.color_to_value(this.color(element));
  }
}
