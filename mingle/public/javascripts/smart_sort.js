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

var SmartSort = {
  maxLenOfNum: function(array) {
    var nums = array.join(',').split(/[^\d]+/).reject(function(n){return n.blank();});
    if(nums.size() == 0) {
      return 0;
    }
    return nums.collect(function(n) {return parseInt(n);}).sortBy(function(o){return o;}).last().toString().length;
  },

  criteria: function(str, maxLen) {
    if(!Object.isString(str)) {
      return str;
    }
    
    str = str.toString().toLowerCase();

    if(maxLen == 0) {return str;}

    var nums = str.split(/[^\d]+/).reject(function(n){return n.blank();}).collect(function(num) {
      if(num.length < maxLen) {
        (maxLen - num.length).times(function(index) {
          num = '0' + num;
        });
      }
      return num;
    });

    var strs = str.split(/\d+/).reject(function(o){return o.blank();});
    return (/^\d/.test(str) ? nums.zip(strs) : strs.zip(nums)).flatten().compact().join();
  }
};

var Smartsortable = {
  smartSort: function() {
    var maxLen = SmartSort.maxLenOfNum(this);
    return this.sortBy(function(o) {
      return SmartSort.criteria(o, maxLen);
    });
  },
  
  smartSortBy: function(stringOrFunction) {
    var maxLen;
    if(Object.isString(stringOrFunction)) {
      maxLen = SmartSort.maxLenOfNum(this.invoke(stringOrFunction));
      return this.sortBy(function(o) {
        return SmartSort.criteria(o[stringOrFunction](), maxLen);
      });
    }else {
      maxLen = SmartSort.maxLenOfNum(this.collect(stringOrFunction));
      return this.sortBy(function(o) {
        return SmartSort.criteria(stringOrFunction(o), maxLen);
      });
    }
  }
};

Object.extend(Array.prototype, Smartsortable);
