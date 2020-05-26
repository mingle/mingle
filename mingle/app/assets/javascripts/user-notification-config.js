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
  $(document).ready(function() {
    if ($(".notification-preview").length === 0) {
      return;
    }

    $(".user-notifications-form").on("input", "textarea,input[type='text'],input[type='url']", function(e) {
      var input = $(e.target);
      var value = $.trim(input.val());
      var name = $(e.target).attr("name");
      var element = $("[data-name='" + name + "']");

      if ("" !== value) {
        input.removeClass("missing");
      }

      switch(name) {
        case "user_notification_avatar":
          if ("" === value) {
            element.removeAttr("src");
            element.addClass("hidden");
          } else {
            element.attr("src", value);
            element.removeClass("hidden");
          }
          break;
        case "user_notification_url":
          element.find("a").attr("href", value);

          if ("" === value) {
            element.hide();
          } else {
            element.show();
          }
          break;
        default:
          if ("" === value) {
            element.text(element.data("default"));
          } else {
            element.text(value);
          }
          break;
      }
    }).on("submit", function(e) {
      var form = $(e.target);
      var result = true;

      form.find("[required]").each(function(i, el) {
        if ("" === $.trim($(el).val())) {
          $(el).addClass("missing");
          result = false;
        }
      });

      return result;
    });
  });
})(jQuery);
