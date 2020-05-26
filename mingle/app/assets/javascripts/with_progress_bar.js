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
(function($){

  var progressBarElementHtml = '<span class="progress">' +
                                 '<span class="progress-bar" role="progressbar">' +
                                   '<span class="sr-only">saving...</span>' +
                                 '</span>' +
                               '</span>';

  $.fn.withProgressBar = function(opts) {

    if ("undefined" === typeof opts) {
      opts = {};
    }

    var wrapper = $("<span class=\"with-progress-bar\"/>");
    if ("string" === typeof opts.wrapperClass) {
      wrapper.addClass(opts.wrapperClass);
    }

    var eventType = opts.event || "submit";

    if("undefined" === typeof opts.attachTo) {
      opts.attachTo = this;
    }
    if ($(opts.attachTo).parents('.with-progress-bar').length) {
      return;
    }
    $(opts.attachTo).wrap(wrapper);

    var progressBarElement = $(progressBarElementHtml);

    progressBarElement.hide();
    progressBarElement.insertBefore(opts.attachTo);

    this.bind(eventType, function() {
      progressBarElement.css('display', 'inline-block');
    });

    $(document).ajaxComplete(function() {
      progressBarElement.hide();
    });
    Ajax.Responders.register({
      onComplete: function(r,j) {
        progressBarElement.hide();
      }
    });

    return this;
  };


})(jQuery);
