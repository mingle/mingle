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
// droppable behavior extention to provide assigment value by a icon
(function($) {
  function exists(obj) {
    return obj.length !== 0;
  }

  function findSlotWithId(container, slotId) {
    return container.find(".slot[data-slot-id='" + slotId + "']");
  }

  function createSlotWithId(container, slotId) {
    var slot = $("<div class=\"slot\" data-slot-id=\""+ slotId + "\" />");
    container.prepend(" ").prepend(slot);
    return slot;
  }

  function findOrCreateSlotWithId(container, slotId) {
    var slot = findSlotWithId(container, slotId);
    if (!exists(slot)) {
      slot = createSlotWithId(container, slotId);
    }
    return slot;
  }

  function selectedSlot(container) {
    return container.find(".slot.selected");
  }

  function isMovemberThemeEnabled() {
    var body = $j('body');
    return (body.data('show-holiday-fun') == true && body.data('holiday-name') == 'Movember 2016');
  }

  function cloneImageIntoSlot(slot, icon) {
    var oldIcon = slot.find('img');
    if(exists(oldIcon)) {
      oldIcon.remove();
    }

    var newIcon = $("<img>").
      attr("src", icon.attr("src")).
      attr('title', slot.data('slot-id') + ": " +  icon.data('name')).
      attr('class', icon.attr('class')).
      attr('data-name', icon.data("name")).
      css('background', icon.css('background')).
      css('background-color', icon.css('background-color')). //for Firefox
      attr('data-value-identifier', icon.data('value-identifier')).
      removeClass('ui-draggable ui-draggable-dragging');

    slot.append(newIcon);
    return {
      newIcon: newIcon,
      oldIcon: oldIcon,
      revert: function() {
        newIcon.remove();
        if(exists(oldIcon)) {
          slot.append(oldIcon);
        }
      }
    };
  }

  function cleanupSlots(container) {
    container.find('.slot').each(function() {
      var slot = $(this);
      slot.removeClass('selected');
      slot.tipsy('hide');

      var slotsContainer = slot.parent();
      var cardIconPlaceholder = $(".card-icon-placeholder-toggle").data("value");
      if(cardIconPlaceholder) {
        if(slot.find('img').length < 1 && slotsContainer.find('.slot').length > 1) {
          slot.remove();
        }
      } else {
        if(slot.find('img').length < 1) {
          slot.remove();
        }
      }
    });
  }

  function refreshSlots(slotsContainer) {
    var slotIds = slotsContainer.data('slot-ids').slice();
    slotIds.reverse();
    $.each(slotIds, function(index, slotId) {
      var slot = findOrCreateSlotWithId(slotsContainer, slotId);

      if (!slot.tipsy(true)) {
        slot.tipsy({
          gravity: $.fn.tipsy.autoBounds(30, 'n'),
          trigger: 'manual',
          title: function() { return "Set as '" + slotId + "'"; }
        });
      }
    });
  }

  function assignData(slot, icon) {
    var data = {properties: {}};
    var propertyName = slot.data('slot-id');
    var propertyValue = icon.data('value-identifier');

    data.properties[propertyName] = propertyValue;
    return data;
  }

  function unassignData(slot) {
    var data = {properties: {}};
    var propertyName = slot.data('slot-id');

    data.properties[propertyName] = null;
    return data;
  }

  function displayError(container, slot, revert) {
    $(".update-error").hide(); // hide all previous errors

    var errorMsg = $('<div class="update-error"><i class="fa fa-warning"></i>Something went wrong during update. Please refresh the page and try again.</div>');
    container.append(errorMsg);
    slot.addClass("error");

    setTimeout(function() {
      errorMsg.remove();
      slot.removeClass("error");
      revert.call();
    }, $.fn.iconDroppable.WARNING_REMOVAL_DELAY);
  }

  function clearFlashMessage() {
    $("#flash").empty();
  }

  function addMoustacheIfNeeded(slot) {
    if(isMovemberThemeEnabled()) {
      var moustache = $("<img>")
          .attr("src", "/images/moustache.png")
          .attr("class", "moustache");

      slot.append(moustache);
    }
  }

  function assign(container, slot, icon, deletionTray, successCallback) {
    container.addClass("operating");
    var clone = cloneImageIntoSlot(slot, icon);
    $.ajax({
      url: container.data('value-update-url'),
      type: 'POST',
      data: assignData(slot, icon),
      beforeSend: clearFlashMessage,

      complete: function() {
        addMoustacheIfNeeded(slot);
        cleanupSlots(container);
        container.removeClass("operating");
      },

      success: function(data, status, xhr) {
        adjustCardLocation(data, container);
        setupDraggable(clone.newIcon, deletionTray);
        if(successCallback !== undefined) {
          successCallback();
        }
      },

      error: function(xhr, status, error) {
        displayError(container, slot, function() {
          clone.revert();
          if (exists(clone.oldIcon)) {
            setupDraggable(clone.oldIcon, deletionTray);
          }
          cleanupSlots(container);
          icon.show();
        });
      }
    });
  }

  function unassignSlot(slot, callback) {
    var container = slot.parents('[data-value-update-url]');

    if (exists(container) && exists(slot)) {
      container.addClass("operating");
      $.ajax({
        url: container.data('value-update-url'),
        type: 'POST',
        data: unassignData(slot),
        beforeSend: clearFlashMessage,

        complete: function() {
          cleanupSlots(container);
          container.removeClass("operating");
        },

        success: function(data, status, xhr) {
          adjustCardLocation(data, container);
          callback(null);
          slot.html("");
        },

        error: function() {
          displayError(container, slot, function() {
            callback("error for unassign, need revert");
            cleanupSlots(container);
          });
        }
      });
    }
  }

  function unassign(icon) {
    var slot = icon.parents('.slot');
    unassignSlot(slot, function(error) {
      if(error) {
        icon.show();
      }
    });
  }

  function adjustCardLocation(data, card) {
    var config = $('[data-view-params]');
    var view, axis, propertyValue, row, newCell, lane, viewOptions;

    if (config.length) {
      if (!config.data("view-object")) {
        viewOptions = $.extend({}, config.data("view-params"), {resetUrl: config.data("view-reset-url")});
        config.data("view-object", new MingleUI.live.View(viewOptions));
      }

      view = config.data("view-object");

      for (var i = 0, props = Object.keys(data.properties), len = props.length, prop; i < len; i++) {
        prop = props[i].toString().toLowerCase();

        if ("string" === typeof view.groupBy("lane") && view.groupBy("lane").toLowerCase() === prop) {
          axis = "horizontal";
          propertyValue = data.properties[props[i]];
          break;
        }

        if ("string" === typeof view.groupBy("row") && view.groupBy("row").toLowerCase() === prop) {
          axis = "vertical";
          propertyValue = data.properties[props[i]];
          break;
        }
      }

      if ("horizontal" === axis) {
        row = card.closest('.grid-row');
        newCell = row.find('.cell[lane_value="' + (propertyValue || "") + '"]');

        if (newCell.length) {
          adoptCard(newCell, card, view);
        } else {
          removeCard(card, view);
        }
      }

      if ("vertical" === axis) {
        row = config.find('.grid-row[row_value="' + (propertyValue || "") + '"]');

        if (row.length) {
          newCell = row.find('.cell[lane_value="' + card.closest(".cell").attr("lane_value") + '"]');
          adoptCard(newCell, card, view);
        } else {
          removeCard(card, view);
        }
      }
    }
  }

  function adoptCard(cell, card, view) {
    cell.append(card);
    view.refreshSorting(card);
    view.updateGridAggregates();
  }

  function removeCard(card, view) {
    var number = card.data("card-number");

    if (MingleUI.grid.instance) {
      MingleUI.grid.instance.removeCard(card.data("card-number"));
    }

    $("#flash").empty().append(
      $("<div class='success-box'/>").
        append(
          $("<div class=\"flash-content\" id=\"notice\"/>").
            text("Card " + number + " is not shown because it does not match the current filter.")
        )
    );

    view.updateGridAggregates();
  }

  $.fn.setupDraggableIcon = function(deletionTray) {
    setupDraggable($(this), deletionTray);
    return this;
  };

  function setupDraggable(draggable, deletionTray) {
    draggable.draggableIcon({
      consuming: true,

      startDragging: function() {
        deletionTray.addClass('visible');
      },

      stopDragging: function() {
        deletionTray.removeClass('visible');
      }
    });
  }

  $.fn.iconDroppableUnassign = function(slot) {
    unassignSlot(slot, function() {});
    return this;
  };

  $.fn.iconDroppableAssign = function(slotId, icon, opts) {
    var slotContainerSelector = opts['slotContainer'];
    var deletionTray = opts['deletionTray'];
    var afterAssign = opts['afterAssign'] || function() {};

    var slot = findOrCreateSlotWithId(this.find(slotContainerSelector), slotId);
    assign(this, slot, icon, deletionTray, afterAssign);
    if (typeof MingleJavascript !== "undefined" &&
        MingleJavascript.metricsEnabled === true &&
        typeof mixpanel !== "undefined") {
      mixpanel.track('click_to_assign', {});
    }
    return this;
  };

  $.fn.iconDroppable = function(opts) {
    var slotContainerSelector = opts['slotContainer'];
    var deletionTray = opts['deletionTray'];

    var container = this;

    deletionTray.find('.slot').droppable({
      accept: opts['accept'],
      hoverClass: 'icon-hover',
      tolerance: 'touch',

      drop: function(event, ui) {
        container.droppable("enable");
        var slot = $(this);
        ui.draggable.data('ui-droppable-dropped', true);
        unassign(ui.draggable);
        cloneImageIntoSlot(slot, ui.helper);
        setTimeout(function() {
          slot.html("");
        }, 500);
        if (typeof MingleJavascript !== "undefined" &&
            MingleJavascript.metricsEnabled === true &&
            typeof mixpanel !== "undefined") {
          mixpanel.track('drag_and_drop_to_unassign', {});
        }
      },
      out: function(e, ui) {
        container.droppable("enable");
        var hovered = $j(".icon-hover");
        if (hovered.size() > 0) {
          refreshSlots(hovered.find(slotContainerSelector));
        }
      },
      over: function(e, ui) {
        container.droppable("disable");
        cleanupSlots(container);
      }
    });

    setupDraggable(container.find(".slot img"), deletionTray);

    return container.droppable({
      accept: opts['accept'],
      hoverClass: 'icon-hover',

      over: function(event, ui) {
        if (!container.droppable("option", "disabled")) {
          refreshSlots($(this).find(slotContainerSelector));
        }
      },

      out: function(event, ui) {
        cleanupSlots($(this));
      },

      drop: function(event, ui) {
        var container = $(this);
        var slot = selectedSlot(container);

        if( exists(slot) && !$.contains(slot.get(0), ui.draggable.get(0))) {
          ui.draggable.data('ui-droppable-dropped', true);
          assign(container, slot, ui.draggable, deletionTray, function() {
            unassign(ui.draggable);
          });
        } else {
          cleanupSlots(container);
        }

        if (typeof MingleJavascript !== "undefined" &&
            MingleJavascript.metricsEnabled === true &&
            typeof mixpanel !== "undefined") {
          mixpanel.track('drag_and_drop_to_assign', {});
        }
      }
    });
  };

  $.fn.iconDroppable.WARNING_REMOVAL_DELAY = 4000;
  $.fn.iconDroppable.AJAX_OPTS = {};

  MingleUI = (MingleUI || {});
  MingleUI.icon = {
    cleanupSlots: cleanupSlots,
    findOrCreateSlotWithId: findOrCreateSlotWithId
  };
})(jQuery);
