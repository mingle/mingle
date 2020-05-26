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
LastVisitedTocLink = Class.create({
  initialize: function(tocElement) {
    this.tocElement = tocElement;
    this.memory = null;
  },

  remember: function(){
    var selectedEntry = this.tocElement.find('.current');
    if (selectedEntry) {
      this.memory = selectedEntry;
      selectedEntry.removeClass('current').addClass('not-current');
    }
  },

  highlightLastRemembered: function(attribute){
    this.memory.addClass('current').removeClass('not-current');
  }
});

MingleHelpSearch = Class.create({
  initialize: function(){
    this.form = $j('#search_form');
    this.welcomeToMingleDiv = $j('#help_content');
    this.noResultsMessageDiv = $j('#no_result_message');
    this.searchResultsContainer = $j('#search_results_container');
    this.searchResults = this.searchResultsContainer.find('#search_results');
    this.lastSelectedToCLink = new LastVisitedTocLink($j('#nav .toc'));
    this.queryString = "";
    this.createSearchBox();
  },

  createSearchBox: function() {
    var el = $j("<input>", {class:'search-input', type:'text', placeholder:'Search help'}  );
    el.on("keyup", this.handleKeyUp.bind(this));
    this.form.html(el);
  },

  handleKeyUp: function(event){
    if(event.which === 13){
      this.queryString = event.target.value;
      if(!this.queryString) return;
      this.doSearch();
    }
  },

  doSearch: function(pageNumber) {
    var queryParams = {q: this.queryString, page_number: pageNumber || 1, page_size: PAGE_SIZE},
        mingleHelpSearch = this;
    $j.ajax({
      url: URL + '?' + $j.param(queryParams),
      beforeSend: function() {
        mingleHelpSearch.searchResults.empty();
        mingleHelpSearch.searchResultsContainer.hide();
      },
      success: this.processResults.bind(this)
    });
  },

  processResults: function(data){
    if(data.total === 0 || data.results.length === 0) {
      this.noResultsMessageDiv.find('.search_term').html(this.queryString);
      this.searchResultsContainer.append(this.noResultsMessageDiv);
      this.noResultsMessageDiv.show();
    } else {
      this.searchResults.append(data.results.collect(this.createResultEntry));
      this.noResultsMessageDiv.hide();
      this._addPaginationLinks(Math.ceil(data.total/PAGE_SIZE), data.current_page);
    }
    this.lastSelectedToCLink.remember();
    if(this.lastSelectedToCLink.memory && this.lastSelectedToCLink.memory.length)
    {
      var backLink = $j('#hide_search_results');
      backLink.html('Back to ' + this.lastSelectedToCLink.memory.html());
      backLink.attr('href', this.lastSelectedToCLink.memory.attr('href'));
      backLink.show();
    }
    this.searchResultsContainer.show();
    this.welcomeToMingleDiv.hide();
  },

  createResultEntry: function(result) {
    var searchResult = $j("<div>", {class: "search-result"}),
        title = $j('<div>',{class: 'search-result-title'}),
        snippet = $j("<span>", {class: "search-snippet"});
    title.append($j("<a>", {target: "_blank", href: result.url, text: result.title}));
    snippet.append(title, $j('<div>').html(result.highlight));
    var img = $j("<span>", {class: "img-container"});
    var imageLink = $j('<a>', {target: '_blank', href: result.url});
    imageLink.html($j("<img>", {src: result.image ? result.image : 'resources/stylesheets/images/mingle_icon.png'}));
    img.append(imageLink);
    searchResult.append(img);
    searchResult.append(snippet);
    return searchResult;
  },

  _addPaginationLinks: function(totalPages, startPage) {
    var mingleHelpSearch = this,
        pagination = $j('<div>', {class: 'search-results-pagination-container'}).twbsPagination({
          first: "&laquo; First",
          prev: "&lsaquo; Prev",
          next: "Next &rsaquo;",
          last: "Last &raquo; ",
          startPage: startPage,
          totalPages: totalPages,
          visiblePages: 10,
          initiateStartPageClick: false,
          onPageClick: function (event, page) {
            mingleHelpSearch.doSearch(page);
          }
        });
    this.searchResults.append(pagination);
  }
});

document.observe('dom:loaded', function() {
  new MingleHelpSearch();
});