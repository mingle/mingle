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
$j(document).ready(function() {
    function reloadMessage(regenerate) {
        if (regenerate) {
            $j('#hmac-key-warning').show();
            $j("input#generate-hmac").val('Regenerate');
        } else {
            $j('#hmac-key-warning').hide();
            $j("input#generate-hmac").val('Generate');
        }
    }

    reloadMessage($j('#hmac-form').data('key-status'));
    $j("input#generate-hmac").click(function() {
        var confirmation = confirm("Are you sure you want to generate new key?");
        if(confirmation) {
            reloadMessage(true);
        }
    });
});
