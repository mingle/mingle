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
var PopupLauncher = function(launcher) {
  var launcherId = launcher;
  
  var onClickHandler = function(e){
    PopupLauncher.closeAllPopups(e);
    showAdjacentPopup(e);
  };

  var showAdjacentPopup = function(e) {
    var anchor = Event.element(e);
    anchor.up('.team-popup-container').setStyle('position: relative');
    anchor.adjacent('.team-popup').first().show();
  };

  Event.observe(launcherId, 'click', onClickHandler.bindAsEventListener(this));
  Event.observe(document, 'click', PopupLauncher.globalClickListener);
  Event.observe(document, 'mingle:droplink_clicked',  PopupLauncher.closeAllPopups);
  
  
  return;
};

PopupLauncher.closeAllPopups = function(e){
  $$('.team-popup').map(Element.hide);
  $$('.team-popup-container').each(function(el) { 
    el.setStyle('position: static'); 
  });  
};

PopupLauncher.globalClickListener = function(event){
  var element = Event.element(event);
  if(!(element && element.ancestors) || element.hasClassName('popup-launcher')) {return true;}
  var clickedOnAVisiblePopup = element.ancestors().detect(function(node){
    if (node.hasClassName('team-popup') && node.visible()) {
      return node;
    }
  });
  var clickedOnExplanationLink = element.hasClassName('explanation');

  if(!clickedOnAVisiblePopup && !clickedOnExplanationLink) {
    PopupLauncher.closeAllPopups();
  } 
  return true;
};