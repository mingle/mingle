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
MingleUI.EasyCharts.StackedBarChart = (MingleUI.EasyCharts.StackedBarChart || {});
MingleUI.EasyCharts.StackedBarChart.XLabelTranslator = function (callback) {
  this.date = function (options) {
    return function (data) {
      var jsProjectDateFormat = MingleUI.RUBY_TO_JS_DATE_FORMAT_MAPPING[options.dateFormat];
      var propertyValues = data.reduce(function (_propertyValues, prop) {
        var val = null;
        if(prop instanceof  Object)
          val = prop[options.property];
        else
          val = prop;
        if (val)
          _propertyValues.push(new Date(val).format(jsProjectDateFormat));
        return _propertyValues;
      }, []);

      function sortingFunction(first, second) {
        return Date.parse(first) - Date.parse(second);
      }

      callback(propertyValues.sort(sortingFunction));
    };
  };

  this.common = function (options) {
    return function (data) {
      var propertyValues = data.reduce(function (_propertyValues, prop) {
        var val = null;
        if(prop instanceof  Object)
          val = prop[Object.keys(prop)[0]];
        else
          val = prop;

        if (val) _propertyValues[val] = val;
        return _propertyValues;
      }, {});
      if (options.isManaged) {
        propertyValues = options.propValues.reduce(function (_propertyValues, propVal) {
          if (propertyValues.hasOwnProperty(propVal))
            _propertyValues.push(propVal);
          return _propertyValues;
        }, []);
      }  else {
        var sortFunction = options.dataType === 'numeric' ? function (value1, value2) {
              return value1 - value2;
            } : undefined;
        var transformFunction = function (value){
          return options.dataType === 'numeric' ? parseFloat(value) : value;
        };
        propertyValues = Object.keys(propertyValues).collect(transformFunction).sort(sortFunction);
      }
      callback(propertyValues);
    };
  };

  this.user = function (options, getDisplayNameFor) {
    return function (data) {
      var propertyValues = data.reduce(function (_propertyValues, prop) {
        var val = null;
        if(prop instanceof  Object)
          val = prop[options.property];
        else
          val = prop;
        if (val) _propertyValues.push([getDisplayNameFor(val), val]);
        return _propertyValues;
      }, []);
      propertyValues = propertyValues.sort(function (left, right) {
            var leftVal = left[0];
            var rightVal = right[0];
            return leftVal.toLowerCase() > rightVal.toLowerCase() ? 1 : (leftVal.toLowerCase() < rightVal.toLowerCase() ? -1 : 0 );
          }
      );
      callback(propertyValues);
    };
  };

  this.card = function (options) {
    return function (data) {
      var propertyValues = data.reduce(function (_propertyValues, prop) {
        var val = null;
        if(prop instanceof  Object)
          val = prop[options.property];
        else
          val = prop;
        if (val) {
          _propertyValues.push(new CardLabel(val));
        }
        return _propertyValues;
      }, []);
      propertyValues = propertyValues.smartSortBy('name').invoke('label');
      callback(propertyValues);
    };
  };

  function CardLabel(cardLabel) {
    function extractName() {
      return cardLabel.replace(/^#\d+\s+/, '');
    }

    this.name = function () {
      return extractName();
    };

    this.label = function () {
      return cardLabel;
    };
  }
};