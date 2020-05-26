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
  window.MingleUI = window.MingleUI || {};

  function initAttachments(container) {
    container.find(".dropzone[data-attachable-id]").each(function(i, el) {
      MingleUI.attachable.initDropzone(el);
    });
  }

  function initFlyout(container) {
    initAttachments(container);
    container.find(".murmurs-card-discussion").cardMurmurs();

    var currentPanel = container.find("[data-current-panel]");
    var attachmentsPanel = container.find("[data-panel-name='attachments']");
    var historyPanel = container.find("[data-panel-name='history']");
    var murmursPanel = container.find("[data-panel-name='murmurs']");

    if (0 === currentPanel.length) {
      return;
    }

    if ("" === $.trim(currentPanel.attr("data-current-panel"))) {
      container.removeClass("sidebar-attached");
    } else {
      container.addClass("sidebar-attached");

      if ("history" === $.trim(currentPanel.attr("data-current-panel")) && historyPanel.length > 0) {
        MingleUI.lightbox.loadHistory(historyPanel);
      }

      if ("murmurs" === $.trim(currentPanel.attr("data-current-panel")) && murmursPanel.length > 0) {
        MingleUI.lightbox.loadMurmurs(murmursPanel);
      }
    }

    container.find(".panel-toggle").on("click", "[data-for-panel]", function(e) {
      var newValue = $(e.currentTarget).attr("data-for-panel");
      var currentValue = currentPanel.attr("data-current-panel");
      var preference = currentPanel.attr("data-preference-key");

      if (currentValue !== newValue) {
        container.find("[data-panel-name='" + newValue + "']").trigger("lightbox-flyout:panel-show");
        container.addClass("sidebar-attached");
      } else {
        newValue = "";
        container.removeClass("sidebar-attached");
      }

      currentPanel.attr("data-current-panel", newValue);
      MingleUI.updateUserPreference(preference, newValue);
    });

    attachmentsPanel.on("lightbox-flyout:panel-show", function(e) {MingleUI.lightbox.loadAttachments($(this));});
    historyPanel.on("lightbox-flyout:panel-show", function(e) {MingleUI.lightbox.loadHistory($(this));});
    murmursPanel.on("lightbox-flyout:panel-show", function(e) {MingleUI.lightbox.loadMurmurs($(this));});
  }

  function ajaxLoadAttachments(panel) {
    var url = panel.find("[data-attachments-load-url]").data("attachments-load-url");
    var spinner = panel.find(".attachments-loading");
    spinner.slideDown();

    $.ajax({
      url: url,
      type: "GET"
    }).done(function(data, status, xhr) {
      var dzElement = panel.find("[data-attached]");
      dzElement.attr("data-attached", JSON.stringify(data));
      MingleUI.attachable.updateExistingAttachments(dzElement);
    }).always(function() {
      spinner.slideUp();
    });
  }

  function ajaxLoadHistory(panel) {
    panel.find(".events-loading").slideDown();
    $.ajax({
      url: panel.data("history-url"),
      type: "GET",
      success: function(data) {
        panel.find('.history-panel-container .renderable-events').html(data);
      },
      complete: function() {
        panel.find(".events-loading").slideUp();
      }
    });
  }

  function ajaxLoadMurmurs(panel) {
    var url = panel.is("[data-source-url]") ? panel.data("source-url") : panel.find("[data-source-url]").data("source-url");

    $.ajax(url, {
      dataType: "json",
      beforeSend: function(xhr, settings) {
        panel.find(".murmurs-loading").slideDown();
      }
    }).done(function(data, status, xhr) {
      panel.find(".murmurs-loading").slideUp();
      populate(panel, data);
    });
  }

  function showMurmursPanel(lightbox) {
    var flyout = $j(lightbox).find(".flyout");
    $j(flyout).data("current-panel", "murmurs");
    $j(flyout).attr("data-current-panel", "murmurs");
    $j(lightbox).find(".flyout [data-panel-name='murmurs']").trigger("lightbox-flyout:panel-show");
  }


  function populate(container, data) {
    var ul = container.find(".content ul");
    var emptyMessage = container.data("readonly") ? "Nothing yet." : "It's kinda quiet in here, start the conversation!";

    ul.empty();

    if (0 !== data.length) {
      $.each(data, function(i, chunk) {
        ul.append($(chunk));
      });
    } else {
      ul.append($("<li class=\"none\"/>").text(emptyMessage));
    }

    var count = data.length > 99 ? "99+" : data.length.toString();
    container.find("[data-murmur-count]").text(count);
  }

  window.MingleUI.lightbox = {
    loadHistory: ajaxLoadHistory,
    loadMurmurs: ajaxLoadMurmurs,
    loadAttachments: ajaxLoadAttachments,
    displayMurmursPanel: showMurmursPanel,

    initSidePanel: initFlyout,
    cards: function initCardsLightbox(instance) {
      var editable = $(instance.content).find("[data-editable]").data("editable");
      var editor = $(instance.content).find(".lightbox_content");

      initFlyout($(instance.content));
      $(instance.content).find(".dependencies-drop-down").dependenciesPopover();
      editor.cardInlineEditor(editable);
    },

    dependencies: function initDependenciesLightbox(instance) {
      var editable = $(instance.content).find("[data-editable]").data("editable");
      var editor = $(instance.content).find(".lightbox_content");

      initFlyout($(instance.content));
      $(instance.content).dependencyPopup();
      editor.dependencyInlineEditor(editable);
    },

    reloadFlyoutPanel: function(parent) {
      var flyoutPanel = parent.find('.flyout').attr('data-current-panel');
      if (flyoutPanel) {
        parent.find(".flyout [data-panel-name='" + flyoutPanel + "']").trigger("lightbox-flyout:panel-show");
      }
    }
  };
})(jQuery);
