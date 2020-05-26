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
DropList.View.Filter = Class.create({
  initialize: function(model, filterAction) {
    this.optionsModel = model;
    this.filterAction = filterAction;
  },

  render: function(dropLinkPanel, dropdownPanel){
    var filterElement = this._createFilterElement();
    var filterContainer = new Element('div');
    filterContainer.addClassName('dropdown-filter-container');
    filterContainer.addClassName('ignore-width');
    var searchIcon = new Element('span');
    searchIcon.addClassName('fa fa-search indicator');
    filterContainer.appendChild(filterElement);
    filterContainer.appendChild(searchIcon);
    dropdownPanel.optionsContainer.insert({ before : filterContainer});
    dropdownPanel.optionsContainer.observe('mingle:droplist_scroll_to_bottom', this.onScrollToBottomListener.bindAsEventListener(this));

    filterContainer.observe('click', this.onClickListener.bindAsEventListener(this));

    // We observe keydown for special case in firefox, #see bug #8304
    // and Safari & IE work as what we want for keydown too
    filterElement.observe('keydown', this.onValueChangeListener.bindAsEventListener(this));
    // We also need observe keypress on firefox, for it keeps fire keypress event
    // when user press a key (e.g. delete) for a while, which is what we need
    // see bug #8621
    if (Prototype.Browser.Gecko) {
      filterElement.observe('keypress', this.onValueChangeListener.bindAsEventListener(this));
    }

    this.filterInput = filterElement;
    this.searchIcon = searchIcon;
  },

  onScrollToBottomListener: function(event) {
    if (this.filterAction && this.filterInput.value) {
      this.filterAction('nextPage', this.searchIcon, this.optionsModel, this.filterInput.value);
    }
  },

  onClickListener: function(event) {
    event.stop();
  },

  onValueChangeListener: function(event) {
    var keyCode = event.keyCode;
    /*jsl:ignore*/
    if (keyCode == Event.KEY_RETURN ||
        keyCode == Event.KEY_ESC ||
        keyCode == Event.KEY_UP ||
        keyCode == Event.KEY_DOWN ||
        keyCode == Event.KEY_LEFT ||
        keyCode == Event.KEY_RIGHT ||
        keyCode == Event.KEY_HOME ||
        keyCode == Event.KEY_END ||
        keyCode == Event.KEY_PAGEUP ||
        keyCode == Event.KEY_DOWN ||
        keyCode == Event.KEY_INSERT) { return; }
    /*jsl:end*/
    setTimeout(function() {
      if (this.filterAction) {
        this.filterAction('firstPage', this.searchIcon, this.optionsModel, this.filterInput.value);
      } else {
        this.optionsModel.filter(this.filterInput.value);
      }
    }.bind(this), 5);
  },

  _createFilterElement: function() {
    var e = new Element('input');
    e.addClassName('dropdown-options-filter');
    return e;
  },

  onDropLinkClicked: function() {
    this.filterInput.value = '';
  },

  reset: function() {
    if (this.filterAction) {
      this.filterAction('reset', this.searchIcon, this.optionsModel);
    }
  }
});
