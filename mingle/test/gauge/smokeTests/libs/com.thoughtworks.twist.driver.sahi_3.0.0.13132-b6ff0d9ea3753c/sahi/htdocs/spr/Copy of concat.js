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

String.isBlankOrNull = function (s) {
    return (s == "" || s == null);
};

var Sahi = function(){
    this.cmds = new Array();
    this.cmdDebugInfo = new Array();

    this.cmdsLocal = new Array();
    this.cmdDebugInfoLocal = new Array();

    this.waitInterval = -1;

    this.promptReturnValue = new Array();
    this.waitCondition = null;

    this.locals = [];

    this.INTERVAL = 100;
    this.ONERROR_INTERVAL = 1000;
    this.MAX_RETRIES = 5;
    this.SAHI_MAX_WAIT_FOR_LOAD = 30;
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

    window.alert = function (s){return _sahi.alertMock(s)};
    window.confirm = function (s){return _sahi.confirmMock(s)};
    window.prompt = function (s){return _sahi.promptMock(s)};
    window.print = function (s){return _sahi.printMock(s)};

    this.XHRs = [];
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
    this.diagnostics = new Object();
    this.storeDiagnostics();
    this.strictVisibilityCheck = false; 
};
Sahi.prototype.storeDiagnostics = function(){
    var d = this.diagnostics;
    d["UserAgent"] = navigator.userAgent;
    d["Native XMLHttpRequest"] = typeof XMLHttpRequest != "undefined";
};
Sahi.prototype.printDiagnostics = function(){
    var s = this.getDiagnostics();
    this._debug(s);
    return s;
};
Sahi.prototype.getDiagnostics = function(){
    var s = "";
    for (var key in this.diagnostics){
        s += key +": "+ this.diagnostics[key]+"\n";
    }
    return s;
};
var _sahi = new Sahi();
var tried = false;
var _sahi_top = window.top;
Sahi.prototype.top = function () {
    //Hack for frames named "top"
	try{
		var x = _sahi_top.location.href; // test
		return _sahi_top;
	}catch(e){
		var p = window;
		while (p != p.parent){
			try{
				var y = p.parent.location.href; // test
				p = p.parent;
			}catch(e){
				return p;
			}
		}
		return p;
	}
};

Sahi.prototype.getAccessor = function (src) {
    try{
        var fr = this.getFrame(this.top(), "top");
        var a = this.getPartialAccessor(src);
        if (a == "" || a == null) return a;
        var elStr = fr + ".document." + a;
        var v = this.getArrayElement(elStr, src);
        return v;
    }catch(e){}
};

Sahi.prototype.getKnownTags = function (src) {
    var el = src;
    while (true) {
        if (!el) return src;
        if (!el.tagName || el.tagName.toLowerCase() == "html" || el.tagName.toLowerCase() == "body") return null;
        var tag = el.tagName.toLowerCase();
        if (tag == "a" || tag == "select" || tag == "img" || tag == "form"
            || tag == "input" || tag == "button" || tag == "textarea"
            || tag == "textarea" || tag == "td" || tag == "table"
            || ((tag == "div" || tag == "span")) || tag == "label" || tag == "li" ) return el;
        el = el.parentNode;
    }
};
Sahi.prototype.byId = function (src) {
    var s = src.id;
    if (String.isBlankOrNull(s)) return "";
    return "getElementById('" + s + "')";
};
Sahi.prototype.getPartialAccessor = function (src) {
    if (src == null || src.tagName == null) return null;
    var tag = src.tagName.toLowerCase();
    var a = this.byId(src);
    if (a != "" && eval("document." + a) == src) {
        return a;
    }

    if (tag == "img") {
        return this.getImg(src);
    }
    else if (tag == "a") {
        return this.getLink(src);
    }
    else if (tag == "form") {
        return this.getForm(src);
    }
    else if (tag == "button" || tag == "input" || tag == "textarea" || tag == "select") {
        return this.getFormElement(src);
    }
    else if (tag == "td") {
        return this.getTableCell(src);
    }
    else if (tag == "table") {
        return this.getTable(src);
    }
    else if (tag == "div" || tag == "span"){
        return this.getByTagName(src);
    }
    else if (tag == "label"){
        return this.getByTagName(src);
    }
    return null;
};
Sahi.prototype.getLink = function (src) {
    var lnx = window.document.getElementsByTagName("A");
    for (var j = 0; j < lnx.length; j++) {
        if (lnx[j] == src) {
            return "links[" + j + "]";
        }
    }
    return  null;
};
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
    if (!String.isBlankOrNull(src.name) && this.nameNotAnInputElement(src)) {
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
Sahi.prototype.getFormElement = function (src) {
    return this.getByTagName(src);
};

Sahi.prototype.getByTagName = function (src) {
    var tagName = src.tagName.toLowerCase();
    var els = window.document.getElementsByTagName(tagName);
    return "getElementsByTagName('" + tagName + "')[" + this.findInArray(els, src) + "]";
};

Sahi.prototype.getTable = function (src) {
    var tables = window.document.getElementsByTagName("table");
    if (src.id && src.id != null && src == window.document.getElementById(src.id)) {
        return "getElementById('" + src.id + "')";
    }
    return "getElementsByTagName('table')[" + this.findInArray(tables, src) + "]";
};

Sahi.prototype.getTableCell = function (src) {
    var tables = window.document.getElementsByTagName("table");
    var row = this.getRow(src);
    if (row.id && row.id != null && row == window.document.getElementById(row.id)) {
        return "getElementById('" + row.id + "').cells[" + src.cellIndex + "]";
    }
    var table = this.getTableEl(src);
    if (table.id && table.id != null && table == window.document.getElementById(table.id)) {
        return "getElementById('" + table.id + "').rows[" + this.getRow(src).rowIndex + "].cells[" + src.cellIndex + "]";
    }
    return "getElementsByTagName('table')[" + this.findInArray(tables, this.getTableEl(src)) + "].rows[" + this.getRow(src).rowIndex + "].cells[" + src.cellIndex + "]";
};

Sahi.prototype.getRow = function (src) {
    return this.getParentNode(src, "tr");
};

Sahi.prototype.getTableEl = function (src) {
    return this.getParentNode(src, "table");
};

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
    var el = src;
    while (el && el.tagName && el.tagName.toLowerCase() != "a") {
        el = el.parentNode;
    }
    return el;
};

Sahi.prototype.getFrame = function (win, s) {
    if (win == self) return s;
    var frs = win.frames;
    for (var j = 0; j < frs.length; j++) {
        var n = frs[j].name;
        if (String.isBlankOrNull(n)) n = "frames[" + j + "]";
        var sub = this.getFrame(frs[j], n);
        if (sub != null) {
            return s + "." + sub;
        }
    }
    return null;
};

var linkClick = function (e) {
    if (!e) e = window.event;
    var performDefault = true;
    if (this.prevClick) {
        performDefault = this.prevClick.apply(this, arguments);
    }
    //_sahi.real_alert(e);
    _sahi.lastLinkEvent = e;
    _sahi.lastLink = this;
    if (performDefault != false) {
        window.setTimeout(function(){_sahi.navigateLink()}, 10);
    } else {
        return false;
    }
};
Sahi.prototype._dragDrop = function (draggable, droppable) {
    this.checkNull(draggable, "_dragDrop", 1, "draggable");
    this.checkNull(droppable, "_dragDrop", 2, "droppable");
    var pos = this.findPos(droppable);
    var x = pos[0];
    var y = pos[1];
    this._dragDropXY(draggable, x, y);
};
Sahi.prototype.addBorder = function(el){
    el.style.border = "1px solid red";
};
Sahi.prototype._dragDropXY = function (draggable, x, y, isRelative) {
    this.checkNull(draggable, "_dragDropXY", 1, "draggable");
    this.simulateMouseEvent(draggable, "mousemove");
    this.simulateMouseEvent(draggable, "mousedown");
    this.simulateMouseEvent(draggable, "mousemove");

    var addX = 0, addY = 0;
    if (isRelative){
        var pos = this.findPos(draggable);
        addX = pos[0];
        addY = pos[1];
        if (!x) x = 0;
        if (!y) y = 0;
        x += addX;
        y += addY;
    }else{
        if (!x) x = this.findPos(draggable)[0];
        if (!y) y = this.findPos(draggable)[1];
    }

    this.simulateMouseEventXY(draggable, "mousemove", x, y);
    this.simulateMouseEventXY(draggable, "mouseup", x, y);
    this.simulateMouseEventXY(draggable, "click", x, y);
    this.simulateMouseEventXY(draggable, "mousemove", x, y);
};
Sahi.prototype.checkNull = function (el, fnName, paramPos, paramName) {
    if (el == null) {
        throw new Error("The " +
        (paramPos==1?"first ":paramPos==2?"second ":paramPos==3?"third ":"") +
        "parameter passed to " + fnName + " was not found on the browser");
    }
};
Sahi.prototype.checkVisible = function (el) {
    if (this.strictVisibilityCheck && !this._isVisible(el)) {
        throw "" + el + " is not visible";
    }
};
Sahi.prototype._isVisible = function (el) {
    try{
        if (el == null) return false;
        var elOrig = el;
        var display = true;
        while (true){
            display = display && this.isStyleDisplay(el);
            if (!display || el.parentNode == el || el.tagName == "BODY") break;
            el = el.parentNode;
        }
        el = elOrig;
        var visible = true;
        while (true){
            visible = visible && this.isStyleVisible(el);
            if (!visible || el.parentNode == el || el.tagName == "BODY") break;
            el = el.parentNode;
        }
        return display && visible;
    } catch(e){return true;}

};
Sahi.prototype.isStyleDisplay = function(el){
    var d = this._style(el, "display");
    return d==null || d != "none";
};
Sahi.prototype.isStyleVisible = function(el){
    var v = this._style(el, "visibility");
    return v==null || v != "hidden";
};
Sahi.prototype._click = function (el) {
    this.checkNull(el, "_click");
    this.checkVisible(el);
    this.simulateClick(el, false, false);
};

