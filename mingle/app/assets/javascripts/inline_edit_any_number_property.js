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

  function saveChange(ele) {
    var propName = ele.data('property-name');
    var propValue = ele.val();
    var params = {
      changed_property: propName,
      card: ele.data('card-id'),
      format: 'json'
    };
    params['properties[' + propName +']'] = propValue;
    var saving = $("<div class='notes inline-editing-saving'>saving...</div>");
    var pp = $(ele.parent());
    pp.append(saving);
    pp.parent().find('.error').remove();
    $.ajax(ele.data('url'), {
      method: 'POST',
      data: params
    }).done(function(data) {
      saving.remove();
      if (data.length) {
        data.each(function(s) {
          var errorMsg = $("<div class='error'>" + s + "</div>");
          pp.parent().append(errorMsg);
        });
      }
    });
  }

  var saveLink = $("<a href='javascript:void(0)'>save</a>").addClass("save-number");
  var cancelLink = $("<a href='javascript:void(0)'>cancel</a>").addClass("cancel-save-number");
  var actionLinkContainer = $("<div class='edit-any-number-action-container'></div>").append(saveLink).append(cancelLink);
  var originalValue;

  MingleUI.readyOrAjaxComplete(function() {
    var inlineEditNumContainer = $('.inline-any-number-property');
    inlineEditNumContainer.find("input").unbind('focus').unbind("blur").unbind("keypress");

    inlineEditNumContainer.find('input').on('click', function() {
      $(this).select();
    }).on('focus', function() {
      originalValue = $(this).val();
      var input = $(this);
      $(this).parent().append(actionLinkContainer);
      actionLinkContainer.find("a.cancel-save-number").on("mousedown", function() {
        input.val(originalValue);
        $(this).unbind("mousedown");
      });
    }).on('blur', function() {
      if ($(this).val() !== originalValue) {
        saveChange($(this));
      }
      actionLinkContainer.remove();
    }).on("keypress", function(e) {
      if (e.which == 13) {
        if ($(this).val() !== originalValue) {
          saveChange($(this));
          originalValue = $(this).val();
        }
      }
    });
  });
})(jQuery);
