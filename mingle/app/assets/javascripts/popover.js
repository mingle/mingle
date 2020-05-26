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

  function withinOrIs(element, container) {
    return container.filter($(element)).length > 0 || container.has($(element)).length > 0;
  }

  function isLeftClick(e) {
    return 1 === e.which;
  }

  function contentElement(container) {
    return container.find(".content, .popover-content");
  }

  function show(container, options) {
    container.addClass("open");
    container.trigger("popover:open");

    var clickElseWhereHandler = function(e) {
      if (isLeftClick(e) && !withinOrIs(e.target, container)) {
        var content = contentElement(container);
        options.beforeClose.apply(container, [content, e]);
        hide(container);
        options.afterClose.apply(container, [content, e]);
      }
    };
    $(document).click(clickElseWhereHandler);
    container.data("popover:clickElseWhereHandler", clickElseWhereHandler);
  }

  function hide(container) {
    container.removeClass("open");
    container.trigger("popover:close");

    var clickElseWhereHandler = container.data("popover:clickElseWhereHandler");
    if(clickElseWhereHandler) {
      $(document).unbind('click', clickElseWhereHandler);
    }
  }

  function handleClick(element, options, event) {
    var content = contentElement(element);

    if (options.shouldShow && (options.shouldShow.apply(element, [content, event]) == false)) {
      return;
    }
    if (withinOrIs($(event.target), content)) {
      return;
    }

    if (content.is(':hidden')) {
      options.beforeShow.apply(element, [content, event]);
      show(element, options);
      options.afterShow.apply(element, [content, event]);
    } else {
      options.beforeClose.apply(element, [content, event]);
      hide(element);
      options.afterClose.apply(element, [content, event]);
    }
  }

  $.fn.popover = function(options) {
    options = $.extend({}, $.fn.popover.defaults, options);
    return this.each(function() {
      var element = $(this);
      if (element.data("popover:clickHandler")) {
        element.unbind('click', element.data("popover:clickHandler"));
      }
      var clickHandler = function(event) {
        handleClick(element, options, event);
      };
      element.data("popover:clickHandler", clickHandler);
      element.click(clickHandler);
    });


  };

  $.fn.popoverClose = function() {
    hide($(this));
    return this;
  };


  $.fn.popover.defaults = {
    beforeShow: $.noop,
    afterShow: $.noop,
    beforeClose: $.noop,
    afterClose: $.noop
  };
})(jQuery);
