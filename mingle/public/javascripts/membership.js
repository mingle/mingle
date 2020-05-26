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
var ProjectAssignment = Class.create({
  initialize: function(tableDomId, addNewAssignmentDomId, submitDomId, dropListOptions) {
    this.assignmentTable = $(tableDomId);
    this.addNewAssignmentElement = $(addNewAssignmentDomId);
    this.submitButton = $(submitDomId);
    this.projectsDropListOptions = dropListOptions.projects;
    this.permissionsDropListOptions = dropListOptions.permissions;
    this.increment = -1;
    this.projectDropLists = [];

    var defaultShowRows = [ProjectAssignment.ROWS_TO_SHOW, this.projectsDropListOptions.size].min();
    for (var i = 0; i < defaultShowRows; i++) {
      this.onNewAssignment();
    }

    this._updateAddNewAssignmentStatus();
    this._updateSubmitButtonStatus();
    this.addNewAssignmentElement.observe('click', this.onNewAssignment.bindAsEventListener(this));
    this.submitButton.observe('click', this.onSave.bindAsEventListener(this));
    ProjectAssignment.initialized = true;
  },

  onSave: function(event) {
    if (event.element().hasClassName('disabled')) {
      return;
    }

    event.stop();
    event.element().up('form').submit();
  },

  onNewAssignment: function() {
    this._addNewAssignmentRow();
    this._updateAddNewAssignmentStatus();
    this._updateVisibleOptions();
  },

  onRemoveAssignment: function(index) {
    var removingDropList = null;
    this.projectDropLists = this.projectDropLists.reject(function(droplist) {
      if (droplist.htmlIdPrefix == 'select_project_' + index) {
        removingDropList = droplist;
        return true;
      }
      return false;
    });

    this._updateVisibleOptions();
    $('project_assignment_row_' + index).remove();

    this._updateSubmitButtonStatus();
    this._updateAddNewAssignmentStatus();
  },

  _getProjectDropListsSelections: function() {
    return this.projectDropLists.map(function(dropList) { return dropList.getSelectedValue(); }).without('');
  },

  _updateVisibleOptions: function() {
    var selectedValues = this._getProjectDropListsSelections();

    this.projectDropLists.each(function(dropList) {

      dropList.model.getOptions().invoke('show');

      selectedValues.each(function(selectedValue) {
        if (selectedValue != dropList.getSelectedValue()) {
          dropList.model.getOptionByValue(selectedValue).hide();
        }
      });
    });
  },

  onProjectSelectionChange: function(dropListOption) {
    this._updateVisibleOptions();
    this._updateSubmitButtonStatus();
  },

   _updateSubmitButtonStatus: function(){
    var projectSelected = this.projectDropLists.any(function(dropList) {
      return dropList.getSelectedValue() != null && dropList.getSelectedValue() != '';
    });
    if (projectSelected) {
      this.submitButton.removeClassName('disabled');
    } else {
      this.submitButton.addClassName('disabled');
    }
  },

  _addNewAssignmentRow: function() {
    this.increment++;
    var index = this.increment;
    var row = new Element("tr", { id: "project_assignment_row_" + index }).insert(
      this._generateNewAssignmentCell(index, "project")).insert(
      this._generateNewAssignmentCell(index, "permission")).insert(
      new Element("td", { className: "action_cell" }).insert(
        new Element("a", { href: "javascript:void(0)",
                             id: "project_assignment_remove_link_" + index,
                      className: "delete_link"
                         }).observe("click", function(){ ProjectAssignment.instance.onRemoveAssignment(index);})));

    this.assignmentTable.down('tbody').insert(row, { position : 'bottom' });

    var projectOptions = { selectOptions : this.projectsDropListOptions, htmlIdPrefix : 'select_project_' + this.increment, initialSelected : ['Select project...', null] };
    projectOptions.onchange = this.onProjectSelectionChange.bindAsEventListener(this);
    this.projectDropLists.push(new DropList(projectOptions));
    new DropList({selectOptions : this.permissionsDropListOptions, htmlIdPrefix : 'select_permission_' + this.increment, initialSelected : this.permissionsDropListOptions[0] });
  },

  _generateNewAssignmentCell: function(index, type) {
    return new Element("td").insert(
    new Element("span", { className: "drop-list-panel" }).insert(
      new Element("input", { type: "hidden",
                             name: "project_assignments[#{index}][#{type}]".interpolate({index: index, type: type}),
                               id: "select_#{type}_#{index}_field".interpolate({index: index, type: type})
                           })).insert(
      new Element("a", { href: "javascript:void(0)",
                    className: "menu_link",
                           id: "select_#{type}_#{index}_drop_link".interpolate({index: index, type: type})
                       }).observe("click", function(){ return false; })));
  },

  _updateAddNewAssignmentStatus: function() {
    if (this.assignmentTable.select('tbody tr').size() < this.projectsDropListOptions.size()) {
          this.addNewAssignmentElement.enable();
    } else {
      this.addNewAssignmentElement.disable();
    }
  }
});

