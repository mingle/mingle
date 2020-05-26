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
function stickyGridViewHeaders() {
  if ($j("#swimming-pool").size() === 0) {
    return;
  }

  var removals = 0, inits = 0;

  function domLog(key, message) {
    if (!window.TRACE) {
      return;
    }

    $j("#swimming-pool").attr("data-" + key, message);

    if (!!console && "function" === typeof console.log) {
      console.log("[sticky header] " + key + ": " + message);
    }
  }

  var header, placeholder, offset;

  jQuery.stickyHeaderInternals = function() {
    return [header, placeholder, offset];
  };

  function init() {
    inits++;
    domLog("inits", inits);
    header = $j("#swimming-pool thead").not("#placeholder-for-header");
    placeholder = header.clone().attr("id", "placeholder-for-header").detach();
    updateThreshold();
  }

  function updateThreshold() {
    var table = $j("#swimming-pool");
    offset = table.offset();
    // write this out to the dom to help debug any positioning issues
    domLog("offset", offset.top);
  }

  function restoreHeader() {
    domLog("position", header.css("position") + " (restored)");
    if (header.hasClass("fixed")) {
      placeholder.detach();
      header.removeClass("fixed");
      WipEditPopup.alignOpenPopup();
    }
  }

  function cloneWidths(from, to) {
    var src = from.find("th");
    var dest = to.find("th");
    $j.each(dest, function(i, el) {
      var w = $j(src.get(i)).css("width");
      $j(el).css("min-width", w);
      $j(el).css("max-width", w);
    });
  }

  function resizeWidths() {
    if ($j.contains(document.documentElement, placeholder[0])) {
      cloneWidths(placeholder, header);
    }
    updateThreshold();
  }

  function handleFixedHeader() {
    var scrollTop = $j(window).scrollTop();
    var isInDom = $j.contains(document.documentElement, header[0]);
    if (scrollTop > offset.top) {

      domLog("threshold", "below");
      domLog("offset", offset.top);

      domLog("attached", isInDom);
      if (!isInDom) {
        removals++;
        domLog("removals", removals);
        // destroy any data or handlers attached
        header.remove();
        placeholder.remove();

        init();
      }

      domLog("position", header.css("position") + " (triggered)");
      domLog("mismatched", header.is("#placeholder-for-header"));
      if (!header.hasClass("fixed")) {
        placeholder.insertBefore(header).css("visibility", "hidden");
        cloneWidths(placeholder, header);
        header.addClass("fixed");
        WipEditPopup.alignOpenPopup();
      }
    } else {
      domLog("threshold", "above");
      domLog("offset", offset.top);
      restoreHeader();
    }
  }

  init();

  $j(window).scroll(handleFixedHeader);
  $j(document).on("mingle:relayout", resizeWidths);

  // in case the window has already been scrolled on load
  handleFixedHeader();
}

$j(document).ready(stickyGridViewHeaders);
