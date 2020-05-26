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
(function ($) {
  "use strict";

  window.MingleUI = window.MingleUI || {};
  MingleUI.grid = MingleUI.grid || {};

  function AggregateCalculator(aggregateType, aggregatePropertyName) {
    var types = {
      SUM: function (values) {
        for (var sum = 0, i = 0, len = values.length; i < len; i++) {
          sum += values[i];
        }
        return sum;
      },
      AVG: function (values) {
        var avg = this.SUM(values) / values.length;
        return Math.round(avg * 10) / 10.0 || 0;
      },
      MIN: function (values) {
        var min = Math.min.apply(this, values);
        return isFinite(min) ? min : 0;
      },
      MAX: function (values) {
        var max = Math.max.apply(this, values);
        return isFinite(max) ? max : 0;
      }
    };
    return {
      calculate: function (cards) {
        if (aggregateType === "COUNT") {
          return cards.length;
        }

        for (var i = 0, current, values = [], len = cards.length; i < len; i++) {
          current = $(cards[i]).find(".card-inner-wrapper").data("card-properties")[aggregatePropertyName];
          if (("undefined" !== typeof current) && (null !== current)) {
            values.push(Number(current));
          }
        }

        return types[aggregateType](values);
      }
    };
  }

  function DimensionHeader(instance, type, element) {
    element = $(element);

    function aggregateElement() {
      return element.find(".aggregate");
    }

    function cards() {
      if ("column" === type) {
        var search = element.data("lane-value").toString();
        return (instance.grid || $(instance.element)).find("tbody").find("td[lane_value=" + JSON.stringify(search) + "]").find(".card-icon");
      }

      if ("row" === type) {
        return element.closest("tr").find(".card-icon");
      }
    }

    return {
      updateAggregate: function () {
        var aggregate = instance[type + 'Aggregate']();
        aggregateElement().text("(" + aggregate.calculate(cards()) + ")");
      },

      aggregateValue: function () {
        return aggregateElement().text();
      }
    };
  }

  var AggregateMixin = {

    setupHeaderAggregates: function setupHeaderAggregates() {
      var self = this;
      this.columnHeaders = $.map(this.grid.find("thead").find(".lane_header"), function (el, i) {
        return new DimensionHeader(self, "column", el);
      });
      this.rowHeaders = $.map(this.grid.find("tbody").find(".row_header"), function (el, i) {
        return new DimensionHeader(self, "row", el);
      });
      this.updateAggregates();
    },

    columnAggregate: function columnAggregate() {
      var aggregateType = this.grid.data("column-aggregate-type");
      var aggregateProperty = this.grid.data("column-aggregate-property");
      return new AggregateCalculator(aggregateType, aggregateProperty);
    },

    rowAggregate: function rowAggregate() {
      var aggregateType = this.grid.data("row-aggregate-type");
      var aggregateProperty = this.grid.data("row-aggregate-property");
      return new AggregateCalculator(aggregateType, aggregateProperty);
    },

    updateAggregates: function updateAggregates() {
      for (var i = 0, cLen = this.columnHeaders.length; i < cLen; i++) {
        this.columnHeaders[i].updateAggregate();
      }

      for (var k = 0, rLen = this.rowHeaders.length; k < rLen; k++) {
        this.rowHeaders[k].updateAggregate();
      }
    }

  };

  // export public api
  $.extend(MingleUI.grid, {
    AggregateMixin: AggregateMixin,
    DimensionHeader: DimensionHeader,
    AggregateCalculator: AggregateCalculator
  });

})(jQuery);
