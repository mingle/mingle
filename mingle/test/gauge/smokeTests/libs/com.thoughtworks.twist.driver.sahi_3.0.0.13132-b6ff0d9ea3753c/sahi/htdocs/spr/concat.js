/**
 * Sahi - Web Automation and Test Tool
 *
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

__sahiDebug__("concat.js: start");
var Sahi = function(){
    this.triggerType = "click";
    this.cmds = new Array();
    this.cmdDebugInfo = new Array();

    this.cmdsLocal = new Array();
    this.cmdDebugInfoLocal = new Array();

    this.promptReturnValue = new Array();

    this.locals = [];

    this.INTERVAL = 100;
    this.ONERROR_INTERVAL = 1000;
    this.MAX_RETRIES = 5;
    this.SAHI_MAX_WAIT_FOR_LOAD = 30;
    this.STABILITY_INDEX = 5;
    this.waitForLoad = this.SAHI_MAX_WAIT_FOR_LOAD;
    this.interval = this.INTERVAL;

    this.localIx = 0;
    this.buffer = "";

    this.controller = null;
    this.lastAccessedInfo = null;
    this.execSteps = null; // from SahiScript through script.js

    this.sahiBuffer = "";

    this.real_alert = window.alert;
    this.real_confirm = window.confirm;
    this.real_prompt = window.prompt;
    this.real_print = window.print;
    this.wrapped = new Array();
    this.mockDialogs(window);
    
    this.lastQs = "";
    this.lastTime = 0;
    
    this.XHRs = [];
    this.XHRTimes = [];
    this.escapeMap = {
        '\b': '\\b',
        '\t': '\\t',
        '\n': '\\n',
        '\f': '\\f',
        '\r': '\\r',
        '"' : '\\"',
        '\\': '\\\\'
    };
    this.lastStepId = 0;
    this.strictVisibilityCheck = false; 
    this.isSingleSession = false;
    this.ADs = [];
    this.controllerURL = "/_s_/spr/controller7.htm";
    this.controllerHeight = 550;
    this.controllerWidth = 460
    this.recorderClass = "Recorder";
    this.stabilityIndex = this.STABILITY_INDEX;
    this.xyoffsets = new Object();
    this.escapeUnicode = false;
    this.CHECK_REGEXP = /^\/.*\/i?$/;
    this.navigator = {"userAgent": navigator.userAgent, "appName": navigator.appName};
    this.textboxTypes = ["text", "number", "password", "textarea", "date", "datetime", "datetime-local", "email", "month", "number", "range", "search", "tel", "time", "url", "week" ];
};
Sahi.prototype.isBlankOrNull = function (s) {
    return (s == "" || s == null);
};
Sahi.BLUR_TIMEOUT = 5000;
Sahi.prototype.storeDiagnostics = function(){
	if (this.diagnostics) return;
    this.diagnostics = new Object();
    var d = this.diagnostics;
    d["UserAgent"] = navigator.userAgent;
    d["Browser Name"] = navigator.appName;
    d["Browser Version"] = navigator.appVersion.substring(0, navigator.appVersion.indexOf(")")+1);
    d["Native XMLHttpRequest"] = typeof XMLHttpRequest != "undefined";
    d["Java Enabled"] = navigator.javaEnabled();
    d["Cookie Enabled"] =  ("" + document.cookie).indexOf("sahisid") != -1 // navigator.cookieEnabled throws an exception on IE on showModalDialogs.
	this.addDiagnostics("OS");
	this.addDiagnostics("Java");
};
Sahi.prototype.addDiagnostics = function(type){
	var s = this.sendToServer("/_s_/dyn/ControllerUI_get"+type+"Info");		
    if(s){
    	var properties = s.split("_$sahi$_;");
    	for (var i=0; i<properties.length; i++){
    		var prop = properties[i].split("_$sahi$_:");
    		if(prop.length == 2) this.diagnostics[prop[0]] = prop[1];
    	}	
    }	 
};
Sahi.prototype.getDiagnostics = function(name){
	if (!this.diagnostics) this.storeDiagnostics();
    if(name){
     	var v = this.diagnostics[name];
     	return (v != null) ? v : "";
    }
    var s = "";
 	for (var key in this.diagnostics){
    	s += key +": "+ this.diagnostics[key]+"\n";
 	}
    return s;
};
Sahi.prototype.wrap = function (fn) {
	var el = this;
	if (this.wrapped[fn] == null) {
		this.wrapped[fn] = function(){return fn.apply(el, arguments);};
	}
	return this.wrapped[fn];
};
Sahi.prototype.alertMock = function (s) {
    if (this.isPlaying()) {
        this.setServerVar("lastAlertText", s);
        return null;
    } else {
        return this._alert(s);
    }
};
Sahi.prototype.confirmMock = function (s) {
    if (this.isPlaying()) {
        var retVal = eval(this.getServerVar("confirm: "+s));
        if (retVal == null) retVal = true;
        this.setServerVar("lastConfirmText", s);
        this.setServerVar("confirm: "+s, null);
        return retVal;
    } else {
        var retVal = this.callFunction(this.real_confirm, window, s);
        if (this.isRecording()){
        	this.recordStep(this.getExpectConfirmScript(s, retVal));
        }
        return retVal;
    }
};
Sahi.prototype.getExpectPromptScript = function(s, retVal){
	return "_expectPrompt(" + this.quotedEscapeValue(s) + ", " + this.quotedEscapeValue(retVal) + ")";
}
Sahi.prototype.getExpectConfirmScript = function(s, retVal){
	return "_expectConfirm(" + this.quotedEscapeValue(s) + ", " + retVal + ");"
}
Sahi.prototype.getNavigateToScript = function(url){
	return "_navigateTo(" + this.quotedEscapeValue(url) +");";
}
Sahi.prototype.promptMock = function (s) {
    if (this.isPlaying()) {
        var retVal = this.getServerVar("prompt: "+s);//this.promptReturnValue[s];
        if (retVal == null) retVal = "";
        this.setServerVar("lastPromptText", s);
        this.setServerVar("prompt: "+s, null);
        return retVal;
    } else {
        var retVal = this.callFunction(this.real_prompt, window, s);
        this.recordStep(this.getExpectPromptScript(s, retVal));
        return retVal;
    }
};
Sahi.prototype.printMock = function () {
    if (this.isPlaying()) {
        this.setServerVar("printCalled", true);
        return null;
    } else {
        return this.callFunction(this.real_print, window);
    }
};
Sahi.prototype.mockDialogs = function (win) {
	win.alert = this.wrap(this.alertMock);
	win.confirm = this.wrap(this.confirmMock);
	win.prompt = this.wrap(this.promptMock);
	win.print = this.wrap(this.printMock);
};
var _sahi = new Sahi();
var tried = false;
var _sahi_top = window.top;
var _sahi_parent = window.parent;

Sahi.prototype.top = function () {
    //Hack for frames named "top"
	try{
		//alert(_sahi_top.location.href);
		var x = _sahi_top.location.href; // test
		return _sahi_top;
	}catch(e){
		var p = window;
		while (p != p._sahi_parent){
			try{
				var y = p._sahi_parent.location.href; // test
				p = p._sahi_parent;
			}catch(e){
				return p;
			}
		}
		return p;
	}
};
Sahi.prototype.getKnownTags = function (src) {
	var el = src;
	while (true) {
		if (!el) return el;
		if (!el.tagName) return null;
		var tagLC = el.tagName.toLowerCase();
		if (tagLC == "html" || tagLC == "body") return null;
		for (var i=0; i<this.ADs.length; i++){
			var d = this.ADs[i];  
			if (d.tag.toLowerCase() == tagLC){
				return el;
			}
		}
		el = el.parentNode;
	}
};
Sahi.prototype.byId = function (src) {
    var s = src.id;
    if (this.isBlankOrNull(s)) return "";
    return "getElementById('" + s + "')";
};
Sahi.prototype.getLink = function (src) {
    var lnx = this.getElementsByTagName("A", window.document);
    for (var j = 0; j < lnx.length; j++) {
        if (lnx[j] == src) {
            return "links[" + j + "]";
        }
    }
    return  null;
};
Sahi.prototype.getElementsByTagName = function(tagName, doc){
	return doc.getElementsByTagName(tagName.toLowerCase());
}
Sahi.prototype.areTagNamesEqual = function(tagName1, tagName2){
	if (tagName1 == tagName2) return true;
	if (tagName1 == null || tagName2 == null) return false;
	return (tagName1.toLowerCase() == tagName2.toLowerCase());
}
Sahi.prototype.getImg = function (src) {
    var lnx = window.document.images;
    for (var j = 0; j < lnx.length; j++) {
        if (lnx[j] == src) {
            return "images[" + j + "]";
        }
    }
    return  null;
};

Sahi.prototype.getForm = function (src) {
    if (!this.isBlankOrNull(src.name) && this.nameNotAnInputElement(src)) {
        return "forms['" + src.name + "']";
    }
    var fs = window.document.forms;
    for (var j = 0; j < fs.length; j++) {
        if (fs[j] == src) {
            return "forms[" + j + "]";
        }
    }
    return null;
};
Sahi.prototype.nameNotAnInputElement = function (src) {
    return (typeof src.name != "object");
};
//Sahi.prototype.getFormElement = function (src) {
//    return this.getByTagName(src);
//};

//Sahi.prototype.getByTagName = function (src) {
//    var tagName = src.tagName.toLowerCase();
//    var els = this.getElementsByTagName(tagName, window.document);
//    return "getElementsByTagName('" + tagName + "')[" + this.findInArray(els, src) + "]";
//};

//Sahi.prototype.getTable = function (src) {
//    var tables = this.getElementsByTagName("table", window.document);
//    if (src.id && src.id != null && src == window.document.getElementById(src.id)) {
//        return "getElementById('" + src.id + "')";
//    }
//    return "getElementsByTagName('table')[" + this.findInArray(tables, src) + "]";
//};

//Sahi.prototype.getTableCell = function (src) {
//    var tables = window.document.getElementsByTagName("table");
//    var row = this.getRow(src);
//    if (row.id && row.id != null && row == window.document.getElementById(row.id)) {
//        return "getElementById('" + row.id + "').cells[" + src.cellIndex + "]";
//    }
//    var table = this.getTableEl(src);
//    if (table.id && table.id != null && table == window.document.getElementById(table.id)) {
//        return "getElementById('" + table.id + "').rows[" + this.getRow(src).rowIndex + "].cells[" + src.cellIndex + "]";
//    }
//    return "getElementsByTagName('table')[" + this.findInArray(tables, this.getTableEl(src)) + "].rows[" + this.getRow(src).rowIndex + "].cells[" + src.cellIndex + "]";
//};

//Sahi.prototype.getRow = function (src) {
//    return this.getParentNode(src, "tr");
//};

//Sahi.prototype.getTableEl = function (src) {
//    return this.getParentNode(src, "table");
//};

Sahi.prototype.getArrayElement = function (s, src) {
    var tag = src.tagName.toLowerCase();
    if (tag == "input" || tag == "textarea" || tag.indexOf("select") != -1) {
        var el2 = eval(s);
        if (el2 == src) return s;
        var ix = -1;
        if (el2 && el2.length) {
            ix = this.findInArray(el2, src);
            return s + "[" + ix + "]";
        }
    }
    return s;
};

Sahi.prototype.getEncapsulatingLink = function (src) {
	return (this.areTagNamesEqual(src.tagName, "A") || this.areTagNamesEqual(src.tagName, "AREA")) ? src : this._parentNode(src, "A");
};
Sahi.prototype.linkClick = function (e) {
    if (!e) e = window.event;
    var performDefault = true;
    var el = this.getTarget(e);
    this.lastLink = this.getEncapsulatingLink(el);
    if (this.lastLink.__sahi__prevClick) {
    	try{
    		performDefault = this.lastLink.__sahi__prevClick.apply(this.lastLink, arguments);
    	}catch(ex){}
    }
    this.lastLinkEvent = e;
    if (performDefault != false && this.lastLink.getAttribute("href") != null) {
    	window.setTimeout(function(){_sahi.navigateLink()}, 0);
    } else {
        return false;
    }
};
Sahi.prototype._dragDrop = function (draggable, droppable, offsetX, offsetY) {
    this.checkNull(draggable, "_dragDrop", 1, "draggable");
    this.checkNull(droppable, "_dragDrop", 2, "droppable");
    var pos = this.findClientPos(droppable);
    var x = pos[0];
    var y = pos[1];
    x = x + (offsetX ? offsetX : 1);
    y = y + (offsetY ? offsetY : 1); // test http://www.snook.ca/technical/mootoolsdragdrop/
    this._dragDropXY(draggable, x, y);
};
Sahi.prototype.addBorder = function(el){
    el.style.border = "1px solid red";
};
Sahi.prototype.getScrollOffsetY = function(){
	if (document.body.scrollTop) return document.body.scrollTop;
	if (document.documentElement && document.documentElement.scrollTop) return document.documentElement.scrollTop;
	if (window.pageYOffset) return window.pageYOffset;
	if (window.scrollY) return window.scrollY;
	return 0;
}
Sahi.prototype.getScrollOffsetX = function(){
	if (document.body.scrollLeft) return document.body.scrollLeft;
	if (document.documentElement && document.documentElement.scrollLeft) return document.documentElement.scrollLeft;
	if (window.pageXOffset) return window.pageXOffset;
	if (window.scrollX) return window.scrollX;
	return 0;
}
Sahi.prototype._dragDropXY = function (draggable, x, y, isRelative) {
    this.checkNull(draggable, "_dragDropXY", 1, "draggable");
    this.simulateMouseEvent(draggable, "mouseover");
    this.simulateMouseEvent(draggable, "mousemove");
    this.simulateMouseEvent(draggable, "mousedown");
    this.simulateMouseEvent(draggable, "mousemove");

    var addX = 0, addY = 0;
    if (isRelative){
        var pos = this.findClientPos(draggable);
        addX = pos[0];
        addY = pos[1];
        if (!x) x = 0;
        if (!y) y = 0;
        x += addX;
        y += addY;
    }else{
        if (!x) x = this.findClientPos(draggable)[0];
        if (!y) y = this.findClientPos(draggable)[1];
    }

//    x = x - this.getScrollOffsetX();
//    y = y - this.getScrollOffsetY();
    
    this.simulateMouseEventXY(draggable, "mousemove", x, y);
    this.simulateMouseEventXY(draggable, "mouseup", x, y);
    this.simulateMouseEventXY(draggable, "click", x, y);
    this.simulateMouseEventXY(draggable, "mousemove", x, y);
    this.simulateMouseEventXY(draggable, "mouseout", x, y);
};
Sahi.prototype.checkNull = function (el, fnName, paramPos, paramName) {
    if (el == null) {
    	var error = new Error("The " +
        (paramPos==1?"first ":paramPos==2?"second ":paramPos==3?"third ":"") +
    	        "parameter passed to " + fnName + " was not found on the browser")
    	error.isSahiError = true;
        throw error;
    }
};
Sahi.prototype.checkVisible = function (el) {
    if (this.strictVisibilityCheck && !this._isVisible(el)) {
        throw "" + el + " is not visible";
    }
};
Sahi.prototype.checkElementVisible = function (el) {
	if (!this.strictVisibilityCheck) return true;
	if (el.type && el.type == "hidden") return true;
    return this._isVisible(el);
}
Sahi.prototype._setStrictVisibilityCheck = function(b){
	this.setServerVar("strictVisibilityCheck", b);
	this.strictVisibilityCheck = b;
}
Sahi.prototype._isVisible = function (el) {
    try{
        if (el == null) return false;
        var elOrig = el;
        var display = true;
        while (true){
            display = display && this.isStyleDisplay(el);
            if (!display || el.parentNode == el || this.areTagNamesEqual(el.tagName, "BODY")) break;
            el = el.parentNode;
        }
        el = elOrig;
        var visible = true;
        while (true){
            visible = visible && this.isStyleVisible(el);
            if (!visible || el.parentNode == el || this.areTagNamesEqual(el.tagName, "BODY")) break;
            el = el.parentNode;
        }
        return display && visible;
    } catch(e){return false;}
};
Sahi.prototype._exists = function(el){
	return el != null;
}
Sahi.prototype.isStyleDisplay = function(el){
    var d = this._style(el, "display");
    return d==null || d != "none";
};
Sahi.prototype.isStyleVisible = function(el){
    var v = this._style(el, "visibility");
    return v==null || v != "hidden";
};
Sahi.prototype.invokeLastBlur = function(){
    if (this.lastBlurFn){
    	window.clearTimeout(this.lastBlurTimeout);
    	this.doNotRecord = true;
    	this.lastBlurFn();
    	this.doNotRecord = false;
    	this.lastBlurFn = null;
    }	
}
Sahi.prototype.setLastBlurFn = function(fn){
	if (this.lastBlurTimeout) window.clearTimeout(this.lastBlurTimeout);
	this.lastBlurFn = fn;
	this.lastBlurTimeout = window.setTimeout(this.wrap(this.invokeLastBlur), Sahi.BLUR_TIMEOUT);
}
Sahi.prototype._click = function (el, combo) {
    this.checkNull(el, "_click");
    this.checkVisible(el);
    this.simulateClick(el, false, false, combo);
};

Sahi.prototype._doubleClick = function (el, combo) {
    this.checkNull(el, "_doubleClick");
    this.checkVisible(el);
    this.simulateDoubleClick(el, false, true, combo);
};

Sahi.prototype._rightClick = function (el, combo) {
    this.checkNull(el, "_rightClick");
    this.checkVisible(el);
    this.simulateRightClick(el, true, false, combo);
};

Sahi.prototype._mouseOver = function (el, combo) {
    this.checkNull(el, "_mouseOver");
    this.checkVisible(el);
    this.simulateMouseEvent(el, "mousemove");
    this.simulateMouseEvent(el, "mouseover");
    
    this.setLastBlurFn(function(){
    	try{
	    	_sahi.simulateMouseEvent(el, "mousemove");
	        _sahi.simulateMouseEvent(el, "mouseout");
	    	_sahi.simulateMouseEvent(el, "blur");
    	}catch(e){}
    });    
};
Sahi.prototype._mouseDown = function (el, isRight, combo) {
	this.simulateMouseEvent(el, "mousedown", isRight, false, combo);	
}
Sahi.prototype._mouseUp = function (el, isRight, combo) {
	this.simulateMouseEvent(el, "mouseup", isRight, false, combo);	
}
Sahi.prototype._keyPress = function (el, val, combo) {
	var append = (el && el.type && (el.type=="text" || el.type=="password" || el.type=="textarea") && this.shouldAppend(el));
	this.simulateKeyPressEvents(el, val, combo, append);
}
Sahi.prototype.simulateKeyPressEvents = function (el, val, combo, append) {
	var origVal = el.value;
	var keyCode = 0;
	var charCode = 0;
	var c = null;
	if (typeof val == "number"){
		charCode = val;
	    keyCode = this.getKeyCode(charCode);
	    c = String.fromCharCode(charCode);
	} else if (typeof val == "object") {
		keyCode = val[0];
		charCode = val[1];
	    c = String.fromCharCode(charCode);
	} else if (typeof val == "string") {
	    charCode = val.charCodeAt(0);
	    keyCode = this.getKeyCode(charCode);
	    c = val;
	}
    var isShift = (charCode >= 65 && charCode <= 90);
    if (isShift) combo = "" + combo + "|SHIFT|";
    this.simulateKeyEvent([(isShift ? 16 : keyCode), 0], el, "keydown", combo);
    this.simulateKeyEvent([0, charCode], el, "keypress", combo);
    if (append && charCode!=10 && origVal == el.value) {
    	if (!this._isFF4Plus() || (this._isFF4Plus() && !(combo == "CTRL" || combo == "ALT")))
        el.value += c;
    }
    this.simulateKeyEvent([keyCode, 0], el, "keyup", combo);
};
Sahi.prototype._keyPressEvent = function (el, codes, combo) {
    this.checkNull(el, "_keyPressEvent", 1);
    this.checkVisible(el);        
    this.simulateKeyEvent(((typeof codes == "object") ? codes : [0, codes]), el, "keypress", combo);
};

Sahi.prototype._focus = function (el) {
    try{
    	el.focus();
    }catch(e){}
    this.simulateEvent(el, "focus");
};

Sahi.prototype._blur = function (el) {
    this.simulateEvent(el, "blur");
};
Sahi.prototype._removeFocus = Sahi.prototype._blur;
Sahi.prototype._keyDown = function (el, codes, combo) {
    this.checkNull(el, "_keyDown", 1);
    this.checkVisible(el);
    this.simulateKeyEvent(((typeof codes == "number")? [codes, 0] : codes), el, "keydown", combo);    
};
Sahi.prototype._keyUp = function (el, codes, combo) {
    this.checkNull(el, "_keyUp", 1);
    this.checkVisible(el);
    this.simulateKeyEvent(((typeof codes == "number")? [codes, 0] : codes), el, "keyup", combo);
};
Sahi.prototype._closeWindow = function (win) {
	if (!win) {
		try {
			win = _sahi_top.window;
		} catch (e) {
			win = window;
		}
	}
	if (win) {
		win.open("", "_self");
		win.close();
	}
};
//Sahi.prototype._readFile = function (fileName) {
//	return this._evalOnRhino("_readFile("+this.quotedEscapeValue(fileName)+")");
//};
//Sahi.prototype._readCSVFile = function (fileName) {
//	return this._evalOnRhino("_readCSVFile("+this.quotedEscapeValue(fileName)+")");
//};
Sahi.prototype._getDB = function (driver, jdbcurl, username, password) {
    return new Sahi.dB(driver, jdbcurl, username, password, this);
};
Sahi.dB = function (driver, jdbcurl, username, password, sahi) {
    this.driver = driver;
    this.jdbcurl = jdbcurl;
    this.username = username;
    this.password = password;
    this.select = function (sql) {
        var qs = "driver=" + this.driver + "&jdbcurl=" + this.jdbcurl + "&username=" + this.username + "&password=" + this.password + "&sql=" + sql;
        return eval(sahi._callServer("net.sf.sahi.plugin.DBClient_select", qs));
    };
    this.update = function (sql) {
        var qs = "driver=" + this.driver + "&jdbcurl=" + this.jdbcurl + "&username=" + this.username + "&password=" + this.password + "&sql=" + sql;
        return eval(sahi._callServer("net.sf.sahi.plugin.DBClient_execute", qs));
    };
};
Sahi.prototype.isCheckboxRadioSimulationRequired = function(){
	if (this._isChrome()) {
		return this.chromeExplicitCheckboxRadioToggle;
	}
	return this.isSafariLike();
};
Sahi.prototype.simulateDoubleClick = function (el, isRight, isDouble, combo) {
    var n = el;
    var callBlur = true;
    if (this._isFF() || this.isSafariLike() || this._isOpera()) {
    	this.simulateMouseEvent(el, "mousemove");
	    this.simulateMouseEvent(el, "mouseover");
	    this.simulateMouseEvent(el, "mousedown", isRight, false, combo);
	    this.invokeLastBlur();
	    callBlur = this.isFocusableFormElement(el);
	    if (callBlur)  this.simulateEvent(el, "focus");
	    this.simulateMouseEvent(el, "mouseup", isRight, false, combo);
	    this.simulateMouseEvent(el, "click", isRight, false, combo);
	    this.simulateMouseEvent(el, "mousedown", isRight, isDouble, combo);
	    this.simulateMouseEvent(el, "mouseup", isRight, isDouble, combo);
	    this.simulateMouseEvent(el, "click", isRight, isDouble, combo);
	    this.simulateMouseEvent(el, "dblclick", isRight, isDouble, combo);
    } else if (this._isIE() && !this._isIE9()){
	    this.simulateMouseEvent(el, "mousemove");
	    this.simulateMouseEvent(el, "mouseover");
	    this.simulateMouseEvent(el, "mousedown", isRight, false, combo);
	    this.invokeLastBlur();
	    this.simulateMouseEvent(el, "focus");
	    this.simulateMouseEvent(el, "mouseup", isRight, false, combo);
	    this.simulateMouseEvent(el, "click", isRight, false, combo);
	    this.simulateMouseEvent(el, "mouseup", isRight, false, combo);	
	    this.simulateMouseEvent(el, "dblclick", isRight, isDouble, combo);
    } else if (this._isIE9()) {
    	this.simulateMouseEvent(el, "mousemove");
	    this.simulateMouseEvent(el, "mouseover");
	    this.simulateMouseEvent(el, "mousedown", isRight, false, combo);
	    this.invokeLastBlur();
	    this.simulateMouseEvent(el, "focus");
	    this.simulateMouseEvent(el, "mouseup", isRight, false, combo);
	    this.simulateMouseEvent(el, "click", isRight, false, combo);
	    this.simulateMouseEvent(el, "mousedown", isRight, isDouble, combo);
	    this.simulateMouseEvent(el, "mouseup", isRight, isDouble, combo);
	    this.simulateMouseEvent(el, "click", isRight, isDouble, combo);
	    this.simulateMouseEvent(el, "dblclick", isRight, isDouble, combo);
    } 
    if (callBlur){
		this.setLastBlurFn(function(){
	    	try{
		    	_sahi.simulateMouseEvent(el, "mousemove");
		        _sahi.simulateMouseEvent(el, "mouseout");
		        if (!(_sahi._isFF() || _sahi._isIE9() || _sahi._isOpera()) && (el.type == "checkbox" || el.type == "radio")){
		        	_sahi.simulateEvent(el, "change");
		        }
		        _sahi.simulateEvent(el, "blur");
	    	}catch(e){}
	    });
    }    
};
Sahi.prototype.simulateRightClick = function (el, isRight, isDouble, combo) {
    var n = el;
    var callBlur = true;
    if (this._isFF() || this.isSafariLike() || this._isOpera()) {
    	this.simulateMouseEvent(el, "mousemove");
	    this.simulateMouseEvent(el, "mouseover");
	    this.simulateMouseEvent(el, "mousedown", isRight, false, combo);
	    this.invokeLastBlur();
	    callBlur = this.isFocusableFormElement(el);
	    if (callBlur)  this.simulateEvent(el, "focus");
	    this.simulateMouseEvent(el, "mouseup", isRight, false, combo);
	    this.simulateMouseEvent(el, "contextmenu", isRight, false, combo);
    } else if (this._isIE()){
	    this.simulateMouseEvent(el, "mousemove");
	    this.simulateMouseEvent(el, "mouseover");
	    this.simulateMouseEvent(el, "mousedown", isRight, false, combo);
	    this.invokeLastBlur();
	    this.simulateMouseEvent(el, "focus");
	    this.simulateMouseEvent(el, "mouseup", isRight, false, combo);
	    this.simulateMouseEvent(el, "contextmenu", isRight, false, combo);
    }
    if (callBlur){
		this.setLastBlurFn(function(){
	    	try{
		    	_sahi.simulateMouseEvent(el, "mousemove");
		        _sahi.simulateMouseEvent(el, "mouseout");
		        if (!(_sahi._isFF() || _sahi._isIE9() || _sahi._isOpera()) && (el.type == "checkbox" || el.type == "radio")){
		        	_sahi.simulateEvent(el, "change");
		        }
		        _sahi.simulateEvent(el, "blur");
	    	}catch(e){}
	    });
    }    
};
Sahi.prototype.isFocusableFormElement = function(el){
	if (!this.isFormElement(el)) return false;
	if (this.isSafariLike() && (el.type == "checkbox" || el.type == "radio" || el.type == "button")) return false;
	return true;
}
Sahi.prototype.simulateClick = function (el, isRight, isDouble, combo) {
    var n = el;

    var link = this.getEncapsulatingLink(n);
    // This is required only for FF right now.
    // Definitely FF3.6
    // Need to check which other versions
    if (link != null && (this._isFF())){
    	link.__sahi__prevClick = link.onclick;
        var elWin = this.getWindow(link);
        link.onclick = function (e) {
        	// test with docWriteIFrame
        	return _sahi.wrap(_sahi.linkClick)(e ? e : elWin.event);
        };
    }
    
    this.simulateMouseEvent(el, "mousemove");
    this.simulateMouseEvent(el, "mouseover");
    this.simulateMouseEvent(el, "mousedown", isRight, false, combo);
    this.invokeLastBlur();
    var focusBlur = this.isFocusableFormElement(el);
    if (focusBlur) this.simulateEvent(el, "focus");
    this.simulateMouseEvent(el, "mouseup", isRight, false, combo);
    try {
        if (this._isIE() && el && (this.areTagNamesEqual(el.tagName, "LABEL") || 
            		(link != null) ||
            		(el.type && (el.type == "submit"
                    || el.type == "reset" || el.type == "image"
                    || el.type == "checkbox" || el.type == "radio")))) {
    		if (link != null) {
    	        this.markStepDone(this.currentStepId, this.currentType);
    		}
    		el.click();
        } else {
        	if (window.opera){
        		// for opera single clicks don't simulate click event; 
        		// Ignoring old comment, seems click is required now. 01 Nov 2010
        		this.simulateMouseEvent(el, "click", isRight, isDouble, combo);
        		if (this.areTagNamesEqual(el.tagName, "INPUT") && (el.type == "radio" || el.type == "checkbox")) {
        			this.simulateEvent(el, "change");
        		}
        	}
        	else {
        		var done = false;
        		if (this.isCheckboxRadioSimulationRequired()) {
                    if (this.areTagNamesEqual(el.tagName, "INPUT")) {
                        if (el.type == "radio" || el.type == "checkbox") {
                        	done = true;
                        	el.checked = (el.type == "radio") ? true : !el.checked;
                        	this.simulateEvent(el, "change");
                        	this.simulateMouseEvent(el, "click", isRight, isDouble, combo);
                        } 
                    }
                } 
                if (!done) this.simulateMouseEvent(el, "click", isRight, isDouble, combo);
        	}
        }
    } catch(e) {
    }

    if (focusBlur){
		this.setLastBlurFn(function(){
	    	try{
		    	_sahi.simulateMouseEvent(el, "mousemove");
		        _sahi.simulateMouseEvent(el, "mouseout");
		        if (!(_sahi._isFF() || _sahi._isIE9() || _sahi._isOpera()) && (el.type == "checkbox" || el.type == "radio")){
		        	_sahi.simulateEvent(el, "change");
		        }
		        _sahi.simulateEvent(el, "blur");
	    	}catch(e){}
	    });
    }
    if (link != null && (this._isFF())){
    	link.onclick = link.__sahi__prevClick;
    }
};
Sahi.prototype.getWebkitVersion = function(){
	var exp = /AppleWebKit\/(.*) \(/;
    exp.test(this.navigator.userAgent);
	return RegExp.$1
}
Sahi.prototype.getChromeBrowserVersion = function(){
	var exp = /Chrome\/(.*) /;
    exp.test(this.navigator.userAgent);
	return RegExp.$1
}
Sahi.prototype.simulateMouseEvent = function (el, type, isRight, isDouble, combo) {
    var xy = this.findClientPos(el);
    var x = xy[0];
    var y = xy[1];
    this.simulateMouseEventXY(el, type, xy[0], xy[1], isRight, isDouble, combo);
};
Sahi.prototype.simulateMouseEventXY = function (el, type, x, y, isRight, isDouble, combo) {
	if (!combo) combo = "";
    var isShift = combo.indexOf("SHIFT")!=-1;
    var isCtrl = combo.indexOf("CTRL")!=-1;
    var isAlt = combo.indexOf("ALT")!=-1;
    var isMeta = combo.indexOf("META")!=-1;
    
    if (!this._isIE() || (this._isIE9() && !(type == "click" && isDouble))) {
        if (this.isSafariLike() || this._isIE9() || this._isOpera()) {
        	if (el.ownerDocument.createEvent) {
	            var evt = el.ownerDocument.createEvent('HTMLEvents');
	            type = type;
	            evt.initEvent(type, true, true);
	            evt.clientX = x;
	            evt.clientY = y;
	            evt.pageX = x;
	            evt.pageY = y;
	            evt.screenX = x;
	            evt.screenY = y;
	            evt.button = isRight ? 2 : 0;
	            evt.which = isRight ? 3 : 1;
	            evt.detail = isDouble ? 2 : (type == "contextmenu" ? 0 : 1);
	            evt.ctrlKey = isCtrl;
	            evt.altKey = isAlt;
	            evt.metaKey = isMeta;            
	            evt.shiftKey = isShift;
	            el.dispatchEvent(evt);
        	}
        }
        else {
            // FF
            var evt = el.ownerDocument.createEvent("MouseEvents");
            evt.initMouseEvent(
            type,
            true, //can bubble
            true, //cancelable
            el.ownerDocument.defaultView, //view
            (isDouble ? 2 : 1), //detail
            x, //screen x
            y, //screen y
            x, //client x
            y, //client y
            isCtrl,
            isAlt,
            isShift,
            isMeta,
            isRight ? 2 : 0, //button
            null//relatedTarget
            );
            el.dispatchEvent(evt);
        }
    } 
    if (this._isIE()) {
        // IE
        var evt = el.ownerDocument.createEventObject();
        evt.clientX = x;
        evt.clientY = y;
        evt.ctrlKey = isCtrl;
        evt.altKey = isAlt;
        evt.metaKey = isMeta;            
        evt.shiftKey = isShift;
        if (type == "mousedown" || type == "mouseup" || type == "mousemove"){
        	evt.button = isRight ? 2 : 1;
        }
        el.fireEvent("on" + type, evt);
        evt.cancelBubble = true;
    }
};
Sahi.prototype.addOffset = function(el, origin){
	var x=origin[0];
	var y=origin[1];
    var offsets = this.xyoffsets[el];
    if (offsets){
    	var ox = offsets[0];
    	var width = parseInt(this._style(el, "width"));
    	if (ox < 0 && ((""+width) != "NaN")) ox = width + ox;
    	x += ox;
    	
    	var oy = offsets[1];
    	var height = parseInt(this._style(el, "height"));
    	if (oy < 0 && ((""+height) != "NaN")) oy = height + oy;    	                 
    	y += oy;
    }	
    return [x,y];
}

Sahi.pointTimer = 0;
Sahi.prototype._highlight = function (el) {
    var oldBorder = el.style.border;
    el.style.border = "1px solid red";
    window.setTimeout(function(){el.style.border = oldBorder;}, 2000);
};
Sahi.prototype._position = function (el){
    return this.findPos(el);
};
Sahi.prototype.findPosX = function (obj){
    return this.findPos(obj)[0];
};
Sahi.prototype.findPosY = function (obj){
    return this.findPos(obj)[1];
};
Sahi.prototype.findClientPos = function (el){
	var xy = this.findPos(el);
//	alert(xy[1] +" " + (xy[1]-this.getScrollOffsetY()));
	return [xy[0]-this.getScrollOffsetX(), xy[1]-this.getScrollOffsetY()];
}
Sahi.prototype.findPos = function (el, isClient){
	var obj = el;
    var x = 0, y = 0;
    if (obj.offsetParent)
    {
        while (obj)
        {
            if (this.areTagNamesEqual(obj.tagName, "MAP")){
            	var res = this.getBlankResult();
            	obj = this.findTagHelper("#"+obj.name, this.getWindow(obj), "IMG", res, "useMap").element;
            	if (obj == null) break;
            }
            var wasStatic = null;
            /*
            if (this._style(obj, "position") == "static"){
                wasStatic = obj.style.position;
                obj.style.position = "relative";
            }
             */
            x += obj.offsetLeft;
            y += obj.offsetTop;
            if (wasStatic != null) obj.style.position = wasStatic;
            obj = obj.offsetParent;
        }
    }
    else if (obj.x){
        x = obj.x;
        y = obj.y;
    }
    return this.addOffset(el, [x,y]);
};
Sahi.prototype.getWindow = function(el){
    var win;
    if (this.isSafariLike()) {
        win = this.getWin(el);
    } else {
        win = el.ownerDocument.defaultView; //FF
        if (!win) win = el.ownerDocument.parentWindow; //IE
    }
    return win;
};

