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

var TreeConfigView = Class.create();
TreeConfigView.prototype = {
  initialize: function(container, typeSelections) {
    this.typeOptionsMediator = new TypeOptionsMediator();
    this.container = $(container);
    this.typeSelections = typeSelections;
    this.addNodeListener = this.addTypeNode.bindAsEventListener(this);
    this.removeNodeListener = this.removeTypeNode.bindAsEventListener(this);
    this.typeNodes = [];
    this._refresh();
  },

  _refresh: function() {
    this._attachAddRemoveEvent();
    this._toggleRemoveButton();
  },

  _toggleRemoveButton: function() {
    var operation = (this._typeNodeCount() <= 2) ? Element.hide : Element.show;
    this.container.select('.remove-button').each(operation);
  },

  getTreeViewContainer: function(){
    return this.container;
  },

  getAvailableTypes: function(){
    return this.typeSelections;
  },

  addTypeNode: function(event){
    var previousNodeContainer = Event.element(event).up(".type-node-container");
    var positionOfPreviousNode = this.getPosition(previousNodeContainer);
    this.createTypeNode(this.findTypeNodeByPosition(positionOfPreviousNode), '');
  },

  createTypeNode: function(previousTypeNode, defaultCardType, defaultRelationshipName){
    var typeNode = new TypeNode(this, previousTypeNode, this._generateUiquePosition(), defaultCardType, defaultRelationshipName);
    if(typeNode.isFirst()){
      this.typeNodes.push(typeNode);
    }else{
      var index = this.typeNodes.indexOf(previousTypeNode);
      this.typeNodes.splice(index + 1, 0, typeNode);
    }
    if(!this._isLastTypeNode(typeNode)){
      var nextIndex = this.typeNodes.indexOf(typeNode) + 1;
      var nextTypeNode = this.typeNodes[nextIndex];
      nextTypeNode.reconnectToPreviousTypeNode(typeNode);
    }
    this._renumberNodes();
    this._refresh();
    return typeNode;
  },

  removeTypeNode: function(event){
    if(this._typeNodeCount() <= 2) {return;}
    var nodeContainer = Event.element(event).up(".type-node-container");
    var position = this.getPosition(nodeContainer);
    var typeNode = this.findTypeNodeByPosition(position);
    var nextTypeNode = this.findTypeNodeByPosition(position + 1);
    this.typeNodes = this.typeNodes.without(typeNode);

    typeNode.destroy(nextTypeNode);
    this._renumberNodes();
    this._refresh();
  },

  _isLastTypeNode: function(typeNode){
    return this.typeNodes.length > 0 && this.typeNodes.length == (this.typeNodes.indexOf(typeNode) + 1);
  },

  _generateUiquePosition: function(){
    // Unique position is OK, because it will be renumbered
    return this.typeNodes.length;
  },

  getPosition: function(typeNodeContainer){
    return Number(typeNodeContainer.id.toString().match(/type_node_(\d*)_container/)[1]);
  },

  findTypeNodeByPosition: function(position){
    return this.typeNodes.detect(function(typeNode){
      return typeNode.getPosition() == position;
    }.bind(this));
  },

  registerDropListModel: function(dropListModel){
    this.typeOptionsMediator.addDroplistModel(dropListModel);
  },

  unRegisterDropListModel: function(dropListModel){
    this.typeOptionsMediator.removeDroplistModel(dropListModel);
  },

  _renumberNodes: function(){
    var typeNodeContainers = this.typeNodes.collect(function(typeNode){
      return [typeNode, typeNode.getTypeNodeContainer()];
    });
    typeNodeContainers.each(function(element, index){
      element[0].renumberNodeTo(element[1], index);
    });
  },

  _typeNodeCount: function() {
    return this.container.select('.type-node').size();
  },

  _attachAddRemoveEvent: function() {
    this.container.select('.add-button').each(function(element){
      Event.stopObserving(element, 'click', this.addNodeListener);
      Event.observe(element, 'click', this.addNodeListener);
    }.bind(this));

    this.container.select('.remove-button').each(function(element){
      Event.stopObserving(element, 'click', this.removeNodeListener);
      Event.observe(element, 'click', this.removeNodeListener);
    }.bind(this));
  }
};

