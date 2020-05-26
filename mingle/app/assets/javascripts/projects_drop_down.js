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
(function($) {

  MingleUI.projectMenu = {
    close: $.noop
  };

  $.fn.projectsDropDown = function(currentProject, projectsUrl) {
    var dropdown = this;

    function loadProjects(content, input) {
      input.prop("disabled", true);

      $.ajax({
        dataType: 'json',
        url: projectsUrl,
        success: function(data) {
          var cache = $.map(data, function(project) {
            if (project.identifier === currentProject) {
              return;
            }
            return {label: project.name, value: project.identifier, url: projectsUrl + '/' + project.identifier};
          });

          dropdown.data("cache", cache);
            // Show all results when opening the dropdown
            input.prop("disabled", false).focus().filteredList("search", "");
          }
        });
    }

    function goToProject(e, ui) {
      var userInputEvent = e.originalEvent.originalEvent;
      if (userInputEvent && (/^key/.test(userInputEvent.type))) {
        e.preventDefault();
        window.location.href = ui.item.url;
      }
    }

    function closeDropdown(e) {
      var returnVal;
      if (e && /key/.test(e.type) && dropdown.is(":visible")) {
        returnVal = false;
      }

      dropdown.popoverClose();

      return returnVal;
    }

    // allow global hotkeys to handle close on ESC key
    MingleUI.projectMenu.close = closeDropdown;

    dropdown.fuzzyDropDown({
      containerClass: "projects",
      itemClass: "project-name",
      onselect: goToProject,
      beforeShow: loadProjects,
      closeOnEscFn: $.noop // handle ESC-key close elsewhere (global hotkeys)
    });
  };

})(jQuery);