Sahi.prototype._doubleClick = function (el) {
    this.checkNull(el, "_doubleClick");
    this.checkVisible(el);
    this.simulateClick(el, false, true);
};

Sahi.prototype._rightClick = function (el) {
    this.checkNull(el, "_rightClick");
    this.checkVisible(el);
    this.simulateClick(el, true, false);
};

Sahi.prototype._mouseOver = function (el) {
    this.checkNull(el, "_mouseOver");
    this.checkVisible(el);
    this.simulateMouseEvent(el, "mousemove");
    this.simulateMouseEvent(el, "mouseover");
};

Sahi.prototype._keyPress = function (el, charCode, combo) {
    this.checkNull(el, "_keyPress", 1);
    this.checkVisible(el);
    if (typeof charCode == "string"){
        charCode = charCode.charCodeAt(0);
    }
    var c = String.fromCharCode(charCode);
    var prev = el.value;
    this.simulateMouseEvent(el, "focus");
    this.simulateKeyEvent(charCode, el, "keydown", combo);
    this.simulateKeyEvent(charCode, el, "keypress", combo);
    if (prev + c != el.value) {
        //      if (!el.maxLength || el.value.length < el.maxLength)
        el.value = el.value + c;
    }
    this.simulateKeyEvent(charCode, el, "keyup", combo);
};

Sahi.prototype._focus = function (el) {
    this.simulateMouseEvent(el, "focus");
};

Sahi.prototype._blur = function (el) {
    this.simulateMouseEvent(el, "blur");
};
Sahi.prototype._removeFocus = Sahi.prototype._blur;
Sahi.prototype._keyDown = function (el, charCode, combo) {
    this.checkNull(el, "_keyDown", 1);
    this.checkVisible(el);
    this.simulateKeyEvent(charCode, el, "keydown", combo);
};

Sahi.prototype._keyUp = function (el, charCode, combo) {
    this.checkNull(el, "_keyUp", 1);
    this.checkVisible(el);
    this.simulateKeyEvent(charCode, el, "keyup", combo);
};


