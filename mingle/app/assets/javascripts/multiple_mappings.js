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
    MultipleMappings = function() {

    function update(channelsList){
        var channels = $j(channelsList);
        var channelsData = getChannelToUpdate(channels);
        disableCancel();
        $.ajax({
            url: $j("#slack-channel-list").data("update-channel-mappings-url"),
            type: "POST",
            dataType: "json",
            contentType: 'application/json',
            data: JSON.stringify({ "channelsToUpdate": channelsData })
        }).done(function(data, status, xhr) {
            $j("#save-channels").blur();
            if (data["error"]) {
                displayFlashMessage("error", data.error);
            } else {
                displayFlashMessage("success", "The channel mappings were updated successfully.");
            }
            updateChannelData(data.updatedChannels);

        });
    }

    function updateChannelData(updatedChannels) {
        if (updatedChannels) {
            for (var i in updatedChannels) {
                var channel = updatedChannels[i];
                var channelCheckbox = $j("#toggle_channel_" + channel.channelId);
                channelCheckbox.data("mapped", channel.mapped);
                channelCheckbox.prop("checked", channel.mapped);
            }
        }
    }

    function updateCancelButton() {
        var cancelButtonDisabled = true;
        $j('.slack-channel-container input').each(function (i, checkbox) {
            if ($j(checkbox).prop("checked") != $j(checkbox).data("mapped")) {
                cancelButtonDisabled = false;
                return false;
            }
        });
        $j("#reset-selection").prop('disabled', cancelButtonDisabled);
    }

    function displayFlashMessage(messageType, message) {
        $("#flash").empty().append(
            $("<div class='" + messageType + "-box'/>").
            append(
                $("<div class=\"flash-content\" id=\"notice\"/>").
                text(message)
            )
        );
    }

    function needUpdate(channel) {
        var channelElement = $j(channel);
        return (channelElement.data('mapped') && !channelElement.prop('checked')) || ( !channelElement.data('mapped') && channelElement.prop('checked'));
    }

    function getAction(prop) {
        return prop ? 'ADD' : 'REMOVE' ;
    }

    function createChannelMappingData(channel){
        var channelElement = $j(channel);
        return {
            channelId   : channelElement.prop('value'),
            name        : channelElement.data('channel-name'),
            action      : getAction(channelElement.prop('checked')),
            privateChannel     : channelElement.data('is-private')
        };
    }

    function getChannelToUpdate(channels){
        var channelsToUpdate = [];
        channels.each(function(_,channel){
            if(needUpdate(channel))
                channelsToUpdate.push(createChannelMappingData(channel));
        });
        return channelsToUpdate;
    }

    function resetChannelsList(channelsList){
        $j(channelsList).each(function(_,channel){
            if(needUpdate(channel)){
                var channelElement  = $j(channel);
                channelElement.prop('checked', !channelElement.prop('checked'));
            }
        });
        disableCancel();
    }

    function disableCancel() {
        $j("#reset-selection").prop('disabled', true);
    }

    return {
        getChannelToUpdate:getChannelToUpdate,
        update: update,
        resetChannelsList:resetChannelsList,
        updateCancelButton: updateCancelButton
    };
  }();

})(jQuery);