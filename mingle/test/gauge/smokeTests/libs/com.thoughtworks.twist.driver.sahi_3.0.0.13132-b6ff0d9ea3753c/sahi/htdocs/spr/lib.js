/**
 * Copyright  2006  V Narayan Raman
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
Sahi.prototype.getSahiScriptStackTrace = function(isBreadCrumb){
//	this.print("getSahiScriptStackTrace called " + (new Date()));
	try{
		var ss=null;
		ss.toString();
	}catch(edd){
		try {
			var s = "";
		var stackTrace = edd.rhinoException.getScriptStackTrace();
		var lines = stackTrace.split("\n");
		for (var i=0; i<lines.length; i++){
				var line = "" + lines[i];
			if (line.indexOf("(") != -1){
					var usefulPart = line.replace(/\r/g, '').replace("at RhinoScriptRunner.run:", "");
					var fnName = usefulPart.replace(/^.*[(]/, "").replace(/[)][ ]*$/, "");
					if (isBreadCrumb) {
						s = " >> " + fnName + s;
					} else {
						var lineNo = parseInt(usefulPart.substring(0, usefulPart.indexOf(" ")));
						if (""+lineNo != "NaN") s += "at " + fnName + " (" + ScriptRunner.getScript().getLineDebugInfo(lineNo-1).replace("&n=", ":") + ")\n" ;
					}
			}
		}
		} catch(e) {
			s = "Some error occured: " + e.message;
		}
	}
	return s;
}
// stub start
var __SAHI_NOT_SET__ = "__SAHI_NOT_SET__"
function Stub(s, count){
	this.s = s;
	this.toString = function() {return this.s;};
}
function stubBinder(nodeName){
	return function () {return new Stub(this.s + "." + nodeName);};
}
function indexBinder(index){
	return function () { return new Stub(this.s + "[" + index + "]"); };
}
function xfunctionBinder(nodeName){
	return function () {return this.getNodesArrayFn(nodeName);};
}
var stubGetters = ['ATTRIBUTE_NODE', 'CDATA_SECTION_NODE', 'COMMENT_NODE', 'Components', 'DOCUMENT_FRAGMENT_NODE', 
                   'DOCUMENT_NODE', 'DOCUMENT_POSITION_CONTAINED_BY', 'DOCUMENT_POSITION_CONTAINS', 'DOCUMENT_POSITION_DISCONNECTED', 'DOCUMENT_POSITION_FOLLOWING', 
                   'DOCUMENT_POSITION_IMPLEMENTATION_SPECIFIC', 'DOCUMENT_POSITION_PRECEDING', 'DOCUMENT_TYPE_NODE', 'ELEMENT_NODE', 'ENTITY_NODE', 
                   'ENTITY_REFERENCE_NODE', 'NOTATION_NODE', 'PROCESSING_INSTRUCTION_NODE', 'TEXT_NODE', 'URL', 'accept', 
                   'acceptCharset', 'accessKey', 'action', 'activeElement', 'align', 
                   'alinkColor', 'alt', 'anchors', 'applets', 'applicationCache', 
                   'attributes', 'baseURI', 'bgColor', 'body', 'boxObject', 
                   'characterSet', 'charset', 'checked', 'childNodes', 'className', 
                   'clientHeight', 'clientLeft', 'clientTop', 'clientWidth', 'closed', 
                   'cols', 'compatMode', 'console', 'content', 'contentEditable', 
                   'contentType', 'controllers', 'cookie', 'coords', 'crypto', 
                   'defaultChecked', 'defaultStatus', 'defaultValue', 'defaultView', 'designMode', 
                   'dir', 'directories', 'disabled', 'doctype', 'document', 
                   'documentElement', 'documentURI', 'domain', 'elements', 'embeds', 
                   'encoding', 'enctype', 'fgColor', 'files', 'firstChild', 
                   'form', 'forms', 'frameElement', 'frames', 'fullScreen', 
                   'globalStorage', 'hash', 'height', 'history', 'host', 
                   'hostname', 'href', 'hreflang', 'id', 'images', 
                   'implementation', 'innerHTML', 'innerHeight', 'innerWidth', 'inputEncoding', 
                   'lang', 'lastChild', 'lastModified', 'lastStyleSheetSet', 'length', 
                   'length', 'length', 'linkColor', 'links', 'localName', 
                   'location', 'locationbar', 'maxLength', 'menubar', 'method', 
                   'multiple', 'name', 'namespaceURI', 'navigator', 'netscape', 
                   'nextSibling', 'nodeName', 'nodeType', 'nodeValue', 'offsetHeight', 
                   'offsetLeft', 'offsetParent', 'offsetTop', 'offsetWidth', 'opener', 
                   'options', 'outerHeight', 'outerWidth', 'ownerDocument', 'pageXOffset', 
                   'pageYOffset', 'parent', 'parentNode', 'pathname', 'personalbar', 
                   'ping', 'pkcs11', 'plugins', 'port', 'preferredStyleSheetSet', 
                   'prefix', 'previousSibling', 'protocol', 'readOnly', 'readyState', 
                   'referrer', 'rel', 'rev', 'rows', 'cells', 'screen', 
                   'screenX', 'screenY', 'scrollHeight', 'scrollLeft', 'scrollMaxX', 
                   'scrollMaxY', 'scrollTop', 'scrollWidth', 'scrollX', 'scrollY', 
                   'scrollbars', 'search', 'selectedIndex', 'selectedStyleSheetSet', 'selectionEnd', 
                   'selectionStart', 'self', 'sessionStorage', 'shape', 'size', 
                   'spellcheck', 'src', 'status', 'statusbar', 'strictErrorChecking', 
                   'style', 'styleSheetSets', 'styleSheets', 'tabIndex', 'tagName', 
                   'target', 'text', 'textContent', 'textLength', 'title', 
                   'toolbar', 'top', 'type', 'useMap', 'value', 
                   'vlinkColor', 'width', 'window', 'xmlEncoding', 'xmlStandalone', 
                   'xmlVersion'];

for (var i = 0; i < stubGetters.length; i++) {
	nodeName = stubGetters[i];
	Stub.prototype.__defineGetter__(nodeName, stubBinder(nodeName));
}                  
for (var i=0; i<100; i++){
	Stub.prototype.__defineGetter__(""+i, indexBinder(i));
}
Stub.prototype.getClass = function(){
	return {getName: function(){return "Stub";}};
};
Stub.prototype.getNodesArrayFn = function(fnName){
	return function(){
		var s = "";
		for (var i=0; i<arguments.length; i++){
			s += s_v(arguments[i]);
			if (i != arguments.length-1) s += ", ";
		}		
		return new Stub(this.s + "." + fnName + "(" + s + ")");
	};
};
Stub.prototype.__noSuchMethod__ = function(fnName, args){
	var s = "";
	for (var i=0; i<args.length; i++){
		s += s_v(args[i]);
		if (i != args.length-1) s += ", ";
	}
	return new Stub(this.s + "." + fnName + "(" + s + ")");		
};
// stub end
function s_v(v) {
	return _sahi.toJSON(v);
};
SahiHashMap = function(){
	this.keys = new Array();
	this.values = new Array();
	this.put = function(k, v){
		var i = this.getIndex(this.keys, k);
		if (i == -1) i = this.keys.length;
		this.keys[i] = k;
		this.values[i] = v;
	}
	this.get = function(k){
		var i = this.getIndex(this.keys, k);
		return this.values[i];
	}
	this.getIndex = function(ar, k){
		for (var i=0; i<ar.length; i++){
			if (k == ar[i]) return i;
		}		
		return -1;
	}
}
function Sahi(){
	this.stepInterval = ScriptRunner.getTimeBetweenSteps();
	this.maxCycles = ScriptRunner.getMaxCyclesForPageLoad() + 300; // 30 seconds more than page load timeout to account for errors.
	this.maxTimeout = this.stepInterval * this.maxCycles;
	this.countSuffix = 0;
	this.stopOnError = true;
	this.includedFiles = {};
};
Sahi.prototype.toJSON = function(el, map){
	if (!map) map = new SahiHashMap();
	var j = map.get(el);
	if (j) return j; 
	map.put(el, '"recursive_access"');
	var v = this.toJSON2(el, map);
	map.put(el, v);
	return v;
}
Sahi.prototype.toJSON2 = function(el, map){
    if (el == null || el == undefined) return 'null';
    
	try{
		if (el.getClass().getName().indexOf("String")!=-1){
			el = "" + el.toString();
		}
	}catch(e){}    
    
    if (el instanceof Stub) return el.toString();
    if (el instanceof RegExp) return el.toString();
    if (el instanceof Date){
        return String(el);
    }else if (typeof el == 'string'){
        if (/["\\\x00-\x1f]/.test(el)) {
            return '"' + el.replace(/([\x00-\x1f\\"])/g, function (a, b) {
                var c = _sahi.escapeMap[b];
                if (c) {
                    return c;
                }
                c = b.charCodeAt();
                return '\\u00' +
                    Math.floor(c / 16).toString(16) +
                    (c % 16).toString(16);
            }) + '"';
        }
        return '"' + el + '"';
    }else if (el instanceof Array){
        var ar = [];
        for (var i=0; i<el.length; i++){
            ar[i] = this.toJSON(el[i], map);
        }
        return '[' + ar.join(',') + ']';
    }else if (typeof el == 'number'){
        return new String(el);
    }else if (typeof el == 'boolean'){
        return String(el);
    }else if (el instanceof Object){
        var ar = [];
        for (var k in el){
            var v = el[k];
            if (typeof v != 'function'){
                ar[ar.length] = this.toJSON(k, map) + ':' + this.toJSON(v, map);
            }
        }
        return '{' + ar.join(',') + '}';
    }
};
Sahi.prototype.convertUnicode = function (source) {
    if (source == null) return null;
    var result = '';
    for (var i = 0; i < source.length; i++) {
        if (source.charCodeAt(i) > 127)
            result += this.addSlashU(source.charCodeAt(i).toString(16));
        else result += source.charAt(i);
    }
    return result;
};
Sahi.prototype.addSlashU = function (num) {
    var buildU
    switch (num.length) {
        case 1:
            buildU = "\\u000" + num
            break
        case 2:
            buildU = "\\u00" + num
            break
        case 3:
            buildU = "\\u0" + num
            break
        case 4:
            buildU = "\\u" + num
            break
    }
    return buildU;
};
Sahi.prototype.escapeMap = {
        '\b': '\\b',
        '\t': '\\t',
        '\n': '\\n',
        '\f': '\\f',
        '\r': '\\r',
        '"' : '\\"',
        '\\': '\\\\'
};
Sahi.prototype.print = function (s){
    java.lang.System.out.println("Rhino lib:" + s);
}
Sahi.prototype.wait = function (n){
    java.lang.Thread.sleep(n);
}

Sahi.prototype.__noSuchMethod__ = function(fnName, args){
	var s = "";
	for (var i=0; i<args.length; i++){
		s += s_v(args[i]);
		if (i != args.length-1) s += ", ";
	}
	return new Stub("_sahi." + fnName + "(" + s + ")");		
};

Sahi.prototype.justStarted = false;
Sahi.prototype.lastId = null;

Sahi.prototype.retry = function(cmd, debugInfo, interval){
    this.wait(interval);
    //this.print('retrying');
    this.schedule(cmd, debugInfo);
};
Sahi.prototype.setStep = function(cmd, debugInfo, stepType){
    //this.print(cmd);
    return ScriptRunner.setStep(cmd, debugInfo, stepType);
};
Sahi.prototype.executeWait = function(cmd, debugInfo){
    var cycles = eval(cmd) / this.stepInterval;
    this.schedule2(cmd, debugInfo, cycles, "WAIT");	
}
Sahi.prototype.schedule = function(cmd, debugInfo){
    var cycles = this.maxCycles;
    if (this.windowContext && cmd.indexOf("_sahi._popup") != 0) { 
    	cmd = "_sahi._popup(" + this.quoted(this.windowContext) + ")." + cmd;
    }
    if (this.domainContext && cmd.indexOf("_sahi._domain") != 0) { 
    	cmd = "_sahi._domain(" + this.quoted(this.domainContext) + ")." + cmd;
    }
    this.schedule2(cmd, debugInfo, cycles, "NORMAL", true);
}
Sahi.prototype._wait = function(t, condn){
    return t;
}
Sahi.prototype.quoted = function (s) {
    return '"' + s.replace(/"/g, '\\"') + '"';
};
Sahi.prototype._condition = function(c, debugInfo){
	var key = "__lastConditionValue__" + (this.countSuffix++);
	ScriptRunner.setVariable(key, __SAHI_NOT_SET__);
	this.schedule("_sahi.saveCondition(\"" + key + "\", " + c + ")", debugInfo);
	var i = 0;
	while(i++ < 5){
		this.wait(100);
		var res = this.getServerVar(key);
		if (res != __SAHI_NOT_SET__) {
			break;
		}
	}
	return res == "true";
}
Sahi.prototype.schedule2 = function(cmd, debugInfo, cycles, stepType, throwException){
    if (cmd == 'done') return;
    ScriptRunner.setStackTrace("");
    this.lastId = this.setStep(cmd, debugInfo, stepType);
    //this.print(cmd);
    var i=0;
    while(i++ < cycles){
        if (ScriptRunner.doneStep(this.lastId) || ScriptRunner.isStopped()){
        	var status = ScriptRunner.getStatus().getName();
        	if (status == "ERROR") {
//        		if (!this.stopOnError) ScriptRunner.log(this.getSahiScriptStackTrace(), "", "ERROR");
        		this.callOnScriptError(ScriptRunner.getBrowserException());
        	} else if (status == "FAILURE"){
//        		ScriptRunner.log(this.getSahiScriptStackTrace(), "", "FAILURE");
        		this.callOnScriptFailure(ScriptRunner.getBrowserException());
        	}
        	if (status == "ERROR" && this.stopOnError) {
		    	var exceptionMsg = ScriptRunner.getBrowserException();
		    	throw new SahiException(exceptionMsg, debugInfo);
        	}
            if (ScriptRunner.isStopped()) {
            	throw new SahiException("Stopped from UI", debugInfo);
            }
            return;
        }else{
        	if (ScriptRunner.needsStackTrace()) {
        		ScriptRunner.setStackTrace(this.getSahiScriptStackTrace());
        	}
            this.wait(this.stepInterval);
        }
    }
    if (throwException){
	    var msg = "Step >" + cmd + "< did not complete in "+(this.maxTimeout/1000)+" seconds.";
	    this.print(msg);
	    throw new SahiException(msg, debugInfo);
    }else{
    	ScriptRunner.markStepDoneFromLib(""+this.lastId, "info", null);
    }
};
Sahi.prototype.start = function(){
    var i=0;
    var cycles = this.maxCycles;
    while(i++ < cycles){
        if (!ScriptRunner.isRunning()) {
            this.wait(this.stepInterval);
        }else{
            this.justStarted = true;
            return;
        }
    }
    if (ScriptRunner.isPartOfSuite()) {
    throw new SahiException('Script did not start within ' + (this.maxTimeout/1000) + ' seconds.');
    }
};
Sahi.prototype._execute = function (cmd, isSync, timeout) {
	if (isSync == null) isSync = false;
	if (timeout == null) timeout = 5*60*1000;
	return net.sf.sahi.util.Utils.executeCommand(cmd, isSync, timeout);
}
Sahi.prototype._dynamicInclude = function ($fileName) {
	var thisPath = this._scriptPath().replace(/\\/g, "/");
	var filePath = "" + net.sf.sahi.util.Utils.concatPaths(thisPath, $fileName);
	if (this.includedFiles[filePath]) return;
	this.includedFiles[filePath] = true;
	var includedScript = (new net.sf.sahi.playback.ScriptFactory()).getScript(filePath);
	var script = ScriptRunner.getScript();
	var includedJS = "" + includedScript.jsString();
	script.addIncludeInfo(includedScript);
	with (this.global){eval(includedJS)};
}
Sahi.prototype._setRecovery = function (recoveryScript, forceAtEnd){
	ScriptRunner.setRecoveryScript("("+recoveryScript+")();");
}
Sahi.prototype._removeRecovery = function (){
	ScriptRunner.setRecoveryScript(null);
}
Sahi.prototype._readFile = function (filePath) {
	filePath = this._resolvePath(filePath);
    return "" + Packages.net.sf.sahi.util.Utils.readFileAsString(filePath);
};
Sahi.prototype._readURL = function (url) {
    return "" + Packages.net.sf.sahi.util.Utils.getString(net.sf.sahi.util.Utils.readURL(url)); 
};
Sahi.prototype._writeFile = function (str, filePath, overwrite) {
	filePath = this._resolvePath(filePath);
	overwrite = (overwrite == true);
    return "" + Packages.net.sf.sahi.util.Utils.writeFile(str, filePath, overwrite);
};
Sahi.prototype._writeToFile = Sahi.prototype._writeFile;
Sahi.prototype._deleteFile = function (filePath) {
	return "" + Packages.net.sf.sahi.util.Utils.deleteFile(filePath) == "true";
};
Sahi.prototype._renameFile = function (oldPath, newPath) {
	return "" + Packages.net.sf.sahi.util.FileUtils.renameFile(oldPath, newPath) == "true";
};
Sahi.prototype._scriptStatus = function(){
	return ScriptRunner.hasErrors() ? "FAILURE" : "SUCCESS";
}
Sahi.prototype._stopOnError = function(){
	this.stopOnError = true;
    ScriptRunner.setStopOnError(true);
};
Sahi.prototype._continueOnError = function(){
	this.stopOnError = false;
    ScriptRunner.setStopOnError(false);
};
Sahi.prototype._setSpeed = function(ms){
	net.sf.sahi.config.Configuration.setTimeBetweenSteps(ms);
}
Sahi.prototype.makeAssociative = function(array2d){
	array2d.set = function(rowHeader, colHeader, newValue){
        var r = null;
        if ((typeof rowHeader) == "number"){
        	if (rowHeader < 0 || rowHeader >= this.length)
        		return null;
        	r = this[rowHeader];
        }
        else{
            for(var i=0; i<this.length; i++){
            	if (rowHeader == this[i][0]){
                    r = this[i];
                }
            }
        }
        if (!r) {return null};
        if (!r[colHeader]) {return null};
        for (var i=0; i<r.length ;i++){
        	var colIndex = 0;
        	var isAssociativeIndex = true;
			for (var j in this[i]){
				if (j != colIndex && isAssociativeIndex){
					isAssociativeIndex = false;
					colIndex=0;
				}
				if ((typeof colHeader) == "number"){	
					if (r[colHeader] == r[colIndex]){
						r[colHeader] = newValue;
						r[j] = newValue;
					}
				}
				else{ 
					if (r[colHeader] == r[colIndex] && j == colHeader){
						r[colHeader] = newValue;
						r[colIndex] = newValue;
					}
				}
				colIndex++;
			}
		}           
    }
	array2d.get = function(rowHeader, colHeader){
        var r = null;
        if ((typeof rowHeader) == "number"){
            r = this[rowHeader];			
        }else{
            for (var i=0; i<this.length; i++){
                if (rowHeader == this[i][0]){
                    r = this[i];
                }
            }
        }
        if (!r) {return null};
        if ((typeof colHeader) == "number"){
            return r[colHeader];
        }else{
			if (r[colHeader]) return r[colHeader];
			for (var j=0; j<r.length; j++){
				   if (colHeader == this[0][j]){
					return r[j];
				}
			}
        }       
    }
    array2d.sortAscendingBy = function(colHeader, includeHeader){
    	return this.sortBy(colHeader, false, includeHeader);
    }
    array2d.sortDescendingBy = function(colHeader){
    	return this.sortBy(colHeader, true, includeHeader);
    }    
    array2d.sortBy = function(colHeader, isDescending, includeHeader){
        var header = new Array();
        if (!includeHeader) 
            header = this.slice(0, 1);        
        var toSort = includeHeader ? this.slice(0) : this.slice(1);
        var colIndex = null;
        if ((typeof colHeader) == "number"){
            colIndex = colHeader;
        }else{
            for (var j=0; j<this[0].length; j++){
                   if (colHeader == this[0][j]){
                    colIndex = j;
                    break;
                }
            }            
        } 
        toSort.sort(function(a, b){
            if (a[colIndex] == b[colIndex]) return 0;
			if (isDescending) return b[colIndex] < a[colIndex] ? -1 : 1;
			else return a[colIndex] < b[colIndex] ? -1 : 1;
        });
        return makeAssociative(header.concat(toSort));
    }
    return array2d;
};
Sahi.prototype.associativeArray = function(array2d, includeHeader){
	var header = array2d.slice(0,1)[0];
	if(!includeHeader) array2d.splice(0,1);
	for(var i = 0; i < array2d.length; i++){
		for(var j=0; j < header.length; j++){
			array2d[i][header[j]] = array2d[i][j];
		}
	}
	return this.makeAssociative(array2d);
};
Sahi.prototype._getDB = function (driver, jdbcurl, username, password) {
    return new Sahi.dB(driver, jdbcurl, username, password);
};
Sahi.dB = function (driver, jdbcurl, username, password) {
    this.driver = driver;
    this.jdbcurl = jdbcurl;
    this.username = username;
    this.password = password;
    this.select = function (sql, includeHeader) {
        var dbclient = new Packages.net.sf.sahi.plugin.DBClient();
        var json = dbclient.select(this.driver, this.jdbcurl, this.username, this.password, sql);
        if (json.indexOf("exception") == 0) {
        	throw new SahiException(json);
        }
        try{
	        var $evaled = eval('('+ json +')')['result'];
	        return _sahi.associativeArray($evaled, includeHeader);
        }catch(e){
        	throw new SahiException(json);
        }
    };
    this.selectWithoutHeader = this.select;
    this.selectWithHeader = function (sql) {
        return this.select(sql, true);
    };
    this.update = function (sql) {
        var dbclient = new Packages.net.sf.sahi.plugin.DBClient();
        dbclient.execute(this.driver, this.jdbcurl, this.username, this.password, sql);
    };
};
Sahi.prototype.end = function(){
	ScriptRunner.stop();
    //this.print('script ended.');
};
Sahi.prototype._getGlobal = function(key){
	var suite = ScriptRunner.getSession().getSuite();
	var val = (suite == null) ? ScriptRunner.getSession().getVariable(key) : suite.getVariable(key);
	return eval('('+val+')');
}
Sahi.prototype.getServerVar = function(key){
    var val = ScriptRunner.getVariable(key);
    //this.print(val);
    return eval('('+val+')');
};
Sahi.prototype._random = function (n) {
    return Math.floor(Math.random() * (n + 1));
};
Sahi.prototype._scriptName = function(){
    return ""+ScriptRunner.getScriptName();
};
Sahi.prototype._logException = function(e){
	this.logExceptionCommon(e, false);
};
Sahi.prototype._logExceptionAsFailure = function(e){
	this.logExceptionCommon(e, true);
};
Sahi.prototype.logExceptionCommon = function(e, fail){
    if (e instanceof SahiException)
          ScriptRunner.logException(e.message, e.debugInfo, fail);
    else {
		var msg = e.message ? e.message : e;
    	if (e.lineNumber != null && ("" + parseInt(e.lineNumber)) != "NaN"){
    		ScriptRunner.logExceptionWithLineNumber(e.message, e.lineNumber-1, fail);
    	}else {
    		ScriptRunner.logException(msg, null, fail);
    	}
    }
};
_sahi = new Sahi();

var document = new Stub("document");
var window = new Stub("window");

SahiException = function(message, debugInfo){
	this.message = message;
	this.debugInfo = debugInfo;
	this.toString = function(){return this.message;};
};
Sahi.prototype._scriptPath = function(){
    return "" + ScriptRunner.getScript().getFilePath();
};
Sahi.prototype._sessionInfo = function(){
    var info = eval("(" + ScriptRunner.getSession().getInfoJSON() + ")");
    info.threadNumber = ScriptRunner.getThreadNo();
    info.scriptPath = this._scriptPath();
    return info;
};
Sahi.prototype._suiteInfo = function(){
	var suite = ScriptRunner.getSession().getSuite();
	if (suite == null) return null;
    var info = eval("(" + suite.getInfoJSON() + ")");
    return info;
};
Sahi.prototype._readCSVFile = function(filePath, wordSeparator){
	if (!wordSeparator) wordSeparator = ",";
	filePath = this._resolvePath(filePath);
    var contents = this._readFile(filePath);
    var lines = contents.replace(/\r\n/g, '\n').replace(/\r/g, '\n').split("\n");
    var data = []; // new Array();
    for (var i=0; i<lines.length; i++){
    	if (lines[i].replace(/^\s*|\s*$/g, '') == "") continue;
        var words = this.splitUnQuoted(lines[i], wordSeparator); //lines[i].split(",");
        for (var j=0; j<words.length; j++){
        	var w = words[j];
        	w = w.replace(/^\s*|\s*$/g, '');
        	if (w.match(/^".*"$/)){
        		words[j] = eval(w); 
        	}
        }
        data[data.length] = words;
    }
    return data;
};
Sahi.prototype.splitUnQuoted = function(s, wordSeparator){
	var words = [];
	var prev = ' ';
	var startIx = 0;
	var quoted = false;
	for (var i=0; i<s.length; i++){
		var c = s.charAt(i);
		if (c == '"' && prev != '\\'){
			quoted = !quoted;
		} else if (c == wordSeparator){
			if (!quoted) {
				words[words.length] = s.substring(startIx, i);
				startIx = i + 1;
			}
		}
		prev = c;
	}
	if (startIx <= s.length) words[words.length] = s.substring(startIx);
	return words;
}
Sahi.prototype._resolvePath = function(path){
	var thisPath = this._scriptPath().replace(/\\/g, "/");
	return "" + net.sf.sahi.util.Utils.concatPaths(thisPath, path);
}
Sahi.CSV_NEWLINE = "\r\n";
Sahi.prototype._writeCSVFile = function(array2d, filePath, overwrite, separator) {
	filePath = this._resolvePath(filePath);
	if (!separator) separator = ",";
	var s = [];
	for (var i=0; i < array2d.length; i++) {
		var row = array2d[i];
		for (var j=0; j < row.length; j++) {
			cell = row[j] ? "" + row[j] : "";
			s[s.length] = s_v(cell);
			if (j != row.length - 1) s[s.length] = separator;
		}
		if (i < array2d.length - 1)
			s[s.length] = Sahi.CSV_NEWLINE;
	}
	var str = s.join("");
	if(!overwrite) {
		str += "\n";
	}
	this._writeFile(str, filePath, overwrite);
};
Sahi.prototype._userDataDir = function(){
	return "" + net.sf.sahi.config.Configuration.getUserDataDir();
}
Sahi.prototype._userDataPath = function(relPath){
	return "" +  net.sf.sahi.config.Configuration.getAbsoluteUserPath(relPath);
}
Sahi.prototype._collect = function (apiType, id, inEl) {
	var count = this._count.apply(this, arguments);
	var els = [];
	for (var j=0; j<count; j++){
		var s = '"' + id + "[" + j + "]\"";
		for (var i=2; i<arguments.length; i++){
			s += ", ";
			s += s_v(arguments[i]);
		}
		els.push(new Stub("_sahi." + apiType + "(" + s + ")"));		
	}
	return els;
}
/* Unit test style start */
_sahi.global = this; 

