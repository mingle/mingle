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
var MingleUI = (MingleUI || {});
MingleUI.EasyCharts = (MingleUI.EasyCharts || {});

(function ($) {
  MingleUI.EasyCharts.PreviewGenerator = function (previewContainer, data, callbacks) {
    var previewData = {}, onSuccess = ensureFunction(callbacks.onSuccess), onError = ensureFunction(callbacks.onError),
        disabled;

    function initialize() {
      previewData.content_provider = {
        provider_type: data.contentProvider.type,
        id: data.contentProvider.id
      };
      previewData.macro_type = data.chartType;
    }

    function onAjaxError(response) {
      if (response.status === 200 || response.status === 422) {
        if (response.getResponseHeader('content-type').match(/json/g))
          previewContainer.displayErrorMessage(response.responseJSON.errors.join(), true);
        else
          previewContainer.displayErrorMessage(response.responseText);
      } else {
        previewContainer.displayErrorMessage("Something went wrong while generating preview. Please try again with valid chart parameters.", true);
      }
      onError && onError();
    }

    function generatePreview() {
      $.ajax({
        type: 'POST',
        url: UrlHelper.macroPreviewUrl(data.projectIdentifier),
        data: previewData
      }).done(function (chartCallback) {
        previewContainer.updatePreview(chartCallback);
        onSuccess && onSuccess();
      }).fail(onAjaxError);
    }

    this.updateCardCountPreview = function (projectIdentifier, cardCountMql) {
      if (disabled) return;
      if (cardCountMql.match(/THIS CARD/)) {
        var contentProvider = data.contentProvider;
        switch (contentProvider.type.toLowerCase()) {
          case 'page':
            previewContainer.displayErrorMessage('THIS CARD as value for card properties is not supported on pages/wiki.');
            return;
          case 'carddefaults':
            previewContainer.displayErrorMessage('Macros using THIS CARD will be rendered when card is created using this card default.');
            return;
          case 'card':
            cardCountMql = cardCountMql.replace(/THIS CARD/g, 'NUMBER ' + contentProvider.number);
        }
      }
      $.ajax({
        method: 'GET',
        url: UrlHelper.executeMqlJsonUrl(projectIdentifier),
        data: {mql: cardCountMql}
      }).done(function (data) {
        previewContainer.updateCardCount(data[0]['Count ']);
      }).fail(onAjaxError);
    };

    this.generate = function (macroValue ) {
      if (disabled) return;
      previewData.macro_editor = macroValue;
      generatePreview();
    };

    this.buildData = function (macroValue ) {
      previewData.macro_editor = macroValue;
      return previewData;
    };

    this.disable = function () {
      disabled = true;
    };

    this.enable = function () {
      disabled = false;
    };

    initialize();
  };
})(jQuery);