Sahi.prototype._readFile = function (fileName) {
    var qs = "fileName=" + fileName;
    return this._callServer("net.sf.sahi.plugin.FileReader_contents", qs);
};
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
Sahi.prototype.simulateClick = function (el, isRight, isDouble) {
    var n = el;

    if (this.isIE() && !isRight) {
        if (el && (el.tagName == "LABEL" || (el.type && (el.type == "submit" || el.type == "button"
            || el.type == "reset" || el.type == "image"
            || el.type == "checkbox" || el.type == "radio")))) {
            el.click();
            if (el.type && (el.type == "checkbox")){
            	this.simulateChange(el);
            }
            return;
        }
    }

    var lastN = null;
    while (n != null && n != lastN) {
        if (n.tagName && n.tagName == "A") {
            n.prevClick = n.onclick;
            n.onclick = this.getWindow(el).linkClick;
        }
        lastN = n;
        n = n.parentNode;
    }

    this.simulateMouseEvent(el, "mousemove");
    this.simulateMouseEvent(el, "focus");
    this.simulateMouseEvent(el, "mouseover");
    this.simulateMouseEvent(el, "mousedown", isRight);
    this.simulateMouseEvent(el, "mouseup", isRight);
    if (isRight) {
        this.simulateMouseEvent(el, "contextmenu", isRight, isDouble);
    } else {
        try {
            if (!window.opera) this.simulateMouseEvent(el, "click", isRight, isDouble);
            if (this.isSafariLike()) {
                if (el.tagName == "INPUT") {
                    if (typeof el.checked == "boolean") {
                        el.checked = (el.type == "radio") ? true : !el.checked;
                    } 
                }
            }
        } catch(e) {
        }
    }
    this.simulateMouseEvent(el, "blur");
    n = el;
    lastN = null;
    while (n != null && n != lastN) {
        if (n.tagName && n.tagName == "A") {
            n.onclick = n.prevClick;
        }
        n = n.parentNode;
    }
};
Sahi.prototype.isSafariLike = function () {
    return /Konqueror|Safari|KHTML/.test(navigator.userAgent);
};
Sahi.prototype.simulateMouseEvent = function (el, type, isRight, isDouble) {
    var xy = this.findPos(el);
    var x = xy[0];
    var y = xy[1];
    this.simulateMouseEventXY(el, type, xy[0], xy[1], isRight, isDouble);
};
Sahi.prototype.simulateMouseEventXY = function (el, type, x, y, isRight, isDouble) {
    if (window.document.createEvent) {
        if (this.isSafariLike()) {
            var evt = el.ownerDocument.createEvent('HTMLEvents');
            evt.initEvent(type, true, true);
            el.dispatchEvent(evt);
        }
        else {
            // FF
            var evt = el.ownerDocument.createEvent("MouseEvents");
            evt.initMouseEvent(
            (isDouble ? "dbl" : "") + type,
            true, //can bubble
            true,
            el.ownerDocument.defaultView,
            (isDouble ? 2 : 1),
            x, //screen x
            y, //screen y
            x, //client x
            y, //client y
            false,
            false,
            false,
            false,
            isRight ? 2 : 0,
            null);
            el.dispatchEvent(evt);
        }
    } else {
        // IE
        var evt = el.ownerDocument.createEventObject();
        evt.clientX = x;
        evt.clientY = y;
        evt.button = isRight ? 2 : 1;
        el.fireEvent("on" + (isDouble ? "dbl" : "") + type, evt);
        evt.cancelBubble = true;
    }
};
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
Sahi.prototype.findPos = function (obj){
    var x = 0, y = 0;
    if (obj.offsetParent)
    {
        while (obj.offsetParent)
        {
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
    return [x, y];
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
    if ((this.isIE() || this.isSafariLike()) && this.lastLinkEvent.returnValue == false) return;
    var win = this.getWindow(ln);
    if (ln.href.indexOf("javascript:") == 0) {
        var s = ln.href.substring(11);
        win.setTimeout(unescape(s), 0);
    } else {
        var target = ln.target;
        if (ln.target == null || ln.target == "") target = "_self";
        if (this.isSafariLike()) {
            var targetWin = win.open("", target);
            try {
                targetWin._sahi.onBeforeUnLoad();
            } catch(e) {
                this._debug(e.message);
            }
            targetWin.location.href = ln.href;
        }
        else win.open(ln.href, target);
    }
};

Sahi.prototype.getClickEv = function (el) {
    var e = new Object();
    if (this.isIE()) el.srcElement = e;
    else e.target = el;
    e.stopPropagation = this.noop;
    return e;
};

Sahi.prototype.noop = function () {
};

// api for link click end

Sahi.prototype._type = function (el, val) {
	for (var i = 0; i < val.length; i++) {
		var ccode = val.charAt(i).charCodeAt(0);
	    this.simulateKeyEvent(ccode, el, "keydown");
	    this.simulateKeyEvent(ccode, el, "keypress");
	    this.simulateKeyEvent(ccode, el, "keyup");
	}
};

Sahi.prototype._setValue = function (el, val) {
	this.setValue(el, val);
};
// api for set value start
Sahi.prototype.setValue = function (el, val) {
    this.checkNull(el, "_setValue", 1);
    this.checkVisible(el);
    val = "" + val;
    var prevVal = el.value;
    if (!window.document.createEvent) el.value = val;
    if (el.type && el.type.indexOf("select") != -1) {
    } else {
        var append = false;
        el.value = "";
        if (typeof val == "string") {
            for (var i = 0; i < val.length; i++) {
                var c = val.charAt(i);
                var ccode = c.charCodeAt(0);
                this.simulateKeyEvent(ccode, el, "keydown");
                this.simulateKeyEvent(ccode, el, "keypress");
                if (i == 0 && el.value != c) {
                    append = true;
                }
                if (append) {
                    //if (!el.maxLength || el.value.length < el.maxLength)
                    el.value += c;
                }
                this.simulateKeyEvent(ccode, el, "keyup");
            }
        }
    }
    if (!this.isIE()) this.simulateEvent(el, "blur");
    if (prevVal != val) {
        if (!this.isFF3()) this.simulateEvent(el, "change");
    }
    if (this.isIE()) this.simulateEvent(el, "blur");
    if (el && el.form){
        try{
            this.simulateEvent(el.form, "change");
        }catch(e){}
    }
};
Sahi.prototype._setFile = function (el, v, url) {
    if (!url) url = (String.isBlankOrNull(el.form.action) || (typeof el.form.action != "string")) ? this.getWindow(el).location.href : el.form.action;
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
    this._callServer("FileUpload_setFile", "n=" + el.name + "&v=" + encodeURIComponent(v) + "&action=" + encodeURIComponent(url));
};

Sahi.prototype.simulateEvent = function (target, evType) {
    if (window.document.createEvent) {
        var evt = new Object();
        evt.type = evType;
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

Sahi.prototype.simulateKeyEvent = function (charCode, target, evType, combo) {
    var c = String.fromCharCode(charCode);
    var isShift = combo == "SHIFT" || (charCode >= 65 && charCode <= 122 && c.toUpperCase() == c);

    if (window.document.createEvent) { // FF
        if (this.isSafariLike() || window.opera) {
            var event = target.ownerDocument.createEvent('HTMLEvents');

            var evt = event;
            if (!window.opera){
	            evt.bubbles = true;
	            evt.cancelable = true;
            }
            evt.ctrlKey = combo == "CTRL";
            evt.altKey = combo == "ALT";
            evt.metaKey = combo == "META";
            evt.charCode = charCode;
            evt.keyCode = charCode;
            evt.shiftKey = isShift;


            event.initEvent(evType, false, false);
            target.dispatchEvent(event);
        } else {
            var evt = new Object();
            evt.type = evType;
            evt.bubbles = true;
            evt.cancelable = true;
            evt.ctrlKey = combo == "CTRL";
            evt.altKey = combo == "ALT";
            evt.metaKey = combo == "META";
            if (charCode >= 31 && charCode <= 256){
                evt.charCode = charCode;
                evt.keyCode = 0;
            }else{
                evt.charCode = 0;
                evt.keyCode = charCode;
            }
            evt.shiftKey = isShift;

            if (!target) return;
            var event = target.ownerDocument.createEvent("KeyEvents");
            event.initKeyEvent(evt.type, evt.bubbles, evt.cancelable, target.ownerDocument.defaultView,
            evt.ctrlKey, evt.altKey, evt.shiftKey, evt.metaKey, evt.keyCode, evt.charCode);
            target.dispatchEvent(event);
        }
    } else {
        var evt = target.ownerDocument.createEventObject();
        evt.type = evType;
        evt.bubbles = true;
        evt.cancelable = true;
        var xy = this.findPos(target);
        evt.clientX = xy[0];
        evt.clientY = xy[1];
        evt.ctrlKey = combo == "CTRL";
        evt.altKey = combo == "ALT";
        evt.metaKey = combo == "META";
        evt.keyCode = charCode;
        evt.shiftKey = isShift; //c.toUpperCase().charCodeAt(0) == evt.charCode;
        evt.shiftLeft = isShift;
        evt.cancelBubble = true;
        target.fireEvent("on" + evType, evt);
    }
};

Sahi.prototype._setSelected = function (el, val, isMultiple) {
    var l = el.options.length;
    var optionEl = null;
    if (typeof val == "string" || val instanceof RegExp){
        for (var i = 0; i < l; i++) {
            if (this.areEqual(el.options[i], "text", val) ||
                this.areEqual(el.options[i], "id", val)) {
                optionEl = el.options[i];
            }
        }
    } else if (typeof val == "number" && el.options.length > val){
        optionEl = el.options[val];
    }
    if (!optionEl) throw new Error("Option not found: " + val);

    for (var i = 0; i < l; i++) {
        if (!isMultiple) el.options[i].selected = false;
    }

    optionEl.selected = true;
    this.simulateEvent(el, "change");
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
Sahi.prototype._button = function (n, inEl) {
    var el = this.findElement(n, "button", "input", inEl);
    if (el == null) el = this.findElement(n, "button", "button", inEl);
    return el;
};
Sahi.prototype._reset = function (n, inEl) {
    var el = this.findElement(n, "reset", "input", inEl);
    if (el == null) el = this.findElement(n, "reset", "button", inEl);
    return el;
};
Sahi.prototype._submit = function (n, inEl) {
    var el = this.findElement(n, "submit", "input", inEl);
    if (el == null) el = this.findElement(n, "submit", "button", inEl);
    return el;
};
Sahi.prototype._wait = function (i, condn) {
    this.setServerVar("waitConditionTime", new Date().valueOf()+i);
    if (condn) {
        this.waitCondition = condn;
        this.setServerVar("waitCondition", condn);
        window.setTimeout("_sahi.cancelWaitCondition()", i);
    }
    else {
        window.setTimeout("_sahi.cancelWaitCondition()", i);
        this.waitInterval = i;
    }
};

Sahi.prototype.cancelWaitCondition = function (){
    this.waitCondition=null;
    this.waitInterval=this.INTERVAL;
    this.setServerVar("waitCondition", null);
    this.setServerVar("waitConditionTime", -1);
};

Sahi.prototype._file = function (n, inEl) {
    return this.findElement(n, "file", "input", inEl);
};
Sahi.prototype._textbox = function (n, inEl) {
    return this.findElement(n, "text", "input", inEl);
};
Sahi.prototype._password = function (n, inEl) {
    return this.findElement(n, "password", "input", inEl);
};
Sahi.prototype._checkbox = function (n, inEl) {
    return this.findElement(n, "checkbox", "input", inEl);
};
Sahi.prototype._textarea = function (n, inEl) {
    return this.findElement(n, "textarea", "textarea", inEl);
};
Sahi.prototype._hidden = function (n, inEl) {
    return this.findElement(n, "hidden", "input", inEl);
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
Sahi.prototype._byClassName = function (className, tagName, inEl) {
	if (!inEl) inEl = this.top();
    var res = this.getBlankResult();
    var el = this.findTagHelper(className, inEl, tagName, res, "className").element;
    return el;
};
Sahi.prototype._select = function (n, inEl) {
    var el = this.findElement(n, "select", "select", inEl);
    //    if (!el) el = this.findElement(n, "select-multiple", "select");
    return el;
};
Sahi.prototype._radio = function (n, inEl) {
    return this.findElement(n, "radio", "input", inEl);
};
Sahi.prototype._div = function (id, inEl) {
	return this.spandivcommon(id, inEl, "div");
};
Sahi.prototype._span = function (id, inEl) {
	return this.spandivcommon(id, inEl, "span");
};
Sahi.prototype.spandivcommon = function (id, inEl, tagName) {
	if (!inEl) inEl = this.top();
    var res = this.getBlankResult();
    var el = this.findTagHelper(id, inEl, tagName, res, "id").element;
    if (el == null) el = this.tagByText(inEl, id, tagName, res).element;
    return el;
};
Sahi.prototype._spandiv = function (id, inEl) {
	if (!inEl) inEl = this.top();
    var el = this._span(id, inEl);
    if (el == null) el = this._div(id, inEl);
    return el;
};
Sahi.prototype._listItem = function (id) {
    var res = this.getBlankResult();
    var el = this.findTagHelper(id, this.top(), "li", res, "id").element;
    if (el == null) el = this.tagByText(this.top(), id, "li", res).element;
    return el;
};
Sahi.prototype._label = function (id) {
    var res = this.getBlankResult();
    var el = this.findTagHelper(id, this.top(), "label", res, "id").element;
    if (el == null) el = this.tagByText(this.top(), id, "label", res).element;
    return el;
};
Sahi.prototype.tagByText = function (win, id, tagName, res) {
    var o = this.getArrayNameAndIndex(id);
    var ix = o.index;
    var fetch = o.name;
    var els = this.getDoc(win).getElementsByTagName(tagName);
    for (var i = 0; i < els.length; i++) {
        var el = els[i];
        var text = this._getText(el);

        if (this.isTextMatch(text, fetch)) {
            res.cnt++;
            if (res.cnt == ix || ix == -1) {
                res.element = this.innerMost(el, id, tagName.toUpperCase());
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
        if (text && text.match(re)){
            var inner = this.innerMost(child, re, tagName);
            if (inner.nodeName == tagName) return inner;
        }
    }
    return el;
};
Sahi.prototype._image = function (n, inEl) {
    return this.findImage(n, inEl);
};
Sahi.prototype._imageSubmitButton = function (n, inEl) {
    return this.findElement(n, "image", "input", inEl);
};
Sahi.prototype._link = function (n, inEl) {
    return this.findLink(n, inEl);
};
Sahi.prototype._simulateEvent = function (el, ev) {
    if (this.isIE()) {
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
    if (this.trim(expected) != this.trim(actual)) throw new SahiAssertionException(3, (s ? s : "") + "\nExpected:[" + expected + "]\nActual:[" + actual + "]");
    return true;
};
Sahi.prototype._assertNotEqual = function (expected, actual, s) {
    if (this.trim(expected) == this.trim(actual)) throw new SahiAssertionException(4, s);
    return true;
};
Sahi.prototype._assertContainsText = function (expected, el, s) {
    var text = this._getText(el);
    var present = false;
    if (expected instanceof RegExp)
        present = expected != null && text.match(expected) != null;
    else present = text.indexOf(expected) != -1;
    if (!present) throw new SahiAssertionException(3, (s ? s : "") + "\nExpected:[" + expected + "] to be part of [" + text + "]");
    return true;
};
Sahi.prototype._getSelectedText = function (el) {
    var opts = el.options;
    for (var i = 0; i < opts.length; i++) {
        if (el.value == opts[i].value) return opts[i].text;
    }
    return null;
};
Sahi.prototype._option = function (el, text) {
    var opts = el.options;
    for (var i = 0; i < opts.length; i++) {
        if (text == opts[i].text) return opts[i];
    }
    return null;
};
Sahi.prototype._getText = function (el) {
    this.checkNull(el, "_getText");
    return this.trim(this.isIE() || this.isSafariLike() ? el.innerText : el.textContent);
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
            if (this._getText(r.cells[j]).indexOf(txt) != -1) {
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
            if (this._getText(r.cells[j]).indexOf(txt) != -1) {
                return j;
            }
        }
    }
    return -1;
};
Sahi.prototype._alert = function (s) {
    return this.callFunction(this.real_alert, window, s);
};
Sahi.prototype.alertMock = function (s) {
    if (this.isPlaying()) {
        this.setServerVar("lastAlertText", s);
        return;
    } else {
        return this._alert(s);
    }
};
Sahi.prototype._lastAlert = function () {
    var v = this.getServerVar("lastAlertText");
    return v;
};
Sahi.prototype._eval = function (s) {
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
    this._callServer("SaveAs_saveLastDownloadedAs", "destination="+encodeURIComponent(filePath));
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
Sahi.prototype.confirmMock = function (s) {
    if (this.isPlaying()) {
        var retVal = eval(this.getServerVar("confirm: "+s));
        if (retVal == null) retVal = true;
        this.setServerVar("lastConfirmText", s);
        this.setServerVar("confirm: "+s, null);
        return retVal;
    } else {
        var retVal = this.callFunction(this.real_confirm, window, s);
        this.sendToServer('/_s_/dyn/Recorder_record?cmd=' + encodeURIComponent("_expectConfirm(\"" + s + "\", " + retVal + ")"));
        return retVal;
    }
};
Sahi.prototype.callFunction = function(fn, obj, args){
    if (fn.apply){
        return fn.apply(window, [args]);
    }else{
        return fn(args);
    }
};
Sahi.prototype._lastConfirm = function () {
    var v = this.getServerVar("lastConfirmText");
    return v;
};

Sahi.prototype.promptMock = function (s) {
    if (this.isPlaying()) {
        var retVal = this.getServerVar("prompt: "+s);//this.promptReturnValue[s];
        if (retVal == null) retVal = "";
        this.setServerVar("lastPromptText", s);
        this.setServerVar("prompt: "+s, null);
        return retVal;
    } else {
        var retVal = this.callFunction(this.real_prompt, window, s);
        this.sendToServer('/_s_/dyn/Recorder_record?cmd=' + encodeURIComponent("_expectPrompt(\"" + s + "\", \"" + retVal + "\")"));
        return retVal;
    }
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

Sahi.prototype._print = function (s){
    return this.callFunction(this.real_print, window, s);
};
Sahi.prototype.printMock = function () {
    if (this.isPlaying()) {
        this.setServerVar("printCalled", true);
    } else {
        return this.callFunction(this.real_print, window);
    }
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
    	return this.findCell(id, row);
    }

    var rowIx = row;
    var colIx = col;
    if (typeof row == "string") {
        rowIx = this.getRowIndexWith(row, id);
        if (rowIx == -1) return null;
    }
    if (typeof col == "string") {
        colIx = this.getColIndexWith(col, id);
        if (colIx == -1) return null;
    }
    if (id.rows[rowIx] == null) return null;
    return id.rows[rowIx].cells[colIx];
};
Sahi.prototype._table = function (n, inEl) {
    return this.findTable(n, inEl);
};
Sahi.prototype._row = function (tableEl, rowIx) {
    if (typeof rowIx == "string") {
        return this.getRowWith(rowIx, tableEl);
    }
    if (typeof rowIx == "number") {
        return tableEl.rows[rowIx];
    }
    return null;
};
Sahi.prototype._containsHTML = function (el, htm) {
    return el && el.innerHTML && el.innerHTML.indexOf(htm) != -1;
};
Sahi.prototype._containsText = function (el, txt) {
    return el && this._getText(el).indexOf(txt) != -1;
};
Sahi.prototype._contains = function (parent, child) {
	var c = child;
    while (true){
    	if (c == parent) return true;
    	if (c == null || c == c.parentNode) return false;
    	c = c.parentNode;
    }
};
Sahi.prototype._popup = function (n) {
    if (this.top().name == n || this.top().document.title == n) {
        return this.top();
    }
    throw new SahiNotMyWindowException(n);
};
Sahi.prototype._log = function (s, type) {
    if (!type) type = "info";
    this.logPlayBack(s, type);
};
Sahi.prototype._navigateTo = function (url, force) {
    if (force || this.top().location.href != url)
        this.top().location.href = url;
    //        this.top().setTimeout("location.href = '"+url+"'", 1);
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
    return this._callServer("Debug_toOut", "msg=Debug: " + encodeURIComponent(s));
};
Sahi.prototype._debugToErr = function (s) {
    return this._callServer("Debug_toErr", "msg=" + encodeURIComponent(s));
};
Sahi.prototype._debugToFile = function (s, file) {
    if (file == null) return;
    return this._callServer("Debug_toFile", "msg=" + encodeURIComponent(s) + "&file=" + encodeURIComponent(file));
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

Sahi.prototype.simulateChange = function (el) {
    if (window.document.all) {
        if (el.onchange) el.onchange();
        if (el.onblur) el.onblur();
    } else {
        if (el.onblur) el.onblur();
        if (el.onchange) el.onchange();
    }
};
Sahi.prototype.areEqual2 = function (el, param, value) {
    if (param == "sahiText") {
        var str = this._getText(el);
        if (value instanceof RegExp)
            return str != null && str.match(value) != null
        return (this.trim(str) == this.trim(value));
    }
    else {
        if (value instanceof RegExp)
            return el[param] != null && el[param].match(value) != null
        return (el[param] == value);
    }
};
Sahi.prototype.areEqual = function (el, param, value) {
	if (typeof param == "function"){
		return this.callFunction(param, this, el) == value;
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
	    var imgs = isImg ? doc.getElementsByTagName("IMG") : doc.getElementsByTagName("A");
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
    var imgs = isImg ? doc.getElementsByTagName("IMG") : doc.getElementsByTagName("A");
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

    var imgs = isImg ? win.document.images : win.document.getElementsByTagName("A");
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
Sahi.prototype.findElement = function (id, type, tagName, inEl) {
    var res = this.getBlankResult();
    var retVal = null;
    if (!inEl) inEl = this.top();
    if (tagName == "button"){
        retVal = this.findElementHelper(id, inEl, type, res, (this.isIE() ? "innerText" : "textContent") , tagName).element;
        if (retVal != null) return retVal;
    } else if (type == "button" || type == "reset" || type == "submit") {
        retVal = this.findElementHelper(id, inEl, type, res, "value", tagName).element;
        if (retVal != null) return retVal;
    }
    else if (type == "image") {
        retVal = this.findElementHelper(id, inEl, type, res, "title|alt", tagName).element;
        if (retVal != null) return retVal;
    }

    res = this.getBlankResult();
    retVal = this.findElementHelper(id, inEl, type, res, "name", tagName).element;
    if (retVal != null) return retVal;

    res = this.getBlankResult();
    if (type == "radio" || type == "checkbox") {
        retVal = this.findElementHelper(id, inEl, type, res, "value", tagName).element;
        if (retVal != null) return retVal;
    }
    
    res = this.getBlankResult();
    return this.findElementHelper(id, inEl, type, res, "id", tagName).element;
};

Sahi.prototype.findFormElementByIndex = function (ix, win, type, res, tagName) {
    var els = this.getDoc(win).getElementsByTagName(tagName);
    for (var j = 0; j < els.length; j++) {
        var el = els[j];
        if (el != null && this.areEqualTypes(el.type, type)) {
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

Sahi.prototype.findElementHelper = function (id, win, type, res, param, tagName) {
    if ((typeof id) == "number") {
        res = this.findFormElementByIndex(id, win, type, res, tagName);
        if (res.found) return res;
    } else {
    	var doc = this.getDoc(win);
        var els = doc.getElementsByTagName(tagName);
        for (var j = 0; j < els.length; j++) {
            if (this.areEqualTypes(els[j].type, type) && this.areEqual(els[j], param, id)) {
                res.element = els[j];
                res.found = true;
                return res;
            }
        }

        var o = this.getArrayNameAndIndex(id);
        var ix = o.index;
        var fetch = o.name;
        els = this.getDoc(win).getElementsByTagName(tagName);
        for (var j = 0; j < els.length; j++) {
            if (this.areEqualTypes(els[j].type, type) && this.areEqual(els[j], param, fetch)) {
                res.cnt++;
                if (res.cnt == ix || ix == -1) {
                    res.element = els[j];
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

Sahi.prototype.findElementIx = function (id, toMatch, type, tagName) {
    var res = this.getBlankResult();
    var retVal = -1;

    if (id == null || id == "") {
        retVal = this.findElementIxHelper(id, type, toMatch, this.top(), res, null, tagName).cnt;
        if (retVal != -1) return retVal;
    }

    if (type == "button" || type == "reset" || type == "submit") {
        retVal = this.findElementIxHelper(id, type, toMatch, this.top(), res, "value", tagName).cnt;
        if (retVal != -1) return retVal;
    }
    else if (type == "image") {
        retVal = this.findElementIxHelper(id, type, toMatch, this.top(), res, "title|alt", tagName).cnt;
        if (retVal != -1) return retVal;
    }
    res = this.getBlankResult();
    retVal = this.findElementIxHelper(id, type, toMatch, this.top(), res, "name", tagName).cnt;
    if (retVal != -1) return retVal;

    res = this.getBlankResult();
    retVal = this.findElementIxHelper(id, type, toMatch, this.top(), res, "id", tagName).cnt;
    return retVal;

};
Sahi.prototype.findElementIxHelper = function (id, type, toMatch, win, res, param, tagName) {
    if (res && res.found) return res;
    var els = win.document.getElementsByTagName(tagName);
    for (var j = 0; j < els.length; j++) {
        if (this.areEqualTypes(els[j].type, type) && this.areEqual(els[j], param, id)) {
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
    res = this.findTagHelper(id, inEl, "td", res, "id").element;
    if (res != null) return res;
    res = this.getBlankResult();
    return this.findTagHelper(id, inEl, "td", res, "sahiText").element;
};

Sahi.prototype.findCellIx = function (id, toMatch, attr) {
    var res = this.getBlankResult();
    var retVal = this.findTagIxHelper(id, toMatch, this.top(), "td", res, attr).cnt;
    if (retVal != -1) return retVal;
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
    if (!(id instanceof RegExp) && id.match(/(.*)\[([0-9]*)\]$/)) {
        o.name = RegExp.$1;
        o.index = parseInt(RegExp.$2);
    } else {
        o.name = id;
        o.index = -1;
    }
    return o;
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
        if (el.name == name && el.type && this.areEqualTypes(el.type, type)) {
            matchedEls[matchedEls.length] = el;
        }
        else if ((el.type == "button" || el.type == "submit") && el.value == name && el.type == type) {
            matchedEls[matchedEls.length] = el;
        }
    }
    return (matchedEls.length > 0) ? (matchedEls.length == 1 ? matchedEls[0] : matchedEls ) : null;
};

Sahi.prototype.findTableIx = function (id, toMatch) {
    var res = this.getBlankResult();
    var retVal = this.findTagIxHelper(id, toMatch, this.top(), "table", res, (id ? "id" : null)).cnt;
    if (retVal != -1) return retVal;
};

Sahi.prototype.findTable = function (id, inEl) {
	if (!inEl) inEl = this.top();
    var res = this.getBlankResult();
    return this.findTagHelper(id, inEl, "table", res, "id").element;
};
Sahi.prototype._iframe = function (id, inEl) {
	if (!inEl) inEl = this.top();
    var res = this.getBlankResult();
    var el = this.findTagHelper(id, inEl, "iframe", res, "id").element;
    if (el != null) return el;

    res = this.getBlankResult();
    el = this.findTagHelper(id, inEl, "iframe", res, "name").element;
    if (el != null) return el;
};
Sahi.prototype._rte = Sahi.prototype._iframe;
Sahi.prototype.findResByIndexInList = function (ix, win, type, res) {
    var tags = this.getDoc(win).getElementsByTagName(type);
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


Sahi.prototype.findTagHelper = function (id, win, type, res, param) {
    if ((typeof id) == "number") {
        res.cnt = 0;
        res = this.findResByIndexInList(id, win, type, res);
        return res;
    } else {
        var o = this.getArrayNameAndIndex(id);
        var ix = o.index;
        var fetch = o.name;
        var tags = this.getDoc(win).getElementsByTagName(type);
        if (tags) {
            for (var i = 0; i < tags.length; i++) {
                if (this.areEqual(tags[i], param, fetch)) {
                    res.cnt++;
                    if (res.cnt == ix || ix == -1) {
                        res.element = tags[i];
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

    var tags = win.document.getElementsByTagName(type);
    if (tags) {
        for (var i = 0; i < tags.length; i++) {
            if (param == null || this.areEqual(tags[i], param, id)) {
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

Sahi.prototype.isRecording = function () {
    if (this.top().Sahi._isRecording == null)
        this.top().Sahi._isRecording = this.getServerVar("sahi_record") == 1;
    return this.top().Sahi._isRecording;
};
Sahi.prototype.createCookie = function (name, value, days){
    var expires = "";
    if (days) {
        var date = new Date();
        date.setTime(date.getTime() + (days * 24 * 60 * 60 * 1000));
        expires = "; expires=" + date.toGMTString();
    }
    window.document.cookie = name + "=" + value + expires + "; path=/";
};
Sahi.prototype._createCookie = Sahi.prototype.createCookie;
Sahi.prototype.readCookie = function (name){
    var nameEQ = name + "=";
    var ca = window.document.cookie.split(';');
    for (var i = 0; i < ca.length; i++)
    {
        var c = ca[i];
        while (c.charAt(0) == ' ') c = c.substring(1, c.length);
        if (c.indexOf(nameEQ) == 0) return c.substring(nameEQ.length, c.length);
    }
    return null;
};
Sahi.prototype._cookie = Sahi.prototype.readCookie;
Sahi.prototype.eraseCookie = function (name)
{
    this.createCookie(name, "", -1);
};
Sahi.prototype._deleteCookie = Sahi.prototype.eraseCookie;
Sahi.prototype._event = function (type, keyCode) {
    this.type = type;
    this.keyCode = keyCode;
};
var SahiAssertionException = function (msgNum, msgText) {
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
var lastQs = "";
var lastTime = 0;
Sahi.prototype.onEv = function (e) {
    if (e.handled == true) return; //FF
    if (_sahi.getServerVar("sahiEvaluateExpr") == true) return;
    var targ = _sahi.getKnownTags(_sahi.getTarget(e));
    if (e.type == "click") {
        if (targ.type) {
            var type = targ.type;
            if (type == "text" || type == "textarea" || type == "password"
                || type == "select-one" || type == "select-multiple") return;
        }
    }
    var info = _sahi.getAccessorInfo(targ);
    var cmd = _sahi.getScript(info);
    if (cmd == null) return;
    if (_sahi.hasEventBeenRecorded(cmd)) return; //IE
    _sahi.sendToServer('/_s_/dyn/Recorder_record?cmd=' + encodeURIComponent(cmd));
    e.handled = true;
    //FF
    _sahi.showInController(info);
};
Sahi.prototype.showInController = function (info) {
    try {
        var c = this.getController();
        if (c) {
            var d = c.top.main.document.currentForm.debug;
            c.top.main.document.currentForm.history.value += "\n" + d.value;
            d.value = this.getScript(info);
        }
    } catch(ex2) {
        //      throw ex2;
    }
};
Sahi.prototype.hasEventBeenRecorded = function (qs) {
    var now = (new Date()).getTime();
    if (qs == lastQs && (now - lastTime) < 500) return true;
    lastQs = qs;
    lastTime = now;
    return false;
};
Sahi.prototype.getPopupName = function () {
    var n = null;
    if (this.isPopup()) {
        n = this.top().name;
        if (!n || n == "") {
            try{
                n = this.top().document.title;
            }catch(e){}
        }
    }
    return n ? n : "";
};
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
Sahi.prototype.doAssert = function (e) {
    try {
        var lastAccessedInfo = this.top()._sahi.lastAccessedInfo;
        if (!lastAccessedInfo) return;
        lastAccessedInfo.event = "assert";
        this.showInController(lastAccessedInfo);
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

Sahi.prototype.getAccessorInfo = function (el) {
    if (el == null) return null;
    var type = el.type;
    var accessor = this.getAccessor(el);
    var shortHand = this.getShortHand(el, accessor);
    //this._alert(type+" -- "+accessor+" --- "+shortHand);
    var tagLC = el.tagName.toLowerCase();
    if (tagLC == "img") {
        return new AccessorInfo(accessor, shortHand, "img", "click");
    } else if (type == "text" || type == "textarea" || type == "password") {
        return new AccessorInfo(accessor, shortHand, type, "setvalue", el.value);
    } else if (type == "select-one" || type == "select-multiple") {
        return new AccessorInfo(accessor, shortHand, type, "setselected", this.getOptionText(el, el.value));
    } else if (tagLC == "a") {
        return new AccessorInfo(accessor, shortHand, "link", "click");
    } else if (type == "button" || type == "reset" || type == "submit" || type == "image") {
        return new AccessorInfo(accessor, shortHand, type, "click");
    } else if (type == "checkbox" || type == "radio") {
        return new AccessorInfo(accessor, shortHand, type, "click", el.checked);
    } else if (type == "file") {
        return new AccessorInfo(accessor, shortHand, type, "setFile", el.value);
    } else if (tagLC == "td") {
        return new AccessorInfo(accessor, shortHand, "cell", "click", this._getText(el));
    } else if (tagLC == "div") {
        return new AccessorInfo(accessor, shortHand, "div", "click", this._getText(el));
    } else if (tagLC == "span") {
        return new AccessorInfo(accessor, shortHand, "span", "click", this._getText(el));
    } else if (tagLC == "label") {
        return new AccessorInfo(accessor, shortHand, "label", "click", this._getText(el));
    } else if (tagLC == "li") {
        return new AccessorInfo(accessor, shortHand, "listItem", "click", this._getText(el));
    }
};

Sahi.prototype.getShortHand = function (el, accessor) {
    var shortHand = "";
    try {
        var tagLC = el.tagName.toLowerCase();
        if (tagLC == "img") {
            shortHand = el.title;
            if (!shortHand) shortHand = el.alt;
            if ((!shortHand || shortHand == "") && !this.isIgnorableId(el.id))  shortHand = el.id;
            if (!shortHand || shortHand == "")  shortHand = this.getImageSrc(el);
            if (shortHand && shortHand != "") {
                if (this.findImage(shortHand) != el) {
                    var ix = this.findImageIx(shortHand, el);
                    if (ix == -1) return "";
                    return shortHand + "[" + ix + "]";
                }
            } else {
                var ix = this.findImageIx(null, el);
                if (ix != -1) shortHand = ix;
            }
            return shortHand;
        } else if (tagLC == "a") {
            shortHand = this._getText(el);
            //(el.innerText) ? el.innerText : el.text;
            shortHand = this.trim(shortHand);
            if ((!shortHand || shortHand == "") && !this.isIgnorableId(el.id))  shortHand = el.id;
            if (shortHand && shortHand != "") {
                if (this.findLink(shortHand) != el) {
                    var ix = this.findLinkIx(shortHand, el);
                    if (ix == -1) return "";
                    return shortHand + "[" + ix + "]";
                }
            }
            return shortHand;
        } else if (tagLC == "button" || tagLC == "input" || tagLC == "textarea" || tagLC.indexOf("select") != -1) {
            if (el.type == "button" || el.type == "reset" || el.type == "submit") shortHand = el.value;
            if (el.type == "image") {
                shortHand = el.title;
                if (!shortHand) shortHand = el.alt;
            } else if (tagLC == "button"){
                shortHand = el.value;
                if (!this.isIE()) shortHand = this._getText(el);
            }
            else if (shortHand == null || shortHand == "") shortHand = el.name;
            if ((shortHand == null || shortHand == "") && !this.isIgnorableId(el.id))  shortHand = el.id;
            if (shortHand != null && shortHand != "") {
                if (this.findElement(shortHand, el.type, tagLC) != el) {
                    var ix = this.findElementIx(shortHand, el, el.type, tagLC);
                    if (ix == -1) return "";
                    return shortHand + "[" + ix + "]";
                }
            } else {
                var ix = this.findElementIx(null, el, el.type, tagLC);
                if (ix != -1) shortHand = ix;
            }
            return shortHand;
        } else if (tagLC == "td") {
            if (!this.isIgnorableId(el.id)) shortHand = el.id;
            if (shortHand != null && shortHand != "") {
                if (this.findCell(shortHand) != el) {
                    var ix = this.findCellIx(shortHand, el, "id");
                    if (ix != -1) return this.quoted(shortHand + "[" + ix + "]");
                }
                return this.quoted(shortHand);
            }
            shortHand = this._getText(el);
            if (shortHand != null && shortHand != "" && shortHand.length < 100) {
                if (this.findCell(shortHand) != el) {
                    var ix = this.findCellIx(shortHand, el, "sahiText");
                    if (ix != -1) return this.quoted(shortHand + "[" + ix + "]");
                }
                return this.quoted(shortHand);
			}
            shortHand = this.getTableShortHand(this.getTableEl(el));
            //"_table(\""+tabId+"\")";
            shortHand += ", " + this.getRow(el).rowIndex;
            shortHand += ", " + el.cellIndex;
        } else if (tagLC == "span" || tagLC == "div" || tagLC == "label" || tagLC == "li") {
            if (el.id && el.id!="" && !this.isIgnorableId(el.id) && this._byId(el.id) == el){
                shortHand = el.id;
            } else {
                shortHand = this._getText(el);
                if (shortHand.length > 100) return null;
                if (tagLC == "label"){
                    if (this._label(shortHand) == el) return shortHand;
                }else if (tagLC == "li") {
                    if (this._listItem(shortHand) == el) return shortHand;
                }else if (tagLC == "div"){
                    if (this._div(shortHand) == el) return shortHand;
                }else if (tagLC == "span"){
                    if (this._span(shortHand) == el) return shortHand;
                }
                if (shortHand != null && shortHand != ""){
	                var res = this.getBlankResult();
	                var attr = "sahiText"; //this.isIE() || this.isSafariLike() ? "innerText" : "textContent";
	                var ix = this.findTagIxHelper(shortHand, el, this.top(), tagLC, res, attr).cnt;
	                if (ix != -1) return shortHand + "[" + ix + "]";
                }
            }
        }
    } catch(ex) {
        this.handleException(ex);
    }
    return shortHand;
};
Sahi.prototype.getTableShortHand = function (el) {
    var shortHand = el.id;
    if (shortHand && shortHand != "" && !this.isIgnorableId(el.id)) {
        if (this.findTable(shortHand) != el) {
            var ix = this.findTableIx(shortHand, el);
            if (ix != -1) return "_table(" + this.quoted(shortHand + "[" + ix + "]") + ")";
        }
        return "_table(" + this.quoted(shortHand) + ")";
    }
    return "_table(" + this.findTableIx(null, el) + ")";
};

var AccessorInfo = function (accessor, shortHand, type, event, value) {
    this.accessor = accessor;
    this.shortHand = shortHand;
    this.type = type;
    this.event = event;
    this.value = value;
};

Sahi.prototype.getAccessorInfoQS = function (ai, isAssert) {
    if (ai == null || ai.event == null) return;
    var s = "event=" + (isAssert ? "assert" : ai.event);
    s += "&accessor=" + encodeURIComponent(this.convertUnicode(ai.accessor));
    s += "&shorthand=" + encodeURIComponent(this.convertUnicode(ai.shortHand));
    s += "&type=" + ai.type;
    if (ai.value) {
        s += "&value=" + encodeURIComponent(this.convertUnicode(ai.value));
    }
    return s;
};

Sahi.prototype.getOptionText = function (sel, val) {
    var l = sel.options.length;
    for (var i = 0; i < l; i++) {
        if (sel.options[i].value == val) return sel.options[i].text;
    }
    return null;
};

Sahi.prototype.addHandlersToAllFrames = function (win) {
    var fs = win.frames;
    if (!fs || fs.length == 0) {
        this.addHandlers(self);
    } else {
        for (var i = 0; i < fs.length; i++) {
            this.addHandlersToAllFrames(fs[i]);
        }
    }
};
Sahi.prototype.docEventHandler = function (e) {
    if (!e) e = window.event;
    //var t = _sahi.getTarget(e);
    var t = _sahi.getKnownTags(_sahi.getTarget(e));
    if (t && !t.hasAttached && t.tagName) {
        var tag = t.tagName.toLowerCase();
        if (tag == "a" || t.form || tag == "img" || tag == "div" || tag == "span" || tag == "li" || tag == "td" || tag == "table"
            || tag == "input" || tag == "textarea" || tag == "button") {
            _sahi.attachEvents(t);
        }
        t.hasAttached = true;
    }

};
Sahi.prototype.addHandlers = function (win) {
    if (!win) win = self;
    var doc = win.document;
    this.addEvent(doc, "keyup", this.docEventHandler);
    this.addEvent(doc, "mousemove", this.docEventHandler);
};

Sahi.prototype.attachEvents = function (el) {
    var tagName = el.tagName.toLowerCase();
    if (tagName == "a") {
        this.attachLinkEvents(el)
//    } else if (el.form && el.type) {
    } else if (el.type) {
        this.attachFormElementEvents(el);
    } else if (tagName == "img" || tagName == "div" || tagName == "span" || tagName == "td" || tagName == "table" || tagName == "li") {
        this.attachImageEvents(el);
    }
};
Sahi.prototype.attachFormElementEvents = function (el) {
    var type = el.type;
    if (el.onchange == this.onEv || el.onblur == this.onEv || el.onclick == this.onEv) return;
    if (type == "text" || type == "file" || type == "textarea" || type == "password") {
        this.addEvent(el, "change", this.onEv);
    } else if (type == "select-one" || type == "select-multiple") {
        this.addEvent(el, "change", this.onEv);
    } else if (type == "button" || type == "submit" || type == "reset" || type == "checkbox" || type == "radio" || type == "image") {
        this.addEvent(el, "click", this.onEv);
    }
};
Sahi.prototype.attachLinkEvents = function (el) {
    this.addEvent(el, "click", this.onEv);
};
Sahi.prototype.attachImageEvents = function (el) {
    this.addEvent(el, "click", this.onEv);
};
Sahi.prototype.addEvent = function (el, ev, fn) {
    if (!el) return;
    if (el.attachEvent) {
        el.attachEvent("on" + ev, fn);
    } else if (el.addEventListener) {
        el.addEventListener(ev, fn, false);
    }
};
Sahi.prototype.removeEvent = function (el, ev, fn) {
    if (!el) return;
    if (el.attachEvent) {
        el.detachEvent("on" + ev, fn);
    } else if (el.removeEventListener) {
        el.removeEventListener(ev, fn, false);
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
    var stack = e.stack ? e.stack : "No trace available";
    return e.name + ": " + e.message + "<br>" + stack.replace(/\n/g, "<br>");
};

Sahi.onError = function (msg, url, lno) {
    try {
        var debugInfo = "Javascript error on page";
        if (!url) url = "";
        if (!lno) lno = "";
        if (msg && msg.indexOf("Access to XPConnect service denied") != -1) { //FF hack
            _sahi.setJSError(msg, lno);
        }
        else {
            _sahi.setJSError(msg, lno);
        }
        if (Sahi.prevOnError && Sahi.prevOnError != Sahi.onError)
            Sahi.prevOnError(msg, url, lno);
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
            this.controller = window.open("/_s_/spr/controller2.htm", "_sahiControl", this.getWinParams(e));
        }
        if (this.controller) this.controller.opener = window;
        if (e) this.controller.focus();
    } catch(ex) {
        this.handleException(ex);
    }
};
Sahi.prototype.getWinParams = function (e) {
    var x = e ? e.screenX - 40 : 500;
    var y = e ? e.screenY - 60 : 100;
    var positionParams = "";
    if (e) {
        if (this.isIE()) positionParams = ",screenX=" + x + ",screenY=" + y;
        else positionParams = ",screenX=" + x + ",screenY=" + y;
    }
    return "height=550px,width=460px,resizable=yes,toolbar=no,status=no" + positionParams;
};
Sahi.prototype.getController = function () {
    var controller = this.top()._sahi.controller;
    if (controller && !controller.closed) return controller;
};
Sahi.openControllerWindow = function (e) {
    if (!e) e = window.event;
    if (!_sahi.isHotKeyPressed(e)) return true;
    _sahi.top()._sahi.openWin(e);
    //    _sahi.openWin(e);
    return true;
};
Sahi.prototype.isHotKeyPressed = function (e) {
    return ((this.hotKey == "SHIFT" && e.shiftKey)
        || (this.hotKey == "CTRL" && e.ctrlKey)
        || (this.hotKey == "ALT" && e.altKey)
        || (this.hotKey == "META" && e.metaKey));
};
Sahi.prototype.mouseOver = function (e) {
    try {
        if (_sahi.getTarget(e) == null) return;
        if (!e.ctrlKey) return;
        var controlWin = _sahi.getController();
        if (controlWin) {
            var el = _sahi.getTarget(e);
            if (el == _sahi.top()._sahi.lastElement){
                return;
            }
            _sahi.top()._sahi.lastElement = el;
            var acc = _sahi.getAccessorInfo(_sahi.getKnownTags(el));
            try {
                if (acc) controlWin.main.displayInfo(acc, _sahi.escapeDollar(_sahi.getAccessor1(acc)), _sahi.escapeValue(acc.value), _sahi.getPopupName());
            } catch(ex2) {
                throw ex2;
            }
            if (acc) _sahi.top()._sahi.lastAccessedInfo = acc;
        }
    } catch(ex) {
        throw ex;
    }
};
Sahi.prototype.escapeDollar = function (s) {
    if (s == null) return null;
    return s.replace(/[$]/g, "\\$");
};
Sahi.prototype.getAccessor1 = function (info) {
    if (info == null) return null;
    if ("" == (""+info.shortHand) || info.shortHand == null) {
        return info.accessor;
    } else {
        if ("image" == info.type) {
            return "_imageSubmitButton(" + this.escapeForScript(info.shortHand) + ")";
        } else if ("img" == info.type) {
            return "_image(" + this.escapeForScript(info.shortHand) + ")";
        } else if ("link" == info.type) {
            return "_link(" + this.escapeForScript(info.shortHand) + ")";
        } else if ("select-one" == info.type || "select-multiple" == info.type) {
            return "_select(" + this.escapeForScript(info.shortHand) + ")";
        } else if ("text" == info.type) {
            return "_textbox(" + this.escapeForScript(info.shortHand) + ")";
        } else if ("file" == info.type) {
            return "_file(" + this.escapeForScript(info.shortHand) + ")";
        } else if ("cell" == info.type) {
            return "_cell(" + info.shortHand + ")";
        }
        return "_" + info.type + "(" + this.escapeForScript(info.shortHand) + ")";
    }
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
    var interval = this.waitInterval > 0 && !this.waitCondition ? this.waitInterval : this.INTERVAL;
    this.execNextStep(false, interval);
};
Sahi.prototype.areXHRsDone = function (){
	//return true;
    var xs = this.XHRs;
    for (var i=0; i<xs.length; i++){
        var xsi = xs[i];
        //this.d("xsi.readyState="+xsi.readyState)
        if (xsi){
        	if (xsi.readyState==2 || xsi.readyState==3){
//        		this._debug("xsi.readyState="+xsi.readyState);
        	}
        	if (xsi.readyState==2) return false;
        	if (xsi.readyState==3){
        		if (this.waitWhenReadyState3) return false;
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
                return (this.isIE() && (win.document.readyState == "complete")) || this.loaded;
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
            if (win.document && win.document.getElementsByTagName("frameset").length == 0)
                return this.loaded;
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
        windowTitle = this.top().document.title;
    }catch(e){
    }
    var v = this.sendToServer("/_s_/dyn/Player_getCurrentStep?derivedName="+this.getPopupName()+
        "&wasOpened="+wasOpened+"&windowName="+encodeURIComponent(windowName)+"&windowTitle="+encodeURIComponent(windowTitle));
    //this.d(v);
    return eval("(" + v + ")");
};
Sahi.prototype.markStepDone = function(stepId, type, failureMsg){
    var qs = "stepId=" + stepId + (failureMsg ? ("&failureMsg=" + encodeURIComponent(failureMsg)) : "") + "&type=" + type;
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
        if (lastStepId == stepId){
            continue;
        }
        lastStepId = stepId;
        var type = stepInfo['type'];
        if (type == "STOP") {
            this.showStopPlayingMessage();
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
Sahi.prototype.ex = function (isStep) {
    var stepId = -1;
    try{
        if (this.isPaused() && !isStep) return;
        if (this.waitCondition) {
            var again = true;
            try {
                if (eval(this.waitCondition)) {
                    again = false;
                    _sahi.cancelWaitCondition();
                }
            } catch(e1) {
            }
            if (again) {
                this.execNextStep(isStep, this.interval);
                return;
            }
        }
        if ((!this.areWindowsLoaded(this.top()) || !this.areXHRsDone()) && this.waitForLoad > 0){
            this.waitForLoad  = this.waitForLoad - 1;
            if (!this.isIE() && this.waitForLoad % 20 == 0){
                this.check204Response();
            }
            this.execNextStep(isStep, this.interval);
            return;
        }
        this.waitForLoad = this.SAHI_MAX_WAIT_FOR_LOAD;
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
            //this.stopPlaying();
            return;
        }
        var step = stepInfo['step'];
        if (step == null || step == 'null' || type == "WAIT"){
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
            this.updateControlWinDisplay("Error in script: "+origStep+"\nLogs may have details.");
            return;
        }
        var type = (step.indexOf("_sahi._assert") != -1) ? "success" : "info";
        this.markStepInProgress(stepId, type);
        this.updateControlWinDisplay(origStep, stepId);
        eval(step);
        this.lastStepId = stepId;
        this.markStepDone(stepId, type);
        this.interval = this.waitInterval >= 0 ? this.waitInterval : this.INTERVAL;
        this.waitInterval = -1;
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
    var url = "/_s_/dyn/Log_getBrowserScript?href="+this.__scriptPath+"&n="+lineNumber;
    msg += "\n<a href='"+url+"'><b>Click for browser script</b></a>";
    return msg;
};
Sahi.prototype.getJSErrorMessage = function(e){
    var msg = this.getExceptionString(e);
    var lineNumber = (e.lineNumber) ? e.lineNumber : -1;
    return this.getJSErrorMessage2(msg, lineNumber);
};
Sahi.prototype.check204Response = function(){
    var last = this._lastDownloadedFileName()
    if (last != null && last != this.lastDownloaded){
        this.lastDownloaded = last;
        this.loaded = true;
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
    this._isPaused = true;
    this.setServerVar("sahi_paused", 1);
};
Sahi.prototype.unpause = function () {
    // TODO
    this._isPaused = false;
    this.setServerVar("sahi_paused", 0);
    this._isPlaying = true;
};
Sahi.prototype.isPaused = function () {
    if (this._isPaused == null)
        this._isPaused = this.getServerVar("sahi_paused") == 1;
    return this._isPaused;
};
Sahi.prototype.updateControlWinDisplay = function (s, i) {
    try {
        var controlWin = this.getController();
        if (controlWin && !controlWin.closed) {
            // controller2.js checks if this i has already been displayed.
            controlWin.main.displayLogs(s.replace(/_sahi[.]/g, ""), i);
            if (i != null) controlWin.main.displayStepNum(i);
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
    if (this._isPlaying == null){
        this._isPlaying = this.sendToServer("/_s_/dyn/Player_isPlaying") == "1";
    }
    return this._isPlaying;
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
    this._isPlaying = false;
};
Sahi.prototype.startRecording = function () {
    this.top().Sahi._isRecording = true;
    this.addHandlersToAllFrames(this.top());
};
Sahi.prototype.stopRecording = function () {
    this.top().Sahi._isRecording = false;
    this.sendToServer("/_s_/dyn/Recorder_stop");
    this.setServerVar("sahi_record", 0);
};
Sahi.prototype.getLogQS = function (msg, type, debugInfo, failureMsg) {
    var qs = "msg=" + encodeURIComponent(msg) + "&type=" + type
        + (debugInfo ? "&debugInfo=" + encodeURIComponent(debugInfo) : "")
        + (failureMsg ? "&failureMsg=" + encodeURIComponent(failureMsg) : "");
    return qs;
};
Sahi.prototype.logPlayBack = function (msg, type, debugInfo, failureMsg) {
    this.sendToServer("/_s_/dyn/TestReporter_logTestResult?"+this.getLogQS(msg, type, debugInfo, failureMsg));
};
Sahi.prototype.trim = function (s) {
    if (s == null) return s;
    if ((typeof s) != "string") return s;
    s = s.replace(/&nbsp;/g, ' ');
    s = s.replace(/\xA0/g, ' ');
    s = s.replace(/^[ \t\n\r]*/g, '');
    s = s.replace(/[ \t\n\r]*$/g, '');
    s = s.replace(/[ \t\n\r]{1,}/g, ' ');
    return s;
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
Sahi.prototype.isIE = function () {return navigator.appName == "Microsoft Internet Explorer";}
Sahi.prototype.isFF3 = function () {return navigator.userAgent.match(/Firefox\/3/) != null;}
Sahi.prototype.isFF = function () {return navigator.userAgent.match(/Firefox/) != null;}
Sahi.prototype.isChrome = function () {return navigator.userAgent.match(/Chrome/) != null;}

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
    var v = this.sendToServer("/_s_/dyn/SessionState_getVar?name=" + encodeURIComponent(name) + "&isglobal="+(isGlobal?1:0));
    return eval("(" + v + ")");
};
Sahi.prototype.setServerVar = function (name, value, isGlobal) {
    this.sendToServer("/_s_/dyn/SessionState_setVar?name=" + encodeURIComponent(name) + "&value=" + encodeURIComponent(this.toJSON(value)) + "&isglobal="+(isGlobal?1:0));
};
Sahi.prototype.logErr = function (msg) {
    //    return;
    this.sendToServer("/_s_/dyn/Log?msg=" + encodeURIComponent(msg) + "&type=err");
};

Sahi.prototype.getParentNode = function (el, tagName, occurrence) {
    if (!occurrence) occurrence = 1;
    var cnt = 0;
    var parent = el.parentNode;
    var tagNameUC = tagName.toUpperCase();
    while (parent && parent.tagName.toLowerCase() != "body" && parent.tagName.toLowerCase() != "html") {
        if (tagNameUC == "ANY" || parent.tagName == tagNameUC) {
            cnt++;
            if (occurrence == cnt) return parent;
        }
        parent = parent.parentNode;
    }
    return null;
};
Sahi.prototype.sendToServer = function (url) {
    try {
        var rand = (new Date()).getTime() + Math.floor(Math.random() * (10000));
        var http = this.createRequestObject();
        url = url + (url.indexOf("?") == -1 ? "?" : "&") + "t=" + rand;
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

Sahi.prototype.onBeforeUnLoad = function () {
    this.loaded = false;
};

Sahi.prototype.init = function (e) {
    try {
        this.loaded = true;
        this.activateHotKey();
    } catch(ex) {
        this.handleException(ex);
    }
    if (this.waitInterval > 0){
        if (this.waitCondition){
            this._wait(this.waitInterval, this.waitCondition);
        }else {
            this._wait(this.waitInterval);
        }
    }

    try {
        if (self == this.top()) {
            this.play();
        }
        if (this.isRecording()) this.addHandlers();
    } catch(ex) {
        //      throw ex;
        this.handleException(ex);
    }
};
Sahi.prototype.activateHotKey = function () {
    try {
        this.addEvent(document, "dblclick", Sahi.openControllerWindow);
        this.addEvent(document, "mousemove", this.mouseOver);
        if (this.isSafariLike()) {
            var prev = window.document.ondblclick;
            window.document.ondblclick = function(e) {
                if (prev != null) prev(e);
                this.openControllerWindow(e)
            };
        }
    } catch(ex) {
        this.handleException(ex);
    }
};
Sahi.prototype.isFirstExecutableFrame = function () {
    var fs = this.top().frames;
    for (var i = 0; i < fs.length; i++) {
        if (self == this.top().frames[i]) return true;
        if ("" + (typeof this.top().frames[i].location) != "undefined") { // = undefined when previous frames are not accessible due to some reason (may be from diff domain)
            return false;
        }
    }
    return false;
};
Sahi.prototype.getScript = function (info) {
    var accessor = this.escapeDollar(this.getAccessor1(info));
    if (accessor == null) return null;
    var ev = info.event;
    var value = info.value;
    var type = info.type
    var popup = this.getPopupName();

    var cmd = null;
    if (value == null)
        value = "";
    if (ev == "load") {
        cmd = "_wait(2000);";
    } else if (ev == "click") {
        cmd = "_click(" + accessor + ");";
    } else if (ev == "setvalue") {
        cmd = "_setValue(" + accessor + ", " + this.quotedEscapeValue(value) + ");";
    } else if (ev == "setselected") {
        cmd = "_setSelected(" + accessor + ", " + this.quotedEscapeValue(value) + ");";
    } else if (ev == "assert") {
        cmd = "_assertExists(" + accessor + ");\r\n";
        if (type == "cell") {
        	this._debug(info.shortHand + " " + this.quotedEscapeValue(value));
        	if (info.shortHand != this.quotedEscapeValue(value)){
	            cmd += "_assertEqual(" + this.quotedEscapeValue(value) + ", _getText(" + accessor + "));\n";
	            cmd += "_assertContainsText(" + this.quotedEscapeValue(value) + ", " + accessor + ");";
        	}
        } else if (type == "select-one" || type == "select-multiple") {
            cmd += "_assertEqual(" + this.quotedEscapeValue(value) + ", _getSelectedText(" + accessor + "));";
        } else if (type == "text" || type == "textarea" || type == "password") {
            cmd += "_assertEqual(" + this.quotedEscapeValue(value) + ", " + accessor + ".value);";
        } else if (type == "checkbox" || type == "radio") {
            cmd += "_assert" + ("true" == "" + value ? "" : "NotTrue" ) + "(" + accessor + ".checked);";
        } else if (type != "link" && type != "img") {
        	if (info.shortHand != this.quotedEscapeValue(value)){
        		cmd += "_assertContainsText(" + this.quotedEscapeValue(value) + ", " + accessor + ");";
        	}
        }
    } else if (ev == "wait") {
            cmd = "_wait(" + value + ");";
        } else if (ev == "mark") {
        cmd = "//MARK: " + value;
    } else if (ev == "setFile") {
        cmd = "_setFile(" + accessor + ", " + this.quotedEscapeValue(value) + ");";
    }
    if (cmd != null && popup != null && popup != "") {
        cmd = "_popup(\"" + popup + "\")." + cmd;
        cmd = cmd.replace(/[\n]_assert/g, "\n_popup(\"" + popup + "\")._assert")
    }
    return cmd;
};

Sahi.prototype.quotedEscapeValue = function (s) {
    return this.quoted(this.escapeValue(s));
};

Sahi.prototype.escapeValue = function (s) {
    if (s == null || typeof s != "string") return s;
    return this.convertUnicode(s.replace(/\r/g, "").replace(/\\/g, "\\\\").replace(/\n/g, "\\n"));
};

Sahi.prototype.escape = function (s) {
    if (s == null) return s;
    return escape(s).replace(/[+]/g, "%2B");
};

Sahi.prototype.saveCondition = function (a) {
    this.setServerVar("condn", a ? "true" : "false");
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
    var status = this._callServer("CommandInvoker_execute", "command=" + encodeURIComponent(command) + "&sync=" + is_sync);
    if ("success" != status) {
        throw new Error("Execute Command Failed!");
    }
};

Sahi.prototype.activateHotKey();

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

Sahi.prototype.setWaitCondition = function(waitCondn) {
    if (!String.isBlankOrNull(waitCondn) && waitCondn != "null") {
        this.waitCondition = waitCondn;
    }
};

Sahi.prototype.setWaitConditionTime = function(time) {
    if (!String.isBlankOrNull(time) && time != "-1") {
        var diff = eval(time) - new Date().valueOf();
        this.waitInterval = (diff > 0) ? diff : -1;
    }
};
// document.write start
Sahi.INSERT_TEXT = "<script src='/_s_/spr/concat.js'></scr"+"ipt>"+
    "<script src='http://sahi.example.com/_s_/dyn/SessionState/state.js'></scr"+"ipt>"+
    "<script src='http://sahi.example.com/_s_/dyn/Player_script/script.js'></scr"+"ipt>"+
    "<script src='/_s_/spr/playback.js'></scr"+"ipt>" +
    "";

Sahi.prototype.ieDocClose = function(){
    this.oldDocWrite(this.sahiBuffer);
    window.document.write(Sahi.INSERT_TEXT);
    window.document.close();
    this.loaded = true;
    this.play();
};
Sahi.prototype.ieDocWrite = function(s){
    this.sahiBuffer += s;
}
if (false && _sahi.isIE()){  // Do not move into method.
    Sahi.prototype.oldDocWrite = window.document.write;
    window.document.write = function (s) {_sahi.ieDocWrite(s);};
    window.document.close = function () {_sahi.ieDocClose();};
};
//--
Sahi.prototype.ffDocClose = function(){
    this.oldDocWrite.apply(document, [this.sahiBuffer + Sahi.INSERT_TEXT]);
    this.oldDocClose.apply(document);
    this.loaded = true;
    this.play();
};
Sahi.prototype.ffDocWrite = function(s){
    this.sahiBuffer += s;
};
if (!_sahi.isIE()) {
    //    Sahi.prototype.oldDocWrite = document.write;
    //    document.write = function (s) {_sahi.ffDocWrite(s);};
    //    Sahi.prototype.oldDocClose = document.close;
    //    document.close = function () {_sahi.ffDocClose();};
}
// document.write end

Sahi.init = function(e){
    eval("_sahi.init()");
};
Sahi.onBeforeUnLoad = function(e){
    _sahi.onBeforeUnLoad(e);
};
// ff xhr start
if (!_sahi.isIE()){
    var d = new XMLHttpRequest();
    d.constructor.prototype.openOld = XMLHttpRequest.prototype.open;
    d.constructor.prototype.open = function(method, url, async, username, password){
        url = ""+url;
        var opened = this.openOld(method, url, async, username, password);
        if (url.indexOf("/_s_/") == -1){
                //_sahi.d("xhr url="+url);
                try{
                        var xs = _sahi.top()._sahi.XHRs;
                        xs[xs.length] = this;
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
    //_sahi.real_alert("inside SahiXHRWrapper");
    this.xhr = isActiveX ? new ActiveXObject(s) : new real_XMLHttpRequest();
    var xs = _sahi.top()._sahi.XHRs;
    xs[xs.length] = this;
    this._async = false;
};
SahiXHRWrapper.prototype.open = function(method, url, async, username, password){
    url = ""+url;
    this._async = async;
    var opened = this.xhr.open(method, url, async, username, password);
    if (url.indexOf("/_s_/") == -1){
        try{
            var xs = _sahi.top()._sahi.XHRs;
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
SahiXHRWrapper.prototype.populateProps = function(){
    this.responseText = this.xhr.responseText;
    this.responseXML = this.xhr.responseXML;
    this.status = this.xhr.status;
    this.statusText = this.xhr.statusText;
};
if (_sahi.isIE() && typeof XMLHttpRequest != "undefined"){
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
Sahi.prototype.isIgnorableId = function(id){
    // zkoss, extjs, xilinus, gmail
    return id.match(/^z_/) || id.match(/^j_id/) || id.match(/^ext[-]gen/) || id.match(/^[:]/);
    //  || id.match(/_[0-9]{10,}_/);
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
Sahi.prototype._scriptName = function(){
    return this.__scriptName;
};
Sahi.prototype._scriptPath = function(){
	return this.__scriptPath;
};
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
Sahi.prototype.getDoc = function(win){
    if (win.type){
    	if (win.type == "_in") return win.element;
	    if (win.type == "_near"){
	    	var parents = [];
	    	for (var i=1; i<7; i++){
	    		parents[parents.length] = this.getParentNode(win.element, "ANY", i);
	    	}
	    	return new SahiDocProxy(parents);
	    }
    }else{
    	return win.document;
    }
};
SahiDocProxy = function(nodes){
	this.nodes = nodes;
};
SahiDocProxy.prototype.getElementsByTagName = function(tag){
	var tags = [];
	for (var i=0; i<this.nodes.length; i++){
		if (this.nodes[i] == null) continue;
		var childNodes = this.nodes[i].getElementsByTagName(tag);
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
	return {"element":el, "type":"_in"};
};
Sahi.prototype._near = function(el){
	return {"element":el, "type":"_near"};
};
Sahi.prototype.addSahi = function(s) {
    return this.sendToServer("/_s_/dyn/ControllerUI_getSahiScript?code=" + sahi().escape(s));
};
Sahi.prevOnError = window.onerror;
window.onerror = Sahi.onError;
Sahi.prototype.setServerVarPlain = function (name, value, isGlobal) {
	if (name == "___lastValue___") this._debug(name+"="+value);
    this.sendToServer("/_s_/dyn/SessionState_setVar?name=" + encodeURIComponent(name) + "&value=" + encodeURIComponent(value) + "&isglobal="+(isGlobal?1:0));
};