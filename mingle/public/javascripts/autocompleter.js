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
// This is a modified version of Autocompleter.Local in Scriptaculous. It has been modified to escape html.
// --------------------------------------------------------------------------------------------------------

// Copyright (c) 2005-2008 Thomas Fuchs (http://script.aculo.us, http://mir.aculo.us)
//           (c) 2005-2007 Ivan Krstic (http://blogs.law.harvard.edu/ivan)
//           (c) 2005-2007 Jon Tirsen (http://www.tirsen.com)
// Contributors:
//  Richard Livsey
//  Rahul Bhargava
//  Rob Wills
// 
// script.aculo.us is freely distributable under the terms of an MIT-style license.
// For details, see the script.aculo.us web site: http://script.aculo.us/

Autocompleter.Mingle = Class.create(Autocompleter.Base, {
    initialize: function(element, update, array, options) {
      this.baseInitialize(element, update, options);
      this.options.array = array;
    },

    getUpdatedChoices: function() {
      this.updateChoices(this.options.selector(this));
    },

    setOptions: function(options) {
      this.options = Object.extend({
        choices: 10,
        partialSearch: true,
        partialChars: 2,
        ignoreCase: true,
        fullSearch: false,
        selector: function(instance) {
          var ret       = []; // Beginning matches
          var partial   = []; // Inside matches
          var entry     = instance.getToken();
          var count     = 0;

          for (var i = 0; i < instance.options.array.length &&  
            ret.length < instance.options.choices ; i++) { 

            var elem = instance.options.array[i];
            var foundPos = instance.options.ignoreCase ? 
              elem.toLowerCase().indexOf(entry.toLowerCase()) : 
              elem.indexOf(entry);

            while (foundPos != -1) {
              if (foundPos == 0 && elem.length != entry.length) { 
                ret.push(("<li><strong>" + elem.substr(0, entry.length).escapeHTML() + "</strong>" + 
                  elem.substr(entry.length).escapeHTML() + "</li>"));
                break;
              } else if (entry.length >= instance.options.partialChars && 
                instance.options.partialSearch && foundPos != -1) {
                if (instance.options.fullSearch || (/\s/).test(elem.substr(foundPos-1,1))) {
                  partial.push("<li>" + (elem.substr(0, foundPos).escapeHTML() + "<strong>" +
                    elem.substr(foundPos, entry.length).escapeHTML() + "</strong>" + elem.substr(
                    foundPos + entry.length).escapeHTML()) + "</li>");
                  break;
                }
              }

              foundPos = instance.options.ignoreCase ? 
                elem.toLowerCase().indexOf(entry.toLowerCase(), foundPos + 1) : 
                elem.indexOf(entry, foundPos + 1);

            }
          }
          if (partial.length){
            ret = ret.concat(partial.slice(0, instance.options.choices - ret.length));
          }
          return "<ul>" + ret.join('') + "</ul>";
        }
      }, options || { });
    }
});

