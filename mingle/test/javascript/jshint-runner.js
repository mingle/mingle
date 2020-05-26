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
var sys = require("system");
var args = sys.args;
var fs = require("fs");
var reportsDir = "test/reports";

if (typeof Function.prototype.bind !== "function") {
  Function.prototype.bind = function (thisArg) {
    var fn = this;
    return function () {
      return fn.apply(thisArg, arguments);
    };
  };
}

function exclude(path) {
  var excludes = [
    /(_packaged|swfobject)\.js$/,
    /(thirdparty|highcharts|ckeditor-[\d]|syntax_highlighter)/i
  ];

  for (var i = 0; i < excludes.length; i++) {
    if (excludes[i].test(path)) {
      return true;
    }
  }
  return false;
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
      } else if (fs.isFile(f) && /\.js$/.test(f) && !exclude(f)) {
        files.push(f);
      } else {
        // console.log("skipping: " + f);
      }
    }

  }

  return files;
}

var JSHINT = require("./jshint.js").JSHINT;
(function(p) {
  var fail = false;

  var scripts = globFiles("app/assets/javascripts");
  scripts.push.apply(scripts, globFiles("public/javascripts"));

  var options = {
    "eqeqeq": false,
    "eqnull": true,
    "-W041": false,
    "sub": true,
    "evil": true,
    "scripturl": true,
    "expr": true,
    "curly": false
  };

  var errorLines = [];
  scripts.forEach(function(f) {
    if (!fs.isReadable(f)) {
      console.log("Unreadable file: " + f);
    } else {
      JSHINT(fs.read(f), options);
      if (JSHINT.errors.length > 0) {
        fail = true;
        JSHINT.errors.forEach(function(err) {
          var errorLine = f + ":" + err.line + ' [' + err.character + '] ' + err.reason
          console.log(errorLine);
          errorLines.push(errorLine);
        });
      }
    }
  });

  var message = "\nJSHint checks passed\n";
  var returnCode = 0;
  if(fail){
    message = "\nJSHint checks failed\n";
    returnCode = 1;
    fs.write('./jshint.errors', message + errorLines.join('\n'), 'w');
  } else {
    if (fs.exists('./jshint.errors')) {
      fs.remove('./jshint.errors');
    }
  }
  console.log(message);
  phantom.exit(returnCode);
})(phantom);
