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

  function saveChange(ele, property_name, pbw) {
    var propName = ele.find('#' + property_name).val();
    var propValue = ele.find('[name="properties[' + propName + ']"]').val();
    var viewParams = $('[data-view-params]').data('view-params');
    var params = $.extend(viewParams, {
      property_name: propName,
      property_value: propValue,
      properties_expanded: $('#card-properties').data('properties-expanded')
    });

    pbw.trigger("mingle.propertyChanged");

    $j('.enter-edit').addClass('disabled');
    $.ajax(ele.data('url'), {
      method: 'POST',
      data: params
    }).done(function() {
      MingleUI.lightbox.reloadFlyoutPanel(pbw.closest('.card-popup-lightbox'));
      $j('.enter-edit').removeClass('disabled');
    });
  }

  $.fn.savePropertyChange = function(property_name) {
    this.each(function(i, element) {
      saveChange($(element), property_name, $(this).parents(".progress-bar-wrapper"));
    });
    return this;
  };

  $.fn.showSavePropertyErrorMessage = function(msg) {
    var errorMsg = $('<div class="card-error-message show-mode-only"/>').
      html('Something went wrong:  <div class="reason">' + msg + "</div>");
    var panel = $(this[0]).parent();
    errorMsg.css('left', panel.position().left);
    panel.append(errorMsg);
    setTimeout(function() { errorMsg.remove(); }, 5000);
  };

})(jQuery);
