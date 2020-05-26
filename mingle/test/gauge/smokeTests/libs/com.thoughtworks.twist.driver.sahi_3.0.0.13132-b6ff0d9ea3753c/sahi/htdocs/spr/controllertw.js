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
Language = function(name){
	this.name = name;
};
Language.prototype.translateFromSahi = function(s){return s;};
Language.prototype.translateToSahi = function(s){return s;};
Language.prototype.translateArrayFromSahi = function (a){
	var newA = new Array();
	for (var i=0; i<a.length; i++){
		newA[i] = this.translateFromSahi(a[i]);
	}
	return newA;
};

Controller = function(){
	this.lastMessage = null;
    this.escapeMap = {
            '\b': '\\b',
            '\t': '\\t',
            '\n': '\\n',
            '\f': '\\f',
            '\r': '\\r',
            '"' : '\\"',
            '\\': '\\\\'
        };	
	//this.listen();
	this.language = new Language("");
};
Controller.prototype.getServerVar = function (name, isGlobal, isDelete) {
	try{
	    var v = this.sendToServer("/_s_/dyn/SessionState_getVar?name=" + encodeURIComponent(name) 
	    		+ "&isglobal="+(isGlobal?1:0) 
	    		+ "&isdelete="+(isDelete?1:0));
	    return eval("(" + v + ")");
	}catch(e){}
};
Controller.prototype.getAndDeleteServerVar = function (name, isGlobal) {
	return this.getServerVar(name, isGlobal, true);
};
Controller.prototype.sendToServer = function (url) {
    try {
        var rand = this.getRandom();
        var http = this.createRequestObject();
        url = url + (url.indexOf("?") == -1 ? "?" : "&") + "t=" + rand;
        var post = url.substring(url.indexOf("?") + 1);
        url = url.substring(0, url.indexOf("?"));
        http.open("POST", url, false);
        http.send(post);
        return http.responseText;
    } catch(ex) {
        this.handleException(ex);
        return null;
    }
};
Controller.prototype.recordStep = function(s){
	showSteps(s);
	this.sendToServer("/_s_/dyn/StepWiseRecorder_record?step="+ encodeURIComponent(s));
};
Controller.prototype.showAllRecordedSteps = function(){
	var steps = this.sendToServer("/_s_/dyn/StepWiseRecorder_getAllSteps");
	this.showAllSteps(steps.replace(/__xxSAHIDIVIDERxx__/g, "<br/>"));
};
Controller.prototype.getRandom = function(){
	return (new Date()).getTime() + Math.floor(Math.random() * (10000));
}
Controller.prototype.handleException = function(ex){
	// alert(e.message);
};
Controller.prototype.createRequestObject = function () {
    var obj;
    if (window.XMLHttpRequest){
        // If IE7, Mozilla, Safari, etc: Use native object
        obj = new XMLHttpRequest();
    }else {
        if (window.ActiveXObject){
            // ...otherwise, use the ActiveX control for IE5.x and IE6
            obj = new ActiveXObject("Microsoft.XMLHTTP");
        }
    }
    return obj;
};
function $(id){return document.getElementById(id);}
Controller.prototype.xlisten = function(){
	var msg = this.getAndDeleteServerVar("CONTROLLER_MessageForController");
	try{
		this.processMessage(msg);
	}catch(e){}
	window.setTimeout("_c.listen()", 500);
};
Controller.prototype.xprocessMessage = function(msg){
	if (msg != null && msg != "" && msg != this.lastMessage){
		this.lastMessage = msg;
		try{ 
		 	if (msg.mode == "PLAYBACK_LOG_REFRESH"){
		 		this.pbLoadExecutionSteps();
		 	} else if (msg.mode == "HOVER" || msg.mode == "RECORD" || msg.mode == "RE_ID"){
				if (msg.accessor && msg.mode != "RE_ID") {
					// msg.accessor = this.language.translateFromSahi(msg.accessor);
					$("accessor").value = msg.accessor;
					this.lastAccessorValue = this.getAccessor(); // otherwise triggers reIdentify on FF if accesor in focus.
				}
		 		//this.populateOptions($("alternatives"), this.language.translateArrayFromSahi(msg.alternatives));
		 		this.populateOptions($("alternatives"), msg.alternatives);
				$("aValue").value = (msg.value) ? msg.value : ""; 
				$("windowName").value = (msg.windowName) ? msg.windowName : ""; 
		 		this.populateOptions($("assertions"), msg.assertions, "", "-- Choose Assertion --");
				if (msg.mode == "RECORD"){
					this.showRecordedSteps();
				}
				if (msg.mode == "HOVER"){
//					tabGroup1.show('tscripts');
//					spyTabs.show('tspy');
				}
		 	}
			$("result").value = (msg.result) ? msg.result : "";
		}catch (e){
//			alert(e.message);
		}
	}	
};
Controller.prototype.getSelectedAssertion = function(){
	var value = $('aValue').value;
	var accessor = $('accessor').value;
	var s = $('assertions').value;
	var winName = $("windowName").value;
	accessor = this.makeJavaAccessor(accessor, winName);
	s = s.replace(/<accessor>/g, accessor).replace(/<value>/g, this.quote(value));
	return s;
};
Controller.prototype.makeJavaAccessor = function(accessor, winName){
	if (accessor.indexOf("_") == 0) accessor = accessor.substring(1);
	accessor = "browser." + (winName == "" ? "" : winName) + accessor; 
	return accessor;
};
Controller.prototype.getText = function(el){
	return el.innerText ? el.innerText : el.textContent;
};
Controller.prototype.setServerVar = function (name, value, isGlobal) {
	var url = "/_s_/dyn/SessionState_setVar?" +
	"sahisid=" + this.sahisid + 
	"&name=" + encodeURIComponent(name) + 
	"&value=" + encodeURIComponent(this.toJSON(value)) + 
	"&isglobal="+(isGlobal?1:0);
//	alert(url);
    this.sendToServer(url);
};
Controller.prototype.toJSON = function(el){
    if (el == null || el == undefined) return 'null';
    if (el instanceof Date){
        return String(el);
    }else if (typeof el == 'string'){
        if (/["\\\x00-\x1f]/.test(el)) {
            return '"' + el.replace(/([\x00-\x1f\\"])/g, function (a, b) {
                var c = _c.escapeMap[b];
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
    return null;
};
Controller.prototype.populateOptions = function(el, opts, selectedOpt, defaultOpt, prefix) {
	var addedOptions = {};
	if (!opts) opts = [];
    el.options.length = 0;
    if (defaultOpt) {
        el.options[0] = new Option(defaultOpt, "");
    }
    var len = opts.length;
    for (var i = 0; i < len; i++) {
        var ix = el.options.length;
        var opt = opts[i];
        if (addedOptions[opt]) return;
        addedOptions[opt] = opt;
        if (prefix) {
            if (opt.indexOf(prefix) == 0) {
                el.options[ix] = new Option(opt.substring(prefix.length), opt);
                if (opt == selectedOpt) el.options[ix].selected = true;
            }
        } else {
            el.options[ix] = new Option(opt, opt);
            if (opt == selectedOpt) el.options[ix].selected = true;
        }
    }
    //    alert(el.options.length)
};
Controller.prototype.getText = function(el){
	return this.isIE() || this.isSafariLike() ? el.innerText : el.textContent;	
};
Controller.prototype.isIE = function () {return navigator.appName == "Microsoft Internet Explorer";};
Controller.prototype.isFF3 = function () {return navigator.userAgent.match(/Firefox\/3/) != null;};
Controller.prototype.isFF = function () {return navigator.userAgent.match(/Firefox/) != null;};
Controller.prototype.isChrome = function () {return navigator.userAgent.match(/Chrome/) != null;};
Controller.prototype.isSafariLike = function () {return /Konqueror|Safari|KHTML/.test(navigator.userAgent);};

var _c = new Controller();
Controller.prototype.onRecordMouseOver = function(){
	if (!this.recording) $('record').style.border = "1px outset white"; 
};
Controller.prototype.onRecordMouseOut = function(){
	if (!this.recording) $('record').style.border = "1px solid white"; 
};
Controller.prototype.startRecording = function(){
	this.recording = true;
	this.setRecordButton(this.recording);
	this.sendToServer("/_s_/dyn/Driver_startRecording?fromBrowser=true");
	this.sendMessageToBrowser("_sahi.startRecording()");	
};
Controller.prototype.clearRecording = function(){
	this.showAllSteps("");
	this.sendToServer("/_s_/dyn/StepWiseRecorder_clear");
};
Controller.prototype.hide = function(el){
	el.style.display = "none";
};
Controller.prototype.show = function(el){
	el.style.display = "block";
};
Controller.prototype.stopRecording = function(){
	this.recording = false;
	this.sendToServer("/_s_/dyn/Driver_stopRecording?fromBrowser=true");
	this.setRecordButton(this.recording);
};
Controller.prototype.editStep = function(el){
	this.editingStep = el;
	$("script").value = this.getText(el);   
};
Controller.prototype.clearSteps = function(isNew){
	edSet.getCurrentEditor().clearSteps();
};
Controller.prototype.startDrag = function(e){
	this.dragging = true;
	if (!e) e = window.event;
	this.dragStart = e.pageX || e.clientX; 
	this.dragStartWidth = parseInt($("fileTD").style.width);
};
function disableSelection(element) {
	element.onselectstart = function() {
		return false;
	};
	element.unselectable = "on";
	element.style.MozUserSelect = "none";
}
Controller.prototype.resizeSection = function(e){
	if (!e) e = window.event;
	if (!this.dragging) return;
	if (!e) e = window.event;
	var diff = (e.pageX || e.clientX) - this.dragStart;
//	$("trecorderWA").value += "resizeSection" + (this.dragStartWidth) + "\n";
	$("editorsListDiv").style.width = (this.dragStartWidth + diff) + "px";
	$("fileTD").style.width = (this.dragStartWidth + diff) + "px";
};
Controller.prototype.stopDrag = function(e){
	if (!this.dragging) return;
//	$("trecorderWA").value += "stopDrag" + (new Date()) + "\n";
	//this.resizeSection(e);
	this.dragging = false;
//	$("trecorderWA").blur();
};
Controller.prototype.reIdentifyQ = function(e){
	if (!e) e = window.event;
	if (e.keyCode != 13) return;
	if (this.reIdentifyTimer) {
		window.clearTimeout(this.reIdentifyTimer);
	}
	this.reIdentifyTimer = window.setTimeout(this.wrap(this.reIdentify), 150);
};
Controller.prototype.reIdentify = function(){
	if (this.getAccessor() != this.lastAccessorValue){
		// alert("called");
		this.sendMessageToBrowser("_sahi.c_reIdentify("+this.quote(this.getAccessor())+")");	
	}
	this.lastAccessorValue = this.getAccessor();
};
Controller.prototype.hover = function(){
	var s = "_mouseOver(" + this.getAccessor() + ")";
	this.sendMessageToBrowser(s);	
	var accessor = this.makeJavaAccessor(this.getAccessor(), $("windowName").value);
	this.recordStep(accessor + ".mouseOver();");
};
Controller.prototype.click = function(){
	var s = "_click(" + this.getAccessor() + ")";
	this.sendMessageToBrowser(s);	
};
Controller.prototype.getAccessor = function(){
	return "_" + $("accessor").value;
}
Controller.prototype.highlight = function(){
	var s = "_sahi._highlight(" + this.getAccessor() + ")";
	this.sendMessageToBrowser(s);	
};
Controller.prototype.setValue = function(){
	var el = this.getAccessor();
	var s = "_sahi._setValue(" + el + ", " + this.quote($("aValue").value) + ")";
	this.sendMessageToBrowser(s);	
};
Controller.prototype.quote = function(s){
	return '"' + s.replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/\n/g, '\\n').replace(/\r/g, '') + '"';
};
Controller.prototype.sendMessageToBrowser = function (s){
	sahi()._eval(sahi().addSahi(s));
};
function sahi(){
	return window.opener.top._sahi;
}
Controller.prototype.informOpen = function(){
    var ishttps = location.href.indexOf("https") == 0;
    var commonDomain = "sahi.example.com";
    try{
    	commonDomain = sahi().commonDomain;
    }catch(e){}
    var href = (ishttps? "https" : "http")  +"://" + commonDomain + "/_s_/dyn/ControllerUI_opened";
    new Image(0,0).src = href;
    window.isWinOpen = true;
};
Controller.prototype.inspect = function(){
	var workarea = $(this.workAreaId);
	$("accessor").value =  this.getSelectedText(workarea);
	this.reIdentify();
	spyTabs.show('tspy');
};
Controller.prototype.evalEx = function(){
	var s = this.getSelectedText($(this.workAreaId));
	$("eval").value = s;
	this.sendMessageToBrowser("_sahi.c_evalEx("+this.quote(s)+")");
	spyTabs.show("teval");
};
Controller.prototype.evalEx2 = function(){
	var s = this.getSelectedText($('eval'));
	this.sendMessageToBrowser("_sahi.c_evalEx("+this.quote(s)+")");
};
Controller.prototype.getSelectedText = function(wa){
	var sel;
	if (_c.isIE() || wa.tagName != "TEXTAREA") {
		sel = this.getSel();
	}else{
		var start = wa.selectionStart;
		var end = wa.selectionEnd;
		sel = wa.value.substring(start, end);
	}
	if (sel == "") sel = wa.value ? wa.value : wa.innerHTML;
	return this.trim(sel);
};
Controller.prototype.trim = function(s){
	return s.replace(/^\s*/, '').replace(/\s*$/, '');
};
Controller.prototype.getSel = function() {
	var txt = '';
	if (window.getSelection) {
		txt = window.getSelection();
	} else if (window.document.getSelection) {
		txt = window.document.getSelection();
	} else if (window.document.selection) {
		txt = window.document.selection.createRange().text;
	}
	return ""+txt;
};
Controller.prototype.toggleGenerate = function(){
	var el = $('generate');
	this.generate = el.checked;
	$('assert').disabled = !this.generate; 
	$('wait').disabled = !this.generate; 
};
Controller.prototype.saveState = function (){
    var ids = ["accessor", "aValue", "result", "pbScript", "pbStartURL", "current_script", "currentLogFileName", "record_script"];
    var s = [];
    for (var i=0; i<ids.length; i++){
    	var id = ids[i];
    	if ($(id) != null)
    		s[s.length] = {id:id, value:$(id).value, type:"element"};
    }
    s = s.concat(TabGroup.getState());
    this.setServerVar("CONTROLLER_recorder_state", this.toJSON(s));	
};
Controller.prototype.restoreState = function (){
	var saved = eval("(" + this.getServerVar("CONTROLLER_recorder_state") + ")");
	if (saved != null){
		for (var i=0; i<saved.length; i++){
			var item = saved[i];
	    	if (item != null){
	    		if (item.type == "tab"){
	    			try{
	    				el.show(item.value);
	    			}catch(e){}
	    		} else if (item.type == "element"){
	    			if ($(item.id)) $(item.id).value = item.value;
	    		}
	    	}		
		}
	}
	TabGroup.showDefaults();
};
Controller.prototype.showRecordedSteps = function (){
	return;
	var ed = edSet.getCurrentEditor();
	if (ed) ed.loadRecordedSteps();
};
Controller.prototype.addVar = function(n, v) {
    return n + "=" + v + "_$sahi$_";
};
Controller.prototype.blankIfNull = function(s) {
    return (s == null || s == "null") ? "" : s;
};
Controller.prototype.wrap = function (fn, el) {
	if (!el) el = this;
	return function(){fn.apply(el, arguments);};
};
Controller.prototype.addWrappedEvent = function (el, ev, fn) {
	this.addEvent(el, ev, this.wrap(fn));
};
Controller.prototype.addEvent = function (el, ev, fn) {
    if (!el) return;
    if (el.attachEvent) {
        el.attachEvent("on" + ev, fn);
    } else if (el.addEventListener) {
        el.addEventListener(ev, fn, false);
    }
};
Controller.prototype.resize = function (el, x, y) {
	if (x!=0) el.style.width = parseInt(el.style.width) + x;
	if (y!=0) el.style.height = parseInt(el.style.height) + y;
};
Controller.prototype.pbSetCommon = function (method, param, value, auto){
	this.sendToServer("/_s_/dyn/Player_" + method + "?manual=1&"+param+"=" + encodeURIComponent(value));
	this.pbClearExecutionLogs();
	$('currentLogFileName').value = this.sendToServer("/_s_/dyn/Player_currentLogFileName");
    window.setTimeout("_c.reloadPage('" + $('pbStartURL').value + "')", 100);
    if (auto) this.pbUnpause();	
};
Controller.prototype.resetStep = function(){
    window.document.getElementById("currentStep").innerHTML = "0";
    window.document.playform.nextStep.value = 1;
    sahiSetServerVar("sahiIx", 0);
    sahiSetServerVar("sahiLocalIx", 0);
};
Controller.prototype.pbPause = function(){
	this.sendToServer("/_s_/dyn/Player_pause");
};
Controller.prototype.pbUnpause = function(){
	this.sendToServer("/_s_/dyn/Player_unpause");
};
Controller.prototype.openScript = function(){
	var file = $('current_script').value; 
	var s = this.sendToServer("/_s_/dyn/Script_getScript?script="+encodeURIComponent(file));
	edSet.add(file, s);
};
Controller.prototype.createNewScript = function(){
	edSet.createNew();
};
Controller.prototype.reloadPage = function(u) {
    if (u == "") {
        this.sendMessageToBrowser("_sahi.top().location.reload(true)");
    } else {
        this.sendMessageToBrowser("_sahi.top().location.href='"+u+"'");
    }
};
Controller.prototype.resetIfNeeded = function (unpause) {
	var reset = this.sendToServer("/_s_/dyn/Player_resetIfStopped?unpause="+(unpause?1:0));
	if (reset == "true") {
		this.pbClearExecutionLogs();
	}
};
Controller.prototype.pbPlay = function () {
	this.resetIfNeeded(true);
	this.sendMessageToBrowser("_sahi.playManual(0)");
};
Controller.prototype.pbStop = function () {
	this.sendMessageToBrowser("_sahi.stopPlaying()");
};
Controller.prototype.pbStep = function () {
	this.resetIfNeeded(false);
	this.sendMessageToBrowser("_sahi.ex(true)");
};
Controller.prototype.pbEditPlayed = function () {
	$("edit_script").value = $("pbScript").value;
	this.openScript();
	tabGroup2.show("tedit");
};
Controller.prototype.chooseScriptType = function(e, d){
	$(e).disabled = false;
	$(e+"Radio").checked = true;
	$(d).disabled = true;
};
Controller.prototype.showProps = function(){
	this.sendMessageToBrowser("_sahi.c_evalEx('_sahi.list("+this.getAccessor()+")')");
	spyTabs.show("teval");
};
Controller.prototype.makeImgButtons = function(){
	var imgs = document.getElementsByTagName("IMG");
	for (var i=0; i<imgs.length; i++){
		var img = imgs[i];
		if (img.className == "cImg"){
			this.addWrappedEvent(img, "mouseover", this.onImgMouseOver);
			this.addWrappedEvent(img, "mouseout", this.onImgMouseUp);
			this.addWrappedEvent(img, "mousedown", this.onImgMouseDown);			
			this.addWrappedEvent(img, "mouseup", this.onImgMouseOver);
		}
	}
};
Controller.prototype.onImgMouseDown = function(e){
	if (!e) e = window.event;
	var el = getTarget(e);
	el.style.border = "1px inset white";
}
Controller.prototype.onImgMouseOver = function(e){
	if (!e) e = window.event;
	var el = getTarget(e);
	el.style.border = "1px outset white";
};
Controller.prototype.onImgMouseUp = function(e){
	if (!e) e = window.event;
	var el = getTarget(e);
	el.style.border = "1px solid white";
};
Controller.prototype.showAllSteps = function(s){
	$("allsteps").innerHTML = s;
	$("allsteps").scrollTop = $("allsteps").scrollHeight;
};
Controller.prototype.setRecordState = function(){
	var isRec = this.sendToServer("/_s_/dyn/Driver_isRecording");
	this.recording = "true" == isRec;
	this.setRecordButton(this.recording);
};
Controller.prototype.setRecordButton = function(isRec){
	if (isRec) { 
		this.hide($("rec_on"));
		this.show($("rec_off"));	
	} else {
		this.hide($("rec_off"));
		this.show($("rec_on"));			
	}
};
_c.informOpen();
_c.addWrappedEvent(window, "beforeunload", _c.saveState);
_c.addWrappedEvent(window, "load", _c.restoreState);


TabGroup = function(name, ids, defaultId){
	this.name = name;
	this.ids = [];
	this.defaultId = defaultId;
	this.addAll(ids);
	TabGroup.instances[TabGroup.instances.length] = this;
	//this.show(this.defaultId);
};
TabGroup.instances = [];
TabGroup.prototype.addAll = function(ids){
	for ( var i = 0; i < ids.length; i++) {
		this.add(ids[i]);
	}
};
TabGroup.prototype.add = function(id){
	this.ids[this.ids.length] = id;
	_c.addEvent($(id), "click", _c.wrap(this.onclick, this));
};
TabGroup.prototype.onclick = function(e){
	var el = getTarget(e);
	var thisId = el.id;
	this.show(thisId);
};
TabGroup.prototype.show = function(thisId){
	if (!thisId || !$(thisId)) thisId = this.defaultId;
	if (!thisId) return;
	for ( var i = 0; i < this.ids.length; i++) {
		var id = this.ids[i];
		if (!$(id)) continue;
		$(id+"box").style.display = (id == thisId) ? "block" : "none";
		$(id).className = "normalTab";
	}	
	var el = $(thisId);
	el.className = "hiTab";
	if (el.onclick) el.onclick();
	this.selectedTab = thisId;
};
var getTarget = function (e) {
    var targ;
    if (!e) e = window.event;
    if (e.target) targ = e.target;
    else if (e.srcElement) targ = e.srcElement;
    if (targ.nodeType == 3) // defeat Safari bug
        targ = targ.parentNode;
    return targ;
};
TabGroup.prototype.getSelectedTab = function (e) {
	return this.selectedTab;
};
TabGroup.prototype.showDefault = function (force) {
	if (force || this.selectedTab == null) this.show();
};
TabGroup.getState = function(){
	var s = [];
	for (var i=0; i<TabGroup.instances.length; i++){
		var tg = TabGroup.instances[i];
		s[s.length] = {id:tg.name, value:tg.getSelectedTab(), type:"tab"};
	}
	return s;
};
TabGroup.showDefaults = function(){
	for (var i=0; i<TabGroup.instances.length; i++){
		TabGroup.instances[i].showDefault();
	}
};
var java = new Language("java");
java.translateFromSahi = function(s){
	return s.replace(/^_/, "");
};
java.translateToSahi = function(s){
	return s.replace(/^browser[.]/, "_");
};
_c.language = java;
Controller.prototype.displayInfo = function(alternatives, accessor, value, windowName, assertions){
	$("accessor").value = accessor;
	this.populateOptions($("alternatives"), alternatives);
	$("aValue").value = (value) ? value : ""; 
	$("windowName").value = (windowName) ? windowName : ""; 
	this.populateOptions($("assertions"), assertions, "", "-- Choose Assertion --");
}
displayInfo = _c.wrap(_c.displayInfo);
var main = _c;
// called from concat.js
function showSteps(s){
	if (!_c.recording) return;
	$("lastSteps").value = s;
//	_c.showAllRecordedSteps();
	var h = $("allsteps").innerHTML;
	_c.showAllSteps((h + "<br/>" + s).replace(/<br[\/]?><br[\/]?>/i, "<br/>"));
};
window.onload = function(){
	_c.setRecordState();
}