Sahi.prototype.navigateLink = function () {
    var ln = this.lastLink;
    if (!ln) return;
    if (this.lastLinkEvent.getPreventDefault) {
        if (this.lastLinkEvent.getPreventDefault()) return;
    }
    if ((this._isIE() || this.isSafariLike()) && this.lastLinkEvent.returnValue == false) return;
    var win = this.getWindow(ln);
    if (ln.href.indexOf("javascript:") == 0) {
        var s = ln.href.substring(11);
        win.setTimeout(unescape(s), 0);
    } else {
        var target = ln.target;
        if (ln.target == null || ln.target == "") {
        	target = this.getBaseTarget(win);
        	if (target == null || target == "") target = "_self";
        }
        //if (!this.loaded) return; // happens if onclick caused unload via form submit. uncomment only if needed.
		var ancestor = this.getNamedWindow(win, target);
		if (ancestor){
    		if (this.isSafariLike()) {
                try {
                    ancestor._sahi.onBeforeUnLoad();
                } catch(e) {
                    //this._debug(e.message);
                }
    		}
			ancestor.location = ln.href;
		}else{
			win.open(ln.href, target);
        }
    }
};
Sahi.prototype.getNamedWindow = function (win, target){
	return this.getNamedAncestor(win, target) || this.getNamedFrame(win, target);
}
Sahi.prototype.getNamedAncestor = function (win, target){
	try{
		var w = win;
		if (target == "_self") return w;
		if (target == "_parent") return win.parent;
		if (target == "_top") return win.top;
		for (var i=0; i<100; i++){
			if (w.name == target) return w;
			if (w == w.parent) return null;
			w = w.parent;
		}
	}catch(e){}
}
Sahi.prototype.getNamedFrame = function (win, target){
	try{
	    var res = this.getBlankResult();
	    var el = this.findTagHelper(target, win, "iframe", res, "name").element;
	    if (el != null) return (el.contentWindow ? el.contentWindow : el);
	    res = this.getBlankResult();
	    el = this.findTagHelper(target, win, "frame", res, "name").element;
	    if (el != null) return el;
	}catch(e){}
}
Sahi.prototype.getBaseTarget = function (win) {
	var bs = this.getElementsByTagName("BASE", win.document);
	for (var i=bs.length-1; i>=0; i--){
		var t = bs[i].target;
		if (t && t != "") return t; 
	}
}
Sahi.prototype.getClickEv = function (el) {
    var e = new Object();
    if (this._isIE()) el.srcElement = e;
    else e.target = el;
    e.stopPropagation = this.noop;
    return e;
};

Sahi.prototype.noop = function () {
};

// api for link click end

Sahi.prototype._type = function (el, val) {
	for (var i = 0; i < val.length; i++) {
		var charCode = val.charAt(i).charCodeAt(0);
	    this.simulateKeyEvent(charCode, el, "keydown");
	    this.simulateKeyEvent(charCode, el, "keypress");
	    this.simulateKeyEvent(charCode, el, "keyup");
	}
};

Sahi.prototype._setValue = function (el, val) {
	if (val == null) return;
    this.invokeLastBlur();
	this.setValue(el, val);
};
Sahi.prototype.shouldAppend = function (el) {
	return !((this._isFF() && !this._isFF4Plus() && !this._isHTMLUnit()) || el.readOnly || el.disabled);
}
// api for set value start
Sahi.prototype.setValue = function (el, val) {
    this.checkNull(el, "_setValue", 1);
    this.checkVisible(el);
    
//    try{
//    	this.getWindow(el).focus();
//    }catch(e){}
    this.simulateEvent(el, "focus");
    
    val = "" + val;
    var ua = this.navigator.userAgent.toLowerCase();
    if (ua.indexOf("windows") != -1) {
    	val = val.replace(/\r/g, '');
    	if (!this._isFF()) val = val.replace(/\n/g, '\r\n');
    } 
    var prevVal = el.value;
    //if (!window.document.createEvent) el.value = val;
    if (this._isFF4Plus()) this._focus(el); // test with textarea.sah

    if (el.type && (el.type == "hidden" || el.type == "range")){
    	el.value = val;
    	return;
    } else if (el.type && el.type.indexOf("select") != -1) {
    } else {
        var append = (el && el.type && (this.findInArray(this.textboxTypes, el.type) != -1) && this.shouldAppend(el));
        el.value = "";
        if (typeof val == "string") {
        	var len = val.length;
        	if (el.maxLength && el.maxLength>=0 && val.length > el.maxLength) 
        		len = el.maxLength;
            for (var i = 0; i < len; i++) {
                var c = val.charAt(i);                
                this.simulateKeyPressEvents(el, c, null, append);
            }
        }
    }
    var triggerOnchange = prevVal != val;
    this.setLastBlurFn(function(){
    	try{
    	    if (triggerOnchange) {
    	        if (!_sahi._isFF3()) 
    	        	_sahi.simulateEvent(el, "change"); 		
    	    }     		
    		_sahi.simulateEvent(el, "blur");
    	}catch(e){}
    });
};
Sahi.prototype._setFile = function (el, v, url) {
	if (v == null) return;
    if (!url) url = (this.isBlankOrNull(el.form.action) || (typeof el.form.action != "string")) ? this.getWindow(el).location.href : el.form.action;
    if (url && (q = url.indexOf("?")) != -1) url = url.substring(0, q);
    if (url.indexOf("http") != 0) {
        var loc = window.location;
        if (url.indexOf("/") == 0){
            url = loc.protocol+ "//" +  loc.hostname + (loc.port ? (':'+loc.port) : '') + url;
        }else{
            var winUrl = loc.href;
            url = winUrl.substring(0, winUrl.lastIndexOf ('/') + 1) + url;
        }
    }
    var msg = this._callServer("FileUpload_setFile", "n=" + el.name + "&v=" + this.encode(v) + "&action=" + this.encode(url));
    if (msg != "true") {
    	throw new Error(msg);
    }
};