var TypeOptionsMediator = Class.create();
TypeOptionsMediator.prototype = {
  initialize: function(){
     this.dropListModels = $A();
  },

  addDroplistModel: function(dropListModel){
    this.dropListModels.push(dropListModel);
    this._attachMethodChain(dropListModel);
  },

  removeDroplistModel: function(dropListModel){
    this.dropListModels = this.dropListModels.without(dropListModel);
  },

  _attachMethodChain: function(dropListModel) {
    dropListModel.getOptionsWithoutChain = dropListModel.getOptions;
    dropListModel.getVisibleOptions = function(){
      var options = dropListModel.getOptionsWithoutChain();
      options = options.reject(this._isSelectedAndNotBlank.bind(this));
      return options;
    }.bind(this);
  },

  _isSelectedAndNotBlank: function(option) {
    return !option.value.blank() && this.dropListModels.any(function(model){
        return model.isSelected(option);
    }.bind(this));
  }
};

var AggregateTypeNode = Class.create();
AggregateTypeNode.prototype = {
  initialize: function(previousTypeNode, position, cardType, relationshipName){

  }
};

var TypeNode = Class.create();
TypeNode.prototype = {
  initialize: function(treeConfigureView, previousTypeNode, position, defaultCardType, defaultRelationshipName){
    this.previousTypeNode = previousTypeNode;
    this.position = position;
    this.treeConfigureView = treeConfigureView;
    this.defaultCardType = defaultCardType;

    var typeNodeContainer = this._buildNewTypeNode();

    var treeViewContainer = treeConfigureView.getTreeViewContainer();
    if(this.isFirst()){
      treeViewContainer.appendChild(typeNodeContainer);
    }else{
      this.previousTypeNode.getTypeNodeContainer().insert({ after: typeNodeContainer});
      this.connector = this._buildRelationshipConector(this.previousTypeNode, defaultRelationshipName);
    }

    this.dropListModel = this._buildCardTypeDropList(treeConfigureView.getAvailableTypes(), defaultCardType);
    treeConfigureView.registerDropListModel(this.dropListModel);
  },

  renumberNodeTo: function(typeNodeContainer, position){
    this.position = position;
    if(!this.isFirst()){
      this.connector.renumberConnectorTo(typeNodeContainer.down('.relationship-connector'), this.getConnectorPosition());
    }
    typeNodeContainer.id = this._getTypeNodeContainerId();
    var typeNode = typeNodeContainer.down('.type-node');
    typeNode.id = this.getTypeNodeDivId();
    typeNode.down('.card-type-field').name = this._getCardTypeHiddenInputName();
    typeNode.down('.card-type-field').id = this._getCardTypeHiddenInputId();
  },

  reconnectToPreviousTypeNode: function(previousTypeNode, defaultRelationshipName){
    this.removeConnector();
    this.connector = this._buildRelationshipConector(previousTypeNode, defaultRelationshipName);
  },

  destroy: function(nextTypeNode){
    if (nextTypeNode) {
      if (this.isFirst()) { nextTypeNode._promoteToFirst();}
      else { nextTypeNode.reconnectToPreviousTypeNode(this.previousTypeNode, this.connector.getRelationshipName()); }
    }
    this.removeConnector();
    this.treeConfigureView.unRegisterDropListModel(this.getDropListModel());
    this.getTypeNodeContainer().remove();
  },

  _promoteToFirst: function(){
    this.removeConnector();
    this.previousTypeNode = null;
  },

  removeConnector: function(){
    if (this.isFirst()) {return;}
    this.connector.deactivate();
    // TODO:this can be move to connector.deactivate
    var oldConnector = this.getTypeNodeContainer().down('.relationship-connector');
    if (oldConnector != null){
      oldConnector.remove();
    }
  },

  isFirst: function(){
    return this.previousTypeNode ? false : true;
  },

  getDropListModel: function(){
    return this.dropListModel;
  },

  getTypeNodeContainer: function(){
    return $(this._getTypeNodeContainerId());
  },

  getPosition: function(){
    return this.position;
  },

  getConnectorPosition: function(){
    return (this.position - 1);
  },

  hasCardType: function(){
    return !(this.getCardType() == null || this.getCardType().blank());
  },

  getCardType: function(){
    if(this.getDropListModel()){
      return this.getDropListModel().selection.value;
    }else{
      return this.defaultCardType;
    }
  },

  _getTypeNodeContainerId: function(){
    return 'type_node_' + this.position + '_container';
  },

  getTypeNodeDivId: function(){
    return  'type_node_' + this.position;
  },

  _getCardTypeHiddenInputId: function(){
    return 'card_types[' + this.position + '][card_type_name]';
  },

  _getCardTypeHiddenInputName: function(){
    return 'card_types[' + this.position + '][card_type_name]';
  },

  _buildNewTypeNode: function(){
    return Builder.node('div', {id: this._getTypeNodeContainerId(), className: 'type-node-container'},[
      Builder.node('div', {className: 'type-node', id: this.getTypeNodeDivId()}, [
        Builder.node('input', {type: 'hidden', name: this._getCardTypeHiddenInputName(), className: 'card-type-field', id: this._getCardTypeHiddenInputId()}),
        Builder.node('a', {href: '#', onclick: 'return false', className: 'add-button'}, ''),
        Builder.node('a', {href: '#', onclick: 'return false', className: 'remove-button'}, ''),
        Builder.node('a', {href: '#', onclick: 'return false', className: 'select-type'}, 'Select type...')
      ])
    ]);
  },

  _buildCardTypeDropList: function(availableTypes, defaultCardType){
    var typeNodeContainer = this.getTypeNodeContainer();
    var selectionLink = typeNodeContainer.select('.select-type').first();
    var cardTypeInput = typeNodeContainer.select('.card-type-field').first();
    if(!(Object.isUndefined(defaultCardType) || defaultCardType == null)){
      cardTypeInput.value = defaultCardType;
    }
    var dropList = new DropList({
      dropLink: selectionLink,
      htmlIdPrefix: this._getTypeNodeContainerId(),
      selectOptions: availableTypes,
      initialSelected: ["Select type...", cardTypeInput.value],
      truncateLink: 40
    });
    return dropList.model;
  },

  _buildRelationshipConector: function(previousTypeNode, defaultRelationshipName){
    var newConnector = new RelationshipConnector(this.getConnectorPosition(), previousTypeNode, defaultRelationshipName);
    newConnector.connectTo($(this.getTypeNodeDivId()));
    newConnector.activate();
    return newConnector;
  }
};

