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
  function updateEdition(input) {
    if (input.val() === "plus") {
      $(".mingle-edition-basic-only").hide();
      $(".mingle-edition-plus-only").show();
    }

    if (input.val() === "basic") {
      $(".mingle-edition-basic-only").show();
      $(".mingle-edition-plus-only").hide();
    }

    $(".pricing-slider").each(function(index) {
      var slider = this.noUiSlider;
      slider.set(slider.get());
    });
  }

  function initSlider() {
    $(".pricing-slider").each(function(index) {
      var slider = $(this);
      var numberOfUsers = $('#buy-form input[name="max_active_full_users"]').val();
      if (numberOfUsers > 100) {
        numberOfUsers = 100;
      }
      noUiSlider.create(this, {
        start: [numberOfUsers],
        step: 1,
        connect: 'lower',
        range: {
          'min': 5,
          'max': 100,
        }
      });
      this.noUiSlider.on('update', function( values, handle ){
        if(handle !== index) {
          return;
        }
        var users = Math.round(values[0]);
        var perUserPrice = $("[name='mingle-edition']:checked").data("per-user-price");
        var price = (users - 5) * perUserPrice;
        if(users >= 100) {
          $(".per-month-price").html("<a href=\"mailto:studios@thoughtworks.com\">Let's Talk</a>");
        } else {
          $(".per-month-price").text("$" + price + "/mo");
        }

        if (price <= 0 ) {
          $(".per-month-price").text("Free");
        }
        slider.find(".noUi-handle").text(users);
      });
    });
  }
  function initBuyButton() {
    $("#buy_button").click(function(e) {
      if ($("#buy_button").data("submitted")) {
        return;
      }

      var numberOfUsers = $(".pricing-slider")[0].noUiSlider.get();
      $('#buy-form input[name="max_active_full_users"]').val(numberOfUsers);

      if ($('input[name="contact_email"]').val() == '') {
        $(this).tipsyFlash("Please leave us contact email.");
        return;
      }
      if ($('input[name="contact_phone"]').val() == '') {
        $(this).tipsyFlash("Please leave us contact phone number.");
        return;
      }
      $("#buy_button").data("submitted", true);
      $("#buy-form").submit();
      $(this).trigger("submitForm");
    }).withProgressBar({ event: "submitForm" });
  }

  $.fn.initBuyForm = function() {
    initBuyButton();
    initSlider();
    $("[name='mingle-edition']").on("change", function() {
      updateEdition($(this));
    });
    updateEdition($("[name='mingle-edition']:checked"));
  };

  $.fn.initBuyButton = function() {
    var button = $(this);
    MingleUI.readyOrAjaxComplete(function() {
      button.data("submitted", false);
    });
    $(this).click(function(e) {
      if ($(this).data("submitted")) {
        return;
      }
      $(this).data("submitted", true);
      $(this).trigger("submitForm");
      $(this).parents('form').submit();
    }).withProgressBar({ event: "submitForm" });
  };

  $.fn.initDowngradeLink = function() {
    $(this).click(function(e) {
      if ($(this).data("submitted")) {
        return;
      }
      $(this).data("submitted", true);
      $('#downgrade_lightbox .bottom-progress-bar').show();
      $(this).parents('form').submit();
    });
  };
}(jQuery));
