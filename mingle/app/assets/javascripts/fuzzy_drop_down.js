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
/* this plugin is really a combination of 2 widgets: a customized autocomplete and popover */
(function($) {

  function cancel(e) {
    e.preventDefault();
  }

  $.widget( "mingle.filteredList", $.ui.autocomplete, {
    _create: function() {
      this._super();

      if (this.options.containerClass) {
        this.menu.element.attr("class", this.options.containerClass);
      }
    },
    _renderItem: function( ul, item ) {
      var link = $( "<a>" ).attr("href", item.url);
      if (item.stats && item.stats.length > 0) {
        link.html(MingleUI.fuzzy.highlight(item.label, item.stats));
      } else {
        link.text(item.label);
      }

      var li = $( "<li>" );
      if (this.options.itemClass) {
        li.attr("class", this.options.itemClass);
      }

      return li.append(link).appendTo(ul);
    },
    _close: function(e) {
      if (e && ["blur", "keydown"].indexOf(e.type) !== -1) {
        e.preventDefault();
        return;
      }
      this._superApply(arguments);
    },
    _suggest: function(items) {
      this._superApply(arguments);
      if (items.length === 1) {
        this.menu.next();
      }
    }
  });

  $.fn.fuzzyDropDown = function fuzzyDropDown(options) {
    options = $.extend({}, $.mingle.filteredList.prototype.options, options);

    var dropdown = this;
    var form = dropdown.find("form").on("submit", cancel);
    var filter = form.find("input");
    var noResults = dropdown.find(".no-results");

    if (!dropdown.data("cache")) {
      dropdown.data("cache", []);
    }

    function defaultClose(e, dropdown) {
      dropdown.popoverClose();
    }

    dropdown.on("keydown", "input[type='text']", function(e) {
      if (e.keyCode === $.ui.keyCode.ESCAPE) {
        return (options.closeOnEscFn || defaultClose)(e, dropdown);
      }
    });

    filter.filteredList({
      minLength: 0,
      delay: 0,
      appendTo: form,
      position: {using: $.noop},
      containerClass: options.containerClass,
      itemClass: options.itemClass,
      source: function( request, response ) {
        response(MingleUI.fuzzy.finder(dropdown.data("cache"), request.term.toString()));
      },
      focus: function(e, ui) {
        e.preventDefault();
        var userInputEvent = e.originalEvent.originalEvent;
        if (userInputEvent && (/^key/.test(userInputEvent.type))) {
          $(this).val(ui.item.label);
        }
      },
      response: function(e, ui) {
        if (ui.content.length === 0) {
          menu.empty();
          noResults.show();
        } else {
          noResults.hide();
        }
      },
      select: function(e, ui) {
        dropdown.popoverClose();
        var domEvent = e.originalEvent.originalEvent;

        // stop event when trigger by the TAB key - strange choice for default behavior
        if (/key/.test(domEvent.type) && domEvent.keyCode === $.ui.keyCode.TAB) {
          e.preventDefault();
        } else {
          (options.onselect || cancel)(e, ui);
        }
      }
    });

    var menu = filter.filteredList("widget");

    dropdown.popover({
      beforeShow: function(content) {
        filter.val("");
        (options.beforeShow || $.noop)(content, filter);
      },
      afterShow: function(content) {
        filter.focus().filteredList("search", "");
        (options.afterShow || $.noop)(content, filter);
      }
    });
  };

})(jQuery);