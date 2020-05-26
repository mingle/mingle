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

Timeline.MainView = Class.create({
  initialize: function(element, mainViewContent) {
    this.element = element;
    this.content = mainViewContent;
    this.overviewPanel = this.element.parentNode.down('.overview');
    this.viewportPanel = this.element.parentNode.down('.viewport');
    this.border = this.element.cumulativeRectangle();
    this.autoScroll = new Timeline.MainView.AutoScroll(this);
  },

  startDragItem: function(action, scrollObserver) {
    this.updateCursor(action);
    this.observeScroll(scrollObserver);
  },
  stopDragItem: function() {
    this.updateCursor('auto');
    this.stopObservingScroll();
  },

  observeScroll: function(observer) {
    this.autoScroll.observe(observer);
    this.autoScroll.disabled = false;
  },

  stopObservingScroll: function() {
    this.autoScroll.disabled = true;
    this.autoScroll.observers.clear();
  },

  ensureVisible: function(pointer) {
    var distance = this.border.distance(new Rectangle({left: pointer.x}));
    if (distance.x == 0) {
      return;
    }
    if(this.viewportSlider) {
      this.viewportSlider.setValue(this.viewportSlider.value + distance.x);
    }
  },

  updateViewport: function() {
    this.updateViewportPosition();
    this.updateViewportSlider();
  },

  updateViewportPosition: function() {
    this.overviewPanel.show();
    Element.clonePosition(this.viewportPanel, this.overviewPanel, { setWidth: false, setTop: false});

    var mainviewWidth = this.element.getWidth();
    var fullWidth = this.content.getWidth();

    var overviewWidth = this.overviewPanel.getWidth();
    var viewportWidth = (mainviewWidth / fullWidth) * overviewWidth;
    this.viewportPanel.setStyle({
      width: viewportWidth + 'px'
    });
  },

  updateViewportSlider: function() {
    if (this.viewportSlider) {
      this.viewportSlider.dispose();
      this.viewportSlider = null;
    }

    var mainviewWidth = this.element.getWidth();
    var allContentWidth = this._getAllContentWidth();
    if (allContentWidth < 1) {
      this.overviewPanel.hide();
      this.viewportPanel.hide();
    } else {
      this.overviewPanel.show();
      this.viewportPanel.show();
      this.viewportSlider = new Control.Slider(this.viewportPanel, this.overviewPanel, {
        range: $R(0, allContentWidth),
        sliderValue: 0,
        onSlide: this.moveMainViewContent.bind(this),
        onChange: this.moveMainViewContent.bind(this)
      });
    }
  },
  
  _getAllContentWidth: function() {
    return this.content.getWidth() - this.element.getWidth();
  },

  restoreViewportSlider: function(columnOrXCoordinate) {
    if (this.viewportSlider) {
      var distance = this._calculateDistance(columnOrXCoordinate);
      var percentage = distance / this._getAllContentWidth();
      var newValue = this._getAllContentWidth() * percentage;

      this.viewportSlider.setValue(newValue);
    } else {
      this.moveMainViewContent(0);
    }
  },

  _calculateDistance: function(columnOrCoordinate) {
    var isColumn = "number" !== typeof columnOrCoordinate;
    if (isColumn) {
      return this.content.distanceToViewColumn(columnOrCoordinate);
    }
    return columnOrCoordinate;
  },

  updateCursor: function(type) {
    this.element.setStyle({
      cursor: type
    });
  },

  registerRenderTimelineCallback: function(renderTimelineCallback) {
    this.renderTimelineCallback = renderTimelineCallback;
  }, 

  unregisterRenderTimelineCallback: function() {
    this.renderTimelineCallback = null;
  },

  moveMainViewContent: function(to) {
    TimelineStatus.instance.start('scrolling');
    this.content.moveTo(-to, function(movedDistance) {
      this.autoScroll.onMainViewScroll(movedDistance);
      TimelineStatus.instance.endAll('scrolling');
      if ("function" === typeof this.renderTimelineCallback) {
        this.renderTimelineCallback();
      }
    }.bind(this));
  },

  _setCaptureForIE: function(element) {
    element.unselectable = "on";

    // on IE, we should setCapture() to allow mouse coordinate tracking outside
    // the window, which will allow us to resize/move with autoscroll
    if (element.setCapture) {
      element.setCapture();
    }
  },

  // on IE, since we use setCapture() to get mouse tracking to work
  // when text selection is disabled, we releaseCapture() when we finish
  // dragging an element
  _releaseCaptureForIE: function(element) {
    if (element.releaseCapture) {
      element.releaseCapture();
    }
  }

});

Timeline.MainView.AutoScroll = Class.create({
  initialize: function(mainView) {
    this.disabled = true;
    this.mainView = mainView;
    this.lastPointer = {x: 0, y: 0};
    this.observers = [];
    Event.observe(document, 'mousemove', this.onMouseMove.bindAsEventListener(this));
  },

  observe: function(observer) {
    this.observers.push(observer);
  },

  onMouseMove: function(e) {
    if (this.disabled) {
      return;
    }
    var pointer = Pointer.Methods.fromEvent(e);
    if (pointer.equals(this.lastPointer)) {
      return;
    }
    this.lastPointer = pointer;
    this.mainView.ensureVisible(this.lastPointer);
  },

  onMainViewScroll: function(movedDistance) {
    if (this.disabled) {
      return;
    }
    var distance = this.mainView.border.distance(new Rectangle({left: this.lastPointer.x}));
    if (distance.x == 0) {
      this.lastPointer.x = this.lastPointer.x + movedDistance;
    }
    this.mainView.ensureVisible(this.lastPointer);
    this.notifyObservers();
  },

  notifyObservers: function() {
    this.observers.each(function(observer) {
      observer(this.lastPointer);
    }.bind(this));
  }
});
