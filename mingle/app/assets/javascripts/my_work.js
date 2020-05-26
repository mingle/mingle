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
MingleUI.myWork = {};

(function($) {
  $.fn.workMenu = function() {
    var element = this;
    var cardsList = this.find(".my-cards");

    function header(title, refreshable) {
      var h = $("<dt>" + title + "</dt>");
      if (!!refreshable) {
        var refresh = $("<i class=\"fa fa-refresh refreshable\"/>").click(function(e) {
          if (e.which !== 1) {
            return;
          }

          e.stopPropagation();
          cardsList.data("inited", false);
          loadCards();
        });
        h.append(refresh);
      }
      return h;
    }

    function loadCards() {
      if (!cardsList.data("inited")) {
        $.ajax({
          beforeSend: function() {
            cardsList.empty().
              append(header("Cards")).
              append("<dd class=\"loading\"><i class=\"fa fa-refresh fa-spin\"></i></dd>");
          },
          dataType: "json",
          url: cardsList.data("url")
        }).done(function(data) {
          cardsList.empty().append(header("Cards", true));
          if (data.length === 0) {
            cardsList.append("<dd class=\"no-cards\">You have no assigned cards in this project</dd>");
          } else {
            var usedCardTypes = {};
            $.each(data, function(i, card) {
              var color = MingleUI.cardTypeColors[card.type];

              if (!usedCardTypes[card.type]) {
                usedCardTypes[card.type] = color;
              }

              var a = $("<a><span class=\"card-summary-number\">#" +
                  card.number + "</span>\n<span class=\"name\">" +
                  card.name + "</span></a>").
                attr("href", card.url).
                css("border-left", "solid 6px " + color);
              cardsList.append($("<dd class=\"card-icon\"/>").append(a));
            });
            cardsList.append(header("Card types").addClass("legend"));
            $.each(usedCardTypes, function(ct, color) {
              cardsList.append($("<dd class=\"color-legend\"/>").
                text(ct).
                prepend("<i style=\"background-color: " + color + "\"/>"));
            });
          }
          cardsList.data("inited", true);
        }).fail(function(xhr, status, error) {
          cardsList.empty().
            append(header("Cards", true)).
            append("<dd class=\"no-cards\">Failed to load cards.</dd>");
        });
      }
    }

    function taskElement(json) {
      var t = $("<dd/>", {"data-id": json.id, "class": "item"}).
        append($("<input/>", {"type": "checkbox", "checked": json.done})).
        append("<span class=\"actions\"><i class=\"fa fa-pencil\"/><i class=\"fa fa-times-circle\"/></span>").
        append($("<span class=\"body\" contenteditable=\"false\"/>").text(json.content)).data("original-content", json.content);
      return t;
    }

    function resetBody(body) {
      var item = body.closest(".item");
      body.attr("contenteditable", false);
      body.text(item.data("original-content"));
    }

    function initTodos(list) {
      list.prepend($("<i/>", {"class": "fa fa-trash-o"}).click(function(e) {
        list.toggleClass("remove");
      }));
      var tasks = $("<dl/>", {"class": "tasks"}).appendTo(list);
      var completed = $("<dl/>", {"class": "completed"}).appendTo(list);

      function itemUrl(item) {
        var id = item.data("id");
        return list.data("url").replace(/(\.json)$/, "/" + id + "$1");
      }

      function cleanup() {
        var stale = completed.find("dd").slice(5);
        if (stale.size() > 0) {
          var ids = $.map(stale, function(el) {
            return $(el).data("id");
          });

          $.ajax({
            data: {"ids": ids},
            dataType: "json",
            url: list.data("url"),
            type: "DELETE"
          }).done(function(data) {
            stale.fadeOut(150, stale.remove);
          });
        }
      }

      function track(action) {
        mixpanelTrack("my_todos", {"action": action});
      }

      tasks.sortable({
        axis: "y",
        items: ".item",
        containment: tasks,
        cursor: "move",
        distance: 3,
        cancel: "i,input,.actions,[contenteditable='true']",
        update: function(e, ui) {
          var sortedIds = $.map(list.find(".item"), function(el) {
            return $(el).data("id");
          });

          $.ajax({
            url: list.data("url").replace(/(\.json)$/, "/sort" + "$1"),
            data: {"todos": sortedIds},
            type: "POST"
          }).done($.noop).fail(function(xhr, status, error) {
            tasks.sortable("cancel");
          });
        }
      });

      tasks.on("submit", "form", function(e) {
        e.preventDefault();
        var form = $(this);
        var input = form.find("input[type='text']");
        var desc = $.trim(input.val());
        input.val(desc);

        if ("" === desc) {
          return;
        }

        // doesn't make sense to be in delete-mode when adding a task
        list.removeClass("remove");

        $.ajax({
          url: form.attr("action"),
          data: form.serialize(),
          dataType: "json",
          type: form.attr("method").toUpperCase()
        }).done(function(data) {
          form.get(0).reset();
          form.closest("dd").after(taskElement(data));
          track("create");
        });
      });

      tasks.on("click", ".actions .fa-pencil", function(e) {
        var description = $(this).closest(".item").find(".body").attr("contenteditable", true);
        description.focus();
      });

      list.on("click", ".actions .fa-times-circle", function(e) {
        var item = $(this).closest(".item");
        $.ajax({
          url: itemUrl(item),
          dataType: "json",
          type: "DELETE"
        }).done(function(data) {
          item.fadeOut(150, function() { item.remove(); });
        });
      });

      tasks.on("keydown", "[contenteditable='true']", function(e) {
        var body = $(this);
        var item = body.closest(".item");
        switch(e.which) {
          case $.ui.keyCode.ENTER:
            e.preventDefault();
            var updatedText = $.trim(body.text());

            if ("" === updatedText) {
              resetBody(body);
              break;
            }

            $.ajax({
              url: itemUrl(item),
              data: {"content": updatedText},
              dataType: "json",
              type: "PUT"
            }).done(function(data) {
              body.text(data.content);
              body.attr("contenteditable", false);
              item.data("original-content", updatedText);
            });
            break;
          case $.ui.keyCode.ESCAPE:
            resetBody(body);
            break;
          default:
            break;
        }
      });

      tasks.on("blur", "[contenteditable='true']", function(e) {
        resetBody($(this));
      });

      list.on("change", "input[type='checkbox']", function(e) {
        var element = $(this);
        var item = element.closest("dd");
        var props = {"done": element.prop("checked")};

        if (!props.done) {
          // when undoing the completion of a task, put it at the bottom
          props["position"] = list.find(".item").size() + 1;
        }

        $.ajax({
          url: itemUrl(item),
          data: props,
          dataType: "json",
          type: "PUT"
        }).done(function(data) {
          if (data.done) {
            item.hide().detach().insertAfter(completed.find("dt")).show(200);
            cleanup();
            track("finish");
          } else {
            item.hide().detach().appendTo(tasks).show(200);
          }
        });
      });

      list.data("inited", true);
    }

    element.popover({
      beforeShow: function() {
        loadCards();

        var list = $(".my-list");

        if (!list.data("inited")) {
          initTodos(list);
        }

        var tasks = list.find(".tasks");
        var completed = list.find(".completed");

        $.ajax({
          beforeSend: function() {
            list.removeClass("remove").find(".fa-trash-o").hide();
            completed.empty();
            tasks.html(header("To-do")).append("<dd class=\"loading\"><i class=\"fa fa-refresh fa-spin\"></i></dd>");
          },
          dataType: "json",
          url: list.data("url")
        }).done(function(data) {
          list.find(".fa-trash-o").show();
          tasks.html(header("To-do"));
          completed.html(header("Completed"));

          var form = $("<form>", {"action": list.data("url"), "method": "POST"}).
            append("<input name=\"content\" type=\"text\" placeholder=\"Add new to-do\"/>");
          tasks.append($("<dd class=\"new\"/>").append(form));

          $.each(data, function(i, el) {
            if (!el.done) {
              tasks.append(taskElement(el));
            } else {
              completed.append(taskElement(el));
            }
          });
        });
      }
    });
  };
})(jQuery);

$j(document).ready(function() {
  $j("#my-work").workMenu();
});
