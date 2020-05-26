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
DropList.View.DropDown = Class.create({
  initialize: function(model, options) {
    this.model = model;
    this.model.cursor.observe('changed', this.highlight.bindAsEventListener(this));
    this.clickListener = Prototype.emptyFunction;
    this.mouseOverListener = Prototype.emptyFunction;
    this.lightboxScrollListener = this._onLightboxScroll.bindAsEventListener(this);
    this.options = options;
    this.scrolling = false;
    this.model.observe('mingle:droplist_replace_options', this._setupScrollBar.bindAsEventListener(this));
  },

  show: function(event) {
    if(this.panel.visible()) {return;}
    this.model.getVisibleOptions().each(this._addOption.bind(this));

    if (this.options.macroEditor) {
      var editor = $("macro_editor");
      editor.setStyle({position: "relative"});
    }

    var offsetParent = $(this.dropLinkPanel).getOffsetParent();
    var inTreeConfig = offsetParent.hasClassName("type-node");
    var coords;

    if (inTreeConfig) {
      coords = Element.cumulativeOffset(this.dropLinkPanel);
    } else {
      coords = Element.positionedOffset(this.dropLinkPanel);
      coords = MingleUI.align.addMarginsBackToPositionedOffset(coords, this.dropLinkPanel);

      // only have offset parent adopt panel as child node if we are not
      // in a tree config node. tree config nodes have overflow: hidden, so it will clip
      // the droplist.
      if (offsetParent !== this.dropLinkPanel.ownerDocument.body) {
        offsetParent.insert({top: this.panel});
      }
    }

    if(this.options.position == 'left') {
      coords.left -= (this.panel.getWidth() - this.dropLinkPanel.getWidth());
    }

    // prevent dropdown from rendering behind left edge of viewport
    if (coords.left < 0) {
      coords.left = 0;
    }

    coords.top+= this.dropLinkPanel.getHeight();

    if(this.options.centerAlign) {
        var smallerWidth = Math.min(this.panel.getWidth(), DropList.View.DropDown.MAX_WIDTH);
        leftPosition = (coords.left + 8 ) - (smallerWidth / 2);
    } else {
        leftPosition = coords.left;
    }

    var position = {
      position: "absolute",
      left: leftPosition + "px",
      top: coords.top + "px"
    };

    this.panel.setStyle(position);
    this.panel.show();

    // make sure dropdown doesn't fall off the edge of the viewport
    var rightEdge = this.panel.getBoundingClientRect().right;
    if (rightEdge > $j(window).width()) {
      leftPosition -= (rightEdge - $j(window).width());
      $j(this.panel).css("left", leftPosition + "px");
    }

    Event.stop(event);
    document.observe("lightbox:scroll", this.lightboxScrollListener);
  },

  hide: function() {
    document.stopObserving("lightbox:scroll", this.lightboxScrollListener);
    this.panel.hide();
    (function() {
      if(this.optionsContainer) {
        $(this.optionsContainer).select('.select-option').each(this._removeOption.bind(this));
      }
    }).bind(this).delay(0.01);
  },

  fixDimension: function(){
    this._setupScrollBar();
    this._fixSubPanelWidth();
    this.panel.setStyle({'visibility' : ''});
  },

  scrollUnlessVisible: function(){
    var panel = this.panel;
    var inView = $j(panel).offset().top - $j(window).scrollTop() + panel.getHeight();
    if (inView > $j(window).height()) {
      panel.scrollIntoView(false);
    }
  },

  highlight: function(selection) {
    if(this.highlighting) {
      if(this.deferedHighlighting) {
        clearTimeout(this.deferedHighlighting);
      }
      this.deferedHighlight = setTimeout(this.highlight.bind(this, selection), 1);
      return;
    }

    this.deferedHighlighting = null;
    this.highlighting = true;
    var lis = this.panel.panelElement.getElementsByTagName('li');
    for(var i = 0; i < lis.length; i++) {
      var li = lis[i];
      if(li.__option == selection) {
        li.__selected = true;
        Element.addClassName(li, 'selected');
        this._scrollTo(li);
      }else {
        if(li.__selected) {
          Element.removeClassName(li, 'selected');
        }
        li.__selected = false;
      }
    }

    this.highlighting = false;
  },

  render: function(dropLinkPanel) {
    this.dropLinkPanel = dropLinkPanel;
    return this._buildDropdownPanel(dropLinkPanel.parentNode);
  },

  redraw: function(model) {
    if (model.options.length == 0) {
      return;
    }

    var allExisting = model.options.all(function(opt) {
      return opt.element;
    });
    if (allExisting) {
      model.options.invoke('toggle');
      return;
    }

    $(this.optionsContainer).select('.select-option').each(function(ele) {
      if (!ele.hasClassName('droplist-action-option')) {
        var existing = model.options.any(function(opt) {
          return opt.element == ele;
        });
        if (!existing) {
          this._removeOption(ele);
        }
      }
    }.bind(this));
    model.getVisibleOptions().each(this._addOption.bind(this));
  },

  _scrollTo: function(li){
    if(!this._dimensionReady()) {
      this._scrollTo.bind(this, li).defer();
      return;
    }

    var offsetTop = Prototype.Browser.IE ? li.offsetTop : li.offsetTop - this.optionsContainer.offsetTop;
    var viewPortHeight = this.optionsContainer.offsetHeight;
    var alreadyInView = offsetTop + li.offsetHeight < viewPortHeight + this.optionsContainer.scrollTop && offsetTop > this.optionsContainer.scrollTop;

    if (!alreadyInView) {
      var coushion = li.offsetHeight * 0.5;
      this._scroll(offsetTop + li.offsetHeight - viewPortHeight + coushion);
    }
  },

  _scroll: function(delta){
    this.scrolling = true;
    this.optionsContainer.scrollTop = delta;
    setTimeout(function() { this.scrolling = false; }.bind(this), 0.01);
  },

  _dimensionReady: function() {
    return this.optionsContainer.offsetHeight > 0;
  },

  _setupScrollBar: function() {
    var optionsPanelElementStyles = $H();
    this.optionsContainer.setStyle({height: 'auto', width: 'auto', 'maxWidth': '', 'maxHeight': ''});

    if (this.optionsContainer.offsetHeight > DropList.View.DropDown.MAX_HEIGHT) {
      this._showVerticalScrollBar(optionsPanelElementStyles);
    }

    if(this.optionsContainer.offsetWidth > DropList.View.DropDown.MAX_WIDTH) {
      this._showHorizontalScrollBar(optionsPanelElementStyles);
    }

    if(Prototype.Browser.IE){
      this._fixHeightAvoidShowingVerticalScrollBarInIE(optionsPanelElementStyles);
    }
    if(optionsPanelElementStyles.size() > 0){
      this.optionsContainer.setStyle(optionsPanelElementStyles.toObject());
    }
  },

  _onLightboxScroll: function(event) {
    var delta = event.memo.delta;
    var lightbox = event.memo.element;
    var lightboxHeight = lightbox.getDimensions().height;

    this.panel.style.top = this.panel.offsetTop - delta + 'px';

    var top = this.panel.offsetTop;
    if(top <= lightbox.offsetTop || top >= lightbox.offsetTop + lightboxHeight) {
      this.hide();
    }
  },

  _showHorizontalScrollBar: function(stylesHash) {
    stylesHash.set('overflowX', 'auto');
    stylesHash.set('maxWidth', DropList.View.DropDown.MAX_WIDTH + 'px');
  },

  _showVerticalScrollBar: function(stylesHash) {
    stylesHash.set('overflowY', 'auto');
    stylesHash.set('maxHeight', DropList.View.DropDown.MAX_HEIGHT + 'px');
  },

  _fixHeightAvoidShowingVerticalScrollBarInIE: function(stylesHash){
    if(stylesHash.get('overflowX') === 'auto' && stylesHash.get('overflowY') === undefined) {
      stylesHash.set('height', this.optionsContainer.getHeight() + 20 + 'px');
    }

    if(stylesHash.get('overflowX')  === undefined && stylesHash.get('overflowY') === 'auto') {
      stylesHash.set('width', this.optionsContainer.getWidth() + 20 + 'px');
    }

    if(stylesHash.get('maxWidth') === undefined || stylesHash.get('maxWidth') === '' || stylesHash.get('width') === undefined || stylesHash.get('width') === ''){
      var reasonableWidthValue = this.panel.getWidth();
      if(reasonableWidthValue > DropList.View.DropDown.MAX_WIDTH){
        reasonableWidthValue = DropList.View.DropDown.MAX_WIDTH;
      }
      stylesHash.set('width', reasonableWidthValue + 'px');
      if(this.panel._CallbackAction_select_option){
        this.panel._CallbackAction_select_option.setStyle({width: reasonableWidthValue - 24 + 'px'});
      }
      if(this.panel._newValueOptionContainer){
        this.panel._newValueOptionContainer.setStyle({width: reasonableWidthValue + 'px'});
      }
    }
  },

  _fixSubPanelWidth: function(){
    var ignoreWidthElements = this.panel.select('.ignore-width');
    if(ignoreWidthElements.size() == 0){
      return;
    }
    ignoreWidthElements.invoke('hide');
    var width = this.panel.getWidth() - 10; /* There are 4px border on each side */
    if(Prototype.Browser.IE){
      this.panel.setStyle({width: this.panel.getWidth() - 2 + 'px'}); //Fix auto width too small bug in IE
    }
    ignoreWidthElements.invoke('setStyle', {'width' : width + 'px', 'display' : ''});
  },

  _addOption: function(option) {
    if (option.element && option.element.parentNode) {
      return;
    }
    var name = option.name;
    var htmlId = this.options.generateId('option_' + name);
    var optionElement = new Element('li', {id: htmlId});
    optionElement.addClassName('select-option');
    option.appendTo(optionElement);
    var action = this.optionsContainer.select('.droplist-action-option');
    if (action.length > 0) {
      this.optionsContainer.insertBefore(optionElement, action[0]);
    } else {
      this.optionsContainer.appendChild(optionElement);
    }
    optionElement.__option = option;

    optionElement.observe('click', this.clickListener);
    optionElement.observe('mouseover', this.mouseOverListener);

    if(this.model.isSelected(option)) {
      this.highlight(option);
    }

    option.element = optionElement;
  },

  _removeOption: function(li) {
    Event.stopObserving(li, 'click', this.clickListener);
    Event.stopObserving(li, 'mouseover', this.mouseOverListener);
    li.remove();
  },

  _buildDropdownPanel: function(container) {
    var htmlId = this.options.generateId('drop_down');

    if ($(htmlId)) {
      // previous dropdowns may be orphaned after ajax updates due to offsetParent adoption
      $(htmlId).remove();
    }

    var optionsContainer = new Element('ul', {style: 'position:static; border: 0; padding:0; margin: 0;'});
    optionsContainer.addClassName('options-only-container');
    if ($j(optionsContainer).scrollToBottom) {
      $j(optionsContainer).scrollToBottom(function(e) {
        optionsContainer.fire('mingle:droplist_scroll_to_bottom');
      });
    }
    this.optionsContainer = optionsContainer;

    var panelElement = new Element('div');
    panelElement.addClassName('dropdown-panel');
    panelElement.appendChild(optionsContainer);

    this.panel = new Element('div', {id: htmlId, style:'display:none'});
    this.panel.addClassName('widget-dropdown');
    this.panel.appendChild(panelElement);
    this.panel.panelElement = panelElement;
    this.panel.optionsContainer = optionsContainer;
    this._appendToProperParentElement(container);
    return this.panel;
  },

  // #7159
  _appendToProperParentElement: function(fromElement) {
    if($(fromElement).ancestors().find(this._isPositioned)) {
      this.panel.addClassName('positioned');
      fromElement.ownerDocument.body.appendChild(this.panel);
    } else {
      this._firstNotRelativeContainer(fromElement).appendChild(this.panel);
    }
  },

  _firstNotRelativeContainer: function(fromElement) {
    if (this._isNotRelativePositioned(fromElement)) {return fromElement;}
    var container = fromElement.ancestors().find(this._isNotRelativePositioned);
    return container ? container.parentNode : fromElement.ownerDocument.body;
  },

  _isNotRelativePositioned: function(element) {
    return element.getStyle('position') != 'relative';
  },

  // #7159
  _isPositioned: function(element) {
    var position = element.getStyle('position');
    if(Prototype.Browser.IE) {
      return position == 'absolute';
    } else {
      return position == 'fixed';
    }
  }
});
DropList.View.DropDown.MAX_HEIGHT = 260;
DropList.View.DropDown.MAX_WIDTH = 220;
