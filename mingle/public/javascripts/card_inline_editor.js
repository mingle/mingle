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
  $.fn.cardInlineEditor = function(editable) {
    var editor = $(this);
    var form = $(this).find('.inline-edit-form');

    function callTagEditor() {
      var tagEditorElement = form.find('.tageditor');
      return tagEditorElement.tageditor.apply(tagEditorElement, arguments);
    }

    function updateColor(cardColor) {
      if (!cardColor) {
        editor.css("border-left", "none");
      } else {
        editor.css("border-left", "10px solid " + cardColor);
      }

      editor.find(".card-type-editor-container").css("background-color", cardColor).adjustFontColor();
    }

    function updateTransitionButton(count) {
      editor.find(".transitions-button").css("display", count > 0 ? "" : "none");
    }

    function updateFromCardData() {
      updateColor(editor.data("color"));
      updateTransitionButton(editor.data("transitions-count"));
    }


    if (editable) {
      var tagsBeforeEdit = null;

      form.inlineEditForm({
        afterEnterEditMode: function() {
          InputingContexts.top().lightbox.disableBlurClick();
          callTagEditor("setEditMode", true);
          callTagEditor("setAutoSubmit", false);
          callTagEditor("setCancelling", false);
          tagsBeforeEdit = callTagEditor("assignedTags");

          form.find('.card-type-editor-container .card-type-name').html(form.find('#edit-card-types #card_type_name').html());
        },

        afterEnterViewMode: function() {
          InputingContexts.top().lightbox.enableBlurClick();
          callTagEditor("setEditMode", false);
          callTagEditor("setAutoSubmit", true);
          callTagEditor("setCancelling", false);
          tagsBeforeEdit = null;
        },

        onCancel: function() {
          callTagEditor("setEditMode", false);
          callTagEditor("setCancelling", true);
          callTagEditor("setAutoSubmit", false);

          if (tagsBeforeEdit) {
            callTagEditor("assignTags", tagsBeforeEdit);
          }
        },

        onSaveSuccess: function(options) {
          MingleUI.lightbox.reloadFlyoutPanel(editor);
          MingleUI.events.markAsViewed(options.data.event, "card:" + options.data.number);

          if (MingleUI.grid.instance) {
            MingleUI.grid.instance.syncCardName(options.data.number, options.data.name);
            MingleUI.grid.instance.syncCardTags(options.data.number, callTagEditor("assignedTags"));
          }
        },

        onSaveError: function(xhr, status, error) {
          var errorReasons = {
            0: "Mingle cannot be contacted or network is down. Please try again later.",
            401: "Session time out occured. You need to signin again.",
            404: "Card may have been destroyed by someone else.",
            422: "Card name cannot be blank.",
            500: "Mingle cannot process your request at this time. Please try again later."
          };
          errorReasons[502] = errorReasons[503] = errorReasons[504] = errorReasons[0];
          var reason = errorReasons[xhr.status] || "There is a technical error. Please save copy and save content and try again later.";
          var errorMsg = $('<div class="card-error-message edit-mode-only"/>').
            html('Something went wrong:  <div class="reason">' + reason + "</div>");
          form.append(errorMsg);
          setTimeout(function() { errorMsg.remove(); }, 5000);
        }
      });
    }

    $('.progress-bar-wrapper').withProgressBar({ event: "mingle.propertyChanged", wrapperClass: "full-width-progress" });
    $('.close-after-save-button').withProgressBar({ event: "click" });
    $('.save-button').withProgressBar({ event: "click" });

    form.find('.close-button').click(function() {
      InputingContexts.pop();
     });

    form.find('.close-after-save-button').click(function() {
      form.on("ajax:success", function() {
        InputingContexts.pop();
        return false;
      });
    });

    form.find("a.delete").on('ajax:success', function() {
      var deleteform = $(InputingContexts.top().findElement("#delete-form"));
      deleteform.on('submit', function(event) {
        event.preventDefault();
        $.ajax({
          url: $(this).attr("action"),
          type: 'POST',
          success: function() {
            InputingContexts.clear();
            if (MingleUI.grid.instance) {
              MingleUI.grid.instance.removeCard(form.data("card-number"));
            } else {
              window.location.reload();
            }
          }
        });
      });
    });

    $(document).ajaxComplete(updateFromCardData);
    updateFromCardData();

    return $(this);
  };
}(jQuery));
