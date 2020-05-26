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
MingleUI = MingleUI || {};

(function($) {
  function convertToOption(user, idFieldName) {
    return [user['name'], user[idFieldName] + '', user['name'], {src: user['icon'], color: user['color']}];
  }

  function appendRecentUsers(list, idFieldName) {
    var ret = [];
    var recentUsers = $('[data-recent-users]').data('recent-users') || [];
    $.each(recentUsers, function(i, ele) {
      ret.push(convertToOption(ele, idFieldName));
    });
    return list.concat(ret);
  }

  function loadingOption() {
    var opt = $('<li/>').addClass('loading-option');
    opt.append($('<i>').addClass('fa fa-refresh fa-spin fa-2x'));
    return opt;
  }

  function filterUsersAction(defaultOptions, idFieldName) {
    return function(action, indicatorEle, optionsModel, q) {
      var indicator = $(indicatorEle);
      var panel = indicator.parents('.dropdown-panel');
      var actionOptions = panel.find('.droplist-action-option');
      if (action == 'nextPage') {
        if (indicator.data('total-entries') == optionsModel.options.length) {
          return;
        }
      }
      if (action == 'reset' || q == '') {
        optionsModel.replaceOptions(defaultOptions, true);
        optionsModel.fireEvent('filterValueChanged');
        optionsModel.fireEvent('mingle:droplist_replace_options');
        actionOptions.show();
        panel.find('.loading-option').remove();
        return;
      }

      indicator.addClass('fa-refresh fa-spin').removeClass('fa-search');

      var page = action == 'firstPage' ? 1 : indicator.data('page') + 1;
      $.ajax({
        url: $('[data-users-search-url]').data('users-search-url'),
        type: 'GET',
        data: {
          search: { query: q },
          page: page,
        },
        dataType: "json"
      }).done(function(data) {
        indicator.addClass('fa-search')
          .removeClass('fa-refresh fa-spin')
          .data('page', data['data-current-page'])
          .data('total-entries', data['data-total-entries']);

        // deep copy from default options any project variables or special values before the model filters
        var options = JSON.parse(JSON.stringify(defaultOptions.filter(function(el) {
          return el[1] === "" || /^\(.+\)$/.test(el[1]);
        })));

        var initialLen = options.length;

        $.each(data['data-users'], function(i, ele) {
          options.push(convertToOption(ele, idFieldName));
        });

        if (options.length === 0) {
          options = [["", null]];
        }

        if (page === 1) {
          optionsModel.replaceOptions(options, true);
        } else {
          optionsModel.addOptions(options, true);
        }

        // filter value changed event will trigger UI element redraw
        // we need redraw UI elements before do filtering to bold
        // search terms
        optionsModel.fireEvent('filterValueChanged');
        optionsModel.filter(q, false);
        optionsModel.cursor.updateOptions(optionsModel.getVisibleOptions(), true);

        if (page === 1) {
          optionsModel.fireEvent('mingle:droplist_replace_options');
          if (data['data-total-entries'] !== 0) {
            actionOptions.hide();
          }
          if (panel.find('.loading-option').length === 0) {
            panel.find('.options-only-container').append(loadingOption());
          }
        }
        if (data['data-total-entries'] === 0 || data['data-total-entries'] === (optionsModel.options.length - initialLen)) {
          panel.find('.loading-option').remove();
        }
      });
    };
  }

  MingleUI.initUserSelector = function(config, idFieldName) {
    if ($('[data-recent-users]').length == 0) {
      return;
    }
    config.selectOptions = appendRecentUsers(config.selectOptions, idFieldName);
    config.filterAction = filterUsersAction(config.selectOptions, idFieldName);
    config.supportFilter = true;
  };

  var userTemplate = "<li class='user'><img class='avatar'/><span class='name'></span></li>";
  var loadMoreTemplate = "<li class='load-more'><button>Load More</button></li>";

  function appendUsersToPanel(panel, usersPanel) {
    usersPanel.data('users').each(function(user) {
      var id = 'select-user-' + user.id;
      if (usersPanel.find('#' + id).length) {
        return;
      }
      var ele = $(userTemplate).attr("id", id).data('user-id', user.id).data('user-name', user.name).data('user-login', user.login);
      var name = user.name + " (@" + user.login + ")";
      ele.find('.avatar').attr("src", user.icon).attr('title', name).attr('style', 'background-color: ' + user.color);
      ele.find('.name').text(name);
      usersPanel.append(ele);
    });
    if (usersPanel.data('current-page') < usersPanel.data("total-pages")) {
      appendLoadMore(panel, usersPanel);
    }
  }

  function updateData(usersPanel, data) {
    usersPanel.data('users', data['data-users']);
    usersPanel.data('current-page', data['data-current-page']);
    usersPanel.data('total-entries', data['data-total-entries']);
    usersPanel.data('total-pages', data['data-total-pages']);
  }

  function appendLoadMore(panel, usersPanel) {
    var loading = false;
    $(loadMoreTemplate).appendTo(usersPanel).click(function() {
      if (loading) {
        return;
      }
      loading = true;
      var $this = $(this);
      $this.html('<i class="fa fa-refresh fa-spin fa-2x"></i>');
      var page = usersPanel.data('current-page') + 1;
      var input = panel.find('.search-field');
      $.ajax({
        url: panel.data('users-search-url'),
        type: 'GET',
        data: {
          page: page,
          search: { query: input.val() }
        },
        dataType: "json"
      }).done(function(data) {
        $this.remove();
        updateData(usersPanel, data);
        appendUsersToPanel(panel, usersPanel);
        loading = false;
      });
    });
  }

  function updateUsersPanel(panel) {
    var usersPanel = panel.find('.users');
    usersPanel.html('');
    appendUsersToPanel(panel, usersPanel);
    panel.find('.pagination-info').text('Found ' + usersPanel.data('total-entries') + ' users');
  }

  function doSearch(panel) {
    var indicator = panel.find('.indicator');
    var input = panel.find('.search-field');
    var usersPanel = panel.find('.users');

    indicator.addClass('fa-refresh fa-spin').removeClass('fa-search');
    $.ajax({
      url: panel.data('users-search-url'),
      type: 'GET',
      data: {
        search: { query: input.val() }
      },
      dataType: "json"
    }).done(function(data) {
      indicator.addClass('fa-search').removeClass('fa-refresh fa-spin');
      updateData(usersPanel, data);
      updateUsersPanel(panel);
    });
  }

  $.fn.initSelectUserPanel = function(action_type) {
    var panel = $('.user-selector-lightbox');
    var input = panel.find('.search-field');
    updateUsersPanel(panel);

    panel.on('click', '.user', function() {
      var value = panel.data('action-type') == 'filter' ? $(this).data('user-login') : $(this).data('user-id');
      InputingContexts.feed({name: $(this).data('user-name'), value: value});
    });
    input.on('keyup', function(e) {
      doSearch(panel);
    });
    input.focus();
    panel.find('.search-results').height($(window).height() * 0.7 - 100).scrollToBottom(function(e) {
      panel.find('.load-more button').click();
    });
  };
})(jQuery);
