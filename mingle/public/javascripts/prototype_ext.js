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
String.prototype.isBlank = function () {
  return this.match(/^\s*$/);
};

String.prototype.stretch = function () {
  return this.replace(/(\n)|(\r\n)/gm, '');
};

String.prototype.isInclude = function () {
  return $A(arguments).all(function (arg) {
    return this.indexOf(arg) >= 0;
  }.bind(this));
};

String.prototype.wordWrap = function (length) {
  var words = this.strip().wordBreak(length, " ");
  if (words.any(function (word) {
        return word.length > length;
      })) {
    return this.truncate(length);
  } else {
    return this;
  }
};

String.prototype.wordBreak = function (length, separator) {
  var result;
  if (this.length > length) {
    result = this.split(separator);
    for (var i = 0; i < result.length - 1; i++) {
      result[i] += separator;
    }
  } else {
    result = [this];
  }
  return result;
};

String.prototype.supplant = function (o) {
  return this.replace(/{([^{}]*)}/g,
      function (a, b) {
        var r = o[b];
        return typeof r === 'string' || typeof r === 'number' ? r : a;
      }
  );
};

String.prototype.toCamelCase = function (separator) {
  if (!separator)
    separator = '_';
  return this.replace(new RegExp("^[^{separator}]+{separator}".supplant({separator: separator}), 'g'), function (match, c) {
    return match ? match.toLowerCase() : '';
  }).replace(new RegExp("[{separator}\\s]+(.)?".supplant({separator: separator}), 'g'), function (match, c) {
    return c ? c.toUpperCase() : '';
  });
};

String.prototype.toSnakeCase = function (separator) {
  if (!this.length) return '';

  this[0] = this[0].toLowerCase();
  return this.replace(/([a-z\d])([A-Z]+)/g, '$1_$2').replace(/[-\s]+/g, '_').toLowerCase();
};

Number.prototype.closestPowerOfTen = function () {
  var result = 0;
  var aNumber = this;
  while (aNumber > 10) {
    result++;
    aNumber = aNumber / Math.pow(10, result);
  }
  return Math.pow(10, result - 1);
};

Number.prototype.roundToClosestOrder = function () {
  return Math.round(this / this.closestPowerOfTen()) * this.closestPowerOfTen();
};

Array.findIntersection = function (arrays, finder) {
  if (arrays == null || arrays.length == 0) {
    return [];
  } else {
    var intersection = arrays[0];
    arrays.slice(1).each(function (array) {
      intersection = intersection.findIntersection(array, finder);
    });
    return intersection;
  }
};

Array.prototype.findIntersection = function (otherArray, finder) {
  return this.select(function (element) {
    if (finder == null) {
      return otherArray.include(element);
    } else {
      return finder(otherArray, element);
    }
  });
};

Array.prototype.equals = function (otherArray) {
  if (!otherArray) return false;
  if (this.length !== otherArray.length) return false;

  return this.findIntersection(otherArray).length == this.length;
};

Array.prototype.eachPair = function (iterator) {
  this.each(function (element, index) {
    if (this[index + 1]) {
      iterator(element, this[index + 1]);
    }
  }.bind(this));
};

Array.prototype.ignoreCaseInclude = function (target) {
  if (!target) {
    return false;
  }
  var upperTarget = target.toUpperCase();
  for (var i = 0; i < this.length; i++) {
    if (upperTarget == this[i].toUpperCase()) {
      return true;
    }
  }
  return false;
};

Array.prototype.ignoreCaseWithout = function (target) {
  if (!target) {
    return;
  }
  var upperTarget = target.toUpperCase();
  return this.reject(function (element) {
    return upperTarget == element.toUpperCase();
  });
};

Array.prototype.sum = function () {
  var ret = 0;
  for (var i = 0; i < this.length; i++) {
    ret += this[i];
  }
  return ret;
};

Array.prototype.empty = function () {
  return this.size() == 0;
};

Element.ExtendMethods = {
  getText: function (element) {
    return $(element).innerHTML.strip().stripTags().replace(/\n/g, ' ').replace(/\s+/g, ' ');
  },

  getForm: function (element) {
    return element.form;
  },

  reassignName: function (element, substitutionValues) {
    var newName = element.getAttribute('name');
    if (newName == null) {
      return;
    }
    $H(substitutionValues).each(function (keyValuePair) {
      newName = newName.gsub(new RegExp(keyValuePair.first()), keyValuePair.last());
    });
    element.name = newName;
  },

  showIn: function (container, elementId) {
    var locatedElement = container.down("#" + elementId);
    Element.show(locatedElement);
  },

  hideIn: function (container, elementId) {
    var locatedElement = container.down("#" + elementId);
    Element.hide(locatedElement);
  },

  wrapContent: function (element, wrappingElement) {
    if (Prototype.Browser.IE) {
      element.moveContentTo(wrappingElement);
    } else {
      wrappingElement.innerHTML = element.innerHTML;
      element.innerHTML = "";
    }

    element.appendChild(wrappingElement);
  },

  moveContentTo: function (element, targetElement) {
    element.cleanWhitespace();
    $A(element.childNodes).each(function (child) {
      if (child.nodeType == 1) {
        targetElement.appendChild(child.remove());
      } else if (child.nodeType == 3) {
        targetElement.appendChild(document.createTextNode(child.nodeValue));
        child.nodeValue = '';
      }
    });
  },

  hasAnyParentWithId: function (element, id) {
    if (element.parentNode == null) {
      return false;
    }
    if (element.parentNode.id != undefined && element.parentNode.id == id) {
      return true;
    }
    return Element.hasAnyParentWithId(element.parentNode, id);
  },

  isFiredInside: function (element, event) {
    element = $(element);
    return event && (event.element() == element || event.element().descendantOf(element));
  }
};
Element.addMethods(Element.ExtendMethods);