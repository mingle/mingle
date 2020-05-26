var TagsEditor = Class.create({
  initialize: function(container, allTags, removeIconPath) {
    this.container      = $(container);
    this.removeIconPath = removeIconPath;

    this.tagsInputField        = this.container.down('.input-box');
    this.tagsField             = Object.extend(this.container.down('.tags-field'), {
      memorizedValue: function() {
        return this._lastValue;
      },
      
      rememberLastValue: function() {
        this._lastValue = this.value;
      }
    });
    this.tagsField.rememberLastValue();
    this.submitButton          = this.container.down('.add-tag-button');
    this.displayContainer      = this.container.down('.display-container');
    this.displayedTagListPanel = this.container.down('.tag-list');
    this.editContainer         = this.container.down('.edit-container');

    this.tagList = new RemovableTagSet(this.container.down('.removable-tag-list-panel'), removeIconPath);
    
    this.openEditorLink        = this.container.down('.open-edit-link');
    this.closeEditorButton     = this.container.down('.close-button');

    this._reloadAllTags();

    this.tagsField.setValue = this._onSetTagsFieldValue.bindAsEventListener(this);

    $j(this.submitButton).click({editor: this}, this.beforeSubmit);
    $j(this.tagsInputField).keypress({editor: this}, this.beforeSubmit);

    Event.observe(this.openEditorLink,    'click',    this._onOpeningEditor.bindAsEventListener(this));
    Event.observe(this.closeEditorButton, 'click',    this._onClosingEditor.bindAsEventListener(this));
    Event.observe(this.container,         'removable_tag:removed', this.removeTag.bindAsEventListener(this));

    this.autocompleter = new Autocompleter.Mingle(
      this.tagsInputField.id, 
      this.container.down('.auto_complete'), 
      allTags,
      { 
        tokens             : [','], 
        fullSearch         : true, 
        partialSearch      : true, 
        partialChars       : 1, 
        afterUpdateElement : function(element, selectElement) { element.value += ', '; }
      });
  },
  
  _onOpeningEditor: function(event) {
    this.displayContainer.hide(); 
    this.editContainer.show(); 
    this.container.addClassName("box"); 
    this._focus();
  },
  
  _onClosingEditor: function(event) {
    this.displayContainer.show();
    this.editContainer.hide();
    this.container.removeClassName("box"); 
  },

  _onSetTagsFieldValue: function(value) {
    if (value != undefined) {
      this.setTagsValue(value);
    }
    this._reloadAllTags();
  },

  beforeSubmit: function(e) {
    var editor = e.data.editor;

    if ((e.type === "click" || e.which === $j.ui.keyCode.ENTER) && !editor.autocompleter.active) {
      e.preventDefault();
      e.stopPropagation();
      if (editor.validate()) {
        editor.submit();
      }
    }
  },

  validate: function() {
    if ($F(this.tagsInputField).blank()) {
      return false;
    }

    this.tagList.addTags(TagsEditor.cleanTags(this.tagsInputField.value));
    this.tagsInputField.clear();

    var afterEditTags = this.tagList.getDisplayNames().sort();
    var newValues = afterEditTags.join(",");
    this.setTagsValue(newValues);

    var existingTags = TagsEditor.cleanTags(this.tagsField.memorizedValue()).sort();
    if (existingTags.join(",") !== newValues) {
      this.refreshTags();
      return true;
    }

    return false;
  },

  removeTag: function(event) {
    var tagName = event.memo.tagName;
    this._focus();
    this._removeFromTagNodes(tagName);

    this.setTagsValue(this.tagsValue().replace(tagName, ''));
    this._resetOpenEditorLink();
    this._reloadDisplayedTagListPanel();

    this.submit();
  },

  refreshTags: function() {
    this.tagsField.rememberLastValue();
    //todo: controller will not work when tags field is empty, still need time to refactor it. xli
    if (this.tagsField.value == "") {
      this.tagsField.value = ' ';
    }

    this._reloadAllTags();
  },

  submit: function() {
    this.refreshTags();

    if ($j(this.tagsField.getForm()).data("filtersForm")) {
      $j(this.tagsField.getForm()).submit();
      return false;
    }

    if ("function" === typeof this.tagsField.getForm().onsubmit) {
      this.tagsField.getForm().onsubmit();
    }
    return false;
  },

  tagsValue: function() {
    return TagsEditor.cleanTagsValue(this.tagsField.value);
  },

  setTagsValue: function(newValue) {
    this.tagsField.value = TagsEditor.cleanTagsValue(newValue);
  },

  hasTagValue: function(tag) {
    return TagsEditor.cleanTags(this.tagsValue().toUpperCase()).include(tag.toUpperCase());
  },

  highlightTag: function(tag) {
    this.tagList.findTag(tag).highlight();
  },

  _focus: function() {
    this.tagsInputField.focus();
  },

  _reloadAllTags: function() {
    this._resetOpenEditorLink();
    this._reloadDisplayedTagListPanel();
    this.tagList.addTags(TagsEditor.cleanTags(this.tagsValue()));
  },

  _resetOpenEditorLink: function() {
    if (!this.openEditorLink) {return;}
    if (this.tagsValue().blank()) {
      this.openEditorLink.innerHTML = '<i class="fa fa-tags"></i> Add tags';
    } else {
      this.openEditorLink.innerHTML = '<i class="fa fa-tags"></i> Edit tags';
    }
  },

  _reloadDisplayedTagListPanel: function() {
    var text = this.tagsValue().replace(/,/g, ', ');
    this.displayedTagListPanel.innerHTML = text.escapeHTML();
  },

  _removeFromTagNodes: function(tag) {
    this.tagList.removeTags(tag);
  }
});

Object.extend(TagsEditor, {
  cleanTagsValue : function(value) {
    return value.strip().replace(/[ ]*,[ ]*/g, ',').replace(/,(,)+/g, ',').replace(/^[ ,]+/, '').replace(/[ ,]+$/, '');
  },
  
  cleanTags : function(value) {
    return this.cleanTagsValue(value).split(',').compact().reject(function(element) { return element.blank(); });
  }
});
