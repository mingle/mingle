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

  var GO_TO_NUMBER_REGEX = /^#(D?)(\d+)$/i;

  $(function() {
    function submitHandler(e) {
      e.stopPropagation();

      var searchInput = $(e.currentTarget).find("input[type='text']");
      var searchString = $.trim(searchInput.val());

      if ("" === searchString) {
        e.preventDefault();
        searchInput.focus();
      }

      if (GO_TO_NUMBER_REGEX.test(searchString)) {
        e.preventDefault();
        $.ajax({
          url: $(e.currentTarget).data("popup-url"),
          type: "GET",
          data: {q: searchString}
        }).fail(function(xhr, status, error) {
          searchInput.tipsyFlash(xhr.responseText, {gravity: "n"});
        }).always(function() {
          searchInput.blur();
        });
      }

    }

    $("#header").on("submit", "form.search", submitHandler);
 });
})(jQuery);
