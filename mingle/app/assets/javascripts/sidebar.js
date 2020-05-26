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
  var shouldPersistSidebarPreferences;

  Sidebar = {
    attach: function(sidebarPanel, control, header, mainContent) {
      shouldPersistSidebarPreferences = true;

      this.sidebarPanel = $(sidebarPanel);
      this.control = $(control);
      this.header = $(header);
      this.mainContent = $(mainContent);
      this.control.on("click", $.proxy(this.toggle, this));

      this.mainContent.on("transitionend", function() {
        $(document).trigger("mingle:relayout");
      });
    },

    persistState: function() {
      shouldPersistSidebarPreferences = true;
    },

    doNotPersistState: function() {
      shouldPersistSidebarPreferences = false;
    },

    toggle: function() {
      if (this.sidebarPanel.is(".expanded")) {
        this.hide();
      } else {
        this.show();
      }
    },

    hide: function() {
      this.sidebarPanel.removeClass("expanded");
      this.header.removeClass("with-sidebar");
      this.mainContent.removeClass("with-sidebar");
      this.control.removeClass("open");

      if (shouldPersistSidebarPreferences){
        MingleUI.updateUserPreference("sidebar_visible", false);
      }
    },

    show: function() {
      this.sidebarPanel.addClass("expanded");
      this.header.addClass("with-sidebar");
      this.mainContent.addClass("with-sidebar");
      this.control.addClass("open");

      if (shouldPersistSidebarPreferences){
        MingleUI.updateUserPreference("sidebar_visible", true);
      }
    },

    visible: function() {
      return this.sidebarPanel.is(":visible");
    }
  };

})(jQuery);
