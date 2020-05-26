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
Timeline.ObjectiveCreation = Class.create({
  initialize: function(mainViewContent) {
    this.mainViewContent = mainViewContent;
    this.mainView = mainViewContent.mainView;
    this.addObjectivePanel = this.mainViewContent.addObjectivePanel;
    this.isDropped = false;
  },

  startOn: function(pointer) {
    var dateCol = this.mainViewContent.findDateAndColumnByPointerX(pointer.x);
    var row = this.mainViewContent.findRowByMousePointerY(pointer.y);
    this.placeHolderObjective = this._createPlaceHolder(dateCol.column, row);
    this.mainViewContent.hideInformingMessageBox();
  },

  dropOn: function(pointer) {
    this.isDropped = true;
    new Timeline.Objective.Popup(this.addObjectivePanel, this.mainViewContent).showNear(this.placeHolderObjective.element, { align: "right" });
    this.updateAddObjectivePanel();
  },

  updateAddObjectivePanel: function() {
    this.addObjectivePanel.down('#objective_start_at').value = this.placeHolderObjective.startDate;
    this.addObjectivePanel.down('#objective_vertical_position').value = this.placeHolderObjective.verticalPosition;
    this.addObjectivePanel.down('#objective_end_at').value = this.placeHolderObjective.endDate;

    var nameField = this.addObjectivePanel.down('#objective_name');
    nameField.value = '';
    nameField.focus();
  },

  showError: function(objective, errors) {
    this._updateFields(objective);
    this._highlightField(errors.errors);
  },
  
  _updateFields: function(objective) {
    this.addObjectivePanel.down('#objective_name').value = objective.name;
  },
  
  _highlightField: function(message) {
    if (message.toString().match(/^name/i)) {
      var label = this.addObjectivePanel.down('.objective_name_label');
      label.update(message.join('. '));
      var span = this.addObjectivePanel.down('.objective_fields');
      span.addClassName('fieldWithErrors');
      field = span.down('.objective_name');
      field.select();
    }
  },

  clear: function() {
    if (this.placeHolderObjective) {
      this.mainView._releaseCaptureForIE(this.placeHolderObjective);
      this.placeHolderObjective.remove();
      this.placeHolderObjective = null;
    }
    this.addObjectivePanel.select('.fieldWithErrors').each(function(element) {
      element.removeClassName('fieldWithErrors');
    });
    this.addObjectivePanel.down('.objective_name_label').update("Name:");
    this.addObjectivePanel.hide();
    this.mainViewContent.renderInformingMessage();
  },

  _createPlaceHolder: function(viewColumn, row) {
    var objectiveData =
           {
              vertical_position: row,
              start_at: viewColumn.dateRange.start,
              end_at: viewColumn.dateRange.end
            };
    var objective = new Timeline.PlaceholderObjective(objectiveData, this.mainViewContent, { placeholder: true });
    objective.render();
    return objective;
  }
});