var RelationshipConnector =  Class.create();
RelationshipConnector.prototype = {
  initialize: function(position, previousTypeNode, defaultRelationshipName){
    this.position = position;
    this.previousTypeNode = previousTypeNode;
    if(this.hasCardType()){
      if(defaultRelationshipName != null){
        this.relationshipName = defaultRelationshipName;
        if(defaultRelationshipName != this._defaultNameForTreeProperty()){
          this.relationshipNameWasModified = true;
        }
      }else{
        this.relationshipName = this._defaultNameForTreeProperty();
      }
    }else{
      this.relationshipName = '';
    }
    this.cardTypeChangeListener = this._onCardTypeChange.bindAsEventListener(this);
  },

  connectTo: function(connectedNode){
    var connector;
    if (this._connectedToConfiguredNode()){
      connector = Builder.node('div', {className: 'relationship-connector', id: this.connectorId()},[this._verticalLine(), this._relationshipEditor()]);
    } else {
      connector = Builder.node('div', {className: 'relationship-connector', id: this.connectorId()},[this._verticalLine()]);
    }
    var container = $(connectedNode).up('.type-node-container');
    container.insertBefore(connector, $(connectedNode));
    this.container = container;
  },

  renumberConnectorTo: function(connectDiv, position){
    this.position = position;
    connectDiv.id = this.connectorId();
    if(this._connectedToConfiguredNode()){
      connectDiv.down('.relationship-name-link').id = this.editLinkId();
      connectDiv.down('.relationship-name-field').id = this.inputFieldId();
      connectDiv.down('.relationship-name-field').name = this.inputFieldName();
    }
  },

  activate: function(){
    this._hightlightEditorIfNecessary();
    this._attachEditorListeners();
    this._attachDroplistListeners();
  },

  deactivate: function(){
    if (this.relatedDroplistModel() != null){
      this.relatedDroplistModel().removeObserver(this.cardTypeChangeListener);
    }
  },

  hasCardType: function(){
    return this.previousTypeNode.hasCardType();
  },

  getCardType: function(){
    return this.previousTypeNode.getCardType();
  },

  getRelationshipName: function(){
    return this.relationshipName;
  },

  _attachEditorListeners: function(){
    if (this._connectedToConfiguredNode()){
      Event.observe(this.editLinkId(), 'click', this._onEditLinkClick.bindAsEventListener(this));
      Event.observe(this.inputFieldId(), 'keypress', this._onEditorFieldKeypress.bindAsEventListener(this));
      Event.observe(this.inputFieldId(), 'blur', this._onEditorFieldBlur.bindAsEventListener(this));
    }
  },

  _attachDroplistListeners: function(){
    if (this.relatedDroplistModel() != null){
      this.relatedDroplistModel().observe('changeSelection', this.cardTypeChangeListener);
    }
  },

  _verticalLine: function(){
    return Builder.node('div', {className: 'vertical-line'});
  },

  _relationshipEditor: function(){
      return Builder.node('div', {className: 'relationship-property'}, [
        Builder.node('a', {href: 'javascript:void(0)', id: this.editLinkId(), className: 'relationship-name-link'}, this.relationshipName.truncate(43)),
        Builder.node('input', {type: 'text', name: this.inputFieldName(), value: this.relationshipName, style: 'display: none;', id: this.inputFieldId(), className: 'relationship-name-field inline-editor'})
      ]);
  },

  _onEditLinkClick: function(e){
    $(this.inputFieldId(), this.editLinkId()).invoke("toggle");
    $(this.inputFieldId()).focus();
    return false;
  },

  _resetHighlightEditor: function(){
    [this.inputFieldId(), this.editLinkId()].map(Element.toggle);
    $(this.inputFieldId()).removeClassName('error-editor');
  },

  _highlightEditor: function(){
    [this.inputFieldId(), this.editLinkId()].map(Element.toggle);
    $(this.inputFieldId()).addClassName('error-editor');
  },

  _isEditorHighlighted: function(){
    $(this.inputFieldId()).hasClassName('error-editor');
  },

  _hightlightEditorIfNecessary: function(){
    if(this._connectedToConfiguredNode() && this.getCardType() != ''){
      if(!this.relationshipName || this.relationshipName == ''){
        this._highlightEditor();
      }else if (this._isEditorHighlighted()){
        this._resetHighlightEditor();
      }
    }
  },

  _onEditorFieldKeypress: function(e){
    var isEnterKeypressEvent = e.keyCode == Event.KEY_RETURN;
    if (!isEnterKeypressEvent) {
      return;
    }
    if ($(this.inputFieldId()).value.blank()){
      return;
    }

    this._applyEditorContentToLink(e);

    return false;
  },

  _onEditorFieldBlur: function(e){
    if ($(this.inputFieldId()).value.blank()){
      var input = $(this.inputFieldId());
      setTimeout(function(){
          input.focus();
        }, 100);
      Event.stop(e);
      return;
    }

    this._applyEditorContentToLink(e);

    return false;
  },

  _applyEditorContentToLink: function(e){
    this._setEditLink($(this.inputFieldId()).value.truncate(43));
    this.relationshipName = $(this.inputFieldId()).value;
    if (this.relationshipName != this._defaultNameForTreeProperty){
      this.relationshipNameWasModified = true;
    }
    Event.stop(e);
    $(this.inputFieldId()).hide();
    $(this.editLinkId()).show();
  },

  _onCardTypeChange: function(e){
    if(!this.hasCardType()){
      $(this.connectorId()).down('.relationship-property').remove();
    }else if($(this.editLinkId()) == null){
      this.relationshipName = this._defaultNameForTreeProperty();
      $(this.connectorId()).appendChild(this._relationshipEditor());
      this._attachEditorListeners();
    } else {
      if(!this.relationshipNameWasModified || this.relationshipName == null || this.relationshipName.blank()){
        this.relationshipName = this._defaultNameForTreeProperty();
        this._refresh();
      }
    }
  },

  _refresh: function(){
    this._setEditLink(this.relationshipName);
    $(this.inputFieldId()).value = this.relationshipName;
    this._hightlightEditorIfNecessary();
  },

  _setEditLink: function(text) {
    $(this.editLinkId()).innerHTML = text.escapeHTML();
  },

  _connectedToConfiguredNode: function(){
    return this.getCardType() != null;
  },

  _defaultNameForTreeProperty: function(){
    return PropertyNameSuggestion.value($('tree_name').value, this.getCardType());
  },

  inputFieldId: function(){
    return 'relationship_' + this.position + '_name_field';
  },

  inputFieldName: function(){
    return 'card_types[' + this.position + '][relationship_name]';
  },

  editLinkId: function(){
    return 'edit_relationship_' + this.position + '_link';
  },

  connectorId: function(){
    return 'relationship_connector_' + this.position;
  },

  previousContainer: function(){
    return $('type_node_' + this.position + '_container');
  },

  relatedDroplistModel: function(){
    return this.previousTypeNode.getDropListModel();
  }
};