Object.extend(ProjectAssignment, {
  ROWS_TO_SHOW : 1,
  initialized: false,
  create: function(tableDomId, addNewAssignmentDomId, submitDomId, dropListOptions) {
    this.instance = new ProjectAssignment(tableDomId, addNewAssignmentDomId, submitDomId, dropListOptions);
    return this.instance;
  }
});

// membership, group assignment and removing

MembershipOperationWidget = Class.create({
  initialize: function(formElement) {
    this.updateMembershipsForm = $(formElement);
    this.removeLink = $('remove_membership');
    this.assignGroups = $('assign_groups');
    this.groupOptions = $('options-container');
    this.membershipCheckboxes = $('users').select('.select-membership');
    new CheckboxController([this.removeLink, this.assignGroups].compact(), this.membershipCheckboxes);

    if (this.removeLink) {
      this.removeLink.observe('click', this._onRemoveLinkClick.bindAsEventListener(this));
    }
  },

  _onRemoveLinkClick: function(event) {
    if (Event.element(event).hasClassName('disabled')) {
      Event.stop(event);
      return;
    }
    this.updateMembershipsForm.action = this.updateMembershipsForm.getAttribute('destroy_users_action');
    this.updateMembershipsForm.submit();
  }

});

GroupSelector = Class.create({
  initialize: function(container, groupLink, groupCheckboxes, membershipInfomation) {
    this.container = $(container);
    this.groupCheckboxes = $$(groupCheckboxes);
    this.membershipOperation = new MembershipOperationWidget($('update_memberships'));
    this.membershipInfomation = membershipInfomation;
    this.groupCheckboxes.each(function(checkbox) {
      checkbox.observe('click', this._onClickCheckBox.bind(this, checkbox));
    }.bind(this));
    this.partiallySelectedCheckboxIds = [];
    if (this.groupCheckboxes.length == 0) {
      this.container.update("<p class='empty-list'>There are currently no groups to list.</p>");
    }
    this.slideDownPanel = new SlideDownPanel(this.container, groupLink, MingleUI.align.alignLeft, {
      'beforeShow' : this.updateCheckboxStatus.bind(this),
      'afterShow' : this._expandToAccomodateScrollbar.bind(this)
    });
  },

  updateCheckboxStatus : function() {
    this.groupCheckboxes.each(function(checkbox) {
      var currentGroup = checkbox.select('input')[0].value;

      if(this._isEveryUserInTheGroup(currentGroup, this._selectedUserIds())){
        this._checkGroup(checkbox);
        return;
      }

      if (this._isAnyUserInGroup(currentGroup, this._selectedUserIds())) {
        this._partiallyCheckGroup(checkbox);
        this.partiallySelectedCheckboxIds.push(checkbox.down('input').id);
        return;
      }

      this._uncheckGroup(checkbox);
    }.bind(this));
  },

  _selectedUserIds: function(){
    return $$('.select-membership').collect(function(element) {
      if(element.checked) {
        return element.value;
      }
    }).compact();
  },

  _isEveryUserInTheGroup: function(group) {
    return this._selectedUserIds().all(function(userId) {
      return this.membershipInfomation[userId].include(group);
    }.bind(this));
  },

  _isAnyUserInGroup: function(group, selectedUserIds) {
    return selectedUserIds.any(function(userId) {
      return this.membershipInfomation[userId].include(group);
    }.bind(this));
  },

  _uncheckGroup: function(element) {
    element.select('input')[0].name = 'removes[]';
    element.removeClassName('tristate-checkbox-partial');
    element.removeClassName('tristate-checkbox-checked');
    element.addClassName('tristate-checkbox-unchecked');
  },

  _checkGroup: function(element) {
    element.select('input')[0].name = 'adds[]';
    element.removeClassName('tristate-checkbox-unchecked');
    element.removeClassName('tristate-checkbox-partial');
    element.addClassName('tristate-checkbox-checked');
  },

  _partiallyCheckGroup: function(element) {
    element.select('input')[0].name="no_change[]";
    element.removeClassName('tristate-checkbox-unchecked');
    element.removeClassName('tristate-checkbox-checked');
    element.addClassName('tristate-checkbox-partial');
  },

  _onClickCheckBox: function(checkbox){
    var field = checkbox.select('input')[0];
    if (field.name == 'removes[]' && this.partiallySelectedCheckboxIds.include(field.id)) {
      this._partiallyCheckGroup(checkbox);
      return;
    }

    if (field.name == 'adds[]') {
      this._uncheckGroup(checkbox);
      return;
    }

    this._checkGroup(checkbox);
  },

  _expandToAccomodateScrollbar: function(){
    this.container.setStyle('width: ' + (this.container.getWidth() + 10) + 'px');
  }
});