Sahi.prototype.showFunctions = function(){
	var done = [];
	for(var [$n, $v] in Iterator(_sahi.global)){
		if (typeof $v == 'function' && $n.indexOf("Sahi") == -1 && $n != "s_v" && $n != "Stub" && $n != "stubBinder" && $n != "indexBinder") {
			_sahi.global[$n] = this.getWrapped($n, $v);
		}
	}	
}

Sahi.prototype.getWrapped = function($n, $v){
	return function () {
		//_log("Enter " + $n, "custom2");
		$v(arguments);
		//_log("Exit " + $n, "custom2");
	}
}

Sahi.prototype._runUnitTests = function(testAr){
	if (!testAr){
		testAr = [];
		for(var [$n, v] in Iterator(_sahi.global)){
			if (typeof v == 'function' && $n.indexOf("test") == 0) {
				testAr[testAr.length] = $n;
			}
		}
	}
	for(var i=0; i<testAr.length; i++){
		var fnName = testAr[i];
		var $status = "success";
		if (typeof setUp != "undefined") setUp();
		try {
			ScriptRunner.log("---- TEST START: " + fnName + " ----", "", "CUSTOM2");
			eval(testAr[i])();
		} catch (e) {
			$status = "failure";
			this._logExceptionAsFailure(e);
		}
		finally {
			ScriptRunner.log("---- TEST FINISH: " + fnName + " ----", "", "CUSTOM2");
			if (typeof tearDown != "undefined") tearDown();
		}
	}
}
Sahi.prototype._fail = function(message){
	throw "Fail" + (message ? (": " + message) : "");
}
Sahi.prototype._stackTrace = function(){
	return this.getSahiScriptStackTrace();
}
/* Unit test style end */ 
/* Data driven start */
Sahi.prototype._dataDrive = function(func, array2D, preFn, postFn){
	for (var i=0; i<array2D.length; i++){
		var args = array2D[i];
		if (preFn) preFn();
		try{
			func.apply(_sahi.global, args);
		}catch(e){
	        this._logExceptionAsFailure(e);
	    }
		finally {
			if (postFn) postFn();
		}
	}	
}
/* Data driven end */

