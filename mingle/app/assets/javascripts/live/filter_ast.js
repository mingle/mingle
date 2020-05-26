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
(function($) {

  // Using NON-STRICT comparisons (e.g. allow implicit type-casting). See note below.
  OPS = {
    "and": "&&",
    "or": "||",
    "=": "==",
    "!=": "!="
  };

  function rhsValue(value) {
    if ("number" === typeof value) {
      return value;
    }

    // default to string
    return ("\"" + value + "\"").toLowerCase();
  }

  function lhsToken(token) {
    return "c.get(\"" + token + "\")";
  }

  function special(node) {
    if ("not" === node.name) {
      return "!" + build(node.ast);
    }
    if ("tagged" === node.name) {
      return "c.taggedWith(\"" + node.ast["with"] + "\")";
    }
  }

  /* assume prefix-style segments; [OP, LHS, RHS]
   *
   * NOTE: It's worth pointing out that we are using ** non-strict comparison operators ** in JavaScript
   * so we don't need to worry about type casting when comparing, and it makes for simpler (and readable)
   * generated code.
   *
   * It's also worth noting that date comparisons serendipitously "just work" because we choose the
   * YYYY-MM-DD string format. This is convenient because the ordinal value of the strings can be correctly
   * evaluated: e.g. "2015-02-23" > "2015-02-22" yields the correct result, etc. This saves a good amount of
   * code that would be invested in type-casting before comparison.
   */
  function build(tree) {
    if (null === tree) {
      // null is an object in JS
      return "null";
    }

    if (tree instanceof Array) {
      var op = OPS[tree[0]] || tree[0];
      var lhs = ("object" === typeof tree[1]) ? build(tree[1]) : lhsToken(tree[1]);
      var rhs;

      if ("in" === op.toLowerCase()) {

        // assume array as second param for "in" operator
        rhs = tree[2].map(function(el) {
          if ("string" === typeof el) {
            return el.toLowerCase();
          }
          return el;
        });

        return "(" + JSON.stringify(rhs) + ".indexOf(" + lhs + ") !== -1)";
      }

      rhs = ("object" === typeof tree[2]) ? build(tree[2]) : rhsValue(tree[2]);
      return ["(", lhs, op, rhs, ")"].join(" ");
    }

    if ("object" === typeof tree && "string" === typeof tree.name) {
      return special(tree);
    }
  }

  function d(message) {
      (console && "function" === typeof console.log) && console.log(message);
  }

  // returns a "compiled" function to match the card to the view filters
  function compiler(tree) {
    var expression = (null === tree) ? "true" : build(tree);
    d(expression);
    var fn = new Function("c", "return " + expression);

    return function(json) {
      var c = new Card(json);
      return fn(c);
    };
  }

  // wrapper object to aid with extracting meaningful values for filter matching
  function Card(json) {
    this.model = json;


    var keys = {};
    // allow case-insensitive get()
    for (var prop in json) {
      if (json.hasOwnProperty(prop)) {
        keys[prop.toLowerCase()] = prop;
      }
    }

    var tagCache;
    this.tags = function() {
      if (!tagCache) {
        tagCache = (this.model["&tags"] || []).map(function(t) {
          return t.toLowerCase();
        });
      }
      return tagCache;
    };

    this.taggedWith = function(tag) {
      return (this.tags().indexOf(tag.toLowerCase()) !== -1);
    };

    // retrieves value with type-casting based on hint
    // values are alway lower cased to ensure case insensitive comparisons when
    // using user-entered MQL filters
    this.get = function(name) {
      var key = this.model.hasOwnProperty(name) ? name : keys[name.toLowerCase()];

      if ("undefined" === typeof key) {
        return;
      }

      // Always cast card number to integer
      if ("number" === key.toLowerCase()) {
        return parseInt(this.model[key], 10);
      }

      var val;
      // if no hint, return raw value
      if (!(this.model[key] instanceof Array)) {
        val = this.model[key];
      } else {
        // so far, numbers are the only values that can be problematic loose comparisons
        // comparing dates as strings seem ok in the ISO 8601 (YYYY-MM-DD) format
        val = this.model[key][0], hint = this.model[key][1];

        if (null === val || "undefined" === typeof val) {
          return null;
        }

        switch (hint) {
          case "user":
            // just return the user id
            val = String(JSON.parse(val)[0]);
            break;
          case "numeric":
            if ("number" === typeof val) {
              break;
            }

            var casted = /\./.test(String(val)) ? parseFloat(val) : parseInt(val, 10);
            if (isNaN(casted)){
              d("parseInt or parseFloat yielded NaN!!:");
              d(val);
            }

            val = casted;
            break;
          default:
            break;
        }

      }

      return ("string" === typeof val) ? val.toLowerCase() : val;
    };
  }

  MingleUI.ast = {
    compiler: compiler,
    Card: Card
  };

})(jQuery);
