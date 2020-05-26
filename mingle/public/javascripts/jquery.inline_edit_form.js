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
  var InlineEditController = function(container, options) {
    function isInViewMode() {
      return container.hasClass('view-mode');
    }

    function isInEditMode() {
      return container.hasClass('edit-mode');
    }

    function editDisabled() {
      return container.find('.enter-edit').hasClass('disabled');
    }

    function enterEditMode() {
      if( isInEditMode() || editDisabled()) {
        return;
      }
      container.addClass('edit-mode');
      container.removeClass('view-mode');
      container.find('.ckeditor-inline-editable').each(function() {
        CKEDITOR.config.autosave_SaveKey = container.data('editable-id');
        CKEDITOR.config.autosave_delay = 2;
        CKEDITOR.config.autosave_saveDetectionSelectors = container.find(".save-content,.cancel-edit,.edit-in-full-view-button");

        $(this).data("editor", CKEDITOR.replace(this, {
            toolbar: options.ckeditorToolbar || "with_image_upload",
            on: {
              instanceReady: function(){
                if(container.setCursorOnDescription){
                   $(this).focus();
                }
              }
            },
            height: $(this).height(),
            filebrowserUploadUrl: $(this).data('image-upload-url')
        }));
      });

      container.find(".view-mode-only").find("input").attr("disabled", true);
      options.afterEnterEditMode.call(container);
    }

    function enterViewMode() {
      if( isInViewMode() ) {
        return;
      }

      container.addClass('view-mode');
      container.removeClass('edit-mode');
      container.find('.ckeditor-inline-editable').each(function() {
        $(this).data("editor").destroy(true);
        $(this).data("editor", null);
      });
      container.find(".view-mode-only").find("input").attr("disabled", false);

      options.afterEnterViewMode.call(container);
    }

    function refreshContent() {
      container.find("[data-reloadable-url]").each(function() {
        var reloadable = $(this);
        $.ajax({
          url : reloadable.data("reloadable-url"),
          success: function(data) {
            var clipboardText = "[" + data.project + "/#" + data.number + "] " + data.name;
            if (reloadable.data('reloadable-escape')) {
              reloadable.text(data.name);
              reloadable.closest("h1").find("[data-clipboard-text]").attr("data-clipboard-text", clipboardText).removeData("clipboard-text");
            } else {
              reloadable.html(data);
            }
          }
        });
      });
    }

    function flushInlineEditContent() {
      container.find('.ckeditor-inline-editable').each(function() {
        var editor = $(this).data("editor");
        if (editor) {
          editor.updateElement();
        }
      });
    }

    function saveContent(event) {
      options.beforeSave.call(container, event);
      flushInlineEditContent();
      container.submit();
    }

    return {
      'enterViewMode': enterViewMode,
      'isInEditMode': isInEditMode,
      'enterEditMode': enterEditMode,
      'saveContent': saveContent,
      'refreshContent': refreshContent,
      'flushInlineEditContent': flushInlineEditContent
    };
  };

  function clearSelection() {
    try {
      var selection = ('getSelection' in window) ?
      window.getSelection() :
      ('selection' in document) ?
      document.selection :
      null;

      if ('removeAllRanges' in selection)  {
        selection.removeAllRanges();
      } else if ('empty' in selection) {
        selection.empty();
      }
    } catch (e) {
      // ignore clear selection failures, mostly happened on IE
      // standard mode
    }
  }


  $.fn.inlineEditForm = function(opts) {
    var options = $.extend({}, {
      beforeSave: function() {},
      afterSave: function() {},
      onCancel: function() {},
      onSaveError: function() {},
      onSaveSuccess: function() {},
      afterEnterEditMode: function() {},
      afterEnterViewMode: function() {},
    }, opts);

    var form = $(this);
    var controller = new InlineEditController(form, options);

    form.on('dblclick', function(event) {
      if( controller.isInEditMode() ||
        $(event.target).attr("class") == "prevent-inline-edit" ||
        $(event.target).is(".prevent-inline-edit *")
        ) {
        return;
      }
      controller.enterEditMode();
      var focusTarget = $(event.target).attr("focus-target");
      if (focusTarget) {
        form.find(focusTarget).first().focus();
        form.setCursorOnDescription = false;
      } else {
        clearSelection();
        form.setCursorOnDescription = true;
      }
    });

    form.find('.enter-edit').click(function() {
      controller.enterEditMode();
    });

    form.find('.cancel-edit').click(function() {
      options.onCancel.call(this);
      controller.enterViewMode();
    });

    form.find('.save-content').click(function(event) {
      if ($(this).data('disabled')) {
        return;
      }
      $(this).data('disabled', true);
      controller.saveContent(event);
    });

    form.on("ajax:success", function(event, data, status, xhr) {
      controller.refreshContent();
      controller.enterViewMode();
      options.onSaveSuccess.call(this, {data: data, status: status, xhr: xhr});
    });

    form.on('ajax:complete', function() {
      options.afterSave.call(this);
      form.find('.save-content').data('disabled', false);
    });

    form.on('ajax:error', function(event, xhr, status, error) {
      options.onSaveError.call(this, xhr, status, error);
    });

    return form;
  };

}(jQuery));