/* RegExp toString Fix start */
if (new RegExp("/").toString() == "///"){
	RegExp.prototype.oldToString = RegExp.prototype.toString;
	RegExp.prototype.toString = function(){
		var s = this.oldToString();
		s = s.substring(1, s.length-1);
		if (s.indexOf("/") != -1 && s.indexOf("\\/") == -1){
			s = s.replace(/\//g, '\\/');
		}
		return "/" + s + "/";
	}
}
/* RegExp toString Fix end */

/* fetch APIs start */
Sahi.prototype._fetch = function(stub){
	var d = java.lang.System.currentTimeMillis();
	var key = "___lastValue___" + d.toString(); 
	this.schedule("_sahi.setServerVar('" +key+ "', " + stub + ");");
	return this.getServerVar(key);	
};
Sahi.prototype.makeFetchAPIs = function(){
	var apis = ["_getValue", "_getAttribute", "_containsText",
	            "_containsHTML", "_getText", "_getCellText", "_getSelectedText", 
	            "_lastAlert", "_lastPrompt", "_lastConfirm", "_style", "_cookie", 
	            "_position", "_rteHTML", "_rteText", "_isVisible", 
	            "_contains", "_title", "_exists", "_isIE", "_isIE9", "_isFF", "_isFF3", "_isFF4", "_isChrome", "_isSafari", "_isOpera",
	            "_lastDownloadedFileName", "_prompt", "_confirm", "_count"];
	for (var i=0; i<apis.length; i++){
		var api = apis[i];
		Sahi.prototype[api] = this.fetchFn(api);
	}
}
Sahi.prototype.fetchFn = function (name){
	return function(){
		var fnName = name;
		var s = "";
		for (var i=0; i<arguments.length; i++){
			s += s_v(arguments[i]);
			if (i != arguments.length-1) s += ", ";
		}			
		return this._fetch("_sahi." + fnName + "(" + s + ")");
	}
};
_sahi.makeFetchAPIs();
/* fetch APIs end */

/*selectWindow selectDomain start*/
Sahi.prototype._selectWindow = function(windowName){
	this.windowContext = windowName;
}
Sahi.prototype._selectDomain = function(domain){
	this.domainContext = domain
}
/*selectWindow selectDomain end*/

/* callbacks start */
Sahi.prototype.callOnScriptEnd = function (){
	try{
		if (typeof onScriptEnd == "function"){
			onScriptEnd();
		}
	} finally {
		this.end();
	}
};
Sahi.prototype.callOnScriptError = function (){
	try {
		if (typeof onScriptError == "function")
			onScriptError();
	}catch(e){
		this.print(e);
	}
};
Sahi.prototype.callOnScriptFailure = function (){
	try {
		if (typeof onScriptFailure == "function")
			onScriptFailure();
	}catch(e){
		this.print(e);
	}
};
/* callbacks end */
Sahi.prototype.getExtraInfo = function (){
	 return ScriptRunner.getSession().getSuite().getExtraInfo();
}
Sahi.prototype.getInitJS = function(){
	if(ScriptRunner.getSession() != null && ScriptRunner.getSession().getSuite() != null)
		return "" + ScriptRunner.getSession().getSuite().getInitJS();
}
//_sahi.print("initJS: " + _sahi.getInitJS());
if(_sahi.getInitJS() && _sahi.getInitJS() != "null"){
	eval(_sahi.getInitJS());	
}