var AggregatePopupHandler = Class.create();
AggregatePopupHandler.prototype = {
  initialize: function() {
    this.lastPopup = null;
  },

  popup: function(div, sourceDiv, showNameText) {
    if (showNameText == null) { showNameText = true; }

    if (this.lastPopup) {
      this.lastPopup.remove();
    }
    this.lastPopup = new AggregatesPopup(div, sourceDiv.innerHTML);
    sourceDiv.innerHTML = '';

    if (showNameText == true) { this.createEnterNameText(); }
  },

  removePopup: function() {
    this.lastPopup.remove();
    this.lastPopup = null;
  },

  createEnterNameText: function() {
    $('aggregate_property_definition_name').observe('focus', function(event) {
      $('no-name-text').hide();
    });

    $('no-name-text').observe('click', function(event) {
      $('no-name-text').hide();
      $('aggregate_property_definition_name').focus();
    });

    var noNameText = $('no-name-text');
    var noNameTextHeight = noNameText.getHeight();
    var nameInput = $('aggregate_property_definition_name');
    var nameInputHeight = nameInput.getHeight();
    noNameText.show();
  }
};

var AggregatesPopup = Class.create();
AggregatesPopup.prototype = {
  initialize: function(card, popupData) {
    this.popup = new GenericPopup(card, popupData, AggregateCardPopupLayoutManager.getInstance(), { popupArrowClass: 'aggregate-popup-arrow', isDraggable: false, popupClass: 'aggregate-popup' });
  },

  remove: function() {
    this.popup.remove();
  }
};

