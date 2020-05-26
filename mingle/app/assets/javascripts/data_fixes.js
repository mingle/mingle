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
  $(document).ready(function() {
    var container = $('#data-fixes');
    if (!container.length) {
      return;
    }
    container.find('.spinner').show();
    container.find('tbody tr').each(function(i, element) {
      var required_status_url = $j(element).data('required-status-url');
      $.ajax({
        context: this,
        url: required_status_url,
        type: "GET"
      }).done(function(data) {
        $j(this).find('td.required').text(data);
        $j(this).find('td .spinner').hide();
      });
    });
  });
})(jQuery);