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
var TrialFeedback = {
  showForm: function(url) {
    (function($){
      $.ajax({
        type: 'get',
        url: url
      });
    })(jQuery);
  }
};

(function ($) {
  $(document).on('ajax:send', 'form#trial-feedback', function() {
    InputingContexts.top().lightbox.enableBlurClick();
    $(this).parents(".trial-feedback").removeClass("prevent-close");
    $('#trial-feedback-container').remove();
    var thank_you_message = $("<div class='thank-you-message'><p>Thank you!</p><div class='message-line'>Follow us on twitter <a href='https://twitter.com/thatsmingle' target='_blank'>@thatsmingle</a> or check out <a href='http://getmingle.io' target='_blank'>our blog</a> getmingle.io</div> </div>");
    thank_you_message.insertAfter('.trial-feedback');
  });
})(jQuery);
