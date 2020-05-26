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
  $.fn.updateCardColor = function() {
    var cardColor = $(this).data("color");
    if (!cardColor) {
      $(this).css("border-left", "none");
    } else {
      $(this).css("border-left", "10px solid " + cardColor);
    }
    $(this).updateCardTypeColor();
  };

  $.fn.updateCardTypeColor = function() {
    var cardColor = $(this).data("color");
    $(this).find(".card-type-editor-container").css("background-color", cardColor).adjustFontColor();
  };

  $.fn.enableCardEditor = function() {
    var lightbox = $(this);
    var form = lightbox.find('.inline-edit-form');

    var QuickAddCardController = function(container) {
      var self = {};
      var flushInlineEditContent = function() {
          container.find('.ckeditor-inline-editable').each(function() {
          var editor = $(this).data("editor");
          if (editor) {
            editor.updateElement();
          }
        });
      };

      self.saveContent = function() {
        flushInlineEditContent();
        form.submit();
      };

      return self;
    };

    var controller = new QuickAddCardController(lightbox);
    lightbox.updateCardColor();
    var saveButton = lightbox.find(".save-content");
    saveButton.withProgressBar({ event: "click" });
    saveButton.click(function(event) {
      if (saveButton.data("disabled")) {
        return;
      }
      saveButton.data("disabled", true);
      controller.saveContent();
      return false;
    });
    saveButton.on('save:error', function(event, message) {
      saveButton.removeData("disabled");
      var longMessage = message.length > 80;
      var className = longMessage ? 'long-card-error-message' : 'card-error-message';
      var errorMsg = $('<div class="' + className + '"/>').
        html('Something went wrong:  <div class="reason">' + message + "</div>");
      form.append(errorMsg);
      setTimeout(function() { errorMsg.remove(); }, longMessage ? 15000 : 5000);
    });

    var colorBy = $("#select_color_by_drop_link").text();
    lightbox.bind('property_value_changed', function(event) {
      var prop = $(event.target);
      if (prop.attr('name') == "properties[" + colorBy + "]") {
        var colorFromLegend = $j('tr[data-color-for="' +  prop.val() + '"] span[class="color_block"]').attr('style').split(':')[1] || "";
        lightbox.data("color", colorFromLegend).updateCardColor();
      } else {
        lightbox.updateCardTypeColor();
      }
    });

    var editor = lightbox.find('.ckeditor-inline-editable');
    editor.on('update_card_defaults', function(e, value) {
      var editor = $(this).data("editor");
      if (editor) {
        editor.updateElement();
        if (!$(this).data('changed')) {
          editor.setData(value);
        }
      }
    });
    editor.each(function() {
      var editorElement = $(this);
      CKEDITOR.config.autosave_SaveKey = 'cards/new';
      CKEDITOR.config.autosave_delay = 2;
      CKEDITOR.config.autosave_saveDetectionSelectors = lightbox.find(".save-content,.popup-close,.close-popup,#quick-add-more-detail");

      $(this).data("editor", CKEDITOR.replace(this, {
          toolbar: 'with_image_upload',
          on: {
            instanceReady: function(){
              if(editor.setCursorOnDescription){
                 $(this).focus();
              }
            },
            change: function() {
              editorElement.data("changed", true);
            },
            focus: function() {
              if (DropList.hideObserver) {
                DropList.hideObserver();
              }
              if (window.calendar) {
                window.calendar.hide();
              }
            }
          },
          height: $(this).height(),
          filebrowserUploadUrl: editorElement.data('image-upload-url')
        }));
    });

  };

}(jQuery));