Sahi.prototype.simulateEvent = function (target, evType) {
    if (!this._isIE()) {
        var evt = new Object();
        evt.type = evType;
        evt.button = 0;
        evt.bubbles = true;
        evt.cancelable = true;
        if (!target) return;
        var event = target.ownerDocument.createEvent("HTMLEvents");
        event.initEvent(evt.type, evt.bubbles, evt.cancelable);
        target.dispatchEvent(event);
    } else {
        var evt = target.ownerDocument.createEventObject();
        evt.type = evType;
        evt.bubbles = true;
        evt.cancelable = true;
        evt.cancelBubble = true;
        target.fireEvent("on" + evType, evt);
    }
};
Sahi.prototype.getKeyCode = function (charCode){
	return (charCode >= 97 && charCode <= 122) ? charCode - 32 : charCode;
}
Sahi.prototype.simulateKeyEvent = function (codes, target, evType, combo) {
	var keyCode = codes[0];
	var charCode = codes[1];
	if (!combo) combo = "";
    var isShift = combo.indexOf("SHIFT")!=-1;
    var isCtrl = combo.indexOf("CTRL")!=-1;
    var isAlt = combo.indexOf("ALT")!=-1;
    var isMeta = combo.indexOf("META")!=-1;

    if (!this._isIE() || this._isIE9()) { // FF chrome safari opera
        if (this.isSafariLike() || window.opera || this._isIE9()) {
        	if (target.ownerDocument.createEvent) {
	            var event = target.ownerDocument.createEvent('HTMLEvents');
	
	            var evt = event;
	            if (!window.opera){
		            evt.bubbles = true;
		            evt.cancelable = true;
	            }
	            evt.ctrlKey = isCtrl;
	            evt.altKey = isAlt;
	            evt.metaKey = isMeta;
	            evt.charCode = charCode;
	            evt.keyCode =  (evType == "keypress") ? charCode : keyCode;
	            evt.shiftKey = isShift;
	            evt.which = evt.keyCode;
	            evt.initEvent(evType, evt.bubbles, evt.cancelable);
	            target.dispatchEvent(evt);
        	}
        } else { //FF
            var evt = new Object();
            evt.type = evType;
            evt.bubbles = true;
            evt.cancelable = true;
            evt.ctrlKey = isCtrl;
            evt.altKey = isAlt;
            evt.metaKey = isMeta;
        	evt.keyCode = keyCode;            	
        	evt.charCode = charCode;
            evt.shiftKey = isShift;

            if (!target) return;
            var event = target.ownerDocument.createEvent("KeyEvents");
            event.initKeyEvent(evt.type, evt.bubbles, evt.cancelable, target.ownerDocument.defaultView,
            evt.ctrlKey, evt.altKey, evt.shiftKey, evt.metaKey, evt.keyCode, evt.charCode);
            target.dispatchEvent(event);
        }
    } 
    if (this._isIE()) { // IE
        var evt = target.ownerDocument.createEventObject();
        evt.type = evType;
        evt.bubbles = true;
        evt.cancelable = true;
        var xy = this.findClientPos(target);
        evt.clientX = xy[0];
        evt.clientY = xy[1];
        evt.ctrlKey = isCtrl;
        evt.altKey = isAlt;
        evt.metaKey = isMeta;
        evt.keyCode = (this._isIE() && evType == "keypress") ? charCode : keyCode;           	
        evt.shiftKey = isShift; //c.toUpperCase().charCodeAt(0) == evt.charCode;
        evt.shiftLeft = isShift;
        evt.cancelBubble = true;
        target.fireEvent("on" + evType, evt);
    }
};
Sahi.prototype._simulateMouseEvent = Sahi.prototype.simulateMouseEvent;
Sahi.prototype._simulateMouseEventXY = Sahi.prototype.simulateMouseEventXY;
Sahi.prototype._simulateKeyEvent = Sahi.prototype.simulateKeyEvent;
Sahi.prototype.selectOption = function(el, val, isCTRL){
	var combo = isCTRL ? "CTRL" : null;
	var optionEl = this._option(val, this._in(el));
	if (!optionEl) throw new Error("Option not found: " + val);
	if (this._isIE()){
		this.simulateMouseEvent(el, "mousedown", false, false, combo);
		this.simulateMouseEvent(el, "mouseup", false, false, combo);
	    optionEl.selected = true;
		this.simulateMouseEvent(el, "change");
		this.simulateMouseEvent(el, "click", false, false, combo);				
	}else if (this._isFF()){
	    optionEl.selected = true;
		this.simulateMouseEvent(optionEl, "mousedown", false, false, combo);
		this.simulateMouseEvent(optionEl, "mouseup", false, false, combo);
		this.simulateMouseEvent(el, "change");
		this.simulateMouseEvent(optionEl, "click", false, false, combo);		
	}else {
		optionEl.selected = true;
		this.simulateMouseEvent(el, "change");
	}
}
Sahi.prototype._setSelected = function (el, val, append) {
	if (val == null) return;
	// reset _under related params so that option does not use _under
	this.xyoffsets = new Object();
	this.alignY = this.alignX = null;
	
	
	var l = el.options.length;
    var optionEl = null;
	if (el.type == "select-one"){
		this.simulateMouseEvent(el, "mousedown");
		this.simulateEvent(el, "focus");
		this.simulateMouseEvent(el, "mouseup");
		this.simulateMouseEvent(el, "click");
    	this.selectOption(el, val);
        return;
    } else {
	    if (!this.isArray(val)) val = [val];
	    if (!append){
	    	for (var i = 0; i < l; i++) {
	    		el.options[i].selected = false;
	    	}    	
	    }
		for (var i=0; i<val.length; i++){
			var isCTRL = (i > 0 || append); // use ctrl for first option if append is true.
			this.selectOption(el, val[i], isCTRL);
		}
    }
    this.setLastBlurFn(function(){
    	try{
    		_sahi.simulateEvent(el, "blur");
    	}catch(e){}
    });
};

// api for set value end
Sahi.prototype._check = function (el) {
    if (el.checked) return;
    this._click(el);
}
Sahi.prototype._uncheck = function (el) {
    if (!el.checked) return;
    this._click(el);
}
Sahi.prototype._wait = function (i, condn) {
	return condn ? eval(condn) : false;
};
Sahi.prototype._accessor = function (n) {
    return eval(n);
};
Sahi.prototype._byId = function (id) {
    return this.findElementById(this.top(), id);
};
Sahi.prototype._byText = function (text, tag) {
    var res = this.getBlankResult();
    return this.tagByText(this.top(), text, tag, res).element;
};
Sahi.prototype._byXPath = function (xpath, inEl) {
	inEl = (inEl && inEl.isRelation && inEl.type == "_in") ? inEl.element : inEl;
	var doc = inEl ? this.getWindow(inEl).document : this.top().document;
	var prefix = "";
	if (inEl){
		var tagName = inEl.tagName;
		var ix = this.findInArray(this.getElementsByTagName(tagName, doc), inEl);
		prefix = "//" + tagName.toLowerCase() + "["+(ix+1)+"]";
	}
//	if (!inEl) inEl = this.top().document;
	var res = doc.evaluate(prefix + xpath, doc, null, 0, null);
	switch(res.resultType) {
		case 1: return res.numberValue;
		case 2: return res.stringValue;
		case 3: return res.booleanValue;
	}
	var el = res.iterateNext();
	return el;
//	var els = new Array();
//	while (true) {
//    	var el = res.iterateNext();
//        if (!el) break;
//        els.push(el);
//    }
//    return els;
}
Sahi.prototype._byClassName = function (className, tagName, inEl) {
	var inEl = this.getDomRelAr(arguments);
	if (inEl.length == 0) inEl = this.top();
    var res = this.getBlankResult();
    var el = this.findTagHelper(className, inEl, tagName, res, "className").element;
    return el;
};
Sahi.prototype.byName = function (name, tagName, inEl) {
	var inEl = this.getDomRelAr(arguments);
	if (inEl.length == 0) inEl = this.top();
    var res = this.getBlankResult();
    var el = this.findTagHelper(name, inEl, tagName, res, "name").element;
    return el;
};
Sahi.prototype._spandiv = function (id, inEl) {
	var el = this._span.apply(this, arguments);
	if (el == null) el = this._div.apply(this, arguments);
	return el;
};
Sahi.prototype.tagByText = function (win, id, tagName, res) {
    var o = this.getArrayNameAndIndex(id);
    var ix = o.index;
    var fetch = o.name;
    var els = this.getElementsByTagName(tagName, this.getDoc(win));
    for (var i = 0; i < els.length; i++) {
        var el = els[i];
        var text = this._getText(el);

        if (this.isTextMatch(text, fetch)) {
            res.cnt++;
            if (res.cnt == ix || ix == -1) {
                res.element = this.innerMost(el, id, tagName);
                res.found = true;
                return res;
            }
        }
    }
    var frs = win.frames;
    if (frs) {
        for (var j = 0; j < frs.length; j++) {
            try{
                res = this.tagByText(frs[j], id, tagName, res);
            }catch(e){}
            if (res && res.found) return res;
        }
    }
    return res;
};
Sahi.prototype.isTextMatch = function(sample, pattern){
    if (pattern instanceof RegExp)
        return sample.match(pattern);
    return (sample == pattern);
};
Sahi.prototype.innerMost = function(el, re, tagName){
    for (var i=0; i < el.childNodes.length; i++){
        var child = el.childNodes[i];
        var text = this._getText(child);
        if (text && this.contains(text, re)){
            var inner = this.innerMost(child, re, tagName);
            if (this.areTagNamesEqual(inner.nodeName, tagName)) return inner;
        }
    }
    return el;
};
Sahi.prototype._simulateEvent = function (el, ev) {
    if (this._isIE()) {
        var newFn = (eval("el.on" + ev.type)).toString();
        newFn = newFn.replace("anonymous()", "s_anon(s_ev)", "g").replace("event", "s_ev", "g");
        eval(newFn);
        s_anon(ev);
    } else {
        eval("el.on" + ev.type + "(ev);");
    }
};
Sahi.prototype._setGlobal = function (name, value) {
    //this._debug("SET name="+name+" value="+value);
    this.setServerVar(name, value, true);
};
Sahi.prototype._getGlobal = function (name) {
    var value = this.getServerVar(name, true);
    //this._debug("GET name="+name+" value="+value);
    return value;
};
Sahi.prototype._set = function (name, value) {
    this.locals[name] = value;
};
Sahi.prototype._get = function (name) {
    var value = this.locals[name];
    return value;
};
Sahi.prototype._assertNotNull = function (n, s) {
    if (n == null) throw new SahiAssertionException(1, s);
    return true;
};
Sahi.prototype._assertExists = Sahi.prototype._assertNotNull;
Sahi.prototype._assertNull = function (n, s) {
    if (n != null) throw new SahiAssertionException(2, s);
    return true;
};
Sahi.prototype._assertNotExists = Sahi.prototype._assertNull;
Sahi.prototype._assertTrue = function (n, s) {
    if (n != true) throw new SahiAssertionException(5, s);
    return true;
};
Sahi.prototype._assert = Sahi.prototype._assertTrue;
Sahi.prototype._assertNotTrue = function (n, s) {
    if (n) throw new SahiAssertionException(6, s);
    return true;
};
Sahi.prototype._assertFalse = Sahi.prototype._assertNotTrue;
Sahi.prototype._assertEqual = function (expected, actual, s) {
    if (this.isArray(expected) && this.isArray(actual))
        return this._assertEqualArrays(expected, actual, s);
	if (this.trim(expected) != this.trim(actual)) 
		throw new SahiAssertionException(3, (s ? s : "") + "\nExpected:[" + expected + "]\nActual:[" + actual + "]");
	return true;
};
Sahi.prototype.isArray = function (obj) {
	return Object.prototype.toString.call(obj) === '[object Array]';
}
Sahi.prototype._assertEqualArrays = function (expected, actual, s) {
    var compareResult = this.compareArrays(expected,actual);
	if (compareResult != "equal") throw new SahiAssertionException(3,(s ? s : "") + "\n"+compareResult);
	return true;	
};
Sahi.prototype._areEqualArrays = function (expected, actual){
	return this.compareArrays(expected,actual) == "equal";
};

Sahi.prototype._assertNotEqual = function (expected, actual, s) {
    if (this.trim(expected) == this.trim(actual)) throw new SahiAssertionException(4, s);
    return true;
};
Sahi.prototype._assertContainsText = function (expected, el, s) {
    if (!this._containsText(el, expected)) 
    	throw new SahiAssertionException(3, (s ? s : "") + "\nExpected:[" + expected + "] to be part of [" + this._getText(el) + "]");
    return true;
};
Sahi.prototype._assertNotContainsText = function (expected, el, s) {
    if (this._containsText(el, expected)) 
    	throw new SahiAssertionException(3, (s ? s : "") + "\nExpected:[" + expected + "] not to be part of [" + this._getText(el) + "]");
    return true;
};
Sahi.prototype._getSelectedText = function (el) {
	return this.getSelectBoxText(el, true);
}
Sahi.prototype.getSelectBoxText = function (el, selectedOnly) {
	if (selectedOnly && el.type == "select-one") return this._getText(el.options[el.selectedIndex]);
	var ar = [];
	var opts = el.options;
    var l = el.options.length;
    for (var i=0; i<l; i++){
    	var opt = opts[i];
    	if (!selectedOnly || opt.selected){
    		ar.push(this._getText(opt));
    	}
    }
    if (ar.length > 0) return ar;
};
//Sahi.prototype._option = function (el, val) {
//    var o = this.getArrayNameAndIndex(id);
//    var imgIx = o.index;
//
//    var opts = el.options;
//    var l = opts.length;
//    var optionEl = null;
//    if (typeof val == "string" || val instanceof RegExp){
//        for (var i = 0; i < l; i++) {
//        	var opt = opts[i];
//            if (this.areEqual(opt, "sahiText", val) ||
//            	this.areEqual(opt, "value", val) ||
//                this.areEqual(opt, "id", val)) {
//                optionEl = opt;
//            }
//        }
//    } else if (typeof val == "number" && opts.length > val){
//        optionEl = opts[val];
//    }    
//    return optionEl;
//};
Sahi.prototype._getText = function (el) {
    this.checkNull(el, "_getText");
    if (el && el.type){
    	if ((el.type=="text" || el.type=="password" || (el.type=="button" && this.areTagNamesEqual(el.tagName, "INPUT")) || el.type=="textarea" || el.type=="submit") && el.value) return el.value;
//    	if (el.type=="select-one" || el.type == "select-multiple") return this._getSelectedText(el);
    }
    return this.trim(this._getTextNoTrim(el));
};
Sahi.prototype._getValue = function (el) {
	return el.value;
};
Sahi.prototype._getAttribute = function (el, attr) {
	return el[attr];
};
Sahi.prototype._getTextNoTrim = function (el) {
    this.checkNull(el, "_getTextNoTrim");
    if (el.tagName) {
    	if (el.tagName.toLowerCase() == "option") return el.text.replace(/\u00A0/g, ' ');
    	else if (el.type=="select-one" || el.type == "select-multiple") {
    		return this.getSelectBoxText(el, false);
    	}
    }
    if (this._isIE() || this.isSafariLike()) return el.innerText;
    var html = el.innerHTML;
    if (!html) return el.textContent; // text nodes
    if (html.indexOf("<br") == -1 && html.indexOf("<BR") == -1) return el.textContent;
    if (document.createElement){
    	var x = document.createElement(el.tagName);
    	x.innerHTML = el.innerHTML.replace(/<br[\/]*>/ig, " ");
    	return x.textContent;
    }
    return el.textContent;
};
Sahi.prototype._getCellText = Sahi.prototype._getText;
Sahi.prototype.getRowIndexWith = function (txt, tableEl) {
    var r = this.getRowWith(txt, tableEl);
    return (r == null) ? -1 : r.rowIndex;
};
Sahi.prototype.getRowWith = function (txt, tableEl) {
    for (var i = 0; i < tableEl.rows.length; i++) {
        var r = tableEl.rows[i];
        for (var j = 0; j < r.cells.length; j++) {
            if (this.areEqualParams(this._getText(r.cells[j]),  this.checkRegex(txt))) {
                return r;
            }
        }
    }
    return null;
};
Sahi.prototype.getColIndexWith = function (txt, tableEl) {
    for (var i = 0; i < tableEl.rows.length; i++) {
        var r = tableEl.rows[i];
        for (var j = 0; j < r.cells.length; j++) {
            if (this.areEqualParams(this._getText(r.cells[j]), this.checkRegex(txt))) {
                return j;
            }
        }
    }
    return -1;
};
Sahi.prototype._alert = function (s) {
    return this.callFunction(this.real_alert, window, s);
};
Sahi.prototype._lastAlert = function () {
    var v = this.getServerVar("lastAlertText");
    return v;
};
Sahi.prototype._clearLastAlert = function () {
	this.setServerVar("lastAlertText", null);
};
Sahi.prototype._clearLastConfirm = function () {
	this.setServerVar("lastConfirmText", null);
};
Sahi.prototype._clearLastPrompt = function () {
	this.setServerVar("lastPromptText", null);
};
Sahi.prototype._eval = function (s) {
	this.xyoffsets = new Object();
	this.alignY = this.alignX = null;
    return eval(s);
};
Sahi.prototype._call = function (s) {
    return s;
};
Sahi.prototype._random = function (n) {
    return Math.floor(Math.random() * (n + 1));
};
Sahi.prototype._savedRandom = function (id, min, max) {
    if (min == null) min = 0;
    if (max == null) max = 10000;
    var r = this.getServerVar("srandom" + id);
    if (r == null || r == "") {
        r = min + this._random(max - min);
        this.setServerVar("srandom" + id, r);
    }
    return r;
};
Sahi.prototype._resetSavedRandom = function (id) {
    this.setServerVar("srandom" + id, "");
};


Sahi.prototype._expectConfirm = function (text, value) {
    this.setServerVar("confirm: "+text, value);
};
Sahi.prototype._saveDownloadedAs = function(filePath){
    this._callServer("SaveAs_saveLastDownloadedAs", "destination="+this.encode(filePath));
};
Sahi.prototype._lastDownloadedFileName = function(){
    var fileName = this._callServer("SaveAs_getLastDownloadedFileName");
    if (fileName == "-1") return null;
    return fileName;
};
Sahi.prototype._clearLastDownloadedFileName = function(){
    this._callServer("SaveAs_clearLastDownloadedFileName");
};
Sahi.prototype._saveFileAs = function(filePath){
    this._callServer("SaveAs_saveTo", filePath);
};
Sahi.prototype.callFunction = function(fn, obj, args){
    if (fn.apply){
        return fn.apply(obj, [args]);
    }else{
        return fn(args);
    }
};
Sahi.prototype._lastConfirm = function () {
    var v = this.getServerVar("lastConfirmText");
    return v;
};
Sahi.prototype._lastPrompt = function () {
    var v = this.getServerVar("lastPromptText");
    return v;
};

Sahi.prototype._expectPrompt = function (text, value) {
    this.setServerVar("prompt: "+text, value);
};
Sahi.prototype._prompt = function (s) {
    return this.callFunction(this.real_prompt, window, s);
};
Sahi.prototype._confirm = function (s) {
    return this.callFunction(this.real_confirm, window, s);
};
Sahi.prototype._print = function (s){
    return this.callFunction(this.real_print, window, s);
};
Sahi.prototype._printCalled = function (){
    return this.getServerVar("printCalled");
};
Sahi.prototype._clearPrintCalled = function (){
    return this.setServerVar("printCalled", null);
};