PropertyNameSuggestion = {
  setup: function(existingPropertyDefinitions){
    this.existingPropertyDefinitions = existingPropertyDefinitions;
  },

  value: function(treeName, cardTypeName){
    var result = [];
    var suffix = null;
    if (!treeName.blank()){
      result.push(treeName);
    }
    if (!cardTypeName.blank()){
      if (result.length != 0){
        result.push('-');
      }
      result.push(cardTypeName);
    }
    if (arguments.length == 3 && arguments[2] != null){
      suffix = arguments[2];
      result.push(suffix);
    }
    var suggestion = result.join(' ');
    if (this.existingName(suggestion)){
      return this.value(treeName, cardTypeName, (suffix == null) ? 1 : (suffix + 1));
    } else if (this.isTooLong(suggestion)) {
      if (treeName != null && treeName.length > 1 && cardTypeName.length < 37){
        return this.value(treeName.truncate(treeName.length - 1,  ''), cardTypeName, suffix);
      } else { // cardTypeName.length > 37
        return this.value('', cardTypeName.truncate(cardTypeName.length - 1, ''), suffix);
      }
    } else {
      return suggestion;
    }
  },

  existingName: function(suggestion){
    return PropertyNameSuggestion.existingPropertyDefinitions.any(function(name){
      return name.toLowerCase() == suggestion.toLowerCase();
    }.bind(this));
  },

  isTooLong: function(suggestion){
    return suggestion.length > 40;
  }
};

