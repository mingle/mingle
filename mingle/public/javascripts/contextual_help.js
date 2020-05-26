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
ContextualHelpController = {

  injectContent: function(data, textStatus, jqXHR) {
    $j("#contextual_help").html($j.trim(data));
    $j("#contextual_help_title_placeholder").html($j("#contextual_help_title").html());
    $j("#full_contextual_help_link_placeholder").html($j("#full_contextual_help_link").html());

    $j("#contextual_help_container").data("loaded", true);
  },

  toggle: function() {
    var link = $j("#contextual_help_link");
    var element = $j("#contextual_help_container");
    if (element.is(":visible")) {
      link.html(link.html().replace(/Hide/, "Show"));
      link.removeClass("selected");
      element.hide();
    } else {
      link.html(link.html().replace(/Show/, "Hide"));
      link.addClass("selected");
      element.show();

      if (!element.data("loaded")) {
        var url = element.data("content");
        $j.ajax({
          url: url,
          dataType: "html",
          success: this.injectContent
        });
      }
    }
  }
};
