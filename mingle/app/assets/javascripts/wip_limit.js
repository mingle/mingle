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
(function ($j) {

  $j(window).on("resize", function() { WipEditPopup.alignOpenPopup(); });

  window.MingleUI = window.MingleUI || {};
  MingleUI.grid = MingleUI.grid || {};
  var WipConstants = {
    WIP_LIMIT_VALUE_SELECTOR: 'input[name=new_wip_limit]',
    WIP_LIMIT_PROPERTY_SELECTOR: '#select_aggregate_property_wip_drop_link'
  };

  WipPolice = (function wipPoliceModule() {
    var _laneHeaders = null;
    var initialized = false;

    function initialize(laneHeaders) {
      _laneHeaders = laneHeaders;
      if (MingleUI.grid.instance === undefined)
        MingleUI.grid.start();
      initialized = true;
      enforce();
    }

    function makeSuffix(errorLanes) {
      if(errorLanes.length == 1)
          return " " + errorLanes[0] + ".";

      var text = "s " + errorLanes.slice(0, errorLanes.length - 1).join(", ");
      text += " and " + errorLanes[errorLanes.length - 1] + ".";
      return text;
    }

    function resetErrorHighlighting(errorContainer) {
      errorContainer.find(WipConstants.WIP_LIMIT_PROPERTY_SELECTOR).removeClass('error-highlight');
      errorContainer.find(WipConstants.WIP_LIMIT_PROPERTY_SELECTOR).removeClass('error-highlight');
      errorContainer.find('.wip-error-box').remove();
    }

    function displayErrorMessage(errorContainer, message, selector, event) {
      if(message == null || selector == null) {
        return;
      }
      errorContainer.find('p.wip-error-box').remove();
      errorContainer.append($j('<p>', {class: 'wip-error-box error-box', html: message}));
      if(selector)
        errorContainer.find(selector).addClass('error-highlight');
      if(event)
        Event.stop(event);
    }

    function calculateCurrentValueForWIP(panel, laneName) {
      var limitType = panel.find('input[name="wip_limits[' + laneName + '][type]"]').val();
      var limitProperty = panel.find('input[name="wip_limits[' + laneName + '][property]"]').val();
      var cards = (MingleUI.grid.instance.grid || $(MingleUI.grid.instance.element)).find("tbody").find("td[lane_value=" + JSON.stringify(laneName) + "]").find(".card-icon");
      var aggregateCalculator = new MingleUI.grid.AggregateCalculator(limitType.toUpperCase(), 'wip.' + limitProperty);

      return aggregateCalculator.calculate(cards);
    }

    function enforce() {
      if (!isInitialized()) return;

      var panel = _laneHeaders.find('.wip-popover');
      var table = $j('table.swimming-pool');
      var errorLanes = [];

      _laneHeaders.each(function(idx, laneHeader){
        laneHeader = $j(laneHeader);
        var laneName = laneHeader.data('lane-value');
        if(!laneName) return;

        var limitInput = panel.find('input[name="wip_limits[' + laneName + '][limit]"]');
        if (!limitInput.val()) return;
        var limit = parseInt(limitInput.val());

        var currentValue = calculateCurrentValueForWIP(panel, laneName);

        var wipLimitViolated = currentValue > limit;
        if (wipLimitViolated) {
          var errorLane = "<strong>"+laneName+"</strong>";
          if (!errorLanes.include(errorLane))
            errorLanes.push(errorLane);
          }
          laneHeader.toggleClass('wip-violation', wipLimitViolated);
          laneHeader.toggleClass('wip-violation-icon', wipLimitViolated);
          table.find('td[lane_value="'+ laneName + '"]').toggleClass('wip-violation', wipLimitViolated);
      });
      var errorContainer = $j("#flash");
      if(errorLanes.length > 0) {
          var errorMessage = "The WIP limit has been exceeded on the swimlane";
          var errorMessageSuffix = makeSuffix(errorLanes);
          displayErrorMessage(errorContainer, errorMessage + errorMessageSuffix, false);
      } else {
          resetErrorHighlighting(errorContainer);
      }
    }

    function isInitialized() {
      return initialized;
    }

    return {
      initialize: initialize,
      enforce: enforce,
      displayErrorMessage: displayErrorMessage,
      isInitialized: isInitialized,
      resetErrorHighlighting: resetErrorHighlighting
    };
  })();

  WipEditPopup = (function wipEditPopupModule() {

    function initEditableWip(laneHeaders, wipTypeDropList, wipAggProDropList) {
      panel = laneHeaders.find(".wip-popover");
      if (panel.length === 0) return;
      var trigger = laneHeaders.find(".editable-wip");
      WipPolice.initialize(laneHeaders);
      trigger.on("click", function (event) {
        if (1 !== event.which) return; // not left click
        var laneHeader = $j(event.target.parentElement);
        var content = panel.find(".content");
        var currentTrigger = $j(event.target);
        event.preventDefault();
        event.stopPropagation();
        if (content.is(":hidden")) {
          setupEditablePopup(content, laneHeader, wipAggProDropList, currentTrigger, wipTypeDropList);
        } else {
          hide();
        }
      });
    }

    function wipPropertyChanged(selection) {
      var popup = $j(selection.element).parents('.editable-content');
      WipPolice.resetErrorHighlighting(popup);
    }

    function initReadonlyWip(laneHeaders) {
      panel = laneHeaders.find(".wip-popover");
      WipPolice.initialize(laneHeaders);
      if (panel.length === 0) return;
      var trigger = laneHeaders.find(".readonly-wip");

      trigger.on("click", function (event) {
        if (1 !== event.which) return; // not left click
        var content = panel.find(".content");
        content.find('p.error-box').remove();
        var currentTrigger = $j(event.target);
        event.preventDefault();
        event.stopPropagation();
        if (content.is(":hidden")) {
          setupReadonlyPopup(currentTrigger, content);
        } else {
          hide();
        }
      });
    }

    function configuredAggWipProp(lane) {
      return lane.find('input[name=wip_property_config]').val();
    }

    function createWipInfoElement(laneHeader) {
      var wipType = configuredWipType(laneHeader).toLowerCase();
      var wipLimit = configuredWipLimit(laneHeader);
      var wipProperty = configuredAggWipProp(laneHeader);
      var message = 'There is no limit on the Work in Progress';
      if (wipLimit != null && wipLimit != '') {
        if (wipType == 'sum')
          message = 'The Work in Progress limit is a sum of ' + wipProperty + ' and is limited to ' + wipLimit;
        else
          message = 'The Work in Progress limit is set to ' + wipLimit + ' cards';
      }
      return $j('<p>', {
        class: 'wip-info',
        text: message
      });
    }

    function setupReadonlyPopup(currentTrigger, content) {
      var laneHeader = currentTrigger.parents('.lane_header');
      alignPopup(currentTrigger, content);
      content.data('lane-id', laneHeader.prop('id'));
      content.empty().append(createWipInfoElement(laneHeader));
      show();
      alignOpenPopup();
      $(document).on("click", new UIUtils().onClickOutside(content, hide));
    }

    function alignPopup(currentTrigger, content) {
      var positionStyle = 'absolute';
      var topOffset = currentTrigger.parent().position().top;
      if ($j("#swimming-pool thead").not("#placeholder-for-header").hasClass('fixed')) {
        positionStyle = 'fixed';
        topOffset = 0;
      }
      content.css('position', positionStyle);
      var position = calculatePopupPosition(currentTrigger, content, topOffset);
      content.css(position);
    }

    function setupEditablePopup(content, laneHeader, wipAggProDropList, currentTrigger, wipTypeDropList) {
      var wipType = configuredWipType(laneHeader);
      content.data('lane-id', laneHeader.prop('id'));
      var wipTypeDropDown = content.find('#select_aggregate_type_wip_drop_link');
      wipTypeDropDown.prop('title', wipType);
      wipTypeDropDown.text(wipType);
      content.find('input[name=select_wip_type_field]').val(wipType.toLowerCase());
      WipPolice.resetErrorHighlighting(content);
      if (wipType.toLowerCase() === 'count')
        resetSelectedWipProp(content, wipAggProDropList);
      else
        setSelectedWipProp(content, wipAggProDropList, currentTrigger);
      wipTypeDropList.replaceSelectedOption([capitalizeFirstLetter(wipType), wipType]);
      show();
      alignOpenPopup();
      content.find('input[name=new_wip_limit]').val(configuredWipLimit(laneHeader));
      content.find('form#set_wip_limit_form').unbind('submit').submit(setWipLimit);
      toggleWipOptions(content, wipType);
      $(document).on("click", new UIUtils().onClickOutside(content, hide));
    }

    function modifyWipLimit(popup, currentLane, wipType) {
      popup.find('input[name="wip_limits[' + currentLane + '][type]"]').val(selectedWipType(popup));
      popup.find('input[name="wip_limits[' + currentLane + '][limit]"]').val(selectedWipLimit(popup));
      if (isWipTypeChangedToCount(wipType, popup))
        popup.find('#set_wip_limit_form').append('<input name="wip_limits[' + currentLane + '][property]" type="hidden" value="' + selectedAggWipProp(popup) + '">');
      else if (isWipTypeChangedToSum(wipType, popup))
        popup.find('input[name="wip_limits[' + currentLane + '][property]"]').val(selectedAggWipProp(popup));
      else if (isNewWipType(wipType, popup))
        popup.find('input[name="wip_limits[' + currentLane + '][property]"]').remove();
    }

    function addWipLimit(popup, currentLane) {
      var formToSetWipLimit = popup.find('#set_wip_limit_form');
      var wipProp = $j('<input>',{class:'name',value:selectedAggWipProp(popup),name:"wip_limits[" + currentLane + "][property]",type:'hidden'});
      var wipType = $j('<input>',{class:'name',value:selectedWipType(popup),name:"wip_limits[" + currentLane + "][type]",type:'hidden'});
      var wipLimit = $j('<input>',{class:'name',value:selectedWipLimit(popup),name:"wip_limits[" + currentLane + "][limit]",type:'hidden'});
      formToSetWipLimit.append(wipType);
      formToSetWipLimit.append(wipLimit);
      if (selectedWipType(popup).toLowerCase() === 'sum')
        formToSetWipLimit.append(wipProp);
    }

    function validateWip(popup, event) {
      var message, selector;
      var returnValue = true;
      if(selectedWipType(popup).match(/sum/gi) && selectedAggWipProp(popup) == ('')) {
        message = 'Please select a property';
        selector = WipConstants.WIP_LIMIT_PROPERTY_SELECTOR;
        returnValue = false;
      } else if (selectedWipLimit(popup) != '' && selectedWipLimit(popup).match(/^\d+$/) == null) {
        message = 'The WIP limit must be a whole number.';
        selector = WipConstants.WIP_LIMIT_VALUE_SELECTOR;
        returnValue = false;
      } else if (selectedWipType(popup).match(/count/gi) && parseInt(selectedWipLimit(popup)) > 500) {
        message = 'A maximum of 500 cards are allowed on the grid view. The WIP limit must be under 500.';
        selector = WipConstants.WIP_LIMIT_VALUE_SELECTOR;
        returnValue = false;
      }
      WipPolice.displayErrorMessage(popup, message, selector, event);
      return returnValue;
    }

    function setWipLimit(event) {
      var popup = $j(event.target).parents('.editable-content');
      var lane = $j('#' + popup.data('lane-id'));
      var wipType = configuredWipType(lane);
      var currentLane = lane.data('lane-value');
      WipPolice.resetErrorHighlighting(popup);
      if(validateWip(popup,event)) {
        var user_entered_wip_limit = popup.find(WipConstants.WIP_LIMIT_VALUE_SELECTOR).val();
        if (user_entered_wip_limit == '') {
          resetWipLimit(popup);
          return true;
        }
        if (!lane.find('input[name=wip_limit_config]').val())
          addWipLimit(popup, currentLane, wipType);
        else
          modifyWipLimit(popup, currentLane, wipType);
      }
    }

    function setSelectedWipProp(content, wipAggProDropList, currentTrigger) {
      var wipProp = currentTrigger.parents('.lane_header').find('input[name=wip_property_config]').val();
      var wipPropDropDown = content.find('#select_aggregate_property_wip_drop_link');
      wipPropDropDown.prop('title', wipProp);
      wipPropDropDown.text(wipProp);
      content.find('input[name=wip_aggregate_property]').val(wipProp);
      wipAggProDropList.replaceSelectedOption([wipProp, wipProp]);
    }

    function resetSelectedWipProp(content, wipAggProDropList) {
      var wipProp = '(select property...)';
      var wipPropDropDown = content.find('#select_aggregate_property_wip_drop_link');
      wipPropDropDown.prop('title', wipProp);
      wipPropDropDown.text(wipProp);
      content.find('input#wip_aggregate_property').val('');
      wipAggProDropList.replaceSelectedOption([wipProp, '']);
    }

    function toggleWipOptions(target, wipType) {
      if (wipType.toLowerCase() === 'sum')
        target.find('#select_aggregate_property_wip_drop_link').show();
      else
        target.find('#select_aggregate_property_wip_drop_link').hide();
    }

    function calculatePopupPosition(currentTrigger, content, topOffset) {
      var top = currentTrigger.position().top + currentTrigger.height() + topOffset;
      var left = currentTrigger.parent().width() / 2 - content.width() / 2;
      return addPos({left: left, top: top}, {
        left: currentTrigger.parent().position().left,
        top: 5
      });
    }

    function wipTypeChanged(selection) {
      if (("undefined" === typeof(selection)) || ("undefined" === typeof(selection.element)))
        return;
      var popup = $j(selection.element).parents('.editable-content');
      WipPolice.resetErrorHighlighting(popup);
      var lane = $j('#' + popup.data('lane-id'));
      var wipType = configuredWipType(lane);
      var targetId = selection.element.id;
      var user_wip_limit_input = popup.find('input[name=new_wip_limit]');
      var wip_limit_value = targetId.match(wipType) ? configuredWipLimit(lane) : null;
      user_wip_limit_input.val(wip_limit_value);
      toggleWipOptions(popup, selection.value);
    }

    function resetWipLimit(popup) {
      WipPolice.resetErrorHighlighting(popup);
      var lane_header = $j('#' + popup.data('lane-id'));
      var currentLane = lane_header.data('lane-value');
      lane_header.find('input[name="wip_type_config"]').val(null);
      lane_header.find('input[name="wip_property_config"]').val(null);
      lane_header.find('input[name="wip_limit_config"]').val(null);
      lane_header.find('.editable-wip').text('WIP : (not-set)');
      popup.find('input[name="wip_limits[' + currentLane + '][limit]"]').val(null);
      popup.find('input[name="wip_limits[' + currentLane + '][property]"]').val(null);
      popup.find('input[name="wip_limits[' + currentLane + '][type]"]').val(null);
    }

    function configuredWipType(laneHeader) {
      return laneHeader.find('input[name=wip_type_config]').val();
    }

    function isNewWipType(wipType, popup) {
      return wipType.toLowerCase() !== selectedWipType(popup).toLowerCase();
    }

    function isWipTypeChangedToCount(wipType, popup) {
      return isNewWipType(wipType, popup) && wipType.toLowerCase() === 'count';
    }

    function isWipTypeChangedToSum(wipType, popup) {
      return !isNewWipType(wipType, popup) && wipType.toLowerCase() === 'sum';
    }

    function selectedAggWipProp(popup) {
      return popup.find('input#wip_aggregate_property').val();
    }

    function selectedWipType(popup) {
      return popup.find('input[name=select_wip_type_field]').val();
    }

    function selectedWipLimit(popup) {
      return popup.find('input[name=new_wip_limit]').val();
    }

    function capitalizeFirstLetter(string) {
      return string.charAt(0).toUpperCase() + string.slice(1);
    }

    function findSelectedTargetId(event) {
      if (event.target.id.match(/(sum|count)$/gi))
        return event.target.id;
      return event.target.parentElement.id;
    }

    function configuredWipLimit(lane) {
      return lane.find('input[name=wip_limit_config]').val();
    }

    function addPos(a, b) {
      return {
        left: a.left + b.left,
        top: a.top + b.top
      };
    }

    function show() {
      panel.addClass("open");
    }

    function hide() {
      panel.removeClass("open");
    }

    function alignOpenPopup() {
      if (($j('.wip-popover').length > 0) && $j('.wip-popover').hasClass('open')) {
        var content = $j('.wip-popover .content');
        var currentTrigger = $j('#' + content.data('lane-id')).find('.lane-wip');
        alignPopup(currentTrigger, content);
      }
    }

    return {
      setupEditableWip: initEditableWip,
      setupReadonlyWip: initReadonlyWip,
      wipTypeChanged: wipTypeChanged,
      wipPropertyChanged: wipPropertyChanged,
      alignOpenPopup: alignOpenPopup
    };

  })();

}(jQuery));
