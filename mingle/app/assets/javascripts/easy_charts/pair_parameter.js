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
var MingleUI = (MingleUI || {});
MingleUI.EasyCharts = (MingleUI.EasyCharts || {});

MingleUI.EasyCharts.PairParameter = function (container, pairDefinition, options) {
  var self = this, paramOne, paramTwo, connectingTextContainer = $j('<div>', {class: 'pair-connector'}),
      pairHidden = false;

  function addConnectingText() {
    var connectingText = $j('<span>', {text: pairDefinition.connecting_text});
    connectingTextContainer.append(connectingText);
    self.htmlContainer.append(connectingTextContainer);
  }

  function addParameter(paramDef) {
    var parameter  = new MingleUI.EasyCharts.Parameter(self.name.toSnakeCase(), paramDef, options);
    self.htmlContainer.append(parameter.htmlContainer);
    return parameter.param;
  }

  function initialize() {
    self.htmlContainer = $j(container);
    self.name = pairDefinition.name;

    paramOne = addParameter(pairDefinition.param_defs[0]);
    addConnectingText();
    paramTwo = addParameter(pairDefinition.param_defs[1]);
  }

  this.hidePairParameter = function () {
    pairHidden = true;
    connectingTextContainer.hide();
    paramTwo.htmlContainer.parent('.parameter-container').hide();
  };

  this.showPairParameter = function () {
    pairHidden = false;
    connectingTextContainer.show();
    paramTwo.htmlContainer.parent('.parameter-container').show();
  };

  this.setPairValues = function(values, initialValue) {
    paramTwo.updateOptions(values, initialValue);
  };

  this.isValid = function () {
    return !!(paramOne.value() && (pairHidden ? true : paramTwo.value()));
  };

  this.value = function(){
    var values = {};
    values[paramOne.name] = paramOne.value();
    values[paramTwo.name] = paramTwo.value();
    return values;
  };

  initialize();
};