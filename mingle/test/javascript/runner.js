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
(function(phantom) {

  var sys = require("system");
  var env = sys.env;

  var fs = require("fs");
  var reportsDir = "test/reports";

  // variables shared among functions to be initialized before running tests
  var suites, totalTests, done, jsErrorLog, jsErrorCount, fail, stats, timing;

  var Config = {
    poolsize: (env["PHANTOMJS_POOL"] && parseInt(env["PHANTOMJS_POOL"], 10)) || 8,
    debug: "true" === env["DEBUG"]
  };

  if (typeof Function.prototype.bind !== "function") {
    Function.prototype.bind = function (thisArg) {
      var fn = this;
      return function () {
        return fn.apply(thisArg, arguments);
      };
    };
  }

  if ("undefined" === typeof window.performance) {
    // cheap polyfill for pre 2.x phantomjs
    window.performance = { now: Date.now };
  }

  function globFiles(path) {
    path = path.replace(/[\\\/]$/, "");
    var root = fs.list(path);
    var files = [], len = root.length;

    for (var i = 0; i < len; i++) {
      var rel = root[i];

      if ("." !== rel && ".." !== rel) {
        var f = path + fs.separator + rel;
        if (fs.isDirectory(f)) {
          files.push.apply(files, globFiles(f));
        } else if (fs.isFile(f) && /\.html$/i.test(f)) {
          files.push(f);
        } else {
          console.log("skipping: " + f);
        }
      }

    }

    return files;
  }

  function testName(url) {
    return /([^\/]+)\.html$/.exec(url)[1];
  }

  function report(label, urls) {
    if (urls.length > 0) {
      var tests = [];
      urls.forEach(function(u) {
        tests.push(testName(u));
      });
      console.log(label + ":\n  " + tests.join("\n  ") + "\n");
    }
  }

  function capture(page, name) {
    page.render(reportsDir + fs.separator + name + ".png");
  }

  function onTestComplete(data) {
    var page = this;
    var name = testName(page.url);
    markTime(name);

    var passed = false, key;

    if (data && data.result) {
      if ("QUnit.done" === data.name) {
        passed = data.result.total === data.result.passed;
        key = passed ? "success" : "failure";
      } else {
        key = data.result.toLowerCase();
        passed = "success" === key;
      }
      stats[key].push(page.url);

      if (!passed) {
        fail = true;
        console.log(key + ": " + name);
        capture(page, name);
      } else {
        if (Config.debug) {
          console.log(key + ": " + name);
        }
      }
    } else {
      // no result?
      fail = true;
      stats['error'].push(page.url);
      capture(page, name);
    }

    if (Config.debug && jsErrorLog[name]) {
      console.log("JS Errors for " + name + ":\n" + jsErrorLog[name].join("\n"));
    }

    done.push(page.url);

    var u = suites.pop();

    if (u) {
      page.open(u, onOpen);
    } else {
      // shut down runner, no more to consume
      page.close();

      // finished last test?
      if (done.length === totalTests) {
        timing.total = performance.now() - timing.total;

        console.log("\n\n-----\npassed: " + stats.success.length + ", failures: " + stats.failure.length+ ", errors: " + stats.error.length + "\n");
        report("Failures", stats.failure);
        report("Errors", stats.error);

        if ((stats.failure.length + stats.error.length) > 0) {
          console.log("Screenshots of failed tests captured in: " + reportsDir + "\n");
        }

        if (jsErrorCount > 0) {
          console.log("Recorded " + jsErrorCount + " JS errors during test run. To see these, set the env variable DEBUG=true\n");
        }

        if (Config.debug) {
          // rank tests slowest to fastest
          var profiles = Object.keys(timing.tests).sort(function(a, b) {
            return timing.tests[b] - timing.tests[a];
          });

          console.log("Test durations (slowest to fastest):");
          console.log("\n");
          for (var i = 0, len = profiles.length; i < len; i++) {
            var t = profiles[i];
            console.log(t + " took " + formatDuration(timing.tests[t]) + " sec");
          }
        }

        console.log("\n");
        console.log("Tests finished in " + formatDuration(timing.total) + " seconds");

        phantom.exit((stats.failure.length + stats.error.length) > 0 ? 1 : 0);
      }
    }
  }

  function onOpen(status) {
    fail = fail || status !== "success";
    var name = testName(this.url);
    markTime(name);
    console.log("running: " + name);
  }

  function onPageError(msg, trace) {
    var page = this;
    var name = testName(page.url);

    if (!jsErrorLog[name]) {
      jsErrorLog[name] = [];
    }

    var formatted = "  " + msg + ":\n    ";

    var stack = [];
    if (trace && trace.length) {
      trace.forEach(function(t) {
        stack.push(' -> ' + t.file + ': ' + t.line + (t["function"] ? ' (in function "' + t["function"] +'")' : ''));
      });
    }

    formatted += stack.join("\n    ");
    jsErrorLog[name].push(formatted);
    jsErrorCount++;
  }

  function beforeAll() {
    done = [], jsErrorLog = {}, jsErrorCount = 0, fail = false;
    timing = {total: performance.now(), tests: {}}, stats = {
      success: [],
      failure: [],
      error: []
    };
  }

  function markTime(test) {
    if (timing.tests.hasOwnProperty(test)) {
      // mark test start
      timing.tests[test] = performance.now() - timing.tests[test];
    } else {
      // mark test end
      timing.tests[test] = performance.now();
    }
  }

  function formatDuration(hiResTime) {
    return (hiResTime / 1000.0).toFixed(3);
  }

  function main(args) {
    beforeAll();

    var webpage = require("webpage");
    fs.isDirectory(reportsDir) || fs.makeTree(reportsDir); // ensure reports dir is present

    var target = args[1] ? args[1] : "test/javascript", runners = [];

    if (fs.isDirectory(target)) {
      suites = globFiles(target);
      console.log("gathering *.html tests in " + target);
    } else {
      suites = [target];
      console.log("running " + target);
    }

    totalTests = suites.length;
    console.log("found " + totalTests + " tests");

    console.log("Running tests with " + Config.poolsize + " runners...");
    for (var i = 0; i < Config.poolsize; i++) {
      var page = webpage.create();
      runners.push(page);

      // some tests will not pass with a small viewport
      page.viewportSize = {
        width: 1280,
        height: 960
      };

      if(Config.debug) {
        page.onConsoleMessage = function (msg, lineNum, sourceId) {
          console.log('CONSOLE: ' + msg + ' (from line #' + lineNum + ' in "' + sourceId + '")');
        }
      }

      page.onCallback = onTestComplete.bind(page);
      page.onError = onPageError.bind(page);

      var u = suites.pop();

      if (u) {
        page.open(u, onOpen);
      }
    }
  }

  main(sys.args);

})(phantom);