var AggregateDropdownChangeObserver = Class.create({
  initialize: function(descendantTypeIds, optionsForNotApplicableAggregateProperty, optionsForChildren, optionsForDescendants, optionsForAggregateProperty, countIdentifier, conditionIdentifier) {
    this.aggregateType = $('aggregate_property_definition_aggregate_type');
    this.aggregateTarget = $('aggregate_property_definition_aggregate_target_id');
    this.aggregateScope = $('aggregate_property_definition_aggregate_scope_card_type_id');
    this.aggregateCondition = $('aggregate_property_definition_aggregate_condition');

    this.descendantTypeIds = descendantTypeIds;
    this.optionsForNotApplicableAggregateProperty = optionsForNotApplicableAggregateProperty;
    this.optionsForChildren = optionsForChildren;
    this.optionsForDescendants = optionsForDescendants;
    this.optionsForAggregateProperty = optionsForAggregateProperty;
    this.countIdentifier = countIdentifier;
    this.conditionIdentifier = conditionIdentifier;
  },

  onAggregateTypeOrScopeChange: function() {
    this._elementVisible(this.aggregateCondition, this._scopeIsCondition());
    if (!this._scopeIsCondition()) {
      this.lastEnteredCondition = this.aggregateCondition.value;
      this.aggregateCondition.value = '';
    } else {
      this.aggregateCondition.value = (this.lastEnteredCondition || this.aggregateCondition.value);
      this.aggregateCondition.focus();
    }

    if (this.typeIsCount()) {
      this.aggregateTarget.innerHTML = '';
      new Insertion.Bottom(this.aggregateTarget, this.optionsForNotApplicableAggregateProperty);
    } else {
      this.changeTargetOptionsBasedOnScope();
    }
  },

  changeTargetOptionsBasedOnScope: function() {
    if (this.aggregateScopeIsASpecificCardType()) {
      this.changeTargetOptions(this.optionsForChildren.get(this.aggregateScope.value));
    } else if (this.scopeIsAllDescendants() || this._scopeIsCondition()) {
      this.changeTargetOptions(this.optionsForDescendants);
    } else {
      this.changeTargetOptions(this.optionsForAggregateProperty);
    }
  },

  aggregateScopeIsASpecificCardType: function() {
    return this.descendantTypeIds.any(function(descendantTypeId) {
      return (this.aggregateScope.value == descendantTypeId);
    }.bind(this));
  },

  changeTargetOptions: function(the_options) {
    var old_selected_value = this.aggregateTarget.getValue();
    this.aggregateTarget.innerHTML = '';
    new Insertion.Bottom(this.aggregateTarget, the_options);
    this.aggregateTarget.setValue(old_selected_value);
  },

  scopeIsAllDescendants: function(identifier) {
    return (this.aggregateScope.value == null || this.aggregateScope.value == '');
  },

  typeIsCount: function() {
    return this.aggregateType.value == this.countIdentifier;
  },

  _scopeIsCondition: function() {
    return this.aggregateScope.value == this.conditionIdentifier;
  },

  _elementVisible: function(element, visible) {
    var display = visible ? "inline" : "none";
    element.setStyle({display: display});
  }

});
