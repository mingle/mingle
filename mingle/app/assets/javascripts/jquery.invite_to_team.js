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
  function showForm(form){
    form.find('input[type=submit]').attr('disabled', 'disabled');
    form.siblings(".show-form").hide();
    form.show();
    form.find('input[type=text]').focus();
  }

  function cancelForm(form) {
    form.hide();
    form.siblings(".show-form").show();
    form.find(".spinner").hide();
    form.find('input[type=text]').val('');
    form.find('input[type=text]').tipsy('hide');
    form.find('input[type=submit]').attr('disabled', 'disabled');
  }

  function validEmail(email) {
    if (/.+\@.+\..+/.match(email)) {
      return true;
    }
    return false;
  }

  function enableSubmit(email, submitButton) {
    if(validEmail(email)){
      submitButton.removeAttr('disabled');
    } else {
      submitButton.attr('disabled', 'disabled');
    }
  }

  function enableAutocomplete(form, emailInput, submitButton) {
    emailInput.autocomplete({
      source: emailInput.data('invite-suggestions-url'),
      position: { my: "left bottom", at: "left top" },
      appendTo: form,
      select: function(event, autoCompleteSelected){
        enableSubmit(autoCompleteSelected.item.value, submitButton);
      }
    });
  }

  var handleFailedInvitation = function(event, xhr, status, error, form) {
    cancelForm(form);
    var data = {};
    try {
      data = jQuery.parseJSON(xhr.responseText);
    } catch (e) {

    }

    var errorMessage = "Unable to send invite.";

    if (data && data.errorMessage) {
      errorMessage = data.errorMessage;
    }

    if (data && data.errorHtml) {
      openLightboxWith(data.errorHtml);
    } else {
      form.parent().find(".show-form").tipsyFlash(errorMessage);
    }

  };

  function handleSuccessfulInvitation(event, data, status, xhr, form, afterInvite) {
    cancelForm(form);
    form.siblings('.show-form').tipsyFlash("Invitation sent!");
    if (data && data.buy) {
      openLightboxWith(data.buy);
    }
    if (data.license_alert_message) {
      updateLicensesAlertMessage(data.license_alert_message);
      disableInviteButtonIfNeeded(data);
    }
    var newIcon = refreshTeamList(data);
    afterInvite(data, newIcon);

    var type = 'existing';
    if (xhr.status == 201) {
      type = 'new';
    }
    trackInviteEvent(type, form.parent().find('.show-form').attr('class'));
  }

  function disableInviteButtonIfNeeded(data) {
    if (data.license_alert_message === 'No licenses left' ) {
      $('#ft button.show-form').attr('disabled', 'true');
    }
  }
  
  function updateLicensesAlertMessage(license_alert_message) {
    if($('#ft .low-on-licenses-alert').length) {
      $('#ft .low-on-licenses-alert span').text(license_alert_message);

    }
    else {
      $('#ft > div.also-viewing').before("<div class='low-on-licenses-alert'></div>");
      $('#ft .low-on-licenses-alert').append('<span>'+license_alert_message+'</span>');
    }
  }
  function openLightboxWith(content) {
    InputingContexts.push(new LightboxInputingContext(null, {closeOnBlur: true}));
    InputingContexts.update(content);
  }

  function refreshTeamList(data) {
    var img = $("<img>").
        attr("class", "avatar").
        attr("src", data.icon).
        attr("title", data.name).
        attr("data-name", data.name).
        attr("style", "background: " + data.color).
        attr("data-value-identifier", data.id);

    $('#ft .team-list').find('.placeholder').first().replaceWith(img.clone().draggableIcon());
    return img;
  }

  var trackShowEvent = function(selector){
    if (typeof mixpanel !== undefined && MingleJavascript.metricsEnabled === true) {
      mixpanel.track("show_invite_form", { clicked_to_open: selector });
    }
  };


  var trackInviteEvent = function(type, selector) {
    if (typeof mixpanel !== undefined && MingleJavascript.metricsEnabled === true) {
      mixpanel.track('invite_user', { type: type, clicked_to_open: selector });
    }
  };

  $.fn.inviteToTeam = function(opts) {
    var options = $.extend({}, {
      beforeShow: function() {},
      afterCancel: function() {},
      afterInvite: function() {},
      onError: function() {},
      inviteFormAnchor: null
    }, opts);

    options.inviteFormAnchor = options.inviteFormAnchor || this;

    var form = function() { return $(options.inviteFormAnchor).find('form'); };
    var submitButton = form().find('input[type=submit]');
    var emailInput = form().find('input[type=text]');

    form().submit(function(event) {
      if(validEmail(emailInput.val())) {
        $(this).find(".spinner").show();
      } else {
        event.preventDefault();
      }
    });

    form().on('ajax:success', function(event, data, status, xhr) {
      handleSuccessfulInvitation(event, data, status, xhr, $(form()), options.afterInvite);
    });

    form().on('ajax:error', function(event, xhr, status, error) {
      options.onError();
      handleFailedInvitation(event, xhr, status, error, $(form()));
    });

    $(options.inviteFormAnchor).on("click", ".show-form", function(event){
      options.beforeShow();
      showForm(form());
      trackShowEvent(event.target.className);
    });

    $(".placeholder").click(function(){
      options.beforeShow();
      showForm(form());
      trackShowEvent(".placeholder");
    });

    $(options.inviteFormAnchor).on("click", ".cancel", function(){
      cancelForm(form());
      options.afterCancel();
      return false;
    });

    enableAutocomplete(form(), emailInput, submitButton);

    emailInput.keyup(function(){
      enableSubmit(emailInput.val(), submitButton);
    });

    return this;
  };
})(jQuery);
