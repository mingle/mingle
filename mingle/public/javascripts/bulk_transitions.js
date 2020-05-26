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
BulkTransitions = Class.create({
  initialize: function(checkboxes, regularApplyForm, requireCommentForm, url) {
    this.checkboxes = checkboxes;
    this.cardTransitions = $A([]);
    this.regularApplyForm = $(regularApplyForm);
    this.requireCommentForm = $(requireCommentForm);
    this.url = url;
    this.transitionButton = $("bulk_transitions");
    this.transitionSlideDownPanel = new SlideDownPanel($('transition-selector'), this.transitionButton, MingleUI.align.alignLeft, { beforeShow : this.beforePanelShow.bind(this) });
    this.noTransitionMessage = $('transition-selector').down('.no_transition_message');
    this.transitionsContainer = $('bulk-transitions-options-container');
    this.checkboxes.registerObserver(this.onCheckBoxClick.bindAsEventListener(this));
    this._evaluateTransitionButtonClickable();
    this.panelOpenObserver = Prototype.emptyFunction;
  },

  beforePanelShow: function() {
    this._makeRequest(this.checkboxes.getSelectedValues());
    this.panelOpenObserver(this);
  },

  close: function() {
    this.transitionSlideDownPanel.close();
  },

  registerPanelOpenObserver: function(observer){
    this.panelOpenObserver = observer;
  },

  updateTransitions: function(cardTransitions) {
    this.cardTransitions = $H(cardTransitions);
    var selectedCards = this.checkboxes.getSelectedValues();
    var transitionsForSelectedCards = selectedCards.map(function(cardId) {
      return cardTransitions[cardId];
    }, this);
    var commonTransitions = Array.findIntersection(transitionsForSelectedCards, function(transitionData, transition) { return transitionData.pluck('name').include(transition.name); });
    if (commonTransitions && commonTransitions.any()) {
      this._hideNoTransitionsMessage();
      this.build_options(commonTransitions);
      this.transitionsContainer.show();
    } else {
      this._showNoTransitionsMessage();
    }
  },

  onCheckBoxClick: function(event) {
    this._evaluateTransitionButtonClickable();
  },

  onSubmitTransition: function(event) {
    var applyForm;
    var selectedTransitionId = Event.element(event).id.match(/transition_(\d+)/)[1];
    if (this._isRequireComment(selectedTransitionId)) {
      applyForm = this.requireCommentForm;
    } else {
      applyForm = this.regularApplyForm;
    }
    applyForm.getInputs('hidden', 'selected_cards')[0].value = this.checkboxes.getSelectedValues();
    applyForm.getInputs('hidden', 'transition_id')[0].value = selectedTransitionId;

    this.transitionSlideDownPanel.close();
    if (this._isRequireComment(selectedTransitionId)) {
      this._submitCommentForm(applyForm);
    } else {
      this._submitRegularForm(applyForm);
    }
  },

  build_options: function(commonTransitions) {
    this.transitionsContainer.update(commonTransitions.map(function(transitionData) { return this._create_transition_li(transitionData.name, transitionData.html_id); }, this).join(''));
    commonTransitions.each(function(transitionData) { $(transitionData.html_id).down().observe('click', this.onSubmitTransition.bindAsEventListener(this)); }.bind(this));
  },

  disableTransitionButton: function() {
    this.transitionButton.addClassName('disabled');
    this._resetDropdownPanel();
  },

  _evaluateTransitionButtonClickable: function() {
    var disable = this.checkboxes.noSelection();
    if (disable) {
      this.disableTransitionButton();
    } else {
      this.transitionButton.removeClassName('disabled');
    }
  },

  _makeRequest: function(cardIds) {
    this._resetDropdownPanel();
    new Ajax.Request(this.url, { method: 'get', parameters: { 'card_ids[]' : cardIds }, onCreate: function(){$('actions-spinner').show();}, onComplete: function(){$('actions-spinner').hide();}});
  },

  _submitRegularForm: function(regularForm){
    regularForm.submit();
  },

  _submitCommentForm: function(ajaxForm) {
    ajaxForm.onsubmit();
  },

  _isRequireComment: function(transitionId) {
    var transitionHash = this.cardTransitions.values().flatten().detect(function(transitionHash) { return transitionHash.id == transitionId; });
    return transitionHash.require_comment;
  },

  _hideNoTransitionsMessage: function(){
    this.noTransitionMessage.hide();
  },

  _showNoTransitionsMessage: function(){
    this.noTransitionMessage.show();
  },

  _create_transition_li: function(transitionName, transitionId) {
    return "<li id='" + transitionId + "'><a id='" + transitionId + "_link' href='javascript:void(0)' onclick='return false;'>" + transitionName + "</a></li>";
  },

  _resetDropdownPanel: function(){
    this.transitionsContainer.update('').hide();
    this._hideNoTransitionsMessage();
  }
});
