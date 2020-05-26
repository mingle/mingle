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
var CardListViewFavoriteHighlightingBase = Class.create({
  destroy: function() {},
  listenerKey: function() {
    return "remove-highlighted-favorite";
  }
});

var RemoveCardListViewFavoriteHighlighting = Class.create(CardListViewFavoriteHighlightingBase, {
  initialize: function(params) {
    this.params = params;
  },

  _asRailsParams: function(params) {
    return new RailsParams(params);
  },

  update: function(params) {
    var significantParamsFromServer = this._asRailsParams(params).exclude(this._paramsToExclude(params));
    var significantStoredParams = this._asRailsParams(this.params).exclude(this._paramsToExclude(params));
    if (significantParamsFromServer.equal(significantStoredParams)) {
      return;
    }
    $j("#favorites-container .favorites li.selected").removeClass("selected");
  },

  _paramsToExclude: function(params){
    return $A(['rank_is_on', 'name', 'action', 'controller', 'project_id', 'ms']);
  }
});

var RegisterCardListViewFavoriteHighlighting = Class.create(CardListViewFavoriteHighlightingBase, {
  initialize: function(favoriteId) {
    this.favoriteId = "favorite-" + favoriteId;
  },
  highlight: function() {
    if ($(this.favoriteId)) {
      $(this.favoriteId).addClassName('selected');
    }
  },
  update: function(params) {
    if ($(this.favoriteId)) {
      ParamsController.register(new RemoveCardListViewFavoriteHighlighting(params));
    }
  }
});
