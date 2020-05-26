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

  "use strict";

  function collapsedSections() {
    var collapsed = [];
    $("tbody.dependencies").each(function(i, val) {
      if ($(val).hasClass("collapsed")) {
        collapsed.push($(val).data("status"));
      }
    });
    if(collapsed.size() == 0) { collapsed.push("none"); }
    return collapsed;
  }

  function assembleStatuses(resolvingStatuses, raisingCard, raisingStatus) {
    raisingCard = raisingCard.toString();
    var statuses = {};
    var cardNumbers = Object.keys(resolvingStatuses);

    for (var i = 0, len = cardNumbers.length, status; i < len; i++) {
      status = resolvingStatuses[cardNumbers[i]];
      statuses[cardNumbers[i].toString()] = { resolving: status };
    }

    statuses[raisingCard] = $.extend(statuses[raisingCard] || {}, { raised: raisingStatus });
    return statuses;
  }

  $.fn.dependenciesPopover = function() {
    var container = this;
    var dependenciesPopover = $(container).find(".dependencies-popover");
    var raisingDependencies = $(container).find(".raising.dependency-subsection");

    container.find("ul.dependencies[data-dependency-popup-url]").on("click", "a[data-dependency-number]", function (e) {
      e.preventDefault();
      e.stopPropagation();
      $(e.currentTarget).showDependencyPopup();
    });

    $(container).find("[name='dependencies[desired_end_date]']").datepicker({
      beforeShow: function(input, datepicker) {
        datepicker.dpDiv.on("click", function(e) {
          e.stopPropagation();
        });
      },
      dateFormat: "yy-mm-dd"
    });

    function blankInputFilter(i, el) {
      return "" === $.trim($(el).val());
    }

    function addToList(dependency) {
      if (raisingDependencies.find("li").size() == 0) {
        raisingDependencies.removeClass("hide");
      }
      raisingDependencies.find(".dependencies").append($("<li/>").addClass("dependency")
        .append($("<a/>").attr("data-dependency-number", dependency.number)
          .text("#D" + dependency.number + " " + dependency.name)
        )
      );
    }

    dependenciesPopover.popover({
      beforeShow: function(content, event) {

        var caret = $(".dependencies-caret");
        var base = caret.position();
        base.top -= 10;
        base.left += caret.width() + 18;

        $(container).find("textarea,input[type='text']").val("");
        $(container).find("input[type='submit']").attr("disabled", "disabled");
        $(content).css(base);
      },

      afterShow: function(content, event) {
        var inViewTop = $(content).offset().top - $(window).scrollTop() + $(content).height();
        if (inViewTop > $(window).height()) {
          this.get(0).scrollIntoView();
        }
        $(content).find("input[type='text']:first").focus();
      }
    });

    $(container).on("input change", "input[type='text']", function(e) {
      var button = $(container).find("input[type='submit']");
      if ("" === $.trim($(e.target).val())) {
        button.attr("disabled", "disabled");
      } else {
        if (!$(container).find("input[type='text']").filter(blankInputFilter).length) {
          button.removeAttr("disabled");
        }
      }
    });


    function createDependency() {
      var params = {};
      var formElements = $(container).find("textarea,input:not([type='submit']), select");
      var blanks = formElements.not("textarea").filter(blankInputFilter);

      if (blanks.length) {
        return;
      }

      $.each(formElements.serializeArray(), function(i, field) {
        var key = field.name.split(/\[|\]/)[1];
        var value = field.value;
        if ("blockedCard" === key) {
          value = parseInt(value, 10);
        }
        params[key] = value;
      });

      $.ajax({
        url: $(container).data("create-url"),
        data: { dependency: params },
        type: "POST"
      }).done(function(data) {
        var statuses = {};
        addToList(data["dependency"]);
        dependenciesPopover.popoverClose();
        updateDependenciesTabCount(data["new_waiting_resolving_count"]);

        if (MingleUI.grid.instance) {
          statuses[data["card_number"].toString()] = {raised: data["status"]};
          MingleUI.grid.instance.syncDependencyStatuses(statuses);
        }
      }).fail(function(xhr, status, error) {
        console.log("error");
        console.log(arguments);
      });
    }

    $(container).on("keydown", "input[type='text'],select", function(e) {
      e.stopPropagation();

      if (e.keyCode !== $.ui.keyCode.ENTER) {
        return;
      }
      e.preventDefault();
      if (!$(container).find("input[type='submit']:disabled").length) {
        createDependency();
      }
    });

    $(container).on("click", "input[type='submit']", createDependency);
  };

  function updateDependenciesTabCount(count) {
    if (count == 0) {
      return $("#tab_dependencies_link .tab-counter").remove();
    }
    var title = count + " new " + (count < 2 ? 'dependency' : 'dependencies') + " to accept";
    if ($("#tab_dependencies_link .tab-counter").length) {
      $("#tab_dependencies_link .tab-counter").text(count).attr("title", title);
    } else {
      var el = $("<span>" + count + "</span>").addClass("tab-counter badge").attr("title", title);
      $("#tab_dependencies_link").append(el);
    }
  }

  function allLinkCardNumbers(container) {
    return $.map(container.find('.card-to-add input'), function(val, i) {
      return $(val).val();
    });
  }

  $.fn.linkCardsPopup = function() {
    var container = $(this);
    var form = container.find('form');
    var cards = container.find('.cards-to-link');
    var cardsList = container.find('.cards');
    var cardSearchBox = container.find('.add-card-field input');
    var raisingCardNumber = container.data('raising-card-number');

    var updateCardCache = function() {
      $.ajax({
        url: container.data("card-search-url"),
        dataType: "json",
        type: "GET",
        data: { mql: "SELECT number, name, type"}
      }).done(function(data) {
        $(data).each(function(i, el) {
          el.label = el.Name;
          el.value = el.Number;

          el.name = el.Name;
          el.number = el.Number;
          el.type = el.Type;
          delete el.Name;
          delete el.Number;
          delete el.Type;
        });
        var namespace = $("#find-any").data("namespace") + ".cardCache";
        try {
          localStorage.setItem(namespace, JSON.stringify(data));
        } catch (err) {
          MingleUI[namespace] = data;
        }
      });
    };

    updateCardCache();

    cardSearchBox.omniCard({
      minLength: 0,
      delay: 0,
      appendTo: cards,
      autoFocus: true,
      focus: function(e, ui) {
        e.preventDefault();
        return false;
      },
      source: function(request, response) {
        var matches = MingleUI.fuzzy.cardFinder(cardData(), request.term.toString());
        var linked = $.map(allLinkCardNumbers(container), function(e, i) { return parseInt(e); });
        linked.push(parseInt(raisingCardNumber));
        matches = matches.filter(function(card){
          return linked.indexOf(parseInt(card.number)) < 0;
        });
        response(matches.slice(0, 25));
      },
      select: function(e, ui) {
        e.stopPropagation();
        selectCard(ui.item);
        cardSearchBox.val('');
        return false;
      }
    });

    cardSearchBox.on("blur", function() {
      cardSearchBox.omniCard("close");
    });

    var cardData = function() {
      var namespace = $("#find-any").data("namespace") + ".cardCache";
      return JSON.parse(localStorage.getItem(namespace)) || MingleUI[namespace] || [];
    };

    function selectCard(cardInfo) {
      if (!!$("input[name='dependency[cards][]'][value='" + cardInfo.number + "']").length) {
        return;
      }

      var text = "#" + cardInfo.number;
      if (cardInfo.name) {
        text = text + " " + cardInfo.name;
      }

      var input = $("<input />")
        .attr("type", "hidden")
        .attr("name", "dependency[cards][]")
        .val(cardInfo.number);
      var close = $("<i>").addClass("fa fa-times");
      var item =  $("<li>").addClass("card-to-add").addClass("new").text(text).prepend(input).append(close);
      cardSearchBox.parent().hide();
      cardsList.append(item);
      enableSubmitIfApplicable();
    }

    function enableSubmitIfApplicable() {
      var button =  container.find(".link-cards");

      if (!container.find('.card-to-add.new').length) {
        button.addClass("disabled");
      } else {
        button.removeClass("disabled");
      }
    }

    cards.find(".add-card").click(function() {
      cardSearchBox.parent().show();
      cardSearchBox.focus();
    });

    cardsList.on("click", ".fa-times", function() {
      if ($(this).parent().hasClass("add-card-field")) {
        cardSearchBox.val('');
        cardSearchBox.omniCard("search", "");
        cardSearchBox.omniCard("close");
        cardSearchBox.parent().hide();
      } else {
        $(this).parent().remove();
      }
      enableSubmitIfApplicable();
    });

    container.find(".link-cards").click(function() {
      if ($(this).hasClass('disabled')) {
        return;
      } else {
        var params = {};
        params['number'] = container.data("dependency-number");
        params['cards'] = allLinkCardNumbers(container);

        $.ajax({
          url: container.data("link-url"),
          type: 'POST',
          data: { dependency: params }
        }).done(function(data) {
          InputingContexts.pop();
          if ($(".dependency-popup-lightbox").length > 0) {
            InputingContexts.top().update(data["lightbox_contents"]);
          }
          $("table#dependencies").replaceWith(data["dependencies_table"]);
          $("table#program-dependencies").replaceWith(data["program_dependencies_table"]);
          updateDependenciesTabCount(data["new_waiting_resolving_count"]);

          $("[data-dep-count]").attr("data-dep-count", data["new_waiting_resolving_count"]).removeData("dep-count");

          var statuses;
          if (MingleUI.grid.instance) {
            statuses = assembleStatuses(data["resolving_cards_statuses"], data["card_number"], data["icon_status"]);
            MingleUI.grid.instance.syncDependencyStatuses(statuses);
          }

          $(".status-property span").effect("bounce", {times: 2.5}, 1500);
        }).fail(function() {
        }).always(function() {
        });
      }
    });
  };

  function initDatePicker() {
    var dateProps = $('#dependency_show_lightbox_content').find(".dependency-date-property .hidden-input");
    var updateDependenciesTable = function(dependency, dateField) {
      $("#dependencies").find("#dep-" + dependency.number + " [data-column=" + dateField + "]").text(dependency[dateField]);
    };

    var updateProperty = function(date, datePicker) {
      var dateField = $("#" + datePicker.id).data("date-field");
      var params = {};
      params[dateField] = date;
      $.ajax({
        url: $(this).data("edit-url"),
        type: 'POST',
        data: params
      }).done(function(data){
        $("#" + dateField).find('button').text(data[dateField]);
        updateDependenciesTable(data, dateField);
        MingleUI.lightbox.reloadFlyoutPanel(dateProps.closest('.dependency-popup-lightbox'));
      });
    };

    $.each(dateProps, function(i, dateProp) {
      $(dateProp).datepicker({
        dateFormat: 'yy-mm-dd',
        showOn: 'button',
        buttonText: $(dateProp).data("initial-date"),
        onSelect: updateProperty
      });
    });
  }

  function highlightStatus() {
    $(".status-property span").effect("bounce", {times: 2.5}, 1500);
  }

  function markResolved(url) {
    $.ajax({
      url: url,
      type: 'POST'
    }).done(function(data) {
      InputingContexts.top().update(data["lightbox_contents"]);
      $(".status-property span").effect("bounce", {times: 2.5}, 1500);
      $("table#dependencies").replaceWith(data["dependencies_table"]);
      $("table#program-dependencies").replaceWith(data["program_dependencies_table"]);

      var statuses;

      if (MingleUI.grid.instance) {
        statuses = assembleStatuses(data["resolving_cards_statuses"], data["card_number"], data["icon_status"]);
        MingleUI.grid.instance.syncDependencyStatuses(statuses);
      }
    });
  }

  function setupProgramDependenciesProjectDropdown() {
    var dropdown = $("#program-dependency-filter-container .project-dropdown");
    dropdown.popover();

    var selectAll = dropdown.find("#select-all-projects").on("change", function(e) {
      var checked = $(this).is(':checked');
      dropdown.find('input[name="project_ids[]"]').each(function(i, ele) {
        $(ele).prop("checked", checked);
      });
      dropdown.find(".select-projects-button").prop('disabled', !checked);
    });
    dropdown.on("change", 'input[name="project_ids[]"]', function(e) {
      var checked = $(this).is(':checked');
      var checkedProjectCount = $.grep(dropdown.find('input[name="project_ids[]"]'), function(ele, i) {
        return $(ele).is(':checked');
      }).length;
      dropdown.find(".select-projects-button").prop('disabled', checkedProjectCount === 0);
      if (!checked) {
        selectAll.prop("checked", false);
      } else {
        var checkAll = dropdown.find('input[name="project_ids[]"]').length == checkedProjectCount;
        selectAll.prop("checked", checkAll);
      }
    });
  }

  $.fn.showDependencyPopup = function() {
    var element = $(this);
    if (element.hasClass("processing")) {
      return false;
    } else {
      element.addClass("processing");
    }

    $.ajax({
        url: element.closest("[data-dependency-popup-url]").data("dependency-popup-url"),
        data: {"number" : element.data("dependency-number"), "version" : element.data("dependency-version")},
        type: 'GET'
    }).fail(function(e) {
      if (e.status === 401 || e.status === 404) {
        element.attr("onclick", "");
      }
    }).always(function(){
      element.removeClass("processing");
    });
  };

  $.fn.dependencyPopup = function() {
    initDatePicker();
    var container = $(this);
    var unlinkSpinner = container.find(".fa-spinner");
    var linkCardsUrl = container.find("[data-link-cards-url]").data("link-cards-url");
    var selectNewResolvingProjectDropDown = $('.select-new-resolving-project-drop-down');

    selectNewResolvingProjectDropDown.popover();

    function removeHazzardIconFromCardPopup(cardNumber, depNumber) {
      var raisingCardPopup = $(".card-popup-lightbox [data-card-number='" + cardNumber + "']");
      var depItem = raisingCardPopup.find(".dependency-subsection.raising li[data-dependency-number='" + depNumber + "']");
      depItem.find("i.fa-exclamation-triangle").remove();
    }

    selectNewResolvingProjectDropDown.find('.resolving-project-item').click(function(e) {
      var params = {
        'resolving_project_id': $(this).data('project-id')
      };

      $.ajax({
        url: selectNewResolvingProjectDropDown.data('url'),
        data: params,
        type: 'POST'
      }).done(function(data) {
        InputingContexts.top().update(data["lightbox_contents"]);
        $("table#dependencies").replaceWith(data["dependencies_table"]);
        removeHazzardIconFromCardPopup(data['card_number'], data['dependency_number']);
      });
    });

    function removeDependencyFromResolvingCardPopup(cardNumber, depNumber) {
      var popupBodies = $(".card-popup-lightbox [data-card-number='" + cardNumber + "'']");
      popupBodies.each(function(i, el) {
        var resolvingSection = $(el).find(".dependency-subsection.resolving");
        var resolvingDep = resolvingSection.find("li a[data-dependency-number=" + depNumber + "]");

        resolvingDep.closest("li").remove();
        if (0 === resolvingSection.find("ul.dependencies li").length) {
          resolvingSection.addClass("hide");
        }
      });
    }

    $.fn.showLatestDependency = function() {
      if (InputingContexts.contexts.length === 1) {
        InputingContexts.pop();
        $(this).showDependencyPopup();
      } else {
        InputingContexts.pop();
      }
    };

    container.on("click", ".card-list a[data-card-number]", function(e) {
      e.stopPropagation();
      e.preventDefault();

      $.ajax({
        url: $(this).attr("href"),
        type: "GET",
        dataType: "script"
      }).fail(function(data) {
        console.log("error: " + data.status);
        console.log(arguments);
      });
    });

    container.on("click", ".resolving-cards-list .unlink-card", function(e) {
      e.stopPropagation();
      e.stopImmediatePropagation();
      e.preventDefault();

      var cardNumber = $(this).closest("[data-card-number]").data("card-number");
      unlinkSpinner.show();

      $.ajax({
        url: $(this).attr("href"),
        type: 'POST'
      }).done(function(data) {
        InputingContexts.top().update(data["lightbox_contents"]);
        $("table#dependencies").replaceWith(data["dependencies_table"]);
        $("table#program-dependencies").replaceWith(data["program_dependencies_table"]);
        updateDependenciesTabCount(data["new_waiting_resolving_count"]);
        $("[data-dep-count]").attr("data-dep-count", data["new_waiting_resolving_count"]).removeData("dep-count");
        removeDependencyFromResolvingCardPopup(cardNumber, data["dependency_number"]);

        var statuses;
        if (MingleUI.grid.instance) {
          statuses = assembleStatuses(data["resolving_cards_statuses"], data["card_number"], data["icon_status"]);
          MingleUI.grid.instance.syncDependencyStatuses(statuses);
        }

        if (data["status"] == "new") {
          highlightStatus();
        }
      }).always(function() {
        unlinkSpinner.hide();
      });
    });

    container.on("click", ".link-card-icon", function(e) {
      var element = $(this);
      if (element.hasClass("processing")) {
        return false;
      } else {
        element.addClass("processing");
      }
      $.ajax({
        url: linkCardsUrl,
        type: 'POST'
      }).done(function(data) {
        InputingContexts.push(new LightboxInputingContext(null, {closeOnBlur: true}));
        InputingContexts.top().update(data["lightbox_contents"]);
      }).always(function(){
        element.removeClass("processing");
      });
    });

    container.find(".toggle-resolved").withProgressBar({ event: "click" }).click(function() {
      markResolved($(this).data("toggle-resolved-url"));
    });
  };

  $(document).ready(function() {
    $(".dependencies-export-import .select-all-projects input[type='checkbox']").on("change", function() {
      var selectAllCheckBox = $(this);

      if (selectAllCheckBox.is(':checked')) {
        $(".dependencies-export-form input[type='checkbox']").prop("checked", true);
      } else {
        $(".dependencies-export-form input[type='checkbox']").prop("checked", false);
      }

      $(".dependencies-export-form input[type='checkbox']:first").trigger("change");
    });

    $(".dependencies-export-form").on("change", "input[type='checkbox']", function(e) {
      var form = $(this.form);
      var all = form.find("input[type='checkbox']");
      var selected = all.filter(":checked");
      var allCheckbox = $(".dependencies-export-import .select-all-projects input[type='checkbox']");

      if (all.length > 0 && all.length === selected.length) {
        allCheckbox.prop("checked", true);
      } else {
        allCheckbox.prop("checked", false);
      }

      if (selected.length > 0) {
        form.find("input[type='submit']").prop('disabled', false);
      } else {
        form.find("input[type='submit']").prop('disabled', true);
      }
    }).submit(function(e) {
      var form = $(this);

      if (0 === form.find("input[type='checkbox']:checked").length) {
        e.stopPropagation();
        e.preventDefault();
      }
    });

    $('#import-form').on("change", "input[type='file']", function(e) {
      var form = $(this.form);

      if (0 === $.trim($(this).val()).length) {
        form.find("input[type='submit']").prop('disabled', true);
      } else {
        form.find("input[type='submit']").prop('disabled', false);
      }

    }).submit(function(e) {
      var form = $(this);

      if (0 === $.trim(form.find("input[type='file']").val()).length) {
        e.stopPropagation();
        e.preventDefault();
      }
    });

    $(".dep-switch").on("change", "[type=\"radio\"]", function() {
      window.location.href = $(this).val();
    });

    setupProgramDependenciesProjectDropdown();

    $("body").on("click", "table#dependencies .dependencies-status td", (function(e) {
      e.stopPropagation();
      var element = $(e.target);
      element.parents("tbody.dependencies").toggleClass("collapsed");

      $.ajax({
        url: $("#dependencies").data("update-view-url"),
        data: {collapsed: collapsedSections()}
      });
    }));

    $(document.body).on("ajax:success", "[accessing='dependencies:delete']", function(e, data, status, xhr) {
      InputingContexts.pop(); // close confirmation

      var nextLightbox = InputingContexts.top(); // close dependency lightbox if shown
      if (!!nextLightbox) {
        var n  = $.trim($(nextLightbox.lightbox.content).find(".dependency-title .dependency-number").text());
        if (n === data.prefixed_number) {
          InputingContexts.pop();
        }
      }

      $("a[data-dependency-number='" + data.deleted + "']").each(function(i, el) {
        if ($(el).closest("li").siblings().size() == 0) {
          $(el).parents(".dependency-subsection").addClass("hide"); // Hide the subsection title on popup if no dependencies present under it
        }
        $(el).closest("li").remove(); // remove any links to this dependency, e.g. from card show popup
        $(el).closest(".dependencies-row").remove(); // remove entry in dependencies table
      });

      updateDependenciesTabCount(data["new_waiting_resolving_count"]);

      var visibleCards, params;
      if ((MingleUI.grid.instance) && $("[data-card-dependencies-statuses-url").length) {
        visibleCards = $.map($("[data-card-number]"), function(el) { return $(el).data("card-number"); });
        params = data.relatedCards.filter(function(num) { return visibleCards.indexOf(num) !== -1; });

        $.ajax({
          url: $("[data-card-dependencies-statuses-url]").data("card-dependencies-statuses-url"),
          type: "GET",
          data: {cards: params},
          dataType: "json"
        }).done(function(data) {
          if (MingleUI.grid.instance) MingleUI.grid.instance.syncDependencyStatuses(data);
        });
      }
    });

    $("#program_projects_container").find(".accepts-dependencies-checkbox input").on("change", function() {
      var p = $(this).parent();
      var spinner = p.find(".spinner");

      var params = {
        accepts_dependencies: $(this).is(':checked')
      };

      $.ajax({
        url: p.data('src'),
        type: 'POST',
        data: params,
        dataType: "script"
      });
    });

    $("#page-identifier-dependencies-index").on('click', '#dependencies .status-resolved td.load-more button', function(e) {
      var loadMoreRow = $(this).parents('.dependencies-row');
      var nextLimit = loadMoreRow.data('limit');

      var lastDepRow = loadMoreRow.siblings('.dependencies-row').last();
      var lastDepId = lastDepRow.data('id');
      $.ajax({
        url: $('#dependencies').data("update-view-url"),
        type: 'GET',
        data: {limit: nextLimit, after_id: lastDepId, status: 'resolved' },
      }).done(function(data) {
        loadMoreRow.remove();
        lastDepRow.after(data);
      });
    });

  });
})(jQuery);

var FakePool = function() {
  return {
    popups: {
      keep: function() {},
      unKeep: function() {},
      clear: function() {}
    }
  };
};
