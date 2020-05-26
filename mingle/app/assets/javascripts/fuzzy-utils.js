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
MingleUI = MingleUI || {};
(
  function($) {
    function gaussSum(upTo) {
      // sums sequence of positive integers from 0 .. upTo
      return 0.5 * ((upTo * upTo) + upTo);
    }

    function consecutive(arr) {
      var i, k = 0, prev, buff = [], len = arr.length;
      for (i = 0; i < len; i++) {

        if (i === 0) {
          buff.push([arr[i]]);
        } else if (1 !== (arr[i] - prev)) {
          buff.push([arr[i]]);
          k++;
        } else {
          buff[k].push(arr[i]);
        }

        prev = arr[i];
      }
      return buff;
    }

    function chunkComparator(a, b) {
      // longest chunks appear first
      // if 2 chunks are the same length, the one with lower values wins (i.e. appears earlier in string)
      return (a.length == b.length) ? b[0] < a[0] : a.length < b.length;
    }

    function scoreComparator(a, b) {
      if (a.score > b.score) {
        return -1;
      }

      return (a.score < b.score) ? 1 : 0;
    }

    MingleUI.fuzzy = {
      escape: (function() {
        // use the browser's native code to escape
        var escaper = document.createElement("span");
        var textNode = document.createTextNode("");
        escaper.appendChild(textNode);

        function escape(text) {
          textNode.nodeValue = text;
          return escaper.innerHTML;
        }

        return escape;
      })(),

      score: function score(stats, string, term) {
        // baseline: length of the string matched
        var rank = stats.length * 10;

        if (stats.length > 0) {
          // bonus for greater percentage of entire string matched
          rank += (stats.length / string.length) * 10;

          // find consecutive chunks, sorted by length and earliest incidence
          var csc = consecutive(stats).sort(chunkComparator);
          var biggest = csc[0];

          // bonus for matching first char of string
          rank += stats[0] === 0 ? 1 : 0;

          // bigger bonuses when bigger consecutive chunks of search term are matched
          rank += (biggest.length / term.length) * 100;

          // even better when first character of biggest chunk was the first character of the search term
          rank += (term.charAt(0).toLowerCase() === string.charAt(biggest[0]).toLowerCase()) ? 1 : 0;

          // reward more for earlier incidences of the biggest chunk
          rank += (1 - (biggest[0] / string.length)) * 10;
        }
        return rank;
      },

      matcher: function matcher(content, term, s1, s2, partition) {
        var j = -1; // remembers position of last found character

        // consider each search character one at a time
        for (var i = 0, len = term.length; i < len; i++) {
          var l = term[i];
          if (l === " ") {
            continue; // ignore spaces
          }

          j = content.indexOf(l, j + 1); // search for character & update position

          if (j === -1) {
            return false; // if it's not found, exclude this item
          }

          if ("number" === typeof partition) {
            if (j < partition) {
              s1.push(j);
            } else {
              s2.push(j - partition);
            }
          } else {
            s1.push(j);
          }
        }

        return true;
      },

      highlight: function highlight(text, locations) {
        var src = text.toString().split("");
        var last = src.length - 1;
        var result = "", norm = "", bold = "";

        $.each(src, function(i, ch) {
          if (locations.indexOf(i) === -1) {
            if ("" !== bold) {
              result += "<b>" + MingleUI.fuzzy.escape(bold) + "</b>";
              bold = "";
            }

            norm += ch;

            if (last === i) {
              result += MingleUI.fuzzy.escape(norm);
            }
          } else {
            if ("" !== norm) {
              result += MingleUI.fuzzy.escape(norm);
              norm = "";
            }

            bold += ch;

            if (last === i) {
              result += "<b>" + MingleUI.fuzzy.escape(bold) + "</b>";
            }
          }
        });

        return result;
      },

      finder: function defaultFinder(set, term) {
        var t = term.toLowerCase();

        function matches(item) {
          var stats = [], score = 0;
          if (!MingleUI.fuzzy.matcher(item.label.toLowerCase(), t, stats)) {
            return false;
          }

          score = MingleUI.fuzzy.score(stats, item.label, term);

          item.score = score;
          item.stats = stats;
          return true;
        }

        function clean(item) {
          delete item.score;
          delete item.stats;
        }

        if (term.trim() === "") {
          set.each(clean);
          return set;
        } else {
          return set.filter(matches).sort(scoreComparator);
        }
      },

      cardFinder: function cardFinder(set, term) {
        var t = term.toLowerCase();
        function matches(item) {
          var prefix = item.value + " ";
          var content = (prefix + item.label).toLowerCase();

          // highlight locations, also serve as scoring stats
          var stats = {number: [], name: []}, score = 0;

          if (!MingleUI.fuzzy.matcher(content, t, stats.number, stats.name, prefix.length)) {
            return false;
          }

          // matching card number is more specific
          score += 2 * MingleUI.fuzzy.score(stats.number, item.value.toString(), term);
          score += MingleUI.fuzzy.score(stats.name, item.label, term);

          item.score = score;
          item.stats = stats;
          return true;
        }

        return set.filter(matches).sort(scoreComparator);
      }
    };
  }
)(jQuery);