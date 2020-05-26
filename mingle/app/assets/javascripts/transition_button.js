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
  function renderTransitionList(container, transitions) {
    $.each(transitions, function(_, transition) {
      var link = $('<a href="#"></a>').
        attr("id", "transition_" + transition.id).
        attr("title", transition.name).
        text(transition.name).
        click(function(event) {
          event.preventDefault();
          var button = $(this).parents(".transitions-button");
          button.find('.link_as_button').trigger("mingle.selectTransition");
          button.popoverClose();
          if(transition.require_popup) {
            TransitionExecutor.popup(transition.id, transition.card_id, transition.project_id);
          } else {
            TransitionExecutor.execute(transition.id, transition.card_id, transition.card_number, transition.project_id);
          }
        });

      container.append($('<li class="transition"></li>').append(link));
    });
  }

  $.fn.showApplyTransitionError = function(msg) {
    var errorMsg = $('<div class="card-error-message"/>').
      html('Something went wrong:  <div class="reason">' + msg + "</div>");
    errorMsg.css('left', $(this[0]).position().left);
    $(this[0]).append(errorMsg);
    setTimeout(function() { errorMsg.remove(); }, 5000);
  };

  MingleUI.readyOrAjaxComplete(function() {
    $(".transitions-button").popover({
      beforeShow: function(content) {
        content.html("");

        var element = $(this);

        element.addClass("loading");
        element.find('.link_as_button').withProgressBar({ event: "mingle.selectTransition" });

        $.ajax(element.data("url"), {
          dataType: "json",
          success: function(data) {
            renderTransitionList(content, data);
          },

          complete: function() {
            element.removeClass("loading");
          }
        });
      }
    });
  });
})(jQuery);
