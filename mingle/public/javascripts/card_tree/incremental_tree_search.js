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

Module.mixin(TreeView, {
  initIncrementalSearch: function(searchPanel) {
    this.incrementalSearch = new IncrementalTreeSearch(this.tree, this.canvas, searchPanel);
  },

  registerWithRedrawSearchPanel: function(tree, canvas) {
    this.hideIncrementalSearchWhenRegisterTree();
    this.registerWithoutRedrawSearchPanel(tree, canvas);
    this.showIncrementalSearchAfterRegisterTree();
  },

  aliasMethodChain: [['register', 'redrawSearchPanel']],

  hideIncrementalSearchWhenRegisterTree: function() {
    if($('tree_incremental_search')){
      $('tree_incremental_search').hide();
    }
  },

  showIncrementalSearchAfterRegisterTree: function() {
    if($('tree_incremental_search')) {
      $('tree_incremental_search').show();
    }
  },

  resetSearchSession: function() {
    this.incrementalSearch.resetSearch();
  }
});

var SearchInfoPanel = Class.create({
  initialize: function(element) {
    this.element = $(element);
  },

  show: function(msg) {
    this.element.innerHTML = msg.escapeHTML();
  },

  clear: function() {
    this.element.innerHTML = "";
  }
});

var TreeSearchSession = Class.create({
  initialize: function(search, results) {
    this.search = search;
    this.results = results;
    this.currentIndex = 0;
  },
  /* jshint ignore:start */
  /*jsl:ignore*/
  highlightCurrent: function() { with(this) {
    search.clearLastHighlight();
    search.highlight(results[currentIndex]);
  }},

  highlightNext: function() { with(this) {
    currentIndex ++;
    if(currentIndex >= results.size()) {
      currentIndex = 0;
    }
    highlightCurrent();
  }},

  highlightPrevious: function() { with(this) {
    currentIndex --;
    if(currentIndex < 0) {
      currentIndex = results.size() - 1;
    }
    highlightCurrent();
  }}
  /*jsl:end*/
  /* jshint ignore:end */
});

var NoResultTreeSearchSession = Class.create({
  initialize: function(search) {
    this.search = search;
  },

  highlightCurrent: function() {
    this.search.clearLastHighlight();
  },

  highlightNext: function() {
    this.search.clearLastHighlight();
  },

  highlightPrevious: function() {
    this.search.clearLastHighlight();
  }
});

TreeSearchSession.create = function(search, results, infoPanel) {
  var session = null;
  if(results.size() == 0) {
    session = new NoResultTreeSearchSession(search);
    infoPanel.show('Not found');
  } else {
    session = new TreeSearchSession(search, results);
    infoPanel.show(results.size() + " matches");
  }
  session.highlightCurrent();
  return session;
};

var IncrementalTreeSearch = Class.create({
  initialize: function(tree, canvas, container) {
    this.tree = tree;
    this.canvas = canvas;
    container = $(container);
    this.infoPanel = new SearchInfoPanel(container.down('.info'));
    this.buttons = [new Button(container.down('.previous-button'), this.goPrev.bind(this)),
                    new Button(container.down('.next-button'), this.goNext.bind(this)),
                    new Button(container.down('.clear-button'), this.resetSearch.bind(this))];
    this.input = container.down('.q');
    this.input.observe('keyup', this.onKeyPress.bindAsEventListener(this));
    HotKey.register('`', this.activateSearchBox.bindAsEventListener(this));
    this.resetSearch();
  },

  activateSearchBox: function() {
    this.input.focus();
  },

  resetSearch:function() {
    this.clearLastHighlight();
    this.infoPanel.clear();
    this.buttons.invoke('disable');
    this.input.value = '';
  },

  goNext: function() {
    if(this.session) {this.session.highlightNext();}
  },

  goPrev: function() {
    if(this.session) {this.session.highlightPrevious();}
  },

  onKeyPress: function(event) {
    if([Event.KEY_LEFT, Event.KEY_UP, Event.KEY_RIGHT, Event.KEY_DOWN, Event.KEY_HOME, Event.KEY_END].include(event.keyCode)) {
      return;
    }

    if(event.keyCode == Event.KEY_RETURN) {
      event.shiftKey ? this.goPrev() : this.goNext();
      return;
    }

    if(event.keyCode == Event.KEY_ESC) {
      this.resetSearch();
      return;
    }

    this.createSession();
  },

  createSession: function() {
    if(this.input.value.blank()) {
      this.resetSearch();
      return;
    }
    var nodes = this.tree.search(this.input.value);
    this.session = TreeSearchSession.create(this, nodes, this.infoPanel);
    this.buttons.invoke('enable');
  },

  highlight: function(node) {
    this.lastHightLightElement = node.innerElement();
    node.highlight();
    this.canvas.centralizeOn(node.innerElement());
  },

  clearLastHighlight: function() {
    if(this.lastHightLightElement) {
      this.lastHightLightElement.removeClassName('searching-matched');
    }
  }
});