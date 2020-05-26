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

var RichTextarea = Class.create({
  initialize: function(element) {
    this.element = $(element);
    this.capturedSelection = {start: 0, end: 0};
  },
  
  setContent: function(text) {
    this.element.value = text;
  },
  
  getContent: function() {
    return this.element.value;
  },
  
  captureSelectionForInsert: function() {
    this.capturedSelection = this.getSelection();
  },
  
  getSelection: function() {
    return {start: this.element.selectionStart, end: this.element.selectionEnd };
  },
  
  setSelection: function(start, end) {
    this.element.selectionStart = start;
    this.element.selectionEnd = end;
    this.captureSelectionForInsert();
  },
  
  setCursor: function(pos) {
    this.setSelection(pos, pos);
  },
  
  insert: function(text) {
    var oldContent = this.getContent();
    var leading = oldContent.substring(0, this.capturedSelection.start);
    var trailing = oldContent.substring(this.capturedSelection.end, oldContent.length);
    this.setContent(leading + text + trailing);
    this.setSelection(leading.length, (leading + text).length);
  },
  
  focus: function() {
    this.element.focus();
  }
});

Module.mixinOnIe(RichTextarea.prototype, {
  aliasMethodChain: [['getSelection', 'ieFix'], ['setSelection', 'ieFix'], ['getContent', 'ieFix']],
  
  getSelectionWithIeFix: function() {
    this._ieSelectionPrepare();
    return this.getSelectionWithoutIeFix();
  },
  
  getContentWithIeFix: function() {
    return this.getContentWithoutIeFix().gsub("\r\n", '\n');
  },
  
  setSelectionWithIeFix: function(start, end) {
    var range = this.element.createTextRange();
    range.collapse(true);
    range.moveStart('character', start);
    range.moveEnd('character', end - start);
    range.select();
    return this.setSelectionWithoutIeFix(start, end);
  },
  
  _ieSelectionPrepare: function() {
    this.focus();
    var range = document.selection.createRange();
    var stored_range = range.duplicate();
    stored_range.moveToElementText(this.element);
    stored_range.setEndPoint('EndToEnd', range);
    this.element.selectionStart = this._textLength(stored_range) - this._textLength(range);
    this.element.selectionEnd = this.element.selectionStart + this._textLength(range);
  },
  
  _textLength : function(range) {
    return range.text.gsub("\r\n", '\n').length;
  }
});
