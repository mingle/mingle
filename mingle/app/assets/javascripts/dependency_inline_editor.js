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
  $.fn.dependencyInlineEditor = function(editable) {
    var editor = $(this);
    var form = $(this).find('.inline-edit-form');
    var lightbox = $(this).closest('.dependency-popup-lightbox');

    if (editable) {
      form.inlineEditForm({
        ckeditorToolbar: 'basic_editor_with_image_upload',
        afterEnterEditMode: function() {
          InputingContexts.top().lightbox.disableBlurClick();
        },

        afterEnterViewMode: function() {
          InputingContexts.top().lightbox.enableBlurClick();
        },

        onCancel: function() {
        },

        onSaveSuccess: function(options) {
          lightbox.find('.dependency-description-content').html(options.data.description);
          lightbox.find('.dependency-title .dependency-name').text(options.data.name);
          MingleUI.lightbox.reloadFlyoutPanel(lightbox);
          $('.dependencies-row td[data-column=name] [data-dependency-number=' + options.data.number + ']').text(options.data.name);
          $('[data-dependency-number=' + options.data.number + '] .dependency-name').text(options.data.name);
        },

        onSaveError: function(xhr, status, error) {
          var errorReasons = {
            0: "Mingle cannot be contacted or network is down. Please try again later.",
            401: "Session time out occured. You need to signin again.",
            404: "Dependency may have been destroyed by someone else.",
            422: "Dependency name cannot be blank.",
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

    $('.save-button').withProgressBar({ event: "click" });

    form.find('.close-button').click(function() {
      InputingContexts.pop();
     });

    return $(this);
  };
})(jQuery);
