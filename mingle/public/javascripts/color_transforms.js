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

var Color = {
  // h: 0 to 360; s,v: 0 to 1.0
  hsv2rgb: function(h,s,v) {
    if (h == 360) {h = 0;}
    if (s == 0) {return [v,v,v];}
    var hTemp = h / 60;
    var i = Math.floor(hTemp);
    var f = hTemp - i;
    var p = v * (1 - s);
    var q = v * (1 - (s * f));
    var t = v * (1 - (s * (1 - f)));
    switch(i){
      case 0: return [v,t,p];
      case 1: return [q,v,p];
      case 2: return [p,v,t];
      case 3: return [p,q,v];
      case 4: return [t,p,v];
      case 5: return [v,p,q];
      default: throw "error h number: " + h;
    }
  },
  // r,g,b: 0 to 1.0
  rgb2hsv: function(r,g,b) {
    var min = Math.min(r,g,b);
    var v = Math.max(r,g,b);
    var d = v - min;
    var h = null;
    var s = (v == 0) ? 0 : d / v;
    if (s == 0) {
      h = 0;
    } else {
      if (r == v) {
        h = 60 * (g - b) / d;
      } else {
        if (g == v) {
          h = 120 + 60 * (b - r) / d;
        } else {
          if (b == v) { h = 240 + 60 * (r - g) / d; }
        }
      }
      if (h < 0 ) { h += 360; }
    }
    h = (h == 0) ? 360 : h;
    return [h,s,v];
  }
};

// Find the index of the closest number in an array of numbers.
Array.prototype.closest_index = function(value) {
  var diffs = this.map(function(v) { return Math.abs(v - value); });
  return diffs.indexOf(diffs.min());
};

var DefaultTransforms = {
  GRAY_VALUES: $R(0,38).map(function(v){return Math.round((v/38)*100)/100;}).reverse(),
  COLOR_SATURATIONS: $R(1,20).map(function(v){return v/20;}),
  COLOR_VALUES: $R(1,20).map(function(v){return v/20;}).reverse(),
  color_to_offset: function(color) {
    var top, left;
    var hue = color[0]; var saturation = color[1]; var value = color[2];
    hue = hue % 360;
    if (saturation == 0) {
      top = this.GRAY_VALUES.closest_index(value)+1;
      left = 190;
    } else {
      left = (hue/2)+1;
      if (value == 1.0) {top = this.COLOR_SATURATIONS.closest_index(saturation)+1;}
      else {top = 20 + this.COLOR_VALUES.closest_index(value);}
    }
    
    return [left, top];
  },
  offset_to_color: function(left, top) {
    var hue, saturation, value;
    
    // colors
    if (left <= 180) {
      hue = (left-1)*2;
      if (top > 20) {
        saturation = 1.0;
        value = this.COLOR_VALUES[top-20];
      } else {
        saturation = this.COLOR_SATURATIONS[top-1];
        value = 1.0;
      }

    // grays
    } else {
      hue = 0;
      saturation = 0;
      value = this.GRAY_VALUES[top-1];
    }

    return [hue, saturation, value];
  },
  color_to_style: function(color) {
    return 'rgb(' + $A(Color.hsv2rgb(color[0],color[1],color[2])).map(function(p){return Math.round(p*255);}).join(',') + ')';
  },
  value_to_color: function(value) {
    var c = $A(value.match(/\d+/g)).map(function(p){return p/255;});
    return Color.rgb2hsv(c[0],c[1],c[2]);
  },
  color_to_value: function(color) {
    return $A(Color.hsv2rgb(color[0],color[1],color[2])).map(function(p){return Math.round(p*255);}).join(',');
  }
};

var HexTransforms = Object.extend(Object.extend({}, DefaultTransforms), {
  value_to_color: function(rgb) {
    if(!(/^#.{6}/.test(rgb))) {return Color.rgb2hsv(1,1,1);}
    var hexs  = rgb.slice(1);
    var c = $A(hexs.match(/../g)).map(function(p) { return parseInt(p, 16)/255; });
    return Color.rgb2hsv(c[0], c[1], c[2]);
  },
  color_to_value: function(c) {
    return "#" + $A(Color.hsv2rgb(c[0], c[1], c[2])).map(function(p){ return Math.round(p*255).toColorPart(); }).join('');
  }
});