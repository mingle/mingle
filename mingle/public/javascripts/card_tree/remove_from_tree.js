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

var RemoveFromTree = new (Class.create({
  removeCardAction: function(nearByElement, hasChildren, removeSingleCardAction, removeCardAndItsChildrenAction) {
    if(hasChildren) {
      var confirm_box_options = this.confirmBoxOptionsFromNearByElement(nearByElement);
      this._removeCardAndItsChildren(confirm_box_options, removeSingleCardAction, removeCardAndItsChildrenAction);
    }else {
      this._removeSingleCard(removeSingleCardAction);
    }
  },
  confirmBoxOptionsFromNearByElement: function(nearByElement){
    return {
      offsetTop: -20,
      offsetLeft: nearByElement.getWidth() + 10,
      dont_add_border: true,
      nearByElement: nearByElement
    };
  },
  removeCardInTree: function(card, removeSingleCardAction, removeCardAndItsChildrenAction) {
    if(card.allCardCount > 0){
      var confirm_box_options = this.confirmBoxOptionsFromNearByElement(card.innerElement());
      this._removeCardAndItsChildren(confirm_box_options, removeSingleCardAction, removeCardAndItsChildrenAction);
    } else {
      this._removeSingleCard(removeSingleCardAction);
    }
  },

  _removeSingleCard: function(removeSingleCardAction){
    ConfirmBox.deactivate();
    removeSingleCardAction();
  },

  _removeCardAndItsChildren: function(confirm_box_options, removeSingleCardAction, removeCardAndItsChildrenAction){
    ConfirmBox.activate(confirm_box_options.nearByElement, [removeCardAndItsChildrenAction, removeSingleCardAction], null, null, confirm_box_options);
  }
}))();
