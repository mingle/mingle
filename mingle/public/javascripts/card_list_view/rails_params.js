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
var RailsParams = Class.create({
  initialize: function(params) {
    this.params = $H(params);
  },
  
  each: function(iterator){
    this.flatten().each(iterator);
  },
  
  get: function(key){
    return this.params.get(key);
  },
  
  merge: function(paramsToMerge) {
    if(!paramsToMerge) { return this; }
    return new RailsParams(this.params.merge(paramsToMerge));
  },
  
  exclude: function(keys) {
    if(!keys) { return this; }
    var excluded = this.params.clone();
    keys.each(function(key) { excluded.unset(key); });
    return new RailsParams(excluded);
  },
    
  toQueryString: function() {
    return this.flatten(encodeURIComponent).collect(function(pair){
      return  pair.first() + '=' + pair.last();
    }).join('&');
  },
  
  flatten: function(encoder) {
    if(!encoder) {
      encoder = Prototype.K;
    }
    
    return this.params.inject($A(), function(memo, pair){
      var key = encoder(pair.first());
      var value = pair.last();
      
      if(typeof value != 'object'){
        if(!value) {
          return memo;
        }
        if(Object.isString(value) && value.blank()) {          
          return memo;
        }
        memo.push([key, encoder(value)]);
        
      } else if(Object.isArray(value)){
        
        value.each(function(element){
          memo.push([key + '[]', encoder(element)]); 
        });
        
      } else {
        
        $H(value).each(function(element){
          var lastValue = element.last();
          if(typeof lastValue === 'object' && !Object.isArray(lastValue) ){
            $H(lastValue).each(function(nestedElement){
                memo.push([key + '[' + encoder(element.first()) + ']['+nestedElement.first()+']', encoder(nestedElement.last())]);
            });
          }
          else
            memo.push([key + '[' + encoder(element.first()) + ']', encoder(lastValue)]);
        });
      }
      return memo;
    });
  },
  
  equal: function(another) {
    return Object.toJSON(this._sortedParams()) === Object.toJSON(another._sortedParams());
  },
  
  toString: function() {
    return '#<RailsParams:{' + this.params.map(function(pair) { return pair.map(Object.inspect).join(': '); }).join(', ') + '}>';
  },
  
  _sortedParams : function() {
    return this.params.sortBy(function(pair){ return pair[0]; });
  }
});