Sahi.prototype._cell = function (id, row, col) {
    if (id == null) return null;
    if (row == null && col == null) {
        return this.findCell(id);
    }
    if (row != null && (row.type == "_in" || row.type == "_near")){
    	return this.findCell(id, this.getDomRelAr(arguments));
    }

    var rowIx = row;
    var colIx = col;
    if (typeof row == "string" || row instanceof RegExp) {
        rowIx = this.getRowIndexWith(row, id);
        if (rowIx == -1) return null;
    }
    if (typeof col == "string" || col instanceof RegExp) {
        colIx = this.getColIndexWith(col, id);
        if (colIx == -1) return null;
    }
    if (id.rows[rowIx] == null) return null;
    return id.rows[rowIx].cells[colIx];
};
Sahi.prototype.x_row = function (tableEl, rowIx) {
    if (typeof rowIx == "string") {
        return this.getRowWith(rowIx, tableEl);
    }
    if (typeof rowIx == "number") {
        return tableEl.rows[rowIx];
    }
    return null;
};
Sahi.prototype._containsHTML = function (el, htm) {
    return this.contains(el.innerHTML, htm)
};
Sahi.prototype._containsText = function (el, txt) {
    return this.contains(this._getText(el), txt)
};
Sahi.prototype.contains = function (orig, substr) {
	substr = this.checkRegex(substr);
    if (substr instanceof RegExp)
        return orig.match(substr) != null;
    return orig.indexOf(substr) != -1;
}
	
