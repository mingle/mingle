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
  window.MingleUI = {};

  var hooks = [];

  function readyOrAjaxComplete(fn) {
    if ("function" === typeof fn) {
      hooks.push(fn);
    }
  }

  function applyHooks() {
    for (var i = 0, len = hooks.length; i < len; i++) {
      hooks[i].apply();
    }
  }

  function attach() {
    $(document).on("ajaxComplete", applyHooks);
    Ajax.Responders.register({
      onComplete: applyHooks
    });
  }

  function updateUserPreference(preference, value) {
    var url = $("[data-user-display-preference-url]").data("user-display-preference-url");
    var key = "user_display_preference[" + preference + "]";
    var data = {};
    data[key] = value;
    $.post(url, data);
  }

  function resetScrollPosition() {
    if (this.scrollPosition) {
      if ($j(window).scrollTop() == this.scrollPosition.top &&  $j(window).scrollLeft() == this.scrollPosition.left) {
        $j(window).scroll(); // Trigger scroll event to ensure sticky headers position gets fixed based on scroll state
      } else {
        $j(window).scrollTop(this.scrollPosition.top);
        $j(window).scrollLeft(this.scrollPosition.left);
      }
      this.scrollPosition = null;
    }
  }

  $.extend(MingleUI, {
    readyOrAjaxComplete: readyOrAjaxComplete,
    updateUserPreference: updateUserPreference,
    resetScrollPosition: resetScrollPosition
  });

  $(document).ready(function() {
    attach();
    applyHooks();
  });


})(jQuery);
