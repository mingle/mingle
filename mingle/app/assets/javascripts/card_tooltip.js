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
(function($) {
  function refreshTipsy(link) {
    if (link.data('tipsyHoverState') === 'in') {
      link.tipsy('show');
    }
  }

  function lazyLoadCardName(link) {
    if ( link.data('card-name') || link.data("tipsy-loading") ) { return; }
    link.data("tipsy-loading", true);

    $.ajax({
      type: 'get',
      url: link.data('card-name-url'),
      dataType: "json",
      success: function(json) {
        var displayTitle = "#" + json.number + " " + json.name;
        link.data('card-name', displayTitle);
      },

      error: function(response) {
        if(401 === response.status || 404 === response.status) {
          link.data('card-name', response.responseText);
        }
      },

      complete: function() {
        link.data("tipsy-loading", false);
        refreshTipsy(link);
      }
    });
  }

  function tipsyInit(link) {
    if ( link.tipsy(true) ) { return; }
    link.tipsy({ gravity: $.fn.tipsy.autoBounds(30, 'n'),
                 opacity: 0.8,
                 trigger: 'manual',
                 fallback: 'Loading...',
                 title: function() {
                   return $(this).data("card-name") || "";
                 }
               });
  }

  function enter(link) {
    tipsyInit(link);
    link.data('tipsyHoverState', 'in');
    link.tipsy('show');
    lazyLoadCardName(link);
  }


  function leave(link) {
    link.data('tipsyHoverState', 'out');
    link.tipsy('hide');
  }

  $.fn.cardTooltip = function(options){
    $(document).on('mouseenter', this.selector, function(e) {
      enter($(this));
    });

    $(document).on('mouseleave', this.selector, function(e) {
      leave($(this));
    });

    return this;
  };

  $(function() {
    $('.card-tool-tip').cardTooltip();
  });

})(jQuery);
