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
var MingleUI = (MingleUI || {});

MingleUI.TagsFilter = function(name, container, projectData, options) {
  this.name = name;
  var self = this, onUpdate = ensureFunction(options.onUpdate), tagEditor, project = projectData;

  function processTagsData(tagsData) {
    return tagsData.reduce(function (data, tag) {
      data[tag.name] = tag.color;
      return data;
    }, {});
  }

  function initTagEditor() {
    tagEditor = $j('<ul>', {
      class: 'tags-filter ui-front',
      data: {
        allTags: processTagsData(project.tags),
        projectIdentifier: project.identifier
      }
    });
    self.htmlContainer.append(tagEditor);
  }

  function handleUpdate(){
    onUpdate && onUpdate(self);
  }

  function initialize() {
    self.htmlContainer = $j(container);
    self.htmlContainer.empty();
    initTagEditor();
    refreshTagEditor(tagEditor, {
      allowNewTags: false,
      enableColorSelector: false
    });
    tagEditor.tageditor('assignTags', options.initialTags || []);
    tagEditor.tageditor('setEventCallback', 'afterTagAdded', handleUpdate);
    tagEditor.tageditor('setEventCallback', 'afterTagRemoved', handleUpdate);
  }

  this.reset = function(projectData) {
    project = projectData;
    initialize();
  };

  this.getTags = function() {
    return tagEditor.tageditor('assignedTags');
  };

  this.value = function(){
    return this.getTags();
  };

  initialize();
};
