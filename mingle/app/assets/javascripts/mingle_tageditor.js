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
var refreshTagEditor;
(function($) {
  //extend jquery.tag-it with following feature:
  // * autoSubmit
  // * programmatically assign list of tags
  // * editMode used by cards to not trigger form changes on ajax success.
  // * ability to reorder tags
  var supportedEvents = ["beforeTagAdded", "afterTagAdded", "beforeTagRemoved", "afterTagRemoved", "onTagClicked", "onTagLimitExceeded"];
  $.widget( "mingle.tageditor", $.ui.tagit, {
    options: {
      autoSubmit: false,
      autoSubmitForm: null,
      editMode : false,
      cancelling: false,
      sortable: false,
      allowNewTags: true,
      enableColorSelector: true
    },

    setCancelling: function(val) {
      this.options.cancelling = val;
    },

    setAutoSubmit: function(val) {
      this.options.autoSubmit = val;
    },

    setEditMode: function(val) {
      this.options.editMode = val;
    },

    setEventCallback: function(event, callback) {
      if(supportedEvents.include(event) && callback && typeof callback === "function") {
        this.options[event] = callback;
      }
    },

    setAllowNewTags: function(val) {
      this.options.allowNewTags = val;
    },

    _create: function() {
      this._super();
      var onReorder = this.options.onReorder;

      if (this.options.sortable == true) {
        $(this.element).sortable({
          cursor: "move",
          items: ".tagit-choice",
          containment: this.element,
          forcePlaceholderSize: true,
          forceHelperSize: true,
          helper: "clone",
          opacity: 1,
          delay: 0,
          distance: 5,
          tolerance: "pointer",
          start: function(event, ui) {
            ui.item.siblings('.tagit-new').hide();
            ui.placeholder.addClass('tag-placeholder');
          },
          stop: function(event, ui) {
            var newOrder = $j.map($j(this).find('.tagit-choice .tagit-label'), function(tag) {
              return $j(tag).text().trim();
            });
            if (onReorder) {
              onReorder(newOrder);
            }
            ui.item.siblings('.tagit-new').show();
          }
        });
      }
    },

    _trigger: function(type, event, data) {
      var widget = this;
      if (!this.options.cancelling && (type === "afterTagAdded" || type === "afterTagRemoved")) {
        editMode = this.options.editMode;

        if (!data.duringInitialization && (this.options.autoSubmit || editMode)) {
          var form = $(this.options.autoSubmitForm);

          if (form.data("tag-editor-standalone-ajax") || editMode) {
            var postData = form.find("input[name='" + this.options.fieldName + "']").serializeArray();
            $.ajax({
              url: form.attr("action"),
              type: "POST",
              data: postData
            }).done(function(data, status, xhr) {
              if (!editMode)
                form.trigger('ajax:success', [data, status, xhr]);
            }).fail(function(xhr, status, error) {
              form.trigger('ajax:error', [xhr, status, error]);
            }).always(function(xhr, status) {
              form.trigger('ajax:complete', [xhr, status]);
            });
          } else {
            form.submit();
          }
        }
      }

      if (type === "afterTagAdded") {
        this._renderTagColor(data.tag);
        data.tag.data('project-identifier', this.element.data('project-identifier'));

        if(this.options.enableColorSelector) {
          data.tag.colorSelector({
            onColorSelect: function (color) {
              MingleUI.tags.get(data.tag.data('project-identifier')).setColor(data.tagLabel, color);
            }
          });
        }

        this.projectTags().addTag(data.tagLabel);
      }

      if (type === "beforeTagAdded" && !this.options.allowNewTags && !this.projectTags().tagExists(data.tagLabel)) {
        return false;
      }
      var callback = this.options[type];
      if (callback && typeof callback === "function") {
        return callback(data.tagLabel);
      }

      return this._superApply(arguments);
    },

    assignTags: function(tags) {
      var oldAutoSubmitState = this.options.autoSubmit;
      this.setAutoSubmit(false);
      this.removeAll();
      for (var i = 0; i < tags.length; i++) {
        this.createTag(tags[i], null, true);
      }
      this.setAutoSubmit(oldAutoSubmitState);
    },

    updateColor: function(tagName) {
      var tag = this._findTagByLabel(tagName);
      if(tag) {
        this._renderTagColor(tag);
      }
    },

    projectTags: function() {
      return MingleUI.tags.get(this.element.data('project-identifier'));
    },

    _renderTagColor: function(tagElement) {
      var tagLabel = this.tagLabel(tagElement);
      tagElement.css("background-color", this.projectTags().colorFor(tagLabel));
      tagElement.find('.tagit-label').css("color", this.projectTags().textColorFor(tagLabel));
      tagElement.find('.ui-icon-close').css("color", this.projectTags().textColorFor(tagLabel));
    }

  });

  refreshTagEditor = function (tagEditorElement, optionsOverrides) {
    if(!tagEditorElement.data("mingleTageditor")) {
      var tagStorage = MingleUI.tags.add(tagEditorElement.data('project-identifier'), tagEditorElement.data("all-tags"), tagEditorElement.data("color-update-url"));
      tagStorage.registerObserver({
        afterColorChange: function(tagName) {
          tagEditorElement.tageditor("updateColor", tagName);
        }
      }, null);
      var onReorderAction = function(newOrder) {
        $.ajax({
          url: tagEditorElement.data("update-order-url"),
          dataType: "json",
          data: {"new_order": newOrder},
          type: "POST"
        }).done(function(data){
          if (MingleUI.grid.instance) {
            MingleUI.grid.instance.syncCardTags(data.number, newOrder);
          }
        });
      };

      tagEditorElement.tageditor($.extend({
        autoSubmit: tagEditorElement.data("auto-submit"),
        editMode: tagEditorElement.data("edit-mode"),
        autoSubmitForm: tagEditorElement.closest("form"),
        allowSpaces: true,
        removeConfirmation: true,
        fieldName: tagEditorElement.data("field-name") + "[]",
        autocomplete: {source: MingleUI.tags.get(tagEditorElement.data('project-identifier')).autoCompleteSource},
        animate: false,
        sortable: tagEditorElement.data("sortable"),
        onReorder: tagEditorElement.data("update-order-url") ? onReorderAction : null
      }, optionsOverrides));
    }
  };

  function refreshAllTagEditors() {
    $("ul.tageditor").each(function() {
       refreshTagEditor($(this), {});
    });
  }

  $(function() {
    var tagStorage = MingleUI.tags.current();
    if (tagStorage != null) {
      tagStorage.registerObserver({
        afterColorChange: function(tagName) {
          $("ul.tageditor").each(function() {
            $(this).tageditor("updateColor", tagName);
          });
        }
      }, refreshAllTagEditors);
    }
  });

  $(document).ajaxComplete(refreshAllTagEditors);
  Ajax.Responders.register({ onComplete: refreshAllTagEditors});


}(jQuery));
