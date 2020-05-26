var RemovableTag = Class.create({
  initialize: function(tag, removeIconPath) {
    this.removeIconPath = removeIconPath;
    this.tag = tag;
    this.panel = $j("<span/>", {"class": "removable-tag"}).
      append(this._createTagPanel()).
      append(this._createRemoveImg())[0];
    this.highlighted = false;
  },

  highlight: function() {
    if (!this.highlighted) {
      new Effect.Highlight(this.panel);
      this.highlighted = true;
    }
  },

  _onRemoveTag: function(e) {
    e.stopPropagation();
    var instance = e.data.instance;
    $(instance.panel).fire(RemovableTag.ON_REMOVE_EVENT_NAME, { tagName : instance.tag });
    $(instance.panel).remove();
  },

  _createRemoveImg: function() {
    return $j("<i/>", {
      id    : 'delete-' + this.tag.gsub(/\W/, '-'),
      title : 'Remove this tag',
      style : 'cursor: pointer; margin-left: 0.3em'
    }).addClass('fa fa-times-circle').click({instance: this}, this._onRemoveTag)[0];
  },

  _createTagPanel: function() {
    return $j("<span/>").html(this.tag.escapeHTML())[0];
  }
});

RemovableTag.ON_REMOVE_EVENT_NAME = "removable_tag:removed";
