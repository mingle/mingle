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
var makeErrorHandler = function($, errorMessageContainer, options) {
    return function onSaveError(xhr, _, error) {
        var errorReasons = $.extend({}, {
            0: "Mingle cannot be contacted or network is down. Please try again later.",
            401: "Session time out occurred. You need to signin again.",
            500: "Mingle cannot process your request at this time. Please try again later.",
            406: "You do not have permissions to perform this action"
        }, options.customrErrorReasons);
        errorReasons[502] = errorReasons[503] = errorReasons[504] = errorReasons[0];
        var reason = errorReasons[xhr.status] || "There is a technical error. Please save copy and save content and try again later.";
        var errorMessageElementHtml = "<div class=\"" + options.errorElementCssClass + "\"/>";
        var errorMsg = $(errorMessageElementHtml).html('Something went wrong:  <div class="reason">' + reason + '</div>');
        errorMessageContainer.prepend(errorMsg);
        setTimeout(function () {
            errorMsg.remove();
        }, 5000);
    };
};