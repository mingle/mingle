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
(function ($) {
  Slack = function() {

    function toggleSectionDisplay(section) {
      $j(section).toggleClass("hide");
    }
    function updateChannelType(formId) {
      var form = $j(formId);
      var optionGroup = form.find('#selected_slack_channel_id option:selected').parent('optgroup');
      var channelType = optionGroup.attr('label');
      form.find('#is_private').val( channelType === 'Private channels' );
    }

    function isEulaAccepted(form) {
      var checkbox = form.find('#eula_acceptance');

      return checkbox.prop('checked');
    }

    function isChannelSelected(form) {
      var optionGroup = form.find('#selected_slack_channel_id option:selected').parent('optgroup');

      return optionGroup.size() > 0;
    }

    function shouldDisableSubmitForMapChannels(form) {
      return !isChannelSelected(form) || (!isEulaAccepted(form));
    }

    function shouldDisbaleSubmitForAuth(form) {
      return (!isEulaAccepted(form));
    }

    var submitDisableChecksForEulaContext = {
      add_to_slack: shouldDisbaleSubmitForAuth,
      slack_user_auth: shouldDisbaleSubmitForAuth,
      map_channels: shouldDisableSubmitForMapChannels
    };

    function toggleSubmit(formId, eula_context) {
      var form = $j(formId);
      var submit = form.find('input:submit');

      submit.prop('disabled', submitDisableChecksForEulaContext[eula_context](form));
    }

    function channelUpdateHandler(formId, eula_context) {
      updateChannelType(formId);
      toggleSubmit(formId, eula_context);
    }

    function resetMapChannelForm() {
      var form = $j('#slack_channel_form');
      form[0].reset();
      form.find('#selected_slack_channel_id').trigger('change');
    }

    function removeIntegrationChecked(value){
      if($("#remove_"+value+"_integration").is(':checked'))
        $("#remove_"+value+"_integration_submit").attr("disabled", false);
      else
        $("#remove_"+value+"_integration_submit").attr("disabled", true);
    }

    return {
      toggleSectionDisplay: toggleSectionDisplay,
      toggleSubmit: toggleSubmit,
      channelUpdateHandler: channelUpdateHandler,
      resetMapChannelForm: resetMapChannelForm,
      removeIntegrationChecked: removeIntegrationChecked
    };
  }();

})(jQuery);