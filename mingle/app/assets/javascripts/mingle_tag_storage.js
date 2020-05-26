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
(function($, tinycolor) {

  function MingleTagStorage() {
    var tagsData = {};
    var colorUpdateUrl;
    var observers = [];

    function caseInsensitiveStringComparator(l, r) {
      var left = l.toLowerCase();
      var right = r.toLowerCase();
      if (left < right) {
        return -1;
      }
      if (right < left) {
        return 1;
      }
      return 0;
    }

    function colorFor(tagName) {
      return tagsData[tagName] || '';
    }

    function tagNames() {
      var names = [];
      $.each(tagsData, function(name) {
        names.push(name);
      });
      return names;
    }

    // register observers for the module
    // observer should have to method on the interface:
    //  * afterColorChange (called after any tag color changed)
    this.registerObserver = function(observer, callback) {
      observers.push(observer);

      if ("function" === typeof callback) {
        callback();
      }
    };

    this.init = function(initialTagsData, theColorUpdateUrl) {
      tagsData = initialTagsData;
      colorUpdateUrl = theColorUpdateUrl;
    };

    this.setColor = function(tagName, color, callback) {
      var self = this;
      $.ajax( {
        type: "POST",
        url: colorUpdateUrl,
        data: {
          name: tagName,
          color: color
        }
      }).done(function(data) {
        MingleUI.events.markAsViewed(data.event, "tag::changed::" + data.tagId);
        self.applyColorChange(tagName, color, callback);
      });
    };

    this.colorFor = colorFor;

    this.textColorFor = function(tagName) {
      var backgroundColor = colorFor(tagName);
      if (backgroundColor === '') {
        return '';
      }
      var color = tinycolor.mostReadable(backgroundColor, ['#000000', '#ffffff']);
      return color.toHexString();
    };

    this.applyColorChange = function(tagName, color, callback) {
      tagsData[tagName] = color;
      $.each(observers, function(i, observer) {
        observer.afterColorChange(tagName, color);
      });

      if ("function" === typeof callback) {
        callback();
      }
    };

    this.renameTag = function(oldName, newName) {
      tagsData[newName] = tagsData[oldName];
      delete tagsData[oldName];
    };

    this.addTag = function(tagName, color) {
      if ($.inArray(tagName, tagNames()) === -1) {
        tagsData[tagName] = color || null;
      }
    };

    this.removeTag = function(tagName) {
      if ($.inArray(tagName, tagNames()) !== -1) {
        delete tagsData[tagName];
      }
    };

    this.autoCompleteSource = function(request, response) {
      var sortedTagNames = tagNames().sort(caseInsensitiveStringComparator);

      if (request.term === "*") {
        response(sortedTagNames);
      } else {
        response($.grep(sortedTagNames, function(tagName) {
          return tagName.toLowerCase().indexOf(request.term.toLowerCase()) === 0;
        }));
      }
    };

    this.tagExists = function(tagName) {
      return tagsData.hasOwnProperty(tagName);
    };

  }

  var allStorages = {};

  window.MingleUI = window.MingleUI || {};
  window.MingleUI.tags = {
    current: function() {
      return this.get(MingleUI.currentProject);
    },
    get: function(project) {
      return allStorages[project] || null;
    },
    add: function(project, data, updateUrl) {
      var storage = new MingleTagStorage();
      storage.init(data, updateUrl);
      allStorages[project] = storage;
      return storage;
    }
  };

  $(function() {

    if (MingleUI.currentProject) {
      MingleUI.tags.add(MingleUI.currentProject, $("#tag-storage").removeData("all-tags").data("all-tags"), $("#tag-storage").data("color-update-url"));
    }

  });

}(jQuery, tinycolor));
