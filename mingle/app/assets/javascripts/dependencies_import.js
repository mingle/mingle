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
    $("#dependencies-import-preview").on('dblclick', ".raising-card .card-select", function(event) {
      event.stopPropagation();
      event.preventDefault();
      return false;
    });

    $("#dependencies-import-preview").on('click', ".raising-card .card-select", function(event) {
      var element = $(event.currentTarget);
      if (element.data("opened")) return;
      InputingContexts.push(new LightboxInputingContext(function(value) {
        element.closest(".raising-card").find("input.raising-card-number").val(value.number);
        element.closest(".raising-card").find("input.raising-card-name").val(value.name_without_number);
        element.find(".summary").text(value.name);
      }, {
        afterDestroy: function() {
          element.data("opened", false);
        }
      }));
      event.stopPropagation();
      event.preventDefault();

      element.data("opened", true);
      $.ajax({
          url: $(event.currentTarget).data("card-selector-url"),
          type: 'GET',
          dataType: "script"
      }).fail(function() {
        InputingContexts.pop();
      });
    });

    $("#dependencies-import-preview").on("click", ".paginated tfoot a", function(e) {
      e.preventDefault();
      e.stopPropagation();
      $(e.currentTarget).closest(".paginated").removeClass("paginated");
      $("#dependencies-import-preview").off("click", ".paginated tfoot a");
    });

  });
})(jQuery);