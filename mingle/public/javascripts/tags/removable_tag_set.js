var RemovableTagSet = Class.create({
  initialize: function(container, removeIconPath) {
    this.container  = $(container);
    this.tagNodes = new CaseInsensitiveHash();
    this.removeIconPath = removeIconPath;
  },

  findTag: function(tag) {
    return this.tagNodes.get(tag);
  },

  addTags: function(args) {
    args = $A(arguments).flatten();
    args.each(function(tag) {
      var removableTag = this.findTag(tag) || new RemovableTag(tag, this.removeIconPath);
      this.tagNodes.set(tag, removableTag);
      this.container.appendChild(removableTag.panel);
      if ($(this.container.parentNode).visible()) {
        removableTag.highlight();
      }
    }, this);
  },

  removeTags: function(args) {
    args = $A(arguments).flatten();
    args.each(function(tag) {
      this.tagNodes.unset(tag);
    }, this);
  },
  
  reload: function() {
    this.tagNodes.each(function(entry) {
      var tag = entry[0], removableTag = entry[1];
      this.container.appendChild(removableTag.panel);
    }, this);
  },
  
  getDisplayNames: function() {
    return this.tagNodes.values().pluck('tag');
  },

  empty: function() {
    return this.tagNodes.size() == 0;
  }
});

TagSetController = Class.create({
  initialize: function(tagsPanel, formField, data, tagsContainer, removeImagePath) {
    tagsContainer = $(tagsContainer);
    var tagSet = new RemovableTagSet(tagsContainer, removeImagePath);
    tagSet.addTags(data);
    if(tagSet.empty())  {
      $(tagsPanel).remove();
    } else {
      Event.observe(tagsContainer, RemovableTag.ON_REMOVE_EVENT_NAME, function(event) {
        tagSet.removeTags(event.memo.tagName);
        if(tagSet.empty())  {
          $(tagsPanel).remove();
        } else {
          $(formField).value = tagSet.getDisplayNames().join(',');
        }
      });
    }
  }
});

