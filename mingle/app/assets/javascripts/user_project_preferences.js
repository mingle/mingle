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
    UserProjectPreferences = function() {

        function createMessage(checkBox,projectName) {
            var message = "You have successfully ";
            message += checkBox.prop('checked') ? 'subscribe' : 'unsubscribe';
            return message +" for "+projectName;
        }

        function getErrorHandler(){
            var container = $j('#main .main_inner');
            return makeErrorHandler($, container, {
                errorElementCssClass: "slack-murmur-notification-subscription-error-message",
                customrErrorReasons: {
                    401: "Unprocessable entity"
                }
            });
        }

        function callBack(checkBox){
            return function(err){
                getErrorHandler(err);
                checkBox = $j('#' + checkBox.attr('id'));
                checkBox.prop('checked', !checkBox.prop('checked'));
            };
        }

        function subscribeUnsubscribe(projectId) {

            var checkBox = $('#slack_murmur_subscription_'+projectId);
            var projectName = $('#project_'+projectId).text().trim();
            var params = {
                project_id: projectId,
                user_project_preference: {  preference:'slack_murmur_subscription', value: checkBox.prop('checked') },
                format: 'json'
            };

            $.ajax(checkBox.data('update-subscription-url'), {
                method: 'PUT',
                data: params
            }).done(function(_) {
                $j("#flash #notice").text(createMessage(checkBox,projectName));
            }).fail(callBack(checkBox));
        }
        return {
            subscribeUnsubscribe: subscribeUnsubscribe
        };
    }();

})(jQuery);