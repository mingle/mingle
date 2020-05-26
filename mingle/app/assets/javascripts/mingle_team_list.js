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
  var users = [];

  var callback = {
    Draggable: function(img, view) {
      img.draggableIcon({
        startDragging: function() {
          view.popoverClose();
        }
      });
    },

    Assignable: function(img, view) {
      img.assignableIcon();
    }
  };


  function createIcon(user) {
    return $("<img></img>").
      attr("class", "avatar").
      attr("src", user.icon).
      attr("title", user.name).
      attr("data-name", user.name).
      attr("style", "background: " + user.color).
      attr("data-value-identifier", user.id);
  }

  function createInviteIcon() {
    return $("<span></span>").attr("class", "avatar invite-avatar show-form fa fa-plus-circle")
      .attr("title", "Invite another person to your team");
  }

  function setupInvitationCallback(view, users, memberCallback, searchBox) {
     var fn = function(user, newIcon) {
        users.push({
          label: user.name,
          id: ""+user.id+"",
          icon: user.icon,
          color: user.color
        });
        view.find(".users").find("ul").append($("<li></li>").append(newIcon));
        callback[memberCallback](newIcon, view);
        newIcon.click();
     };
     return fn;
  }

  function setupInviteForm(view, users, memberCallback, searchBox) {
    var card = view.parents(".card-icon");
    var inviteContainer = $("#" + card.attr("id") + " .assign-team-member");
    inviteContainer.inviteToTeam({
      beforeShow: function() {
        searchBox.hide();
        view.find(".unassign a").hide();
      },
      afterCancel: function() {
        searchBox.show().focus();
        view.find(".unassign a").show();
      },
      afterInvite: setupInvitationCallback(view, users, memberCallback, searchBox),
      onError: function() {
        searchBox.show().focus();
        view.find(".unassign a").show();
      },
      inviteFormAnchor: view
    });
  }

  function resetSearch(searchBox) {
    searchBox.val("");
    searchBox.autocomplete("search", "").focus();
  }

  function addInviteIcon(view) {
    var inviteIcon = createInviteIcon();
    view.find(".users ul").prepend(
      $("<li></li>").attr("class", "invite-item").append(inviteIcon)
    );
  }

  function renderTeamList(view, users, memberCallback, searchBox) {
    var ul = $("<ul> </ul>");
    $.each(users, function(_, user) {
        var img = createIcon(user);
        callback[memberCallback](img, view);
        ul.append($("<li></li>").append(img));
    });

    view.find(".users").html(ul);
  }

  function closePropertyDropDown(propertyList) {
    propertyList.removeClass("open");
    propertyList.addClass("closed");
  }

  function openPropertyDropDown(propertyList) {
    propertyList.removeClass("closed");
    propertyList.addClass("open");
  }

  function setupDropDown(selectedPropertyName, teamList) {
    var props = $(teamList.find(".avatars").data("slot-ids"));
    if (!props.length) {
      return;
    }

    teamList.find(".property-assignment-selector").remove();
    var propertyListContainer = $("<div/>").addClass("property-assignment-selector");
    var selectedProperty = $("<div/>").addClass("selected-property");
    selectedProperty.text(selectedPropertyName || props[0]);
    propertyListContainer.append(selectedProperty);

    var propertyList = $("<ul/>").addClass("property-list closed");
    propertyListContainer.append(propertyList);

    teamList.find(".avatars").find(".slot[data-slot-id='" + selectedProperty.text() + "']").addClass("current-property");

    props.each(function(i, el) {
      var prop = $("<li/>").addClass("property-to-assign-to");
      prop.attr("data-property-name", el);
      prop.text(el);
      prop.hover(function() {
        teamList.find(".avatars").find(".slot").removeClass("current-property");
        teamList.find(".avatars").find(".slot[data-slot-id='" + $(this).data("property-name") + "']").addClass("current-property");
      }).mouseleave(function() {
        teamList.find(".avatars").find(".slot").removeClass("current-property");
        teamList.find(".avatars").find(".slot[data-slot-id='" + selectedProperty.text() + "']").addClass("current-property");
      });
      prop.click(function() {
        selectedProperty.text($(this).data("property-name"));
        teamList.find(".avatars").find(".slot").removeClass("current-property");
        teamList.find(".avatars").find(".slot[data-slot-id='" + selectedProperty.text() + "']").addClass("current-property");
      });
      propertyList.append(prop);
    });

    propertyListContainer.click(function() {
      if (propertyList.hasClass("closed")) {
        openPropertyDropDown(propertyList);
      } else {
        closePropertyDropDown(propertyList);
      }
    });
    teamList.find(".card-assign").prepend(propertyListContainer);
  }

  $.fn.mingleTeamList = function(memberCallback) {
    this.each(function() {
      var teamList = $(this).find(".full-team-list");

      if (memberCallback === "Draggable") {
        $(this).find(".avatar").draggableIcon();
      }

      teamList.popover({
        beforeShow: function(content, event) {
          if (memberCallback == "Assignable") {
            content.empty().append($("#team-list-popover-content")[0].outerHTML);
            var selectedProperty = $(event.target).parent().data("slot-id");
            setupDropDown(selectedProperty, teamList);
            teamList.find(".unassign").unAssignableIcon();
          } else {
            content.html('<input type="text" class="search-for-team-members" placeholder="Kevin Bacon"/><div class="users short-list"></div>');
          }

          var searchBox = teamList.find("input.search-for-team-members");
          searchBox.show();
          teamList.find(".unassign a").show();
          searchBox.autocomplete({
            minLength: 0,
            delay: 0,
            source:function(request) {
              renderTeamList(teamList, $.ui.autocomplete.filter(users, request.term.toString()), memberCallback, searchBox);
            }
          });

          teamList.find(".assign-team-member form").hide();

         if(!teamList.data("data-loaded")) {
          $.ajax($("#team-list-popover-content").data("url"), {
              success: function(data) {
                users = data;
                setupInviteForm(teamList, users, memberCallback, searchBox);
                resetSearch(searchBox);
                teamList.data("data-loaded", true);
              }
            });
          }
        },

        shouldShow: function(content, event) {
          return true;
        },

        afterShow: function(content, event) {
          if(teamList.data("data-loaded")) {
            resetSearch(teamList.find("input.search-for-team-members"));
          }
        },
        beforeClose: function(content, event) {
          teamList.find(".avatars").find(".slot").removeClass("current-property");
        }
      });

    });
    return this;
  };
})(jQuery);