Sahi.prototype._contains = function (parent, child) {
	if (parent == null) return false;
	var c = child;
    while (true){
    	if (c == parent) return true;
    	if (c == null || c == c.parentNode) return false;
    	c = c.parentNode;
    }
};
Sahi.prototype._popup = function (n) {
    if (this.top().name == n || this.getTitle() == n) {
        return this.top();
    }
    throw new SahiNotMyWindowException(n);
};
Sahi.prototype._domain = function (n) {
    if (document.domain == n) {
        return this.top();
    }
    throw new SahiNotMyDomainException(n);
};
Sahi.prototype._log = function (s, type) {
    if (!type) type = "info";
    this.logPlayBack(s, type);
};
Sahi.prototype._navigateTo = function (url, force) {
    if (force || this.top().location.href != url){
        //this.top().location.href = url;
        window.setTimeout("_sahi.top().location.href = '"+url.replace(/'/g, "\\'")+"'", 0); // for _navigateTo(relUrl) from controller
    }
};
Sahi.prototype._callServer = function (cmd, qs) {
    return this.sendToServer("/_s_/dyn/" + cmd + (qs == null ? "" : ("?" + qs)));
};
Sahi.prototype._removeMock = function (pattern) {
    return this._callServer("MockResponder_remove", "pattern=" + pattern);
};
Sahi.prototype._addMock = function (pattern, clazz) {
    if (clazz == null) clazz = "MockResponder_simple";
    return this._callServer("MockResponder_add", "pattern=" + pattern + "&class=" + clazz);
};
Sahi.prototype._mockImage = function (pattern, clazz) {
    if (clazz == null) clazz = "MockResponder_mockImage";
    return this._callServer("MockResponder_add", "pattern=" + pattern + "&class=" + clazz);
};
Sahi.prototype._debug = function (s) {
    return this._callServer("Debug_toOut", "msg=Debug: " + this.encode(s));
};
Sahi.prototype._debugToErr = function (s) {
    return this._callServer("Debug_toErr", "msg=" + this.encode(s));
};
Sahi.prototype._debugToFile = function (s, file) {
    if (file == null) return;
    return this._callServer("Debug_toFile", "msg=" + this.encode(s) + "&file=" + this.encode(file));
};
Sahi.prototype._enableKeepAlive = function () {
    this.sendToServer('/_s_/dyn/Configuration_enableKeepAlive');
};
Sahi.prototype._disableKeepAlive = function () {
    this.sendToServer('/_s_/dyn/Configuration_disableKeepAlive');
};
Sahi.prototype.getWin = function (el) {
    if (el == null) return self;
    if (el.nodeName.indexOf("document") != -1) return this.getFrame1(this.top(), el);
    return this.getWin(el.parentNode);
};
// finds window to which a document belongs
Sahi.prototype.getFrame1 = function (win, doc) {
    if (win.document == doc) return win;
    var frs = win.frames;
    for (var j = 0; j < frs.length; j++) {
        var sub = this.getFrame1(frs[j], doc);
        if (sub != null) {
            return sub;
        }
    }
    return null;
};
Sahi.prototype.areEqual2 = function (el, param, value) {
    if (param == "sahiText") {
        var str = this._getTextNoTrim(el);
        if (value instanceof RegExp){
        	str = this.trim(str);
            return str != null && str.match(value) != null;
        }
        if (str.length - value.length > 200) return false;
        return (this.trim(str) == this.trim(value));
    }
    else {
    	return this.areEqualParams(el[param], value);
    }
};
Sahi.prototype.areEqualParams = function(actual, input){
	if (input instanceof RegExp)
        return actual != null && (typeof actual == "string") && actual.match(input) != null;
    return (actual == input);
}
Sahi.prototype.areEqual = function (el, param, value) {
	if (typeof param == "function"){
		return this.areEqualParams(this.callFunction(param, this, el), value);
	}
	if (param == null || param.indexOf("|") == -1)
		return this.areEqual2(el, param, value);
    var params = param.split("|");
    for (var i=0; i<params.length; i++){
        var param = params[i];
        if (this.areEqual2(el, param, value)) return true;
    }
    return false;
};
Sahi.prototype.findLink = function (id, inEl) {
	var inEl = inEl ? inEl : this.top();
    var res = this.getBlankResult();
    var retVal = this.findImageHelper(id, inEl, res, "sahiText", false).element;
    if (retVal != null) return retVal;

    res = this.getBlankResult();
    return this.findImageHelper(id, inEl, res, "id", false).element;
};
Sahi.prototype.findImage = function (id, inEl) {
	inEl = inEl ? inEl : this.top();
    var res = this.getBlankResult();
    var retVal = this.findImageHelper(id, inEl, res, "title|alt", true).element;
    if (retVal != null) return retVal;

    res = this.getBlankResult();
    retVal = this.findImageHelper(id, inEl, res, "id", true).element;
    if (retVal != null) return retVal;

    retVal = this.findImageHelper(id, inEl, res, this.getImageSrc, true).element;
    return retVal;
};
Sahi.prototype.getImageSrc = function(el){
	var src = el.src;
	return src.substring(src.lastIndexOf("/")+1);
};
Sahi.prototype.findImageHelper = function (id, win, res, param, isImg) {
    if ((typeof id) == "number") {
        res.cnt = 0;
        res = this.findImageByIx(id, win, res, isImg);
        return res;
    } else {
        var o = this.getArrayNameAndIndex(id);
        var imgIx = o.index;
        var fetch = o.name;
        var doc = this.getDoc(win);
	    var imgs = isImg ? this.getElementsByTagName("IMG", doc) : this.getElementsByTagName("A", doc);
        for (var i = 0; i < imgs.length; i++) {
            if (this.areEqual(imgs[i], param, fetch)) {
                res.cnt++;
                if (res.cnt == imgIx || imgIx == -1) {
                    res.element = imgs[i];
                    res.found = true;
                    return res;
                }
            }
        }
    }

    var frs = win.frames;
    if (frs) {
        for (var j = 0; j < frs.length; j++) {
        	try{
        		res = this.findImageHelper(id, frs[j], res, param, isImg);
        	}catch(diffDomain){}
            if (res && res.found) return res;
        }
    }
    return res;
};

Sahi.prototype.findImageByIx = function (ix, win, res, isImg) {
    var doc = this.getDoc(win);
    var imgs = isImg ? this.getElementsByTagName("IMG", doc) : this.getElementsByTagName("A", doc);
//    var imgs = isImg ? win.document.images : win.document.getElementsByTagName("A");
    if (imgs[ix - res.cnt]) {
        res.element = imgs[ix - res.cnt];
        res.found = true;
        return res;
    }
    res.cnt += imgs.length;
    var frs = win.frames;
    if (frs) {
        for (var j = 0; j < frs.length; j++) {
            try{
            	res = this.findImageByIx(ix, frs[j], res, isImg);
        	}catch(diffDomain){}
            if (res && res.found) return res;
        }
    }
    return res;
};

Sahi.prototype.findLinkIx = function (id, toMatch) {
    var res = this.getBlankResult();
    if (id == null || id == "") {
        var retVal = this.findImageIxHelper(id, toMatch, this.top(), res, null, false).cnt;
        if (retVal != -1) return retVal;
    }

    res = this.getBlankResult();
    var retVal = this.findImageIxHelper(id, toMatch, this.top(), res, "sahiText", false).cnt;
    if (retVal != -1) return retVal;

    res = this.getBlankResult();
    return this.findImageIxHelper(id, toMatch, this.top(), res, "id", false).cnt;
};
Sahi.prototype.findImageIx = function (id, toMatch) {
    var res = this.getBlankResult();
    if (id == null || id == "") {
        var retVal = this.findImageIxHelper(id, toMatch, this.top(), res, null, true).cnt;
        if (retVal != -1) return retVal;
    }

    res = this.getBlankResult();
    var retVal = this.findImageIxHelper(id, toMatch, this.top(), res, this.getImageSrc, true).cnt;
    if (retVal != -1) return retVal;

    res = this.getBlankResult();
    var retVal = this.findImageIxHelper(id, toMatch, this.top(), res, "title|alt", true).cnt;
    if (retVal != -1) return retVal;

    res = this.getBlankResult();
    return this.findImageIxHelper(id, toMatch, this.top(), res, "id", true).cnt;
};
Sahi.prototype.findImageIxHelper = function (id, toMatch, win, res, param, isImg) {
    if (res && res.found) return res;

    var imgs = isImg ? win.document.images : this.getElementsByTagName("A", win.document);
    for (var i = 0; i < imgs.length; i++) {
        if (param == null || this.areEqual(imgs[i], param, id)) {
            res.cnt++;
            if (imgs[i] == toMatch) {
                res.found = true;
                return res;
            }
        }
    }
    var frs = win.frames;
    if (frs) {
        for (var j = 0; j < frs.length; j++) {
            try{
            	res = this.findImageIxHelper(id, toMatch, frs[j], res, param, isImg);
            }catch(diffDomain){}
            if (res && res.found) return res;
        }
    }
    return res;
};
Sahi.prototype.findElementById = function (win, id) {
    var res = null;
    if (win.document.getElementById(id) != null) {
        return win.document.getElementById(id);
    }
    var frs = win.frames;
    if (frs) {
        for (var j = 0; j < frs.length; j++) {
            try{
            	res = this.findElementById(frs[j], id);
            }catch(diffDomain){}
            if (res) return res;
        }
    }
    return res;
};
Sahi.prototype.findFormElementByIndex = function (ix, win, type, res, tagName) {
    var els = this.getElementsByTagName(tagName, this.getDoc(win));
    els = this.isWithinBounds(els);
    for (var j = 0; j < els.length; j++) {
        var el = els[j];
        if (el != null && this.areEqualTypes(this.getElementType(el), type) && this.checkElementVisible(el)) {
            res.cnt++;
            if (res.cnt == ix) {
                res.element = el;
                res.found = true;
                return res;
            }
        }
    }
    var frs = win.frames;
    if (frs) {
        for (var j = 0; j < frs.length; j++) {
        	try{
        		res = this.findFormElementByIndex(ix, frs[j], type, res, tagName);
        	}catch(diffDomain){}
            if (res && res.found) return res;
        }
    }
    return res;
};

Sahi.prototype.getElementType = function (el) {
	var t1 = el.getAttribute("type");
	if (el.type == "text" && el.type != t1) {
		if (this.findInArray(this.textboxTypes, t1) == -1) return "text";
		return t1;
	}
	return el.type;
}

Sahi.prototype.findElementHelper = function (id, win, type, res, param, tagName) {
    if ((typeof id) == "number") {
        res = this.findFormElementByIndex(id, win, type, res, tagName);
        if (res.found) return res;
    } else {
    	// for elements with name like usernames[]
    	var doc = this.getDoc(win);
        var els = this.getElementsByTagName(tagName, doc);
        els = this.isWithinBounds(els);
        for (var j = 0; j < els.length; j++) {
        	var el = els[j];
            if (this.areEqualTypes(this.getElementType(el), type) && this.areEqual(el, param, id) && this.checkElementVisible(el)) {
                res.element = el;
                res.found = true;
                return res;
            }
        }

        // normal
        var o = this.getArrayNameAndIndex(id);
        var ix = o.index;
        var fetch = o.name;
        els = this.getElementsByTagName(tagName, this.getDoc(win));
        els = this.isWithinBounds(els);
        for (var j = 0; j < els.length; j++) {
        	var el = els[j];
        	if (this.areEqualTypes(this.getElementType(el), type) && this.areEqual(el, param, fetch) && this.checkElementVisible(el)) {
                res.cnt++;
                if (res.cnt == ix || ix == -1) {
                    res.element = el;
                    res.found = true;
                    return res;
                }
            }
        }


    }
    var frs = win.frames;
    if (frs) {
        for (var j = 0; j < frs.length; j++) {
        	try{
        		res = this.findElementHelper(id, frs[j], type, res, param, tagName);
        	}catch(diffDomain){}
            if (res && res.found) return res;
        }
    }
    return res;
};
Sahi.prototype.findElementIxHelper = function (id, type, toMatch, win, res, param, tagName) {
    if (res && res.found) return res;
    var els = this.getElementsByTagName(tagName, this.getDoc(win));
    for (var j = 0; j < els.length; j++) {
        if (this.areEqualTypes(this.getElementType(els[j]), type) && this.areEqual(els[j], param, id) && this.checkElementVisible(els[j])) {
            res.cnt++;
            if (els[j] == toMatch) {
                res.found = true;
                return res;
            }
        }
    }
    var frs = win.frames;
    if (frs) {
        for (var j = 0; j < frs.length; j++) {
        	try{
        		res = this.findElementIxHelper(id, type, toMatch, frs[j], res, param, tagName);
            }catch(diffDomain){}
            if (res && res.found) return res;
        }
    }
    return res;
};
Sahi.prototype.areEqualTypes = function (type1, type2) {
    if (type1 == type2) return true;
    return (type1.indexOf("select") != -1 && type2.indexOf("select") != -1);
};
Sahi.prototype.findCell = function (id, inEl) {
	if (!inEl) inEl = this.top();
    var res = this.getBlankResult();
    res = this.findTagHelper(id, inEl, "td", res, "sahiText").element;
    if (res != null) return res;
    var res = this.getBlankResult();
    res = this.findTagHelper(id, inEl, "td", res, "id").element;
    if (res != null) return res;
    res = this.getBlankResult();
    return this.findTagHelper(id, inEl, "td", res, "className").element;
};
Sahi.prototype.getBlankResult = function () {
    var res = new Object();
    res.cnt = -1;
    res.found = false;
    res.element = null;
    return res;
};
Sahi.prototype.getArrayNameAndIndex = function (id) {
    var o = new Object();
    if (!(id instanceof RegExp)) {
    	var m = id.match(/(.*)\[([0-9]*)\]$/);
    	if (m){
	        o.name = this.checkRegex(m[1]);
	        o.index = m[2];
	        return o;
    	}
    }
	o.name = this.checkRegex(id);
	o.index = -1;
    return o;
};
Sahi.prototype.checkRegex = function(s){
	return ((typeof s) == "string" && s.match(this.CHECK_REGEXP)) ?  eval(s) : s;
};
Sahi.prototype.findInForms = function (id, win, type) {
    var fms = win.document.forms;
    if (fms == null) return null;
    for (var j = 0; j < fms.length; j++) {
        var el = this.findInForm(id, fms[j], type);
        if (el != null) return el;
    }
    return null;
};
Sahi.prototype.findInForm = function (name, fm, type) {
    var els = fm.elements;
    var matchedEls = new Array();
    for (var i = 0; i < els.length; i++) {
        var el = els[i];
        if (el.name == name && el.type && this.areEqualTypes(this.getElementType(el), type)) {
            matchedEls[matchedEls.length] = el;
        }
        else if ((el.type == "button" || el.type == "submit") && el.value == name && el.type == type) {
            matchedEls[matchedEls.length] = el;
        }
    }
    return (matchedEls.length > 0) ? (matchedEls.length == 1 ? matchedEls[0] : matchedEls ) : null;
};
Sahi.prototype.findTable = function (id, inEl) {
	var inEl = this.getDomRelAr(arguments);
	if (inEl.length == 0) inEl = this.top();
//	if (!inEl) inEl = this.top();
    var res = this.getBlankResult();
    return this.findTagHelper(id, inEl, "table", res, "id").element;
};
Sahi.prototype._iframe = function (id, inEl) {
	var inEl = this.getDomRelAr(arguments);
	if (inEl.length == 0) inEl = this.top();
//	if (!inEl) inEl = this.top();

    var res = this.getBlankResult();
    var el = this.findTagHelper(id, inEl, "iframe", res, "id").element;
    if (el != null) return el;

    res = this.getBlankResult();
    el = this.findTagHelper(id, inEl, "iframe", res, "name").element;
    if (el != null) return el;
};
// used from lib.js
Sahi.prototype.getArgsAr = function (args, start, end) {
	if (start == null) start = 0;
	if (end == null) end = args.length;
	var ar = []
	for (var i=start; i<end; i++) {
		ar.push(args[i]);
	}
	return ar;
}
Sahi.prototype._count = function (apiType, id, inEl) {
	var upper = 2048;
	var lower = 0;
	var origArgs = this.getArgsAr(arguments, 2);
	var fn = this[apiType];
	if (fn.apply(this, [id].concat(origArgs)) == null) return 0;
	var j=20;
	while (true && j-- >= 0) {
		var diff = Math.floor((upper-lower)/2);
		if (diff == 0) return lower + 1;
		var lookAt = lower + diff;
		var id2 = id + "[" + lookAt + "]";
		var args = [id2].concat(origArgs);
		var el = fn.apply(this, args);
		if (el == null) {
			upper = lookAt;
		} else {
			lower = lookAt;
		}
		if (upper == lower) return lower + 1;
	}
	return 0;
};
// used on browser
Sahi.prototype._collect = function (apiType, id, inEl) {
	var args = this.getArgsAr(arguments, 2)
	var els = [];
	var origArgs = this.getArgsAr(arguments, 2);
	var fn = this[apiType];	
	for (var i=0; i<2048; i++) {
		var id2 = id + "[" + i + "]";
		var el = fn.apply(this, args);
		if (el == null) break;
		els.push(el);
	}
	return els;
}
Sahi.prototype._rte = Sahi.prototype._iframe;
Sahi.prototype.findResByIndexInList = function (ix, win, type, res) {
    var tags = this.getElementsByTagName(type, this.getDoc(win));
    tags = this.isWithinBounds(tags);
    if (tags[ix - res.cnt]) {
        res.element = tags[ix - res.cnt];
        res.found = true;
        return res;
    }
    res.cnt += tags.length;
    var frs = win.frames;
    if (frs) {
        for (var j = 0; j < frs.length; j++) {
        	try{
        		res = this.findResByIndexInList(ix, frs[j], type, res);
            }catch(diffDomain){}
            if (res && res.found) return res;
        }
    }
    return res;
};
Sahi.prototype.isWithinBounds = function (tags){
	if (this.alignX == null && this.alignY == null) return tags;
	var filtered = []
	for (var i=0; i<tags.length; i++){
		var add = true;
		var tag = tags[i];
		var xy = this.findPos(tag);
		if (this.alignX && !this.withinOffset(xy[0], this.alignX, this.alignXOuter, this.underOffset)){
			add = false;
		} else if (this.belowY && xy[1] < this.belowY) {
			add = false;
		}
//		if (this.alignY && !this.withinOffset(this.alignY, xy[1], 20)){
//			add = false;
//		}
		if (add) filtered[filtered.length] = tag;
	}
	return filtered;
}
Sahi.prototype.withinOffset = function(actual, left, right, offset){
	return actual >= (left - offset) && actual < (right + offset); 
//	return Math.abs(a - b) <= offset; 
}

Sahi.prototype.findTagHelper = function (id, win, type, res, param) {
    if ((typeof id) == "number") {
        res.cnt = 0;
        res = this.findResByIndexInList(id, win, type, res);
        return res;
    } else {
        var o = this.getArrayNameAndIndex(id);
        var ix = o.index;
        var fetch = o.name;
        var tags = this.getElementsByTagName(type, this.getDoc(win));
        tags = this.isWithinBounds(tags);
        if (tags) {
            for (var i = 0; i < tags.length; i++) {
                if (this.areEqual(tags[i], param, fetch)) {
                	var el = tags[i];
                	if ((param == "sahiText" && (this.innerMost(el, fetch, type) != el)) || !this.checkElementVisible(el)){
                		continue;
                	}
                    res.cnt++;
                    if (res.cnt == ix || ix == -1) {
                        res.element = el;
                        res.found = true;
                        return res;
                    }
                }
            }
        }
    }

    var frs = win.frames;
    if (frs) {
        for (var j = 0; j < frs.length; j++) {
            try{
            	res = this.findTagHelper(id, frs[j], type, res, param);
            }catch(diffDomain){}
            if (res && res.found) return res;
        }
    }
    return res;
};
Sahi.prototype.findTagIxHelper = function (id, toMatch, win, type, res, param) {
    if (res && res.found) return res;

    var tags = this.getElementsByTagName(type, this.getDoc(win));
    if (tags) {
        for (var i = 0; i < tags.length; i++) {
            if ((param == null || this.areEqual(tags[i], param, id)) && this.checkElementVisible(tags[i])) {
                res.cnt++;
                if (tags[i] == toMatch) {
                    res.found = true;
                    return res;
                }
            }
        }
    }
    var frs = win.frames;
    if (frs) {
        for (var j = 0; j < frs.length; j++) {
        	try{
        		res = this.findTagIxHelper(id, toMatch, frs[j], type, res, param);
            }catch(diffDomain){}
            if (res && res.found) return res;
        }
    }
    return res;
};
Sahi.prototype.canSimulateClick = function (el) {
    return (el.click || el.dispatchEvent);
};
Sahi.prototype.recordStep = function (step) {
	this.showStepsInController(step, true);
	this.sendToServer('/_s_/dyn/' + this.recorderClass + '_record?step=' + this.encode(step));
}
Sahi.prototype.isRecording = function () {
    if (this.topSahi()._isRecording == null)
        this.topSahi()._isRecording = this.sendToServer("/_s_/dyn/SessionState_isRecording") == "1";
    return this.topSahi()._isRecording;
};
Sahi.prototype.createCookie = function (name, value, days, path, domain, secure){
    var expires = "";
    if (days) {
        var date = new Date();
        date.setTime(date.getTime() + (days * 24 * 60 * 60 * 1000));
        expires = "; expires=" + date.toGMTString();
    }
    var s = name + "=" + value + expires;
    s += "; path=" + (path ? path : "/");
    if (domain) s += "; domain=" + domain;
    if (secure) s += "; secure=" + secure;
    window.document.cookie = s;
};
Sahi.prototype._createCookie = Sahi.prototype.createCookie;
Sahi.prototype.readCookie = function (name){
	return this.sendToServer("/_s_/dyn/Cookies_read?name=" + name);
};
Sahi.prototype._cookie = Sahi.prototype.readCookie;
Sahi.prototype.eraseCookie = function (name, path){
	return this.sendToServer("/_s_/dyn/Cookies_delete?name=" + name + (path ? ("&path=" + encodeURIComponent(path)) : ""));
};
Sahi.prototype._deleteCookie = Sahi.prototype.eraseCookie;
Sahi.prototype._event = function (type, keyCode) {
    this.type = type;
    this.keyCode = keyCode;
};
var SahiAssertionException = function (msgNum, msgText) {
	_sahi.lastAssertStatus = "failure";
    this.messageNumber = msgNum;
    this.messageText = msgText;
    this.exceptionType = "SahiAssertionException";
};
var SahiNotMyWindowException = function (n) {
    this.name = "SahiNotMyWindowException";
    if (n){
        this.message = "Window with name ["+n+"] not found";
    }else{
        this.message = "Base window not found";
    }
};
var SahiNotMyDomainException = function (n) {
    this.name = "SahiNotMyDomainException";
    if (n){
        this.message = "Window with domain ["+n+"] not found";
    }else{
        this.message = "Base domain not found!";
    }
};
Sahi.prototype.onEv = function (e) {
    if (e.handled == true) return; //FF
    if (this.doNotRecord || this.getServerVar("sahiEvaluateExpr") == true) return;
    var targ = this.getKnownTags(this.getTarget(e));
    if (targ.id && targ.id.indexOf("_sahi_ignore_") != -1) return;
    if (e.type == this.triggerType) {
        if (targ.type) {
            var type = targ.type;
            if (type == "text" || type == "textarea" || type == "password"
                || type == "select-one" || type == "select-multiple") return;
        }
    }
	var elInfo = this.identify(targ);
	var ids = elInfo.apis; 
	if (ids.length == 0) return;
	var script = this.getScript(ids, targ);
	if (script == null) return;
	if (this.hasEventBeenRecorded(script)) return; //IE
	this.recordStep(script);
	//this.sendIdsToController(elInfo, "RECORD");
    e.handled = true;
    //this.showInController(ids[0]);
};
Sahi.prototype.showStepsInController = function (s, isRecorded) {
    try {
        var c = this.getController();
        if (c) {
        	c.showSteps(s, isRecorded);
        }
    } catch(ex2) {
        // throw ex2;
    }
};
Sahi.prototype.showInController = function (info) {
	this.showStepsInController(this.getScript([info]));
};
Sahi.prototype.hasEventBeenRecorded = function (qs) {
    var now = (new Date()).getTime();
    if (qs == this.lastQs && (now - this.lastTime) < 500) return true;
    this.lastQs = qs;
    this.lastTime = now;
    return false;
};
Sahi.prototype.getPopupName = function () {
    var n = null;
    if (this.isPopup()) {
        n = this.top().name;
        if (!n || n == "") {
            try{
                n = this.getTitle();
            }catch(e){}
        }
    }
    return n ? n : "";
};
Sahi.prototype._title = function(){
	return this.getTitle();
}
Sahi.prototype.getTitle = function(){
	return this.trim(this.top().document.title);	
}
Sahi.prototype.isPopup = function () {
    if (this.top().opener == null) return false;
    if (_sahi.top().opener.closed) return true;
    try{
        var x = _sahi.top().opener._sahi;
    }catch(openerFromDiffDomain){
        return true;
    }
    if (_sahi.top().opener._sahi != null && _sahi.top().opener._sahi.top() != window._sahi.top()){
        return true;
    }
    return false;
};
Sahi.prototype.addWait = function (time) {
    var val = parseInt(time);
    if (("" + val) == "NaN" || val < 200) throw new Error();
    this.showInController(new AccessorInfo("", "", "", "wait", time));
    //    this.sendToServer('/_s_/dyn/Recorder_record?event=wait&value='+val);
};
Sahi.prototype.mark = function (s) {
    this.showInController(new AccessorInfo("", "", "", "mark", s));
};
Sahi.prototype.doAssert = function (s, v) {
    try {
    	var el = eval(this.addSahi(s));
    	if ((typeof el) == "string" || (typeof el) == "boolean" || (typeof el) == "number"){
    		var steps = "_assertEqual(" + this.quoted(v)+ ", " + s + ");";
    		this.addPopupDomainPrefixes(steps);
    		this.showStepsInController(steps);
    	}
    	else if (el){    		
    		var assertions = this.identify(el).assertions;
    		var steps = assertions.join("\n");
    		steps = steps.replace(/<accessor>/g, s);
    		steps = steps.replace(/<value>/g, this.toJSON(v));
    		steps = steps.replace(/<popup>/g, this.getPopupDomainPrefixes())
    		this.showStepsInController(steps);
    	}
        //this.showInController(lastAccessedInfo);
        //      this.sendToServer('/_s_/dyn/Recorder_record?'+getSahiPopUpQS()+this.getAccessorInfoQS(this.top()._lastAccessedInfo, true));
    } catch(ex) {
        this.handleException(ex);
    }
};
Sahi.prototype.getTarget = function (e) {
    var targ;
    if (!e) e = window.event;
    var evType = e.type;
    if (e.target) targ = e.target;
    else if (e.srcElement) targ = e.srcElement;
    if (targ.nodeType == 3) // defeat Safari bug
        targ = targ.parentNode;  
    return targ;
};
var AccessorInfo = function (accessor, shortHand, type, event, value, valueType, relationStr) {
    this.accessor = accessor;
    this.shortHand = shortHand;
    this.type = type;
    this.event = event;
    this.value = value;
    this.valueType = valueType;
    this.relationStr = relationStr;
};

Sahi.prototype.getAccessorInfoQS = function (ai, isAssert) {
    if (ai == null || ai.event == null) return;
    var s = "event=" + (isAssert ? "assert" : ai.event);
    s += "&accessor=" + this.encode(this.convertUnicode(ai.accessor));
    s += "&shorthand=" + this.encode(this.convertUnicode(ai.shortHand));
    s += "&type=" + ai.type;
    if (ai.value) {
        s += "&value=" + this.encode(this.convertUnicode(ai.value));
    }
    return s;
};
Sahi.prototype.addHandlersToAllFrames = function (win) {
    var fs = win.frames;
	try{
		this.addHandlers(win);
	}catch(e){}
    if (fs && fs.length > 0) {
        for (var i = 0; i < fs.length; i++) {
        	try{
        		this.addHandlersToAllFrames(fs[i]);
        	}catch(e){}
        }
    }
};
Sahi.prototype.docEventHandler = function (e) {
    if (!e) e = window.event;
    var t = this.getKnownTags(this.getTarget(e));
    if (t) this.attachEvents(t);
};
Sahi.prototype.addHandlers = function (win) {
    if (!win) win = self;
    var doc = win.document;
    this.addWrappedEvent(doc, "keyup", this.docEventHandler);
    this.addWrappedEvent(doc, "mousemove", this.docEventHandler);
};
Sahi.prototype.attachEvents = function (el) {
	if (el.hasAttached) return;
    var tagName = el.tagName.toLowerCase();
    if (this.isFormElement(el)) {
        this.attachFormElementEvents(el);
    } else {
        this.attachImageEvents(el);
    }
    el.hasAttached = true;
};
Sahi.prototype.attachFormElementEvents = function (el) {
    var type = el.type;
    var wrapped = this.wrappedOnEv; 
    if (el.onchange == wrapped || el.onblur == wrapped || el.onclick == wrapped) return;
    if (type == "text" || type == "file" || type == "textarea" || type == "password") {
        this.addEvent(el, "change", wrapped);
    } else if (type == "select-one" || type == "select-multiple") {
        this.addEvent(el, "change", wrapped);
    } else if (type == "button" || type == "submit" || type == "reset" || type == "checkbox" || type == "radio" || type == "image") {
        this.addEvent(el, this.triggerType, wrapped);
    }
};
Sahi.prototype.attachLinkEvents = function (el) {
    this.addWrappedEvent(el, this.triggerType, this.onEv);
};
Sahi.prototype.attachImageEvents = function (el) {
    this.addWrappedEvent(el, this.triggerType, this.onEv);
};
Sahi.prototype.addWrappedEvent = function (el, ev, fn) {
	this.addEvent(el, ev, this.wrap(fn));
};
Sahi.prototype.addEvent = function (el, ev, fn) {
    if (!el) return;
    if (el.attachEvent) {
        el.attachEvent("on" + ev, fn);
    } else if (el.addEventListener) {
        el.addEventListener(ev, fn, true);
    }
};
Sahi.prototype.removeEvent = function (el, ev, fn) {
    if (!el) return;
    if (el.attachEvent) {
        el.detachEvent("on" + ev, fn);
    } else if (el.removeEventListener) {
        el.removeEventListener(ev, fn, true);
    }
};
Sahi.prototype.setRetries = function (i) {
    this.sendToServer("/_s_/dyn/Player_setRetries?retries="+i);
    //this.setServerVar("sahi_retries", i);
};
Sahi.prototype.getRetries = function () {
    var i = parseInt(this.sendToServer("/_s_/dyn/Player_getRetries"));
    return ("" + i != "NaN") ? i : 0;
};
Sahi.prototype.getExceptionString = function (e)
{
    var stack = e.isSahiError ? "" : ("\n" + (e.stack ? e.stack : "No trace available"));
    return e.name + ": " + e.message + stack;
};

Sahi.prototype.onError = function (msg, url, lno) {
    try {
        var debugInfo = "Javascript error on page";
        if (!url) url = "";
        if (!lno) lno = "";
        var jsMsg = msg + " (" + url + ":" + lno + ")";
        if (msg && msg.indexOf("Access to XPConnect service denied") == -1) { //FF hack
            this.setJSError(jsMsg, lno);
        }
        if (this.prevOnError && this.prevOnError != this.onError){
        	this.prevOnError(msg, url, lno);
        }
    } catch(swallow) {
    }
};
Sahi.prototype.setJSError = function (msg, lno) {
    this.__jsError = {'message':msg, 'lineNumber':lno};
};
Sahi.prototype.openWin = function (e) {
    try {
        if (!e) e = window.event;
        this.controller = window.open("", "_sahiControl", this.getWinParams(e));
        var diffDom = false;
        try {
            var checkDiffDomain = this.controller.document.domain;
        } catch(domainInaccessible) {
            diffDom = true;
        }
        if (diffDom || !this.controller.isWinOpen) {
            this.controller = window.open(this.controllerURL, "_sahiControl", this.getWinParams(e));
        }
        if (this.controller) this.controller.opener = window;
        if (e) this.controller.focus();
    } catch(ex) {
        this.handleException(ex);
    }
};
Sahi.prototype.openController = Sahi.prototype.openWin;
Sahi.prototype.closeController = function(){
    var controlWin = this.getController();
    if (controlWin && !controlWin.closed) {
    	controlWin.close();
    }
};

Sahi.prototype.getWinParams = function (e) {
    var positionParams = "";
    
    var x = e ? e.screenX - 40 : window.screen.width - this.controllerWidth - 50;
    var y = e ? e.screenY - 60 : 100;
    
    if (this._isIE()) positionParams = ",left=" + x + ",top=" + y;
    else positionParams = ",screenX=" + x + ",screenY=" + y;
    
    return "height="+ this.controllerHeight +"px,width="+ this.controllerWidth +"px,resizable=yes,toolbar=no,status=no" + positionParams;
};
Sahi.prototype.getController = function () {
    var controller = this.topSahi().controller;
    if (controller && !controller.closed) return controller;
};
Sahi.prototype.openControllerWindow = function (e) {
    if (!e) e = window.event;
    if (!this.isHotKeyPressed(e)) return true;
    this.topSahi().openWin(e);
    return true;
};
Sahi.prototype.isHotKeyPressed = function (e) {
    return ((this.hotKey == "SHIFT" && e.shiftKey)
        || (this.hotKey == "CTRL" && e.ctrlKey)
        || (this.hotKey == "ALT" && e.altKey)
        || (this.hotKey == "META" && e.metaKey));
};
Sahi.prototype.mouseOver = function (e) {
    if (!e) e = window.event;
    try {
        if (this.getTarget(e) == null) return;
        if (!e.ctrlKey) return;
//        var controlWin = this.getController();
//        if (controlWin) {
            var el = this.getTarget(e);
            this.__lastMousedOverElement = el;
            if (this.__queuedMouseOverTimer) window.clearTimeout(this.__queuedMouseOverTimer);
            this.__queuedMouseOverTimer = window.setTimeout(this.wrap(this.queuedMouseOver), 50);
//        }
    } catch(ex) {
        // throw ex;
    }
};
Sahi.prototype.queuedMouseOver = function(){
	var el = this.__lastMousedOverElement;
	try{
		this.identifyAndDisplay(el);
	}catch(e){
	}
};
Sahi.prototype.identifyAndDisplay = function(el){
    var elInfo = this.identify(this.getKnownTags(el));
    if (elInfo == null || elInfo.apis == null) return;
    if (elInfo.apis.length > 0) acc = elInfo.apis[0];
    else acc = null;
    if (acc) {
		var accessors = [];
		for ( var i = 0; i < elInfo.apis.length; i++) {
			accessors[i] = this.escapeDollar(this.getAccessor1(elInfo.apis[i]));
		}
		this.sendIdentifierInfo(accessors, 
    			this.escapeDollar(this.getAccessor1(acc)), 
    			this.escapeValue(acc.value), 
    			this.getPopupDomainPrefixes(el), 
    			elInfo.assertions);
    }
}
Sahi.prototype.sendIdentifierInfo = function(accessors, escapedAccessor, escapedValue, popupName, assertions){
    var controlWin = this.getController();
	controlWin.displayInfo(accessors, escapedAccessor, escapedValue, popupName, assertions);	
}
Sahi.prototype.escapeDollar = function (s) {
    if (s == null) return null;
    return s.replace(/[$]/g, "\\$");
};
Sahi.prototype.getAccessor1 = function (info) {
    if (info == null) return null;
    if ("" == (""+info.shortHand) || info.shortHand == null) return null;
    return info.type + "(" + this.escapeForScript(info.shortHand) + (info.relationStr ? (", " + info.relationStr) : "") + ")"; 
};
Sahi.prototype.escapeForScript = function (s) {
    return this.quoteIfString(s);
};
Sahi.prototype.schedule = function (cmd, debugInfo) {
    if (!this.cmds) return;
    var i = this.cmds.length;
    this.cmds[i] = cmd;
    this.cmdDebugInfo[i] = debugInfo;
};
Sahi.prototype.instant = function (cmd, debugInfo) {
    if (!this.cmds) return;
    var i = this.cmdsLocal.length;
    this.cmdsLocal[i] = cmd;
    this.cmdDebugInfoLocal[i] = debugInfo;
};
Sahi.prototype.play = function () {
	this.execNextStep(false, this.INTERVAL);
};
Sahi.prototype.setWaitForXHRReadyStates = function(s){
	this.waitWhenXHRReadyState1 = s.indexOf("1") != -1;
	this.waitWhenXHRReadyState2 = s.indexOf("2") != -1;
	this.waitWhenXHRReadyState3 = s.indexOf("3") != -1;
}
Sahi.prototype.showOpenXHRs = function (){
    var xs = this.XHRs;
    var s = "";
    for (var i=0; i<xs.length; i++){
        var xsi = xs[i];
        if (xsi){
        	try{
        		if (xsi.readyState!=4){
        			s += "this.XHRs[" + i + "] " + xsi + ": xsi.readyState="+xsi.readyState + "\n";
        		}
        	}catch(e){
        		s += e;
        	}
        }
    }	
    return s;
}
Sahi.prototype.areXHRsDone = function (){
    var xs = this.XHRs;
    var maxTime = this.SAHI_MAX_WAIT_FOR_LOAD * this.INTERVAL;
    var now = new Date();
    for (var i=0; i<xs.length; i++){
        var xsi = xs[i];
        //this.d("xsi.readyState="+xsi.readyState)
        if (xsi){
        	var t = this.XHRTimes[i];
        	if (t == -1) continue;
        	if (now - t > maxTime) {
        		// AJAX request has been around for more than 2 minutes. Consider as Comet
            	this.XHRTimes[i] = -1;
        		continue;
        	}
        	if (xsi.readyState==2 || xsi.readyState==3){
//        		this._debug("xsi.readyState="+xsi.readyState);
        	}
        	if (xsi.readyState==1 && this.waitWhenXHRReadyState1) {
        		return false;
        	}
        	if (xsi.readyState==2 && this.waitWhenXHRReadyState2) {
        		return false;
        	}
        	if (xsi.readyState==3){
        		if (this.waitWhenXHRReadyState3) return false;
        		try{
        			var m = xsi.responseText;
        		}catch(e){return false;}
        	}
        }
    }
    return true;
};
Sahi.prototype.d = function(s){
    this.updateControlWinDisplay(s);
};
Sahi.prototype.areWindowsLoaded = function (win) {
    try {
        if (win.location.href == "about:blank") return true;
    } catch(e) {
        return true;
        // diff domain
    }
    try {
        var fs = win.frames;
        if (!fs || fs.length == 0) {
            try {
                return (this._isIE() && (win.document.readyState == "complete")) || this.loaded;
            } catch(e) {
                //this.d("**********");
                return true;
                //diff domain; don't bother
            }
        } else {
            if (win.name == "listIframe") this.d("fs.length="+fs.length);
            for (var i = 0; i < fs.length; i++) {
                //this.d("" + i + ") " +fs[i].name);
                try{
                    if (""+fs[i].location != "about:blank" && !fs[i]._sahi.areWindowsLoaded(fs[i])) return false;
                }catch(e){
                    // skip if error. can happen for ""+fs[i].location if diff domain.
                }
            }
            if (win.document && this.getElementsByTagName("frameset", win.document).length == 0)
                return (this._isIE() && (win.document.readyState == "complete")) || this.loaded;
            else return true;
        }
    }
    catch(ex) {
        //this.d("2 to " + ex);
        //this._debugToErr("3 pr " + ex.prototype);
        return true;
        //for diff domains.
    }
};
var _isLocal = false;
Sahi._timer = null

Sahi.prototype.execNextStep = function (isStep, interval) {
    if (isStep || !this.isPlaying()) return;
    if (Sahi._timer) window.clearTimeout(Sahi._timer);
    Sahi._timer = window.setTimeout("try{_sahi.ex();}catch(ex){}", interval);
};
Sahi.prototype.hasErrors = function () {
    var i = this.sendToServer("/_s_/dyn/Player_hasErrors");
    return i == "true";
};
Sahi.prototype.getCurrentStep = function () {
    var wasOpened = 1;
    var windowName = "";
    var windowTitle = "";
    try{
        wasOpened = (this.top().opener == null || (this.top().opener._sahi.top() == this.top())) ? 0 : 1;
    }catch(e){
    }
    try{
        windowName = this.top().name;
    }catch(e){
    }
    try{
        windowTitle = this.getTitle();
    }catch(e){
    }
    var v = this.sendToServer("/_s_/dyn/Player_getCurrentStep?derivedName="+this.getPopupName()+
        "&wasOpened="+wasOpened+"&windowName="+this.encode(windowName)+"&windowTitle="+this.encode(windowTitle) 
        + "&domain=" + this.encode(this.getDomainContext()));
    var dec = this.decode(v);
    //this.d(dec);
    return eval("(" + dec + ")");
};
Sahi.prototype.getDomainContext = function(){
	return (this.top() == _sahi_top) ? "" : document.domain;
}
Sahi.prototype.markStepDone = function(stepId, type, failureMsg){
	// duplicate checking needed for IE8 link clicks
	if (this.lastStepInfo && stepId == this.lastStepInfo[0] && type == this.lastStepInfo[1] && failureMsg == this.lastStepInfo[2]) return;
	this.lastStepInfo = [stepId, type, failureMsg];
    var qs = "stepId=" + stepId + (failureMsg ? ("&failureMsg=" + this.encode(failureMsg)) : "") + "&type=" + type;
    this.sendToServer("/_s_/dyn/Player_markStepDone?"+qs);
};
Sahi.prototype.markStepInProgress = function(stepId, type){
    var qs = "stepId=" + stepId + "&type=" + type;
    this.sendToServer("/_s_/dyn/Player_markStepInProgress?"+qs);
};

Sahi.prototype.skipTill = function(n){
    var stepId = -1;
    var lastStepId = -1;
    while(true){
        var stepInfo = this.getCurrentStep();
        var stepId = stepInfo['stepId'];
        if (stepId == null) return;
        if (lastStepId == stepId){
            continue;
        }
        lastStepId = stepId;
        var type = stepInfo['type'];
        if (type == "STOP") {
            this.showStopPlayingMessage();
            this.topSahi()._isPlaying = false;
            return;
        }
        var step = stepInfo['step'];
        if (step == null || step == 'null') continue;
        if (stepId < n){
            this.markStepDone(stepId, "skipped");
        }else{
            break;
        }
    }
};
// This is needed for non Sahi drivers.
Sahi.prototype.ping = function () {
	if (this.controllerMode == "sahi") return;
	if (!this.pinger){
		this.pinger = this.createRequestObject();
		this.pinger.onreadystatechange = function(){
			 if(this.readyState==4){
			    	try{
				    	if ( this.status == 200 ){
				    		var s = this.responseText;
				    		var obj = eval("(" + s + ")");
//				    		alert(s);
				    		_sahi.setState(obj);
				    		window.setTimeout("_sahi.ping()", 1000);
				    	}else{
				    		//_sahi._alert( "HTTP "+req.status+".  An error was encountered: "+ req.statusText );
				    	}	
			    	}catch(e){
			    		//throw(e);
			    	}
				}	
		}	
	}
	this.pinger.open("GET", "/_s_/dyn/SessionState_ping", true);
	this.pinger.send(null);	
}
Sahi.prototype.setState = function(o){
	if (this.topSahi()._isRecording != o.isRecording){
		if (o.isRecording)
			this.startRecording();
		else
			this.stopRecording();
	}
	this.topSahi()._isRecording = o.isRecording;
	
	this.topSahi()._isPaused = o.isPaused;
	
	var wasPlaying = this.topSahi()._isPlaying;
	this.topSahi()._isPlaying = o.isPlaying;	
	if (o.isPlaying && wasPlaying != o.isPlaying){
		this.play();
	}
}
//Sahi.prototype.checkExecution = function(){
//	//this._debug("checkExecution " + (new Date() - this.exLastTimeStamp));
//	if (new Date() - this.exLastTimeStamp > 5000) {
//		this.execNextStep(this.exIsStep, this.interval);
//	}
//}
Sahi.prototype.ex = function (isStep) {
//	this.exLastTimeStamp = new Date();
//	this.exIsStep = isStep;
    var stepId = -1;
    try{
        if (this.isPaused() && !isStep) return;
        //this._debug(this.areWindowsLoaded(this.top()));
        if ((!this.areWindowsLoaded(this.top()) || !this.areXHRsDone()) && this.waitForLoad > 0){
            this.stabilityIndex = 0; 
        }
        if (this.stabilityIndex < this.STABILITY_INDEX){
        	this.stabilityIndex = this.stabilityIndex + 1;
        	this.waitForLoad  = this.waitForLoad - 1;
            if (!this._isIE() && this.waitForLoad % 20 == 0){
                this.check204Response(this.top());
            }
            this.execNextStep(isStep, this.interval);
            return;        	
        }
        if (this.__jsError){
            var msg = this.getJSErrorMessage(this.__jsError);
            this._log(msg, "custom1");
            this.d(this.__jsError.message);
            this.__jsError = null;
        }
        var stepInfo = this.getCurrentStep();
        var type = stepInfo['type'];
        if (type == "STOP") {
            this.showStopPlayingMessage();
            if (!this.isSingleSession) {
	            this.topSahi()._isPlaying = false;
	            //this.stopPlaying();
	            return;
            }
        }
        var step = stepInfo['step'];
        // this._debug(this.getPopupName() + "::" + type+"::"+ new Date());
        if (type == "WAIT"){
        	if (step != null && step != 'null'){
        		var stepId = stepInfo['stepId']
        		this.updateControlWinDisplay(step, stepId);
        		try{
        			var res = eval(step);
        		}catch(e){}
        		if (res) this.markStepDone(stepId, "info");
        	}
			this.execNextStep(isStep, this.interval);
			return;
        }
        if (step == null || step == 'null'){
            this.execNextStep(isStep, this.interval);
            return;
        }
        stepId = stepInfo['stepId'];
        if (this.lastStepId == stepId){
            this.execNextStep(isStep, this.interval);
            return;
        }
        var debugInfo = stepInfo['debugInfo'];
        var origStep = stepInfo['origStep'];
        if (type == 'JSERROR'){
        	var m = (stepInfo.message) ? stepInfo.message : "Logs may have details.";
            this.updateControlWinDisplay("Error in script: "+origStep+"\n" + m);
            return;
        }
        var type = (step.indexOf("_sahi._assert") != -1) ? "success" : "info";
        this.markStepInProgress(stepId, type);
        this.updateControlWinDisplay(origStep, stepId);
        this.reAttachEvents();
    	this.xyoffsets = new Object();
    	this.alignY = this.alignX = null;
    	if (step.indexOf("_sahi._assert") != -1) this.lastAssertStatus = "success";
    	this.currentStepId = stepId;
    	this.currentType = type; 
//    	this._alert(this.loaded);
        eval(step);
        this.lastStepId = stepId;
        this.markStepDone(stepId, type);
        this.waitForLoad = this.SAHI_MAX_WAIT_FOR_LOAD;
        this.interval = this.INTERVAL;
        this.execNextStep(isStep, this.interval);
    }catch(e){
        var retries = this.getRetries();
        if (retries < this.MAX_RETRIES) {
            retries = retries + 1;
            this.setRetries(retries);
            this.interval = this.ONERROR_INTERVAL; //100 * (2^retries);
            this.execNextStep(isStep, this.interval);
            return;
        } else {
            if (e instanceof SahiAssertionException){
                var failureMsg = "Assertion Failed. " + (e.messageText ? e.messageText : "");
                this.setRetries(0);
                this.markStepDone(stepId, "failure", failureMsg);
                this.execNextStep(isStep, this.interval);
            } else {
                if (this.isPlaying()) {
                    var msg = this.getJSErrorMessage(e);
                    this.markStepDone(stepId, "error", msg);
                }
                this.execNextStep(isStep, this.interval);
            }
        }
    }
};
Sahi.prototype.getJSErrorMessage2 = function(msg, lineNumber){
	if (_sahi.controllerMode == "sahi"){
	    var url = "/_s_/dyn/Log_getBrowserScript?href="+this._scriptPath()+"&n="+lineNumber;
	    msg += "\n<a href='"+url+"'><b>Click for browser script</b></a>";
	}
    return msg;
};
Sahi.prototype.getJSErrorMessage = function(e){
    var msg = this.getExceptionString(e);
    var lineNumber = (e.lineNumber) ? e.lineNumber : -1;
    return e.isSahiError ? msg : this.getJSErrorMessage2(msg, lineNumber);
};
Sahi.prototype.check204Response = function(win){
	if (win._sahi.loaded != true) {
		var was204 = this.sendToServer("/_s_/dyn/Player_check204");
//		this._alert(was204+ " " + (typeof was204));
		if (was204 == "true") win._sahi.loaded = true;
	}
    var frs = win.frames;
    if (frs) {
        for (var j = 0; j < frs.length; j++) {
        	try{this.check204Response(frs[j]);}catch(e){}
        }
    }  
};
Sahi.prototype.xcanEvalInBase = function (cmd) {
    return  (this.top().opener == null && !this.isForPopup(cmd)) || (this.top().opener && this.top().opener._sahi.top() == this.top());
};
Sahi.prototype.xisForPopup = function (cmd) {
    return cmd.indexOf("_sahi._popup") == 0;
};
Sahi.prototype.xcanEval = function (cmd) {
    return (this.top().opener == null && !this.isForPopup(cmd)) // for base window
        || (this.top().opener && this.top().opener._sahi.top() == this.top()) // for links in firefox
        || (this.top().opener != null && this.isForPopup(cmd));
    // for popups
};
Sahi.prototype.pause = function () {
    this.topSahi()._isPaused = true;
    this.setServerVar("sahi_paused", 1);
};
Sahi.prototype.unpause = function () {
    // TODO
    this.topSahi()._isPaused = false;
    this.setServerVar("sahi_paused", 0);
    this.topSahi()._isPlaying = true;
};
Sahi.prototype.isPaused = function () {
    if (this.topSahi()._isPaused == null)
        this.topSahi()._isPaused = this.getServerVar("sahi_paused") == 1;
    return this.topSahi()._isPaused;
};
Sahi.prototype.topSahi = function(){
	//alert(this.top());
	return this.top()._sahi;
}
Sahi.prototype.updateControlWinDisplay = function (s, i) {
    try {
        var controlWin = this.getController();
        if (controlWin && !controlWin.closed) {
            // controller2.js checks if this i has already been displayed.
            controlWin.displayLogs(s.replace(/_sahi[.]/g, ""), i);
            if (i != null) controlWin.displayStepNum(i);
        }
    } catch(ex) {
    }
};
Sahi.prototype.setCurrentIndex = function (i) {
    this.startFromStep = i;
    return;
    if (_isLocal) {
        this.setServerVar("this.localIx", i);
    }
    else this.setServerVar("this.ix", i);
};
Sahi.prototype.xgetCurrentIndex = function () {
    if (this.cmdsLocal.length > 0) {
        var i = parseInt(this.getServerVar("this.localIx"));
        var localIx = ("" + i != "NaN") ? i : 0;
        if (this.cmdsLocal.length == localIx) {
            this.cmdsLocal = new Array();
            this.setServerVar("this.localIx", 0);
            _isLocal = false;
        } else {
            return localIx;
        }
    }
    var i = parseInt(this.getServerVar("this.ix"));
    return ("" + i != "NaN") ? i : 0;
};
Sahi.prototype.isPlaying = function () {
    if (this.topSahi()._isPlaying == null){
        this.topSahi()._isPlaying = this.sendToServer("/_s_/dyn/SessionState_isPlaying") == "1";
    }
    return this.topSahi()._isPlaying;
};
Sahi.prototype.playManual = function (ix) {
    this.skipTill(ix);
    //this.setCurrentIndex(ix);
    this.unpause();
    this.ex();
};
Sahi.prototype.startPlaying = function () {
    this.sendToServer("/_s_/dyn/Player_start");
};
Sahi.prototype.stepWisePlay = function () {
    this.sendToServer("/_s_/dyn/Player_stepWisePlay");
};
Sahi.prototype.showStopPlayingMessage = function () {
    this.updateControlWinDisplay("--Stopped Playback: " + (this.hasErrors() ? "FAILURE" : "SUCCESS") + "--");
};
Sahi.prototype.stopPlaying = function () {
    this.sendToServer("/_s_/dyn/Player_stop");
    this.showStopPlayingMessage();
    this.topSahi()._isPlaying = false;
};
Sahi.prototype.startRecording = function () {
    this.topSahi()._isRecording = true;
    this.addHandlersToAllFrames(this.top());
    //this.sendToServer("/_s_/dyn/Recorder_start");
};
Sahi.prototype.stopRecording = function () {
    this.topSahi()._isRecording = false;
    this.sendToServer("/_s_/dyn/Recorder_stop");
//    this.setServerVar("sahi_record", 0);
};
Sahi.prototype.getLogQS = function (msg, type, debugInfo, failureMsg) {
    var qs = "msg=" + this.encode(msg) + "&type=" + type
        + (debugInfo ? "&debugInfo=" + this.encode(debugInfo) : "")
        + (failureMsg ? "&failureMsg=" + this.encode(failureMsg) : "");
    return qs;
};
Sahi.prototype.logPlayBack = function (msg, type, debugInfo, failureMsg) {
    this.sendToServer("/_s_/dyn/TestReporter_logTestResult?"+this.getLogQS(msg, type, debugInfo, failureMsg));
};

Sahi.prototype.compareArrays = function (a1,a2) {
	if (a1 == null || a2 == null) return "One of the arrays is null";
	if (a1.length != a2.length && typeof(a1) == typeof(a2)) return "Difference in length of arrays:\nExpected Length:["+a1.length+"]\nActual Length:["+a2.length+"]";
	for(var i=0;i<a1.length;i++){
		//if ((typeof a1[i]) != (typeof a2[i])) return "Type mis-match error at index " + i;
		if ((typeof a1[i]) == "object" && (typeof a2[i]) == "object" && a1[i].length && a2[i].length){
			if (this.compareArrays(a1[i], a2[i])!="equal") return "Expected:[" + a1[i] + "]\nActual:[" + a2[i] + "] at index "+i;
		} else if (a1[i] != a2[i]) return "Expected:[" + a1[i] + "]\nActual:[" + a2[i] + "] at index "+i;
	}
	return "equal"
};

Sahi.prototype.trim = function (s) {
    if (s == null) return s;
    if ((typeof s) != "string") return s;
    s = s.replace(/\xA0/g, ' ').replace(/\s\s*/g, ' ');
    var ws = /\s/;
    var t1 = (ws.test(s.charAt(0))) ? 1 : 0;
    var t2 = (ws.test(s.charAt(s.length-1))) ? s.length-1 : s.length;
    return s.slice(t1, t2);
};
Sahi.prototype.list = function (el) {
    var s = "";
    var f = "";
    var j = 0;
    if (typeof el == "array"){
        for (var i=0; i<el.length; i++) {
            s += i + "=" + el[i];
        }
    }
    if (typeof el == "object") {
        for (var i in el) {
            try {
                if (el[i] && el[i] != el) {
                    if (("" + el[i]).indexOf("function") == 0) {
                        f += i + "\n";
                    } else {
                        if (typeof el[i] == "object" && el[i] != el.parentNode) {
                            s += i + "={{" + el[i] + "}};\n";
                        }
                        s += i + "=" + el[i] + ";\n";
                        j++;
                    }
                }
            } catch(e) {
                s += "" + i + "\n";
            }
        }
    } else {
        s += el;
    }
    return s + "\n\n-----Functions------\n\n" + f;
};

Sahi.prototype.findInArray = function (ar, el) {
    var len = ar.length;
    for (var i = 0; i < len; i++) {
        if (ar[i] == el) return i;
    }
    return -1;
};
Sahi.prototype._isIE = function () {
    if(this.navigator.appName == "Microsoft Internet Explorer") {
        return true;
    } else {
        if (this.navigator.userAgent.match(/Trident/)) {
            return true;
        }
    }
    return false;
}
Sahi.prototype._isIE9 = function () {return /MSIE 9[.]/.test(this.navigator.userAgent);};
Sahi.prototype._isFF2 = function () {return /Firefox\/2[.]|Iceweasel\/2[.]|Shiretoko\/2[.]/.test(this.navigator.userAgent);};
Sahi.prototype._isFF3 = function () {return /Firefox\/3[.]|Iceweasel\/3[.]|Shiretoko\/3[.]/.test(this.navigator.userAgent);};
Sahi.prototype._isFF4 = function () {return /Firefox\/4[.]|Iceweasel\/4[.]|Shiretoko\/4[.]/.test(this.navigator.userAgent);};
Sahi.prototype._isFF5 = function () {return /Firefox\/5[.]|Iceweasel\/5[.]|Shiretoko\/5[.]/.test(this.navigator.userAgent);};
Sahi.prototype._isFF4Plus = function () {return (this._isFF() && !this._isFF2() && !this._isFF3());};
Sahi.prototype._isFF = function () {return /Firefox|Iceweasel|Shiretoko/.test(this.navigator.userAgent);};
Sahi.prototype._isChrome = function () {return /Chrome/.test(this.navigator.userAgent);};
Sahi.prototype._isSafari = function () {return /Safari/.test(this.navigator.userAgent);};
Sahi.prototype._isOpera = function () {return /Opera/.test(this.navigator.userAgent);};
Sahi.prototype.isSafariLike = function () {return /Konqueror|Safari|KHTML/.test(this.navigator.userAgent);};
Sahi.prototype._isHTMLUnit = function() {return /HTMLUnit/.test(this.navigator.userAgent);}
Sahi.prototype.createRequestObject = function () {
    var obj;
    if (window.XMLHttpRequest){
        // If IE7, Mozilla, Safari, etc: Use native object
        obj = new XMLHttpRequest()
    }else {
        if (window.ActiveXObject){
            // ...otherwise, use the ActiveX control for IE5.x and IE6
            obj = new ActiveXObject("Microsoft.XMLHTTP");
        }
    }
    return obj;
};
Sahi.prototype.getServerVar = function (name, isGlobal) {
    var v = this.sendToServer("/_s_/dyn/SessionState_getVar?name=" + this.encode(name) + "&isglobal="+(isGlobal?1:0));
    return eval("(" + this.decode(v) + ")");
};
Sahi.prototype.setServerVar = function (name, value, isGlobal) {
    this.sendToServer("/_s_/dyn/SessionState_setVar?name=" + this.encode(name) + "&value=" + this.encode(this.toJSON(value)) + "&isglobal="+(isGlobal?1:0));
};
Sahi.prototype.logErr = function (msg) {
    //    return;
    this.sendToServer("/_s_/dyn/Log?msg=" + this.encode(msg) + "&type=err");
};

Sahi.prototype.getParentNode = function (el, tagName, occurrence, maxPossible) {
    if (!occurrence) occurrence = 1;
    var cnt = 0;
    var parent = el.parentNode;
    var maxParent = parent;
    while (parent && !this.areTagNamesEqual(parent.tagName, "body") && !this.areTagNamesEqual(parent.tagName.toLowerCase(), "html")) {
        if (this.areTagNamesEqual(tagName, "ANY") || this.areTagNamesEqual(parent.tagName, tagName)) {
            cnt++;
            if (occurrence == cnt) return parent;
        }
        maxParent = parent;
        parent = parent.parentNode;
    }
    if (maxPossible) return maxParent;
    return null;
};
Sahi.prototype.sendToServer = function (url) {
    try {
        var rand = (new Date()).getTime() + Math.floor(Math.random() * (10000));
        var http = this.createRequestObject();
        url = url + (url.indexOf("?") == -1 ? "?" : "&") + "t=" + rand;
        url = url + "&sahisid=" + encodeURIComponent(this.sid);
        var post = url.substring(url.indexOf("?") + 1);
        url = url.substring(0, url.indexOf("?"));
        http.open("POST", url, false);
        http.send(post);
        return http.responseText;
    } catch(ex) {
        this.handleException(ex)
    }
};
var s_v = function (v) {
    var type = typeof v;
    if (type == "number") return v;
    else if (type == "string") return "\"" + v.replace(/\r/g, '\\r').replace(/\n/g, '\\n').replace(/"/g, '\\"') + "\"";
    else return v;
};
Sahi.prototype.quoted = function (s) {
    return '"' + s.replace(/"/g, '\\"') + '"';
};
Sahi.prototype.handleException = function (e) {
    //  alert(e);
    //  throw e;
};
Sahi.prototype.convertUnicode = function (s) {
	return _sahi.escapeUnicode ? this.unicode(s) : s;
}
Sahi.prototype.unicode = function (source) {
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
Sahi.prototype.reAttachEvents = function () {
	if (!this.areWindowsLoaded(this.top())) return;
    this.reAttachSahi(this.top());
    if (this.isRecording()) 
        this.addHandlersToAllFrames(this.top());    
}

if (_sahi.top() == window){
    window.setInterval(_sahi.wrap(_sahi.reAttachEvents), 500);
}
Sahi.prototype.reAttachSahi = function (win) {
    try{
        if (!win._sahi) {
			this.reAttachSahiToWin(win);
        }
    }catch(e){}
    var fs = win.frames;
    if (fs && fs.length > 0) {
        for (var i = 0; i < fs.length; i++) {
            try{
            	if (this._isHTMLUnit() && fs[i].location.href && fs[i].location.href.indexOf(".gif") != -1) continue;
            	this.reAttachSahi(fs[i]);
            }catch(e){}
        }
    } 
}
Sahi.prototype.reAttachSahiToWin = function(win){
	this.mockDialogs(win);
    this.activateHotKey(win);
}
Sahi.prototype.onBeforeUnLoad = function () {
    this.loaded = false;
};
Sahi.prototype.onWindowLoad = function (e){
    try {
        this.loaded = true;
        this.activateHotKey();
    } catch(ex) {
        this.handleException(ex);
    }
    if (self == this.top()) {
    	__sahiDebug__("onWindowLoad: self == this.top(), play()");
        this.play();
        this.ping();
    }
    if (this.isRecording()) {
    	__sahiDebug__("init: isRecording() addHandlersToAllFrames");
    	this.addHandlersToAllFrames(this.top());
    }
}
Sahi.onWindowLoad = function(e){
    eval("_sahi.onWindowLoad()");
};

Sahi.prototype.init = function (e) {
	__sahiDebug__("init: start");
	if (this.initTimer) window.clearTimeout(this.initTimer);
    if (this.initialized) return;
    this.initialized = true;	
    try {
        this.activateHotKey();
    } catch(ex) {
        this.handleException(ex);
    }
    this.prepareADs();
    this.makeLibFunctionsAvailable();
    try {
//        if (self == this.top() && self.parent == this.top()) {
// Replaced above condition on addition of domain support. check.
    	__sahiDebug__("init: in try");
        if (self == this.top()) {
        	__sahiDebug__("init: self == this.top(), play()");
            //this.ping();
        }
        if (this.isRecording()) {
        	__sahiDebug__("init: isRecording() addHandlersToAllFrames");
        	this.addHandlersToAllFrames(this.top());
        }
    } catch(ex) {
        //      throw ex;
        this.handleException(ex);
    }
	__sahiDebug__("init: before isHTMLUnit");
    
    this.wrappedOnEv = this.wrap(this.onEv);
//	this.isHTMLUnit = this._isHTMLUnit();
//    alert("Cookies: " + document.domain + " " + document.cookie);
//    this.listen();    
	__sahiDebug__("init: end");
};
Sahi.prototype.activateHotKey = function (win) {
    if (!win) win = self;
    try {
        var doc = win.document;
        this.addWrappedEvent(doc, "dblclick", this.reAttachEvents);
        this.addWrappedEvent(doc, "dblclick", this.openControllerWindow);
        this.addWrappedEvent(doc, "mousemove", this.mouseOver);
//        if (this.isSafariLike()) {
//            var prev = doc.ondblclick;
//            doc.ondblclick = function(e) {
//                if (prev != null) prev(e);
//                _sahi.openControllerWindow(e);
//            };
//        }
    } catch(ex) {
        this.handleException(ex);
    }
};
Sahi.prototype.xisFirstExecutableFrame = function () {
    var fs = this.top().frames;
    for (var i = 0; i < fs.length; i++) {
        if (self == this.top().frames[i]) return true;
        if ("" + (typeof this.top().frames[i].location) != "undefined") { // = undefined when previous frames are not accessible due to some reason (may be from diff domain)
            return false;
        }
    }
    return false;
};
Sahi.prototype.getScript = function (infoAr) {
	var info = infoAr[0];
    var accessor = this.escapeDollar(this.getAccessor1(info));
    if (accessor == null) return null;
    var ev = info.event;
    var value = info.value;
    var type = info.type;
    
    var cmd = null;
    if (value == null)
        value = "";
    if (ev == "load") {
        cmd = "_wait(2000);";
    } else if (ev == "_click") {
        cmd = "_click(" + accessor + ");";
    } else if (ev == "_setValue") {
        cmd = "_setValue(" + accessor + ", " + this.quotedEscapeValue(value) + ");";
    } else if (ev == "_setSelected") {
        cmd = "_setSelected(" + accessor + ", " + this.toJSON(value) + ");";
    } else if (ev == "wait") {
        cmd = "_wait(" + value + ");";
    } else if (ev == "mark") {
        cmd = "//MARK: " + value;
    } else if (ev == "_setFile") {
        cmd = "_setFile(" + accessor + ", " + this.quotedEscapeValue(value) + ");";
    }

    return this.addPopupDomainPrefixes(cmd);
};
Sahi.prototype.addPopupDomainPrefixes = function(cmd){
	return this.getPopupDomainPrefixes() + cmd;
}
Sahi.prototype.getPopupDomainPrefixes = function(){
    var popup = this.getPopupName();
    var domain = this.getDomainContext();	
    var prefix = "";
    if (prefix != null && domain != null && domain != "") {
    	prefix = this.language.DOMAIN.replace(/<domain>/g, this.quoted(domain)); //"_domain(\"" + domain + "\").";
    }	
    if (prefix != null && popup != null && popup != "") {
    	prefix += this.language.POPUP.replace(/<window_name>/g, this.quoted(popup));
    }
    return prefix;
}
Sahi.prototype.quotedEscapeValue = function (s) {
    return this.quoted(this.escapeValue(s));
};

Sahi.prototype.escapeValue = function (s) {
    if (s == null || typeof s != "string") return s;
    return this.convertUnicode(s.replace(/\r/g, "").replace(/\\/g, "\\\\").replace(/\n/g, "\\n"));
};

Sahi.prototype.escape = function (s) {
    if (s == null) return s;
    return this.encode(s);
};

Sahi.prototype.saveCondition = function (key, a) {
    this.setServerVar(key, a ? "true" : "false");
    //this.resetCmds();
};
Sahi.prototype.resetCmds = function(){
    this.cmds = new Array();
    this.cmdDebugInfo = new Array();
    this.scriptScope();
};
Sahi.prototype.handleSet = function(varName, value){
    this.setServerVar(varName, value);
    //this.resetCmds();
};
Sahi.prototype.quoteIfString = function (shortHand) {
//    if (("" + shortHand).match(/^[0-9]+$/)) return shortHand;
    if (typeof shortHand == "number") return shortHand;
    return this.quotedEscapeValue(shortHand);
};


Sahi.prototype._execute = function (command, sync) {
    var is_sync = sync ? "true" : "false";
    var status = this._callServer("CommandInvoker_execute", "command=" + this.encode(command) + "&sync=" + is_sync);
    if ("success" != status) {
        throw new Error("Execute Command Failed!");
    }
};

_sahi.activateHotKey();

Sahi.prototype._style = function (el, style) {
    var value = el.style[this.toCamelCase(style)];

    if (!value){
        if (el.ownerDocument && el.ownerDocument.defaultView) // FF
            value = el.ownerDocument.defaultView.getComputedStyle(el, "").getPropertyValue(style);
        else if (el.currentStyle)
            value = el.currentStyle[this.toCamelCase(style)];
    }

    return value;
};

Sahi.prototype.toCamelCase = function (s) {
    var exp = /-([a-z])/
    for (;exp.test(s); s = s.replace(exp, RegExp.$1.toUpperCase()));
    return s;
};
Sahi.init = function(e){
    eval("_sahi.init()");
};
Sahi.onBeforeUnLoad = function(e){
    _sahi.onBeforeUnLoad(e);
};
// ff xhr start
if (!_sahi._isIE()){
	if ((XMLHttpRequest.prototype.__sahiModified__ == null)){ 
	    XMLHttpRequest.prototype._sahi_openOld = XMLHttpRequest.prototype.open;
	    XMLHttpRequest.prototype.__sahiModified__ = true;
	    XMLHttpRequest.prototype.open = function(method, url, async, username, password){
//	        var opened = this._sahi_openOld(method, url, async, username, password);
	        var opened = this._sahi_openOld.apply(this, arguments);
	        url = ""+url;
	        if (url.indexOf("/_s_/") == -1){
	            try{
	                if (!_sahi.isComet(url)){
	                	var xs = _sahi.topSahi().XHRs;
	                	var j = xs.length;
	                    xs[j] = this;
	                    _sahi.topSahi().XHRTimes[j] = new Date();
	                }
	            }catch(e){
	                _sahi._debug("concat.js: Diff domain: Could not add XHR to list for automatic monitoring "+e);
	            }
	            this.setRequestHeader("sahi-isxhr", "true");
	        }
	        return opened;
	    }
	    new_ActiveXObject = function(s){ // Some custom implementation of ActiveXObject
	        return new ActiveXObject(s);
	    }
	}
}else{
    new_ActiveXObject = function(s){
        var lower = s.toLowerCase();
        if (lower.indexOf("microsoft.xmlhttp")!=-1 || lower.indexOf("msxml2.xmlhttp")!=-1){
            return new SahiXHRWrapper(s, true);
        }else{
            return new ActiveXObject(s);
        }
    }
}
// ff xhr end
SahiXHRWrapper = function (s, isActiveX){
	try{
		this.xhr = isActiveX ? new ActiveXObject(s) : new real_XMLHttpRequest();
	}catch(e){
		if (_sahi._isIE() && window.ActiveXObject){
			this.xhr = new ActiveXObject("Microsoft.XMLHTTP");
		}
	}
    var xs = _sahi.topSahi().XHRs;
    xs[xs.length] = this;
    this._async = false;
};
SahiXHRWrapper.prototype.open = function(method, url, async, username, password){
    url = ""+url;
    this._async = async;
    var opened = this.xhr.open(method, url, async, username, password);
    if (url.indexOf("/_s_/") == -1){
        try{
            var xs = _sahi.topSahi().XHRs;
            xs[xs.length] = this;
        }catch(e){}
        this.xhr.setRequestHeader("sahi-isxhr", "true");
    }
    var fn = this.stateChange;
    var obj = this;
    this.xhr.onreadystatechange = function(){fn.apply(obj, arguments);}
    return opened;
};
SahiXHRWrapper.prototype.getAllResponseHeaders = function(){
    return this.xhr.getAllResponseHeaders();
};
SahiXHRWrapper.prototype.getResponseHeader = function(s){
    return this.xhr.getResponseHeader(s);
};
SahiXHRWrapper.prototype.setRequestHeader = function(k, v){
    return this.xhr.setRequestHeader(k, v);
};
SahiXHRWrapper.prototype.send = function(s){
    var sent = this.xhr.send(s);
    if (!this._async) this.populateProps();
    return sent;
};
SahiXHRWrapper.prototype.stateChange = function(){
    this.readyState = this.xhr.readyState;
    if (this.readyState==4){
        this.populateProps();
    }
    if (this.onreadystatechange) this.onreadystatechange();
};
SahiXHRWrapper.prototype.abort = function(){
	return this.xhr.abort();
}
SahiXHRWrapper.prototype.populateProps = function(){
    this.responseText = this.xhr.responseText;
    this.responseXML = this.xhr.responseXML;
    this.status = this.xhr.status;
    this.statusText = this.xhr.statusText;
};
if (_sahi._isIE() && typeof XMLHttpRequest != "undefined"){
    window.real_XMLHttpRequest = XMLHttpRequest;
    XMLHttpRequest = SahiXHRWrapper;
}
Sahi.prototype.toJSON = function(el){
    if (el == null || el == undefined) return 'null';
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
            ar[i] = this.toJSON(el[i]);
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
                ar[ar.length] = this.toJSON(k) + ':' + this.toJSON(v);
            }
        }
        return '{' + ar.join(',') + '}';
    }
};
Sahi.prototype.isComet = function(u){
	return /\/comet[\/.]/.test(u);
}
Sahi.prototype.isIgnorableId = function(id){
	return this.ignorableIdsPattern.test(id);
};
Sahi.prototype.iframeFromStr = function(iframe){
    if (typeof iframe == "string") return this._byId(iframe);
    return iframe;
};
Sahi.prototype._rteWrite = function(iframe, s){
    this.iframeFromStr(iframe).contentWindow.document.body.innerHTML = s;
};
Sahi.prototype._rteHTML = function(iframe){
    return this.iframeFromStr(iframe).contentWindow.document.body.innerHTML;
};
Sahi.prototype._rteText = function(iframe){
    return this._getText(this.iframeFromStr(iframe).contentWindow.document.body);
};
Sahi.prototype._re = function(s){
    return eval("/"+s.replace(/\s+/g, '\\s+')+"/");
};
//Sahi.prototype._scriptName = function(){
//	this._evalOnRhino("_scriptName()");
////    return this.__scriptName;
//};
//Sahi.prototype._scriptPath = function(){
//	return this.__scriptPath;
//};
Sahi.prototype._parentNode = function (el, tagName, occurrence){
	if (tagName == null && occurrence == null){
		tagName = "ANY";
	} else if (typeof(tagName) == "number") {
		occurrence = tagName;
		tagName = "ANY";
	}
	return this.getParentNode(el, tagName, occurrence);
};
Sahi.prototype._parentCell = function(el, occurrence){
    return this._parentNode(el, "TD", occurrence);
};
Sahi.prototype._parentRow = function(el, occurrence){
    return this._parentNode(el, "TR", occurrence);
};
Sahi.prototype._parentTable = function(el, occurrence){
    return this._parentNode(el, "TABLE", occurrence);
};
Sahi.prototype.getDoc = function(relations){
	if (this.isArray(relations)){
		var nodes = [];
		for (var i=0; i<relations.length; i++){
			var relation = relations[i];
			if (!relation.type && this.isWindow(relation)) {
				nodes.push(relation.document); // window
			}
			if (relation.type && relation.type == "_near"){
				nodes = nodes.concat(this.getDoc(relation).nodes);
			}
		}
		var inEl = null;
		for (var i=0; i<relations.length; i++){
			var relation = relations[i];
			if (relation.type && relation.type == "_in"){
				var relEl = relation.element;
				if (inEl != null && !this._contains(inEl, relEl) && !this._contains(relEl, inEl)){
					// mutually exclusive nodes
					return new SahiDocProxy([]);
				}
				if(inEl == null || this._contains(inEl, relEl)){
					// inner element
					inEl = relEl;
				}
			}			
		}
		if (inEl == null) return new SahiDocProxy(nodes); 
		if (nodes.length == 0) return inEl;
		var narrowed = [];
		for (var i=0; i<nodes.length; i++){
			if (this._contains(inEl, nodes[i])){
				narrowed.push(nodes[i]);
			}
			if (this._contains(nodes[i], inEl)){
				narrowed.push(inEl);
			}			
		}		
		return new SahiDocProxy(narrowed); 
	}
    if (relations.type){
    	if (relations.type == "_in") return relations.element;
	    if (relations.type == "_near"){
	    	var parents = [];
	    	for (var i=1; i<7; i++){
	    		parents[parents.length] = this.getParentNode(relations.element, "ANY", i);
	    	}
	    	return new SahiDocProxy(parents);
	    }
    }
    return relations.document;
};
SahiDocProxy = function(nodes){
	this.nodes = nodes;
};
SahiDocProxy.prototype.getElementsByTagName = function(tag){
	var tags = [];
	for (var i=0; i<this.nodes.length; i++){
		if (this.nodes[i] == null) continue;
		var childNodes = _sahi.getElementsByTagName(tag, this.nodes[i]);
		for (var j=0; j<childNodes.length; j++){
			var childNode = childNodes[j];
			var alreadyAdded = false;
			for (var k=0; k<tags.length; k++){
				if (tags[k] === childNode){
					alreadyAdded = true;
					break;
				}
			}
			if (!alreadyAdded){
				tags[tags.length] = childNode;
			}
		}		
	}
	return tags;
};
Sahi.prototype._in = function(el){
	return {"element":el, "type":"_in", "isRelation": true};
};
Sahi.prototype._near = function(el){
	return {"element":el, "type":"_near", "isRelation": true};
};
Sahi.prototype._under = function(el, offset){
	this.alignX = this.findPosX(el);
	this.alignXOuter = this.alignX + el.offsetWidth;
//	alert(this._style(el, "height"));
	var h = el.offsetHeight;
	this.belowY = this.findPosY(el) + (isNaN(h) ? 0 : h/2);
	this.underOffset = offset;
	if (this.underOffset == null) this.underOffset = 0;
	return null;
};
Sahi.prototype._across = function(el){
	this.alignY = this.findPosY(el);
	return null;
};

Sahi.prototype._xy = function(el, x, y){
	this.xyoffsets[el] = [x,y];
	return el;
}

Sahi.prototype.addSahi = function(s) {
    return this.decode(this.sendToServer("/_s_/dyn/ControllerUI_getSahiScript?code=" + this.encode(s)));
};
_sahi.prevOnError = window.onerror;
window.onerror = _sahi.wrap(_sahi.onError);
Sahi.prototype.setServerVarPlain = function (name, value, isGlobal) {
//	if (name == "___lastValue___") this._debug(name+"="+value);
    this.sendToServer("/_s_/dyn/SessionState_setVar?name=" + this.encode(name) + "&value=" + this.encode(value) + "&isglobal="+(isGlobal?1:0));
};
/* execCommand start */
if (_sahi._isIE()){
	_sahi.real_execCommand = document.execCommand;
	document.execCommand = function(){return _sahi_dummyExecCommand.apply(document, arguments);};
}
Sahi.prototype.encode = function(str) {  
	  return encodeURIComponent(str).replace(/%20/g, '+').replace(/!/g, '%21').replace(/'/g, '%27').replace(/\(/g, '%28').  
	                                 replace(/\)/g, '%29').replace(/\*/g, '%2A');
} 
Sahi.prototype.decode = function(msg){
	if (!msg) return msg;
	return decodeURIComponent(msg.replace(/[+]/g, ' '));	
}
function _sahi_dummyExecCommand(){
	if (arguments[0] == 'ClearAuthenticationCache'){
		_sahi.sendToServer("/_s_/dyn/SessionState_removeAllCredentials");
		return true;
	}else{
		return _sahi.real_execCommand.apply(window.document, arguments);
	}
}
/* execCommand end */

/** id start **/
Sahi.prototype.getOptionId = function (sel, val) {
	if (sel.selectedIndex != -1)
		return sel.options[sel.selectedIndex].id;
};
Sahi.prototype.addADAr = function(a){
	this.ADs[this.ADs.length] = a;
};
Sahi.prototype.getAD = function(el){
	var defs = [];
	for (var i=0; i<this.ADs.length; i++){
		var d = this.ADs[i];  
		if (this.areTagNamesEqual(d.tag, el.tagName)){
			if (!el.type) defs[defs.length] = d;
			else if (!d.type || this.getElementType(el) == d.type) defs[defs.length] = d; 
		}
	}
	return defs;
};
Sahi.prototype.getDomRelAr = function(args){
	var rels = [];
	for (var i=1; i<args.length; i++){
		if (args[i] && (args[i].isRelation == true || this.isWindow(args[i]))) rels.push(args[i]);
	}
	return rels;
}
Sahi.prototype.isWindow = function(o){
	return (o && o.location && o.document) != null;
}
Sahi.prototype.addAD = function(a){
	this.addADAr(a);
	var old = Sahi.prototype[a.name];
	var newFn = function(identifier){
		var inEl = this.getDomRelAr(arguments);
		if (inEl.length == 0) inEl = this.top();
		if (old) {
			var el = old.apply(this, arguments);
			if (el) return el;
		}
		for (var i=0; i<a.attributes.length; i++){
			var res = this.getBlankResult();
			if (a.type){
				var el = this.findElementHelper(identifier, inEl, a.type, res, a.attributes[i], a.tag).element;
			} else {
				var el = this.findTagHelper(identifier, inEl, a.tag, res, a.attributes[i]).element;
			}
			if (el != null) return el;
		}
	};
	if (!a.idOnly) Sahi.prototype[a.name] = newFn;
};
Sahi.prototype.identify = function(el){
	this.alignY = this.alignX = null;
	if (el == null) return null;
	var apis = [];
	var assertions = [];
	var tagLC = el.tagName.toLowerCase();
	var accs = this.getAD(el);
	var relation = null;
	var relationStr = null;
	var anchor = this.topSahi().anchor;
	if (anchor){
		if (anchor == el){
			// do nothing
		} else if (this._contains(anchor, el)) {
			relation = this._in(anchor);
			relationStr = "_in(" + this.topSahi().anchorStr + ")";
		} else if (this._contains(this.getParentNode(anchor, "ANY", 7, true), el)){
			relation = this._near(anchor);
			relationStr = "_near(" + this.topSahi().anchorStr + ")";
		}
	} 
	for (var k=0; k<accs.length; k++){
		var acc = accs[k];
		if (acc && acc.attributes){
			var r = acc.attributes;
			for (var i=0; i<r.length; i++){
				try{
					var attr = r[i];
					if (attr == "index"){
						var ix = this.getIdentifyIx(null, el, null, relation);
						if (ix != -1 && this[acc.name](ix) == el){
							apis[apis.length] = this.buildAccessorInfo(el, acc, ix, relationStr);
						}				
					} else if (typeof attr == "string" && attr.indexOf("encaps") == 0) {
						var parentTag = attr.substring(attr.indexOf("_") + 1);
						var p = this._parentNode(el, parentTag);
						var pAccs = this.identify(p);
						// TODO: check this assertions get added to both child and parent. may come out incorrect.
						if (pAccs){
							apis = apis.concat(pAccs.apis);
							assertions = assertions.concat(pAccs.assertions);
						}
					} else {
						var val = this.getAttribute(el, attr);
						if (val && !this.isIgnorableId(val) && !(attr == "sahiText" && val.length > 200)){
							if (this[acc.name](val, relation) == el){
								apis[apis.length] = this.buildAccessorInfo(el, acc, val, relationStr);
							} else {
								var ix = this.getIdentifyIx(val, el, attr, relation);
								val = val + "[" + ix + "]";
								if (ix != -1 && this[acc.name](val) == el){
									apis[apis.length] = this.buildAccessorInfo(el, acc, val, relationStr);
								}
							}
						}
					}
				}catch(e){
					//alert(e +" " + attr + " " + el.tagName);
				}
			}
		}
	}
	
	if (apis.length > 0) {
		assertions = assertions.concat(this.getAssertions(accs, apis[0]));
	}
	
	return {apis: apis, assertions: assertions};
};
Sahi.prototype.buildAccessorInfo = function(el, acc, identifier, relationStr){
	return new AccessorInfo("", identifier, acc.name, acc.action, (acc.value ? this.getAttribute(el, acc.value):null), acc.value, relationStr);
};
Sahi.prototype.getIdentifyIx = function(val, el, attr, inEl){
	var inEl = this.getDomRelAr(arguments);
	if (inEl.length == 0) inEl = this.top();
	var tagLC = el.tagName.toLowerCase();
	var res = this.getBlankResult();
	if (this.isFormElement(el)){
		return this.findElementIxHelper(val, el.type, el, inEl, res, attr, tagLC).cnt;
	} else {
		return this.findTagIxHelper(val, el, inEl, tagLC, res, attr).cnt;
	}	
};
Sahi.prototype.isFormElement = function(el){
	var n = el.tagName.toLowerCase();
	return n == "input" || n == "button" || n == "textarea" || n == "select" || n == "option";
}
Sahi.prototype.getAttribute = function (el, attr){
	if (typeof attr == "function"){
		return attr(el);
	}
	if (attr.indexOf("|") != -1){
	    var attrs = attr.split("|");
	    for (var i=0; i<attrs.length; i++){
	    	var v = this.getAttribute(el, attrs[i]);
	        if (v != null && v != "") return v;
	    }
	}else{
        if (attr == "sahiText") {
            return this._getText(el);
        }
        return el[attr];
	}
};
Sahi.prototype.makeLibFunctionsAvailable = function(){
	var fns = ["_scriptName", "_scriptPath", "_suiteInfo", "_userDataDir", 
	           "_sessionInfo", "_userDataPath", "_readFile", "_readCSVFile", 
	           "_readURL", "_scriptStatus", "_stackTrace", "_selectWindow"];
	for (var i=0; i<fns.length; i++){		
		this.addRhinoFn(fns[i]);
	}
}
Sahi.prototype.addRhinoFn = function(fnName){
	this[fnName] = function(){
		var s = "";
		for (var i=0; i<arguments.length; i++){
			if (i != 0) s += ", ";
			s += this.toJSON(arguments[i]); 
		}
		return this._evalOnRhino(fnName + "(" + s + ")");
	}	
}
Sahi.prototype._evalOnRhino = function (s){
	try{
		var v = this.sendToServer("/_s_/dyn/RhinoRuntime_eval?toEval=" + this.encode(s));
		return eval("(" + this.decode(v) + ")");
	}catch(e){return null;}
}
Sahi.prototype.getFileFromURL = function(el){
	var src = el.src; 
	src = src.replace(/[;?].*$/, '');
	return src.substring(src.lastIndexOf("/")+1);
}
//Sahi.prototype.getXPathCrumb = function(el){
//	var locators = {
//			A:["sahiText", "link="],
//			ANY: ["id", ]
//			}
//	if (el.id) return el.tagName "[@id=" + 
//}
Sahi.prototype.getXPath = function(el){
	var n = el;
	var s = "";
	while (true){
		var p = n.parentNode;
		if (p == n || p == null) break;
		var ix = this.findInArray(this.getElementsByTagName(n.tagName, p), n);
		var sfx = ix > 0 ? "["+(ix+1)+"]" : "";
		s = n.tagName.toLowerCase() + sfx + (s == "" ? "" : ("/" + s));
		n = p;
	}
	return "/" + s;
}
Sahi.prototype.prepareADs = function(){
//	this.addAD({tag: "SPAN", type: null, event:"click", name: "_spanWithImage", 
//		attributes: [function(el){ if (el.parentNode.tagName == "TD"){return _sahi._getText(el);}}], action: "_click", value: "sahiText"});

	this.addAD({tag: "A", type: null, event:"click", name: "_link", attributes: ["sahiText", "title|alt", "id", "index", "href", "className"], action: "_click", value: "sahiText"});
	this.addAD({tag: "IMG", type: null, event:"click", name: "_image", attributes: ["title|alt", "id", 
	                  this.getFileFromURL, "index", "className"], action: "_click"});
	this.addAD({tag: "LABEL", type: null, event:"click", name: "_label", attributes: ["sahiText", "id", "className", "index"], action: "_click", value: "sahiText"});
	this.addAD({tag: "LI", type: null, event:"click", name: "_listItem", attributes: ["sahiText", "id", "className", "index"], action: "_click", value: "sahiText"});
	this.addAD({tag: "UL", type: null, event:"click", name: "_list", attributes: ["id", "className", "index"], action: "_click", value: "sahiText"});
	this.addAD({tag: "OL", type: null, event:"click", name: "_list", attributes: ["id", "className", "index"], action: "_click", value: "sahiText"});
	this.addAD({tag: "DIV", type: null, event:"click", name: "_div", attributes: ["sahiText", "id", "className", "index"], action: "_click", value: "sahiText"});
	this.addAD({tag: "SPAN", type: null, event:"click", name: "_span", attributes: ["sahiText", "id", "className", "index"], action: "_click", value: "sahiText"});
	this.addAD({tag: "TABLE", type: null, event:"click", name: "_table", attributes: ["id", "className", "index"], action: null, value: "sahiText"});
	this.addAD({tag: "TR", type: null, event:"click", name: "_row", attributes: ["id", "className", "sahiText", "index"], action: "_click", value: "sahiText"});
	this.addAD({tag: "TD", type: null, event:"click", name: "_cell", attributes: ["sahiText", "id", "className", "encaps_TR", "encaps_TABLE"], action: "_click", idOnly: true, value: "sahiText"});
	this.addAD({tag: "TH", type: null, event:"click", name: "_tableHeader", attributes: ["sahiText", "id", "className", "encaps_TABLE"], action: "_click", value: "sahiText"});

	this.addAD({tag: "INPUT", type: "button", event:"click", name: "_button", attributes: ["value", "name", "id", "index", "className"], action: "_click", value: "value"});
	this.addAD({tag: "BUTTON", type: "button", event:"click", name: "_button", attributes: ["sahiText", "name", "id", "className", "index"], action: "_click", value: "sahiText"});
	
	this.addAD({tag: "INPUT", type: "checkbox", event:"click", name: "_checkbox", attributes: ["name", "id", "value", "className", "index"], action: "_click", value: "checked",
			assertions: function(value){return [("true" == ("" + value)) ? _sahi.language.ASSERT_CHECKED : _sahi.language.ASSERT_NOT_CHECKED];}});
	this.addAD({tag: "INPUT", type: "password", event:"change", name: "_password", attributes: ["name", "id", "index", "className"], action: "_setValue", value: "value"});
	this.addAD({tag: "INPUT", type: "radio", event:"click", name: "_radio", attributes: ["id", "name", "value", "className", "index"], action: "_click", value: "checked", 
			assertions: function(value){return [("true" == ("" + value)) ? _sahi.language.ASSERT_CHECKED : _sahi.language.ASSERT_NOT_CHECKED];}});	
	
	this.addAD({tag: "INPUT", type: "submit", event:"click", name: "_submit", attributes: ["value", "name", "id", "className", "index"], action: "_click", value: "value"});	
	this.addAD({tag: "BUTTON", type: "submit", event:"click", name: "_submit", attributes: ["sahiText", "name", "id", "className", "index"], action: "_click", value: "sahiText"});	

	this.addAD({tag: "INPUT", type: "text", event:"change", name: "_textbox", attributes: ["name", "id", "index", "className"], action: "_setValue", value: "value"});
	
	this.addAD({tag: "INPUT", type: "reset", event:"click", name: "_reset", attributes: ["value", "name", "id", "className", "index"], action: "_click", value: "value"});	
	this.addAD({tag: "BUTTON", type: "reset", event:"click", name: "_reset", attributes: ["sahiText", "name", "id", "className", "index"], action: "_click", value: "sahiText"});	

	this.addAD({tag: "INPUT", type: "hidden", event:"", name: "_hidden", attributes: ["name", "id", "className", "index"], action: "_setValue", value: "value"});	
	
	this.addAD({tag: "INPUT", type: "file", event:"click", name: "_file", attributes: ["name", "id", "index", "className"], action: "_setFile", value: "value"});	
	this.addAD({tag: "INPUT", type: "image", event:"click", name: "_imageSubmitButton", attributes: ["title|alt", "name", "id", 
	                  this.getFileFromURL, "index", "className"], action: "_click"});	
	this.addAD({tag: "INPUT", type: "date", event:"change", name: "_datebox", attributes: ["name", "id", "index", "className"], action: "_setValue", value: "value"});
	this.addAD({tag: "INPUT", type: "datetime", event:"change", name: "_datetimebox", attributes: ["name", "id", "index", "className"], action: "_setValue", value: "value"});
	this.addAD({tag: "INPUT", type: "datetime-local", event:"change", name: "_datetimelocalbox", attributes: ["name", "id", "index", "className"], action: "_setValue", value: "value"});
	this.addAD({tag: "INPUT", type: "email", event:"change", name: "_emailbox", attributes: ["name", "id", "index", "className"], action: "_setValue", value: "value"});
	this.addAD({tag: "INPUT", type: "month", event:"change", name: "_monthbox", attributes: ["name", "id", "index", "className"], action: "_setValue", value: "value"});
	this.addAD({tag: "INPUT", type: "number", event:"change", name: "_numberbox", attributes: ["name", "id", "index", "className"], action: "_setValue", value: "value"});
	this.addAD({tag: "INPUT", type: "range", event:"change", name: "_rangebox", attributes: ["name", "id", "index", "className"], action: "_setValue", value: "value"});
	this.addAD({tag: "INPUT", type: "search", event:"change", name: "_searchbox", attributes: ["name", "id", "index", "className"], action: "_setValue", value: "value"});
	this.addAD({tag: "INPUT", type: "tel", event:"change", name: "_telephonebox", attributes: ["name", "id", "index", "className"], action: "_setValue", value: "value"});
	this.addAD({tag: "INPUT", type: "time", event:"change", name: "_timebox", attributes: ["name", "id", "index", "className"], action: "_setValue", value: "value"});
	this.addAD({tag: "INPUT", type: "url", event:"change", name: "_urlbox", attributes: ["name", "id", "index", "className"], action: "_setValue", value: "value"});
	this.addAD({tag: "INPUT", type: "week", event:"change", name: "_weekbox", attributes: ["name", "id", "index", "className"], action: "_setValue", value: "value"});

	
	
	this.addAD({tag: "SELECT", type: null, event:"change", name: "_select", attributes: ["name", "id", "index", "className"], action: "_setSelected", value: function(el){return _sahi._getSelectedText(el) || _sahi.getOptionId(el, el.value) || el.value;},
		assertions: function(value){return [_sahi.language.ASSERT_SELECTION];}});	
	this.addAD({tag: "OPTION", type: null, event:"none", name: "_option", attributes: ["encaps_SELECT", "sahiText", "value", "id", "index"], action: "", value: "sahiText"});	
	this.addAD({tag: "TEXTAREA", type: null, event:"change", name: "_textarea", attributes: ["name", "id", "index", "className"], action: "_setValue", value: "value"});
	this.addAD({tag: "H1", type: null, event:"click", name: "_heading1", attributes: ["sahiText", "id", "className", "index"], action: "_click", value: "sahiText"});
	this.addAD({tag: "H2", type: null, event:"click", name: "_heading2", attributes: ["sahiText", "id", "className", "index"], action: "_click", value: "sahiText"});
	this.addAD({tag: "H3", type: null, event:"click", name: "_heading3", attributes: ["sahiText", "id", "className", "index"], action: "_click", value: "sahiText"});
	this.addAD({tag: "H4", type: null, event:"click", name: "_heading4", attributes: ["sahiText", "id", "className", "index"], action: "_click", value: "sahiText"});
	this.addAD({tag: "H5", type: null, event:"click", name: "_heading5", attributes: ["sahiText", "id", "className", "index"], action: "_click", value: "sahiText"});
	this.addAD({tag: "H6", type: null, event:"click", name: "_heading6", attributes: ["sahiText", "id", "className", "index"], action: "_click", value: "sahiText"});
	
	this.addAD({tag: "AREA", type: null, event:"click", name: "_area", attributes: ["id", "title|alt", "href", "shape", "className", "index"], action: "_click"});
	this.addAD({tag: "MAP", type: null, event:"click", name: "_map", attributes: ["name", "id", "title", "className", "index"], action: "_click"});

	this.addAD({tag: "I", type: null, event:"click", name: "_italic", attributes: ["encaps_A", "sahiText", "id", "className", "index"], action: "_click", value: "sahiText"});
	this.addAD({tag: "EM", type: null, event:"click", name: "_emphasis", attributes: ["encaps_A", "sahiText", "id", "className", "index"], action: "_click", value: "sahiText"});
	this.addAD({tag: "B", type: null, event:"click", name: "_bold", attributes: ["encaps_A", "sahiText", "id", "className", "index"], action: "_click", value: "sahiText"});
	this.addAD({tag: "STRONG", type: null, event:"click", name: "_strong", attributes: ["encaps_A", "sahiText", "id", "className", "index"], action: "_click", value: "sahiText"});
	this.addAD({tag: "PRE", type: null, event:"click", name: "_preformatted", attributes: ["sahiText", "id", "className", "index"], action: "_click", value: "sahiText"});
	this.addAD({tag: "CODE", type: null, event:"click", name: "_code", attributes: ["sahiText", "id", "className", "index"], action: "_click", value: "sahiText"});
	this.addAD({tag: "BLOCKQUOTE", type: null, event:"click", name: "_blockquote", attributes: ["sahiText", "id", "className", "index"], action: "_click", value: "sahiText"});	
	this.addAD({tag: "CANVAS", type: null, event:"click", name: "_canvas", attributes: ["sahiText", "id", "className", "index"], action: "_click", value: "sahiText"});
	this.addAD({tag: "ABBR", type: null, event:"click", name: "_abbr", attributes: ["encaps_A", "sahiText", "id", "className", "index"], action: "_click", value: "sahiText"});

};
Sahi.prototype.getAssertions = function(accs, info){
	var a = [this.language.ASSERT_EXISTS, this.language.ASSERT_VISIBLE];
	for (var k=0; k<accs.length; k++){
		var acc = accs[k];
		if (acc.assertions)
			a = a.concat(acc.assertions(info.value));
	}
	if (info.valueType == "sahiText"){
		a[a.length] = this.language.ASSERT_EQUAL_TEXT; 
		a[a.length] = this.language.ASSERT_CONTAINS_TEXT; 
	} else if (info.valueType == "value"){
		a[a.length] = this.language.ASSERT_EQUAL_VALUE; 
	}
	return a;
};
var sahiLanguage = {
		ASSERT_EXISTS: "<popup>_assertExists(<accessor>);",
		ASSERT_VISIBLE: "<popup>_assert(_isVisible(<accessor>));",
		ASSERT_EQUAL_TEXT: "<popup>_assertEqual(<value>, _getText(<accessor>));",
		ASSERT_CONTAINS_TEXT: "<popup>_assertContainsText(<value>, <accessor>);",
		ASSERT_EQUAL_VALUE: "<popup>_assertEqual(<value>, _getValue(<accessor>));",
		ASSERT_SELECTION: "<popup>_assertEqual(<value>, _getSelectedText(<accessor>));",
		ASSERT_CHECKED: "<popup>_assert(<accessor>.checked);",
		ASSERT_NOT_CHECKED: "<popup>_assertNotTrue(<accessor>.checked);",
		POPUP: "_popup(<window_name>).",
		DOMAIN: "_domain(<domain>)."
};
_sahi.language = sahiLanguage;
/** id end **/
_sahi.init();
/** Selenium start **/
Sahi.prototype._bySeleniumLocator = function(locator){
	if (locator.indexOf("//") == 0) return this._byXPath(locator);
	else if (locator.indexOf("document") == 0) return this._accessor(locator);
	else return this._byId(locator) || this.byName(locator, "*");
}
/** Selenium end **/
Sahi.prototype.loadXPathScript = function(){
	if (this._isFF() || this._isHTMLUnit()) return false;
	if (!(document.implementation && document.implementation.hasFeature && document.implementation.hasFeature("XPath", null))){
		this.loadScript('/_s_/spr/ext/javascript-xpath/javascript-xpath.js', "_sahi_concat");
	}
}
Sahi.prototype.loadScript = function(src, id){
	var newcontent = document.createElement('script');
	newcontent.src = src;
	var bef = document.getElementById(id);
	bef.parentNode.insertBefore(newcontent, bef);	
}
//document.body.onclick = function(){alert(window.event.clientX + " " + window.event.clientY)}

Sahi.prototype.setLastHTMLSnapShotFile = function(filePath){
	try{
		var $htmlUnitViewer = new Packages.com.pushtotest.sahi.SahiHTMLUnit();
		if($htmlUnitViewer){
			if(filePath){
				var $file = new Packages.java.io.File(filePath);
				filePath = $htmlUnitViewer.takeSnapShot($file);
			}
		}
	} catch(e){}
}
__sahiDebug__("concat.js: end");