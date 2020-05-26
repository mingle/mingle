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
	this.listen();
};
Controller.prototype.getServerVar = function (name, isGlobal, isDelete) {
    var v = this.sendToServer("/_s_/dyn/SessionState_getVar?name=" + encodeURIComponent(name) 
    		+ "&isglobal="+(isGlobal?1:0) 
    		+ "&isdelete="+(isDelete?1:0));
    return eval("(" + v + ")");
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
Controller.prototype.listen = function(){
	var msg = this.getAndDeleteServerVar("CONTROLLER_MessageForController");
	try{
		this.processMessage(msg);
	}catch(e){}
	window.setTimeout("_c.listen()", 500);
};
Controller.prototype.processMessage = function(msg){
	if (msg != null && msg != "" && msg != this.lastMessage){
		this.lastMessage = msg;
		try{ 
		 	if (msg.mode == "PLAYBACK_LOG_REFRESH"){
		 		this.pbLoadExecutionSteps();
		 	} else if (msg.mode == "HOVER" || msg.mode == "RECORD" || msg.mode == "RE_ID"){
				if (msg.accessor && msg.mode != "RE_ID") {
					this.lastAccessorValue = msg.accessor; // otherwise triggers reIdentify on FF if accesor in focus.
					$("accessor").value = msg.accessor;
				}
		 		this.populateOptions($("alternatives"), msg.alternatives);
				$("aValue").value = (msg.value) ? msg.value : ""; 
				$("windowName").value = (msg.windowName) ? msg.windowName : ""; 
		 		this.populateOptions($("assertions"), msg.assertions, "", "-- Choose Assertion --");
				if (msg.mode == "RECORD"){
					this.showRecordedSteps();
				}
				if (msg.mode == "HOVER"){
					tabGroup1.show('tscripts');
					spyTabs.show('tspy');
				}
		 	}
			$("result").value = (msg.result) ? msg.result : "";
		}catch (e){
			alert(e.message);
		}
	}	
};
Controller.prototype.setWorkArea = function (id){
	this.hideFileDialog();
	this.workAreaId = id;
};
Controller.prototype.playFromRecorder = function (){
	this.stopRecording();
	this.saveCurrent();
	tabGroup2.show("tplay");
	var fileName = edSet.getCurrentFile();
//	if (fileName != ""){
		$("pbScript").value = fileName; 
		this.pbSetScript(true);
//	}else{
//		this.pbSetSteps(true);
//	}
};
Controller.prototype.saveCurrent = function(){
	this.save(edSet.getCurrentFile(), _c.getRecorderWA().value, false);
	edSet.getCurrentEditor().indicateSaved();
};
Controller.prototype.save = function(fileName, content, append){
	this.sendToServer("ControllerUI_saveScript" +
			"?fileName="+encodeURIComponent(fileName)+
			"&content="+encodeURIComponent(content)+
			"&append="+(append?1:0));
};
Controller.prototype.pbLoadLogs = function () {
	var file = this.sendToServer("/_s_/dyn/Player_currentLogFileName"); //$('currentLogFileName').value;
	var s = "/_s_/dyn/Log_viewLogs/" + file + ".htm";
	$('pblogs_log_iframe').contentWindow.location.href = s; 
};
Controller.prototype.pbLoadExecutionSteps = function(){
	var s = this.getServerVar("CONTROLLER_Playback_Log");
	s = this.makeHTML(s);
	$('tplayWA').innerHTML = s;
	$('tplayWA').scrollTop = $('tplayWA').scrollHeight;
};
Controller.prototype.pbClearExecutionLogs = function () {
	this.setServerVar("CONTROLLER_Playback_Log", "");
	$('tplayWA').innerHTML = "";	
};
Controller.prototype.makeHTML = function(s){
	if (s == null || s == "") return "";
	var steps = new Object();
	var sb = [];
	var lines = s.replace(/\r/g, '').split("\n");
	for (var i=0; i<lines.length; i++){
		var line = lines[i];
		if (line == "") continue;
		var o = eval("(" + line + ")");
		if (o.id == null || !steps[o.id]){
			sb[sb.length] = "<tr><td style='width:20px;background-color:white;margin:0px;'>" + (o.id ? o.id : "") + "</td><td>" + o.step + "</td></tr>";
		}
		steps[o.id] = o.id;
	}
	return "<table>" + sb.join("") + "</table>";
};
Controller.prototype.addStep = function(s){
	edSet.getCurrentEditor().addContent(s);
};
Controller.prototype.getSelectedAssertion = function(){
	var value = $('aValue').value;
	var accessor = $('accessor').value;
	var s = $('assertions').value;
	s = s.replace(/<accessor>/g, accessor).replace(/<value>/g, this.quote(value));
	return s;
};
//Controller.prototype.xsetFileAndSaveSteps = function(append){
//	if ($('record_script').value == "")
//		this.setRecorderFile();
//	this.saveSteps(this.getRecorderWA().value);
//};
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
	if (!opts) opts = [];
    el.options.length = 0;
    if (defaultOpt) {
        el.options[0] = new Option(defaultOpt, "");
    }
    var len = opts.length;
    for (var i = 0; i < len; i++) {
        var ix = el.options.length;
        if (prefix) {
            if (opts[i].indexOf(prefix) == 0) {
                el.options[ix] = new Option(opts[i].substring(prefix.length), opts[i]);
                if (opts[i] == selectedOpt) el.options[ix].selected = true;
            }
        } else {
            el.options[ix] = new Option(opts[i], opts[i]);
            if (opts[i] == selectedOpt) el.options[ix].selected = true;
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
Controller.prototype.toggleRecording = function(){
	if (this.recording) this.stopRecording();
	else {
		if (!edSet.getCurrentEditor()){
			this.createNewScript();
		}
		this.startRecording();
	}
};
Controller.prototype.onRecordMouseOver = function(){
	if (!this.recording) $('record').style.border = "1px outset white"; 
};
Controller.prototype.onRecordMouseOut = function(){
	if (!this.recording) $('record').style.border = "1px solid white"; 
};
Controller.prototype.startRecording = function(){
	this.recording = true;
	//if ($('record_script').value != "")
//	this.setRecorderFile();
	$('record').style.border = "1px inset white"; 
	this.sendMessageToBrowser("_sahi.startRecording()");	
};
Controller.prototype.stopRecording = function(){
	this.recording = false;
	$('record').style.border = "1px solid white"; 
	this.sendMessageToBrowser("_sahi.stopRecording()");	
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
	if ($("accessor").value != this.lastAccessorValue){
		// alert("called");
		this.sendMessageToBrowser("_sahi.c_reIdentify("+this.quote($("accessor").value)+")");	
	}
	this.lastAccessorValue = $("accessor").value;
};
Controller.prototype.hover = function(){
	var s = "_mouseOver(" + $("accessor").value + ")";
	this.sendMessageToBrowser(s);	
	this.addStep(s);
};
Controller.prototype.click = function(){
	var s = "_click(" + $("accessor").value + ")";
	this.sendMessageToBrowser(s);	
};
Controller.prototype.highlight = function(){
	var s = "_sahi._highlight(" + $("accessor").value + ")";
	this.sendMessageToBrowser(s);	
};
Controller.prototype.setValue = function(){
	var el = $("accessor").value;
	var s = "_sahi._setValue(" + el + ", " + this.quote($("aValue").value) + ")";
	this.sendMessageToBrowser(s);	
};
Controller.prototype.quote = function(s){
	return '"' + s.replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/\n/g, '\\n').replace(/\r/g, '') + '"';
};
Controller.prototype.sendMessageToBrowser = function (s){
//	window.opener._sahi.processMessage(s);
	var url = "/_s_/dyn/Messages_setMessageForBrowser" +
			"?windowName="+ $('windowName').value +
			"&message=" + encodeURIComponent(this.toJSON({id: this.getRandom(), command: s}));
	return this.sendToServer(url);	
};
Controller.prototype.informOpen = function(){
    var ishttps = location.href.indexOf("https") == 0;
    var href = (ishttps? "https" : "http")  +"://sahi.example.com/_s_/dyn/ControllerUI_opened";
    new Image(0,0).src = href;
    window.isWinOpen = true;
};
Controller.prototype.experiment = function(){
	alert(this.getRecorderWA().contentWindow.document.body.innerHTML);
};
Controller.prototype.getRecorderWA = function(){
	return edSet.getCurrentTA();
//	return $('trecorderWA');
};
Controller.prototype.hideFileDialog = function(){
	$('dfile_open').style.display = "none";
};
Controller.prototype.chooseScript = function(){
	this.chooseFile('pbScript', true, false, true, 80, {name:"Choose",callBack:null});
};
//Controller.prototype.chooseSave = function(){
//	this.chooseFile('record_script', false, true, true, 80, {name:"Save",callBack:this.wrap(this.setRecorderFileAndAppend, this)}, true);
//};
//Controller.prototype.chooseEdit = function(){
//	this.chooseFile('edit_script', false, true, true, 80, {name:"Open",callBack:this.wrap(this.openScript, this)});
//};
Controller.prototype.chooseOpen = function(){
	this.chooseFile('current_script', false, false, true, 80, {name:"Open",callBack:this.wrap(this.openScript, this)});
};
//Controller.prototype.setRecorderFileAndAppend = function(){
//	var append = $("dfile_append").checked?1:0;
//	this.setRecorderFile(append);
//};
//Controller.prototype.xsetRecorderFile = function(append){
//	var fileName = $('record_script').value;
//	fileName = this.sendToServer("/_s_/dyn/Recorder2_setFile?file=" + encodeURIComponent(fileName));
//	this.saveSteps(this.getRecorderWA().value, append);
//	if (append == 1) this.showRecordedSteps();
//	$('record_script').value = fileName;
//};
Controller.prototype.chooseFile = function(id, showURL, showNew, showScript, y, button, defaultIsNew){
	var el=$('dfile_open');
	if (el.style.display == "block"){
		el.style.display = "none";
		return;
	}
	var loaded = this.pbLoadFolders($(id).value);
	if (!showURL){
		openTabs.show("tfile");
	}
	$('turl').style.display = showURL ? "inline" : "none";
	if (defaultIsNew && !loaded) this.chooseScriptType('newScript', 'pbScripts'); 
	else this.chooseScriptType('pbScripts', 'newScript');
	$('newScriptOption').style.display = showNew ? "" : "none";
	$('oldScriptOption').style.display = showScript ? "" : "none";
	
	$('dfile_open_button').value = button.name;
	$('dfile_open_button').onclick = function(){_c.pickFile();if (button.callBack) button.callBack();};	
	
	this.fileFieldId = id;
	el.style.display='block';
	el.style.top = (y ? y : 100) + 'px';
};
Controller.prototype.pickFile = function(){
	$(this.fileFieldId).value = $('pbScripts').disabled ? ($('pbFolders').value + $('newScript').value) : $('pbScripts').value;
	$('dfile_open').style.display='none';
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
//Controller.prototype.getSelectedTextDiv = function(){
//	if (window.getSelection) {
//		return window.getSelection();
//	} else if (document.selection) {
//		return document.selection.createRange();
//	}
//	return null;
//};
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
	this.pbLoadExecutionSteps();
	if (this.getServerVar("sahi_record") == 1){
		this.startRecording();
	} else {
		this.stopRecording();
	}
	//tabGroup2.showDefault();
	//tabGroup3.showDefault();	
    this.showRecordedSteps();
};
Controller.prototype.showRecordedSteps = function (){
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
Controller.prototype.pbLoadFolders = function (val) {
	var folders = eval("(" + this.sendToServer("/_s_/dyn/ControllerUI_scriptDirsListJSON") + ")");
	var selected = null;
	for (var i=0; i<folders.length; i++){
		if (val.indexOf(folders[i]) != -1){
			selected = folders[i];
		}
	}
	this.populateOptions($("pbFolders"), folders, selected, "-- Choose Folder --");
	if (selected != null){
		this.pbLoadScripts(selected, val);
		return true;
	}
	return false;
};
Controller.prototype.pbLoadScripts = function (dir, sel) {
	var scripts = eval("(" + this.sendToServer("/_s_/dyn/ControllerUI_scriptsListJSON?dir="+dir) + ")");
	this.populateOptions($("pbScripts"), scripts, sel, "-- Choose Script --", dir);
};
Controller.prototype.pbSetScript = function (auto) {
	this.pbSetCommon("setScriptFile", "file", $("pbScript").value, auto);
};
//Controller.prototype.pbSetSteps = function (auto) {
//    $('pbScript').value = this.setRecorderFile();
//    this.pbSetCommon("setScriptFile", "file", $("pbScript").value, auto);	
///*	
// 	this.pbSetCommon("setScriptSteps", "steps", this.getRecorderWA().value, auto);
//    var file = this.sendToServer("/_s_/dyn/Player_currentScriptFileName");
//    $('pbScript').value = file;
//    $('record_script').value = file;
//*/
//};
Controller.prototype.pbSetCommon = function (method, param, value, auto){
	this.sendToServer("/_s_/dyn/Player_" + method + "?manual=1&"+param+"=" + encodeURIComponent(value));
	this.pbClearExecutionLogs();
	$('currentLogFileName').value = this.sendToServer("/_s_/dyn/Player_currentLogFileName");
    window.setTimeout("_c.reloadPage('" + $('pbStartURL').value + "')", 100);
    //$('pscript_iframe').contentWindow.location.href = "http://sahi.example.com/_s_/dyn/Log_highlight?href="+encodeURIComponent(file)+"&n=0";
    //$('pscript_ta').value = this.sendToServer("/_s_/dyn/Script_getScript?script="+encodeURIComponent(file));
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
	this.sendMessageToBrowser("_sahi.c_evalEx('_sahi.list("+$("accessor").value+")')");
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
}
Controller.prototype.onImgMouseUp = function(e){
	if (!e) e = window.event;
	var el = getTarget(e);
	el.style.border = "1px solid white";
}
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
EditorSet = function(editorsDivId, editorsListDivId){
	this.editorsDiv = $(editorsDivId);
	this.editorsListDiv = $(editorsListDivId);
	this.tabGroup = new TabGroup("editors", [], null);
	this.editors = new Object();
	this.untitledCount = 0;
};
EditorSet.prototype.add = function(file, content, name){
	var ed = new Editor(file, content, name, this);
	this.editors[ed.id] = ed; 	    
	this.tabGroup.add(ed.id);
	this.tabGroup.show(ed.id);
};
EditorSet.prototype.createNew = function(){
	this.untitledCount = this.untitledCount + 1;
	var file = _c.sendToServer("/_s_/dyn/ControllerUI_createUntitledFile?count=" + this.untitledCount);
	this.add(file, "", "untitled_" + this.untitledCount);	
};
EditorSet.prototype.getCurrentTA = function(){
	return $(this.tabGroup.selectedTab + "box");
};
EditorSet.prototype.getCurrentEditor = function(){
	return this.editors[this.tabGroup.selectedTab];
};
EditorSet.prototype.getCurrentFile = function(){
	return this.editors[this.tabGroup.selectedTab].file;
};
Editor = function(file, content, name, editorSet){
	this.file = file;
	if (!name){
		var s = file.replace(/\\/g, '/');
		this.name = s.substring(s.lastIndexOf('/')+1);
		this.name = this.name.replace(/[.]sah$/, "");
	}else this.name = name;
	this.content = content;
	this.id = "editor_" + _c.getRandom();

	var item = document.createElement("DIV");
    item.setAttribute("id", this.id);
    item.innerHTML = this.name;
    editorSet.editorsListDiv.appendChild(item);
    this.handle = item;
    _c.addEvent(item, "click", _c.wrap(this.onEditorHandleClick, this));
    
    
	var item2 = document.createElement("TEXTAREA");
    item2.setAttribute("id", this.id + "box");
    item2.setAttribute("style", "display:none");
    item2.setAttribute("wrap", "off");
    item2.className = "editorbox";
    editorSet.editorsDiv.appendChild(item2);
    item2.value = content;
    this.saveSteps(content);
    this.ta = item2;
    
    _c.addEvent(item2, "keyup", _c.wrap(this.handleKeyUp, this));
};
Editor.prototype.onEditorHandleClick = function(e){
	_c.stopRecording();
	this.saveSteps(this.ta.value, false);
};
Editor.prototype.handleKeyUp = function(e){
	if (!e) e = window.event;
	if (this.content == this.ta.value) return;
	this.content = this.ta.value;
	this.saveSteps(this.content, false);
	this.indicateUnsaved(); // in this case this.ta.value == content
};
Editor.prototype.indicateSaved = function(e){
	this.handle.innerHTML = this.name; 
};
Editor.prototype.indicateUnsaved = function(e){
	this.handle.innerHTML = "*" + this.name; 
};
Editor.prototype.saveSteps = function(content, append){
	_c.sendToServer("/_s_/dyn/Recorder2_setRecordedSteps?content="+encodeURIComponent(content)  +"&append=" + append);
};
Editor.prototype.clearSteps = function(s){
	this.setContent("");
};
Editor.prototype.setContent = function(s, append){
	if (s == null) return;
	var ta = this.ta;
	if (ta.value == s) return;
	s = _c.trim(s);
	if (append) s = ta.value + "\n" + s + ";";
	if (ta.value != s) 
		this.indicateUnsaved();
	ta.value = s;
	this.content == s;
	ta.scrollTop = ta.scrollHeight;
	this.saveSteps(s);
};
Editor.prototype.addContent = function(s){
	this.setContent(s, true);
};
Editor.prototype.loadRecordedSteps = function(){
	var s = _c.sendToServer("/_s_/dyn/Recorder2_getRecordedSteps");
	this.setContent(s);
};


