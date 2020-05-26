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
var RadioPanel = Class.create({
  initialize: function(radiosContainer, panels) {
    this.radios = $$(radiosContainer)[0].select('input');
    this.panels = $$(panels);

    this.radios.each(function(radio, index) {
      radio.observe('click', this.radioOnClick.bindAsEventListener(this));
    }.bind(this));

	this.panels.each(function(panel){
		if (this.doesNotContainCheckboxes(panel)){
			return;
		}
		panel.select('input').each(function(inputElement){
			$(inputElement).observe('click', this.deselectSelectionsInAllOtherPanels.bindAsEventListener(this));
		}.bind(this));
	}.bind(this));

    this.selectRadio(this.checkedRadioIndex());
  },

  radioOnClick: function(e) {
    var index = this.radios.indexOf(e.element());
    this.showPanelByIndex(index);
  },

  selectRadio: function(index) {
    this.radios[index].checked = true;
    this.showPanelByIndex(index);
  },

  deselectSelectionsInAllOtherPanels: function(e){
    this.panels.each(function(panel, panelIndex){
      if (panelIndex == this.checkedRadioIndex() || this.doesNotContainCheckboxes(panel)){
	    return;
      }
      panel.select('input').each(function(checkbox){
	    checkbox.checked = false;
      });
    }.bind(this));
  },

  checkedRadioIndex: function(){
    var checkedRadio = this.radios.detect(function(radio, index) { return radio.checked; }) || this.radios[0];
    return this.radios.indexOf(checkedRadio);
  },

  doesNotContainCheckboxes: function(panel){
	return panel.select('input').size() == 0;
  },

  showPanelByIndex: function(index) {
    this.panels.each(function(panel, i) {
      if(i == index) {
        panel.show();
      } else {
        panel.hide();
      }
    });
  }
});