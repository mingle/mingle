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

var currentWord = function(inputElement) {
  var string = inputElement.value;
  return string.substring(0, inputElement.selectionStart).split(' ').pop();
};

var replaceCurrentWord = function(inputElement, word) {
  var text = inputElement.value;
  var preWords = text.substring(0, inputElement.selectionStart).split(' ');
  var postWords = text.substring(inputElement.selectionStart);

  preWords.pop();
  preWords.push(word);
  if(!postWords.startsWith(' '))
    preWords.push("");

  inputElement.value = preWords.join(" ") + postWords;
};


var usersCache = null;

var makeFilter = function($, inputElement, usersUrl) {
  return function(request, response) {
    var term = currentWord(inputElement).replace(/^@/, '');
    if (usersCache) {
      var results = $.ui.autocomplete.filter(usersCache, term);
      response(results.slice(0, 100));
    } else {
      $.getJSON(usersUrl, function(data, status, xhr) {
        usersCache = data;
        var results = $.ui.autocomplete.filter(usersCache, term);
        response(results.slice(0, 100));
      });
    }
  };
};

(function($) {
  var inputElement = null;

  var renderAutocompleteItem = function(ul, item) {
    var img;
    if (item.icon == 'fa-users') {
      img = '<i class="fa fa-users fa-2x"></i>';
    } else {
      img = $("<img/>").attr({
        src: item.icon,
        style: item.icon_options.style,
        onerror: item.icon_options.onerror
      });
    }
    var i = $("<a>").text(item.label).prepend(img);
    return $j("<li class='murmur-input-autocomplete'>").append(i).appendTo(ul);
  };

  var selectItem = function(event, ui) {
    replaceCurrentWord(inputElement, ui.item.value);
    event.stopPropagation();
    return false;
  };

  function bindKeypress(element) {
    $(element).keypress(function(e) {
      inputElement = $(this).get(0);
      var startWithAt = currentWord(inputElement).indexOf('@') == 0;
      var atKey = e.which === 64;

      if (e.which == 32 || e.which == 13 || (!startWithAt && !atKey)) {
        $(this).autocomplete("disable");
        return;
      }
      var usersUrl = $(this).data('users-url');

      $(this).autocomplete({
        disabled: false,
        appendTo: $(this).parent(),
        source: makeFilter($, inputElement, usersUrl)
      }).data("ui-autocomplete")._renderItem = renderAutocompleteItem;
    }).autocomplete({
      position: {my: "left top", at: "left bottom"},
      disabled: true,
      autoFocus: true,
      close: function(event, ui) {
        $(this).autocomplete('disable');
      },
      select: selectItem,
      focus: function() {
        // prevent value inserted on focus
        return false;
      }
    });
  }

  $.fn.at_user_autocomplete = function() {
    this.each(function(i, element) {
      if (!$(element).data('autocomplete-bound')) {
        bindKeypress(element);
        $(element).data('autocomplete-bound', true);
      }
    });
  };

  MingleUI.readyOrAjaxComplete(function() {
    $('[data-at-login-autocomplete=true]').at_user_autocomplete();
  });

})(jQuery);
