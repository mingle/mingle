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
  MingleUI.EasyCharts.PreviewContainer = function (helpUrl) {
    var self = this, previewPanel;

    function addTitle() {
      var titleContainer = $('<div>', {class: 'clearfix preview-title-container'}),
          title = $('<span>', {class: 'preview-title', text: 'Preview'}),
          helpLink = $('<a>', {
            href: helpUrl,
            target: 'blank',
            title: 'Click to open help document',
            class: 'page-help-at-action-bar',
            text: 'Help'
          });
      self.htmlContainer.append(titleContainer);
      titleContainer.append(title);
      titleContainer.append(helpLink);
    }

    function initialize() {
      self.htmlContainer = $j('<div>', {class: 'easy-charts-preview-panel-container'});
      addTitle();
      previewPanel = $j('<div>', {id: 'macro_preview', class: 'preview-panel wiki'});
      self.htmlContainer.append(previewPanel);
    }

    function cardCountMessage(count) {
      return ((count === '0' ) ? 'no cards found' : ((count === '1' ) ? '1 card found' : count + ' cards found'));
    }

    this.updatePreview = function (content) {
      previewPanel.html(content);
    };

    this.displayErrorMessage = function (content, format) {
      if (format)
        content = $j('<div>', {class: 'error macro', text: content.trim().replace(/^[a-z]/, function(m) { return m.toUpperCase(); })});
      previewPanel.html(content);
    };

    this.updateCardCount = function (count) {
      previewPanel.html($j('<div>', {class: 'card-count-container', text: cardCountMessage(count)}));
    };

    this.reset = function () {
      previewPanel.empty();
    };

    initialize();
  };
})(jQuery);