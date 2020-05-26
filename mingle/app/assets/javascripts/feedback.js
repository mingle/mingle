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
var Mingle = Mingle || {};

(function ($) {
  $(function(){
     var feedbackForm = {
      initialize: function() {
        var messageBox = $('.feedback-message').focus();
        var emailTextField = $('.email-text-field');

        function checkEmailFormat(e) {
          var field = e.target;
          if ("function" === typeof field.setCustomValidity) {
            if (field.validity.typeMismatch || field.validity.patternMismatch) {
              field.setCustomValidity("Please enter a valid email address.");
            } else {
              field.setCustomValidity("");
            }
          }
        }

        function feedbackSubmitHandler(e) {
          e.preventDefault();
          e.stopPropagation();

          var feedbackMessage = $.trim(messageBox.val());
          var emailAddress = $.trim(emailTextField.val());

          var form = $(e.target);

          messageBox.val(feedbackMessage);
          emailTextField.val(emailAddress);

          if (!emailAddress || 0 === emailAddress.length) {
              emailTextField.attr("placeholder", "You haven't entered an email address.") ;
              emailTextField.focus();
              return false;
          }

          if ( !feedbackMessage || 0 === feedbackMessage.length) {
              messageBox.attr("placeholder", "You haven't mentioned anything yet.") ;
              messageBox.focus();
              return false;
          }

          var timeouts = [];

          $.ajax({
            url: form.attr("action"),
            type: "POST",
            data: form.serialize(),
            beforeSend: function(xhr, settings) {
              $.each(timeouts, function(i, id) {
                clearTimeout(id);
              });

              $(".send-error").remove();
            }
          }).done(function(data) {
            $('#speak-with-us-container').remove();
            var thank_you_message = $("<p class='thank-you-message'>Thanks for your feedback!</p>");
            thank_you_message.insertAfter('.speak-with-us');
          }).fail(function(xhr, status, error) {
            var errorMsg = $('<div class="send-error"/>').html('<span>Failed to send message:</span> <div class="reason">' + status + "</div>");
            form.find(".send-feedback input[type='submit']").after(errorMsg);
            timeouts.push(setTimeout(function() { errorMsg.remove(); }, 5000));
          });
        }

        function emailUpdateNoticeHandler(e) {
          var field = $('.email-text-field');
          var defaultEmail = field.data("default-user-email");
          if (defaultEmail) {
            if (defaultEmail !== field.val()) {
              $('.email-message').html("<p>Thanks! We see you've entered a new email address above.</p> <p>We will continue to use <strong>" + defaultEmail + "</strong> as your account email.</p>" );
            }
          }
        }

        $("#speak-with-us").on("submit", feedbackSubmitHandler);
        emailTextField.on('input', checkEmailFormat);
        emailTextField.on('change', emailUpdateNoticeHandler);
      }
    };

    Mingle.feedbackForm = feedbackForm;
  });
})(jQuery);
