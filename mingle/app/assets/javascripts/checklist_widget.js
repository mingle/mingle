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
  $.fn.checklist = function(options) {

    var checklistContainer = $(this);
    var incompleteItems = checklistContainer.find(".items-list");
    var completedItems = checklistContainer.find(".completed-items-list");
    var inputContainer = checklistContainer.find(".checklist-input");
    var toggleCompleted = checklistContainer.find(".toggle-completed");

    var errorHandler = makeErrorHandler($, checklistContainer, {
        errorElementCssClass: "card-error-message",
        customrErrorReasons: {
          404: "Card may have been destroyed by someone else.",
          422: "Checklist item must have a name",
        }
    });

    var sortableItems = incompleteItems.sortable({
      cursor: "move",
      axis: "y",
      scroll: true,
      items: "li",
      handle: ".item-dragging-anchor",
      over: function (event, ui) {
        ui.item.data('sortableItem').scrollParent = checklistContainer.parent();
        ui.item.data('sortableItem').overflowOffset = checklistContainer.parent().offset();
      }
    });

    sortableItems.on("sortstop", function(event, ui) {
      var itemOrder = sortableItems.sortable("toArray", {
        "attribute": "data-item-id"
      });
      updateItemOrder(itemOrder);
    });

    toggleCompleted.click(function(e) {
      if (completedItems.css("display") === "none") {
        showCompletedToggle();
      } else {
        hideCompletedToggle();
      }
    });

    toggleCompletedLink();
    hideCompletedToggle();

    function toggleCompletedLink() {
      if (completedItems.find("li").length > 0) {
        completedItems.siblings(".toggle-completed-container").show();
      } else {
        completedItems.siblings(".toggle-completed-container").hide();
      }
    }

    function showCompletedToggle() {
      completedItems.show();
      toggleCompleted.text('Hide completed items');
    }

    function hideCompletedToggle() {
      completedItems.hide();
      toggleCompleted.text('Show completed items');
    }

    inputContainer.focusout(function() {
      $(this).find("input").val('');
    });

    function addItem(params) {
      addToItems(createItem(params), incompleteItems);
    }

    function addWithAjax(input) {
      var params = { item: input.val(),
                     card_number: checklistContainer.data("card-number"),
                     format: 'json'
                   };

      inputContainer.find(".add-item-spinner").show();
        $.ajax(inputContainer.data('url'), {
        method: 'POST',
        data: params
      }).done(function(data) {
          addItem($.extend({}, data, params));
      }).fail(errorHandler).always(function() {
         inputContainer.find(".add-item-spinner").hide();
      });
    }

    function addChecklistItem(input) {
      if (input.val() === "") {
        return;
      }
      options.autoSave ? addWithAjax(input) : addItem({item: input.val()});
      input.val("");
    }

    function deleteItem(item) {
      var params = { item_id: item.data('item-id'),
                     format: 'json'
                   };

      $.ajax(checklistContainer.data('delete-url'), {
        method: 'POST',
        data: params
      }).done(function() {
        item.remove();
        toggleCompletedLink();
      }).fail(errorHandler);
    }

    function createItem(data) {
      var listItem = $("<li class='view-mode prevent-inline-edit'>").attr("data-item-id", data.item_id).attr("data-position", data.position);
      $("<div class='anchor-container'></div>").append($("<span class='item-dragging-anchor'></span>")).appendTo(listItem);

      var checkboxContainer = $("<div class='item-checkbox-container'>").appendTo(listItem);
      iconElementHTML = "<i class='" + (options.completable ? 'checkbox' : 'bullet') + "'>";
      $(iconElementHTML).appendTo(checkboxContainer);

      var itemNameContainer = $("<div class='item-name-container'>").appendTo(listItem);
      $("<span class='item-name view-mode-only'>").append(document.createTextNode(data.item)).appendTo(itemNameContainer);

      inputItemName = options.itemInputName || "";
      var inputElementHTML = "<input type='text' class='edit-mode-only' name='" +  inputItemName + "' />";
      $(inputElementHTML).val(data.item).appendTo(itemNameContainer);
      $("<i class='fa fa-times delete-item'>").appendTo(itemNameContainer);

      attachItemEvents(listItem);
      return listItem;
    }

    function updateItemWithAjax(item, input) {
      var params = { item_id: item.data('item-id'),
                     item_completed: item.data("completed"),
                     card_number: inputContainer.data("card-number"),
                     item_text: input.val(),
                     format: 'json'
                    };

      $.ajax(checklistContainer.data('update-url'), {
        method: 'POST',
        data: params
      }).done(function(data, status, xhr) {
        updateItem(item, $j.extend({}, params, data));
      }).fail(errorHandler);
    }

    function updateChecklistItem(item, input) {
      options.autoSave ? updateItemWithAjax(item, input) : updateItem(item, {item_text: input.val()});
    }

    function updateItem(item, data) {
      item.data("item-id", data['item_id']);
      item.find(".item-name").text(data.item_text);
      enterViewMode(item);
    }

    function addToItems(item, itemsList) {
      options.appendBottom ? itemsList.append(item) : itemsList.prepend(item);
    }

    function toggleChecklistItem(item){
      var params = { item_id: item.data('item-id'),
                     completed: item.hasClass('complete-item'),
                     card_number: inputContainer.data("card-number"),
                     item_text: item.find(".item-name").text(),
                     format: 'json'};

      $.ajax({
        url: checklistContainer.data('mark-url'),
        method: 'POST',
        data: params
      }).done(function(data, status, xhr) {
        item.data("item-id", data['item_id']);
        itemsList = item.hasClass('complete-item') ? completedItems : incompleteItems;
        if(!item.hasClass('complete-item')) {
          item.find(".anchor-container").removeClass("invisible");
          item.find(".item-dragging-anchor").hide();
        }
        addToItems(item, itemsList);
        toggleCompletedLink();
      }).fail(function(data, status, xhr){
        item.removeClass("complete-item");
        errorHandler(data, status, xhr);
      });
    }

    function updateItemOrder(newOrder) {
      $.ajax(checklistContainer.data("reorder-url"), {
        method: "POST",
        data: { items: newOrder, format: 'json' }
      }).fail(function(data, status, xhr) {
        sortableItems.sortable("cancel");
        errorHandler(data, status, xhr);
      });
    }

    function enterEditMode(item) {
      item.removeClass("view-mode").addClass("edit-mode");
      item.find(".view-mode-only").hide();
      item.find(".edit-mode-only").show();
      item.find("input").focus();
    }

    function enterViewMode(item) {
      item.removeClass("edit-mode").addClass("view-mode");
      item.find(".view-mode-only").show();
      item.find(".edit-mode-only").hide();
    }

    function attachItemEvents(item) {
      item.find('.delete-item').click(function(e) {
        deleteItem(item);
      });

      if(options.completable){
        item.find('.checkbox').click(function(e) {
          item.toggleClass("complete-item");
          toggleChecklistItem(item);
        });
      }

      item.find("input").keypress(function(e) {
        if (e.which == $.ui.keyCode.ENTER) {
          updateChecklistItem(item, $(this));
          return false;
        }
      });

      item.find("input").blur(function() {
        enterViewMode(item);
      });

      item.find(".item-name").on('dblclick', function(event) {
        enterEditMode(item);
      });

      item.hover(function() {
        item.find(".item-dragging-anchor").show();
      });

      item.on("mouseleave", function() {
          item.find(".item-dragging-anchor").hide();
      });
    }

    if (checklistContainer.data('enabled')) {
      return;
    }
    checklistContainer.data('enabled', true);

    inputContainer.find("input").keypress(function(e) {
      if (e.which == $.ui.keyCode.ENTER) {
        addChecklistItem($(this));
        return false;
      }
    });

    inputContainer.click(function() {
      inputContainer.find("input").focus();
    });

    checklistContainer.find('.items-list li, .completed-items-list li').each(function(_, item) {
      attachItemEvents($(item));
    });

  };
})(jQuery);