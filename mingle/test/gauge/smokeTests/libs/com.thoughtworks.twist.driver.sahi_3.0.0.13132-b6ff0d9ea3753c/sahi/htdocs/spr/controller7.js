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
sahisid = "$sahisid";
function showSteps(s){
    var d = top.document.currentForm.debug;
    top.document.currentForm.history.value += "\n" + d.value;
    d.value = s;	
};
var currentActiveTab = null;
TabGroup = function(name, ids, defaultId){
	this.name = name;
	this.ids = [];
	this.defaultId = defaultId;
	this.addAll(ids);
	var activeTab = getTabVar("controller_active_tab");
	if (activeTab != null)
		this.show(activeTab);
	else
		this.show(this.defaultId);	
	TabGroup.instances[TabGroup.instances.length] = this;
};
TabGroup.instances = [];
TabGroup.prototype.addAll = function(ids){
	for ( var i = 0; i < ids.length; i++) {
		this.add(ids[i]);
	}
};
TabGroup.prototype.add = function(id){
	this.ids[this.ids.length] = id;
	$(id).onclick_ = $(id).onclick;
	$(id).onclick = null;
	this.addEvent($(id), "click", this.wrap(this.onclick, this));
};
TabGroup.prototype.addEvent = function (el, ev, fn) {
    if (!el) return;
    if (el.attachEvent) {
        el.attachEvent("on" + ev, fn);
    } else if (el.addEventListener) {
        el.addEventListener(ev, fn, false);
    }
};
TabGroup.prototype.wrap = function (fn, el) {
	if (!el) el = this;
	return function(){fn.apply(el, arguments);};
};
TabGroup.prototype.onclick = function(e){
	var el = getTarget(e);
	var thisId = el.id;
	this.show(thisId, true);
};
TabGroup.prototype.show = function(thisId, isEvent){
	if (!thisId || !$(thisId)) thisId = this.defaultId;
	if (!thisId) return;
		
	for ( var i = 0; i < this.ids.length; i++) {
		var id = this.ids[i];
		if (!$(id)) continue;
		$(id+"box").style.display = (id == thisId) ? "block" : "none";
		$(id).className = "dimTab";
	}
	
	var el = $(thisId);
	el.className = "hiTab";
//	if (el.onclick && !isEvent) el.onclick();
	if (el.onclick_) el.onclick_();
	this.selectedTab = thisId;
	currentActiveTab = this.selectedTab;
};
function recOnClick(){
	doOnPlaybackUnLoad();
	doOnRecLoad();
}
function playbackOnClick(){
	doOnRecUnLoad();
	doOnPlaybackLoad();
}
function infoOnClick(){
	sahi().storeDiagnostics();
	displayInfoTab();
	doOnPlaybackUnLoad();
	doOnRecUnLoad();
}
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
function $(id){
	return document.getElementById(id);
}
function checkOpener() {
    try {
        var x = window.top.opener.document;
    }
    catch (e) {
    }
}
function sahi(){
    return sahiOpener()._sahi;
}
function sahiOpener() {
    return window.top.opener._sahi.top();
}
window.onerror = checkOpener;
function trim(s) {
    s = s.replace(/^[ \t]/, "", "g");
    return s.replace(/[ \t]$/, "", "g");
}

function checkURL(url) {
    if (url == null || trim(url) == "") return "";
    if (url.indexOf("://") == -1) return "http://" + url;
    return url;
}
function resetIfNeeded(){
	var nextStep = parseInt($("nextStep").value);
	var currentStep = parseInt($("currentStep").innerHTML);
	if (nextStep <= currentStep){
		resetScript();
	}
}
function play() {
	resetIfNeeded();
    try {
        sahi().playManual(parseInt($("nextStep").value))
    } catch (e) {
        displayLogs("Please open the Controller again. \n(Press CTRL ALT-DblClick on the main window.)");
    }
    return true;
}
function stepWisePlay() {
	resetIfNeeded();
    var i = parseInt($("nextStep").value);
    sahiOpener().eval("_sahi.skipTill("+i+")");
    sahiOpener().eval("_sahi.ex(true)");
}
function pause() {
    sahi().pause();
}
function stopPlay() {
    sahi().stopPlaying();
}
function resetStep() {
    $("currentStep").innerHTML = "0";
    $("nextStep").value = 1;
    sahiSetServerVar("sahiIx", 0);
    sahiSetServerVar("sahiLocalIx", 0);
}
function clearLogs() {
    $("talogs").value = "";
}
function stopRec() {
    try {
        sahi().stopRecording();
    } catch(ex) {
    	sahiSendToServer("/_s_/dyn/Recorder_stop");
    }
    enableRecordButton();
}
window.top.isWinOpen = true;
function pageUnLoad(s) {
	sendPlaybackSnapshot();
	sendRecorderSnapshot(); 
	var s = addVar("controller_active_tab", currentActiveTab);
    sahiSetServerVar("tab_state", s);
    sahiSendToServer('/_s_/dyn/ControllerUI_closed');
    try {
        window.top.isWinOpen = false;
    } catch(ex) {
        sahiHandleException(ex);
    }
}
function pageOnLoad(){
	Suggest.hideAll();
	resizeTAs();
}
function doOnRecUnLoad(s) {
    sendRecorderSnapshot();
}
function doOnPlaybackUnLoad(s) {
    sendPlaybackSnapshot();
}
function sendPlaybackSnapshot() {
    var s = "";
    s += addVar("controller_url", $("url").value);
    s += addVar("controller_logs", $("talogs").value);
    s += addVar("controller_step", $("nextStep").value);
    s += addVar("controller_url_starturl", $("url_starturl").value);
    s += addVar("controller_pb_dir", $("pbdir").value);
    s += addVar("controller_file_starturl", $("script_starturl").value);
    s += addVar("controller_file_scriptname", $("filebox").value);
    var showUrl = "" + ($("seturl").style.display == "block");
    s += addVar("controller_show_url", showUrl);
    sahiSetServerVar("playback_state", s);
}
function sendRecorderSnapshot() {
    var s = "";
    s += addVar("controller_recorder_file", $("recfile").value);
    s += addVar("controller_el_value", $("elValue").value);
//    s += addVar("controller_comment", $("comment").value);
    s += addVar("controller_accessor", $("accessor").value);
//    s += addVar("controller_alternative", window.document.currentForm.alternative.value);
    s += addVar("controller_debug", $("taDebug").value);
    s += addVar("controller_history", $("history").value);
//    s += addVar("controller_waitTime", $("waitTime").value);
    s += addVar("controller_result", $("taResult").value);
    s += addVar("controller_rec_dir", $("recdir").value);
    sahiSetServerVar("recorder_state", s);
}
function addVar(n, v) {
    return n + "=" + v + "_$sahi$_";
}
_recVars = null;
function getRecVar(name) {
    if (_recVars == null || _recVars == "") {
       _recVars = loadVars("recorder_state");
    }
    return blankIfNull(_recVars[name]);
}
_tabVars = null;
function getTabVar(name) {
	if (_tabVars == null || _tabVars == "") {
       _tabVars = loadVars("tab_state");
    }
    return blankIfNull(_tabVars[name]);
}

function loadVars(serverVarName) {
    var s = sahiGetServerVar(serverVarName);
    var a = new Array();
    if (s) {
        var nv = s.split("_$sahi$_");
        for (var i = 0; i < nv.length; i++) {
            var ix = nv[i].indexOf("=");
            var n = nv[i].substring(0, ix);
            var v = nv[i].substring(ix + 1);
            a[n] = blankIfNull(v);
        }
    }
    return a;
}
_pbVars = null;
function getPbVar(name) {
    if (_pbVars == null || _pbVars == "") {
        _pbVars = loadVars("playback_state");
    }
    return blankIfNull(_pbVars[name]);
}
var _selectedScriptDir = null;
var _selectedScript = null;
var _scriptDirList = null;
var _scriptFileList = null;

function doOnRecLoad() {
    _scriptDirList = refreshScriptListDir();
    populateOptions($("recdir"), _scriptDirList, _selectedScriptDir);
    initRecorderTab();
}

// Returns the number of characters of the longest element in a list
function getLongestListElementSize(p_list) {
    var longestSize = 0;
    var len = p_list.length;
    for (var i = 0; i < len; ++i) {
        if (p_list[i].length > longestSize) {
            longestSize = p_list[i].length;
        }
    }
    return longestSize;
}

// Changes the width of an element. If more than 1 element has the same name, we resize
//  the first one.
function resizeElementWidth(p_elementName, p_size) {
    var el = $(p_elementName);
    if (!el) {
        el = window.document.getElementsByName(p_elementName)[0];
    }
    if (parseInt(el.style.width) < p_size) el.style.width = p_size;
}

// Resize a dropdown list so we can see its entire content.
function resizeDropdown(p_dropdownContent, p_dropdownName, p_prefix) {
    var longest = getLongestListElementSize(p_dropdownContent);
    // A caracter is about 7 pixel long
    var newDropdownSize = (longest - p_prefix) * 6.2 + 20;
    resizeElementWidth(p_dropdownName, newDropdownSize);
}

function populateScripts(dir) {
	_scriptFileList = refreshScriptListFile(dir);
	setSelectedScriptDir(dir);
	$('filebox').value = "";
}

function refreshScriptListDir(){
	return eval("(" + sahiSendToServer("/_s_/dyn/ControllerUI_scriptDirsListJSON") + ")");
}

function refreshScriptListFile(dir){
	return eval("(" + sahiSendToServer("/_s_/dyn/ControllerUI_scriptsListJSON?dir="+dir) + ")");
}

function populateOptions(el, opts, selectedOpt, defaultOpt, prefix) {
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
}

function doOnPlaybackLoad() {
	initPlaybackTab();

    var ix = sahiGetCurrentIndex();
    if (ix != null) {
        displayStepNum(ix);
    }
}
function isSameStep(ix) {
    try {
        return ($("nextStep").value == "" + ix);
    } catch(e) {
    	return false;
    }
}

function displayStepNum(ix) {
    try {
        if (window.document.playform)
            $("currentStep").innerHTML = "" + ix;
            $("nextStep").value = "" + (ix + 1);
    } catch(e) {
        sahiHandleException(e);
    }
}
function sahiGetCurrentIndex() {
    try {
        var i = parseInt(sahiGetServerVar("sahiIx"));
        return ("" + i != "NaN") ? i : 0;
    } catch(e) {
        sahiHandleException(e);
    }
}
function displayQuery(s) {
    //    document.currentForm.query.value = forceWrap(s);
}
function displayLogs(s, i) {
	if (i == null){ // for stop PlayBack messages
		if ($("talogs").value.match(s+"[\r\n]*$")) return;
	}
	if ((""+i) != $("currentStep").innerHTML) {
	    $("talogs").value += s + "\n";
	    $("talogs").scrollTop = $("talogs").scrollHeight;
    }
}

function forceWrap(s1) {
    var ix = s1.indexOf("\n");
    var s = s1;
    var rest = "";
    if (ix != -1) {
        s = s1.substring(0, ix);
        rest = s1.substring(ix);
    }
    var start = 0;
    var BR_LEN = 51;
    var len = s.length;
    var broken = "";
    while (true) {
        if (start + BR_LEN >= len) {
            broken += s.substring(start);
            break;
        }
        else {
            broken += s.substring(start, start + BR_LEN) + "\n";
            start += BR_LEN;
        }
    }
    return broken + rest;
}
function setSelectedScriptDir(s) {
    _selectedScriptDir = s;
}
function setSelectedScript(s) {
    _selectedScript = s;
}
var isRecordAll = true;
function recordAll() {
    isRecordAll = !isRecordAll;
}
function disableRecordButton(){
	$("record").disabled = true;
}
function enableRecordButton(){
	$("record").disabled = false;
}
function onRecordStartFormSubmit(f) {
    if ($("recfile").value == "") {
        alert("Please enter a name for the script");
        $("recfile").focus();
        return false;
    }
    if (sahiOpener()) {
    	var el1 = $("recdir");
    	var el2 = $("recfile");
    	var value1 = el1.options[el1.selectedIndex].value.replace(/:/g,'%3A');
    	var value2 = el2.value;
    	sahiSendToServer("/_s_/dyn/Recorder_start?dir="+value1+"&file="+value2);
        sahi().startRecording(recordAll);
		disableRecordButton();
        //    	window.setTimeout("top.location.reload();", 1000);
    }
    return true;
}

function initRecorderTab() {
    $("recfile").value = getRecVar("controller_recorder_file");
    $("elValue").value = getRecVar("controller_el_value");
    $("accessor").value = getRecVar("controller_accessor");
//    window.document.currentForm.alternative.value = getRecVar("controller_alternative");
//    $("comment").value = getRecVar("controller_comment");
    $("history").value = getRecVar("controller_history");
    $("taDebug").value = getRecVar("controller_debug");
//    $("waitTime").value = getRecVar("controller_waitTime");
    $("taResult").value = getRecVar("controller_result");
    var dir = getRecVar("controller_rec_dir");
    if (dir && dir != null) $("recdir").value = getRecVar("controller_rec_dir");	 
    if (sahi().isRecording()) disableRecordButton();
}
function showTab(s) {
    if (window.top.main.location.href.indexOf(s + '.htm') != -1) return;
    hilightTab(s);
    window.top.main.location.href = s + '.htm'
}
function listProperties(){
    $("taDebug").value = sahi()._eval("sahiList("+addSahi($("accessor").value)+")");
}
function initPlaybackTab() {
	//var f = window.document.scriptfileform;
    var dir = getPbVar("controller_pb_dir");
	_scriptDirList = refreshScriptListDir();
    populateOptions($("pbdir"), _scriptDirList, dir);
   	setSelectedScriptDir($("pbdir").value);
	_scriptFileList = refreshScriptListFile($("pbdir").value);
	$("filebox").value = getPbVar("controller_file_scriptname");
    $("url").value = getPbVar("controller_url");
    $("talogs").value = getPbVar("controller_logs");
    $("url_starturl").value = getPbVar("controller_url_starturl");
    $("script_starturl").value = getPbVar("controller_file_starturl");
    $("nextStep").value = getPbVar("controller_step");
    byFile(getPbVar("controller_show_url") != "true");
}
function displayInfo(accessors, escapedAccessor, escapedValue, popupName) {
    var f = window.document.currentForm;
    if (f) {
        f.elValue.value = escapedValue ? escapedValue : "";
        f.accessor.value = escapedAccessor;
        populateOptions(f.alternative, accessors);
        //f.alternative.value = info.accessor;
        f.winName.value = popupName;
    }
}

function resetValue(){
    try{
        $("elValue").value = getEvaluateExpressionResult($("accessor").value);
    }catch(e){}
}

function setAPI(){
    var el = $("apiTextbox");
    //    try{
    el.value = $("apiSelect").value;
    //    }catch(e){}
}

function handleEnterKey(e, el){
    if (!e) e = window.event;
    if (e.keyCode && e.keyCode == 26){
        resetValue();
        return false;
    }
}

function addWait() {
    try {
        sahi().addWait($("waitTime").value);
    } catch(ex) {
        alert("Please enter the number of milliseconds to wait (should be >= 200)");
        $("waitTime").value = 3000;
    }
}

function mark() {
    sahi().mark($("comment").value);
    //   sahiSendToServer('/_s_/dyn/Recorder_record?event=mark&value='+escape(document.currentForm.comment.value));
}
function getEvaluateExpressionResult(str){
    sahiSetServerVar("sahiEvaluateExpr", "true");
    var res = "";
    try {
        res = sahi()._eval(addSahi(str));
    } catch(e) {
    	//throw e;
        if (e.exceptionType && e.exceptionType == "SahiAssertionException") {
            res = "[Assertion Failed]" + (e.messageText?e.messageText:"");
        }
        else {
            res = "[Exception] " + e;
        }
        sahiHandleException(e);
    }
    sahiSetServerVar("sahiEvaluateExpr", "false");
    return res;
}

function evaluateExpr(showErr) {
    if (!showErr) showErr = false;
    $("history").value += "\n" + $("taDebug").value;
    var txt = getText();
    var res = getEvaluateExpressionResult(txt);
    if (showErr) {
        $("taResult").value = "" + res;
    }
}
function demoClick() {
    setDebugValue("_click(" + $("accessor").value + ");");
    evaluateExpr();
}
function demoHighlight() {
    setDebugValue("_highlight(" + $("accessor").value + ");");
    evaluateExpr();
}
function demoHover() {
    setDebugValue("_mouseOver(" + $("accessor").value + ");");
    evaluateExpr();
}
function demoAction(el) {
	if (el.value == "comment1") {
		setDebugValue("// Single line comment"); 
	} else if (el.value == "comment2") {
		setDebugValue("/* Multiline \n Comment */");
	} else if (el.value == "svon") {
		setDebugValue("_setStrictVisibilityCheck(true);");
		evaluateExpr();
	} else if (el.value == "svoff") {
		setDebugValue("_setStrictVisibilityCheck(false);");
		evaluateExpr();
	} else {
		setDebugValue(el.value + "(" + $("accessor").value + ");");
		evaluateExpr();
	}
	el.options[0].selected = true;
}
function getSelectedText(){
	if (sahi()._isIE()) return getSel();
	var textarea = $("taDebug");
	var len = textarea.value.length;
	var start = textarea.selectionStart;
	var end = textarea.selectionEnd;
	var sel = textarea.value.substring(start, end);
	return sel;
}
function getText(){
    var txt = getSelectedText();
    if (txt == "") txt = $("taDebug").value;
    return txt;
}
function demoHighlight2(){
	getEvaluateExpressionResult("_highlight(" + getText() + ");");
}
function demoClick2(){
	getEvaluateExpressionResult("_click(" + getText() + ");");
}
function demoSetValue() {
    var acc = $("accessor").value;
    if (acc.indexOf("_select") == 0 || acc.indexOf('e("select")') != -1) {
        setDebugValue("_setSelected(" + acc + ", \"" + $('elValue').value + "\");");
    } else
        setDebugValue("_setValue(" + acc + ", \"" + $('elValue').value + "\");");
    evaluateExpr();
}
function setDebugValue(s) {
    $("history").value += "\n" + $('taDebug').value;
    $("taDebug").value = s;
}
function append() {
    sahiSendToServer('/_s_/dyn/Recorder_record?step=' + fixedEncodeURIComponent(getText()));
}

function addSahi(s) {
	var msg = sahiSendToServer("/_s_/dyn/ControllerUI_getSahiScript?code=" + fixedEncodeURIComponent(s));
	//alert(decodeURIComponent(msg))
    return fixedDecodeURIComponent(msg);
}

function blankIfNull(s) {
    return (s == null || s == "null") ? "" : s;
}
function byFile(showFile) {
    $("seturl").style.display = showFile?"none":"block";
    $("setfile").style.display = showFile?"block":"none";
}
function checkScript(f) {
    if (f.filebox && f.filebox.value == "") {
        alert("Please choose a script file");
        return false;
    }
    if (f.url && f.url.value == "") {
        alert("Please specify the url to script file");
        return false;
    }
    return true;

}
function replay(){
    resetStep();
    clearLogs();
    resetScript();
}
function resetScript(){
	sahiSendToServer("/_s_/dyn/Player_resetScript");
}
function onScriptFormSubmit(f) {
	if($('seturl').style.display == "none")	f = window.document.scriptfileform;
	else f = window.document.scripturlform;  
    if (!checkScript(f)) return false;
    if (f.starturl.value == "") f.starturl.value = sahiOpener().location.href;
    var url = checkURL(f.starturl.value);
    resetStep();
    clearLogs();
	sendPlaybackSnapshot();
    window.setTimeout("reloadPage('" + url + "')", 100);
    var starturl = f.starturl.value.replace(/:/g,'%3A');
    if($('seturl').style.display == "none"){
    	var dirPath = f.dir.options[f.dir.selectedIndex].value.replace(/:/g,'%3A');
    	var file = trim(f.filebox.value);
    	sahiSendToServer("_s_/dyn/Player_setScriptFile?dir="+dirPath+"&file="+file+"&starturl="+starturl+"&manual=1");
    }
    else {
    	var url = f.url.value.replace(/:/g,'%3A');
    	sahiSendToServer("_s_/dyn/Player_setScriptUrl?url="+url+"&starturl="+starturl+"&manual=1");
    }
}
function reloadPage(u) {
    if (u == "" || sahiOpener().location.href == u) {
        sahiOpener().location.reload();
    } else {
        sahiOpener().location.href = u;
    }
}
function getSel(){
    var txt = '';
    if (window.getSelection)
    {
        txt = window.getSelection();
    }
    else if (window.document.getSelection)
    {
        txt = window.document.getSelection();
    }
    else if (window.document.selection)
    {
        txt = window.document.selection.createRange().text;
    }
    return txt;
}
function showHistory() {
    var histWin = window.open("history.htm", "sahi_history", "height=500px,width=450px");
}
function findPos(obj){
    var x = 0, y = 0;
    if (obj.offsetParent)
    {
        while (obj.offsetParent)
        {
            //var wasStatic = null;
            x += obj.offsetLeft;
            y += obj.offsetTop;
            //if (wasStatic != null) obj.style.position = wasStatic;
            obj = obj.offsetParent;
        }
    }
    else if (obj.x){
        x = obj.x;
        y = obj.y;
    }
    return [x, y];
};
function resizeTA2(el, minusRight, minusTop, percent) {
	var winH, winW;
	if (window.innerWidth){
        winW = window.innerWidth;
        winH = window.innerHeight;		
	}else if (document.body.offsetWidth) {
        winW = document.body.offsetWidth;
        winH = document.body.offsetHeight;
 	}
    el.style.width = winW - minusRight + 'px';
    el.style.height = (winH - minusTop)*(percent/100) + 'px';
}
function resizeTAs(){
	var t = findPos($('taDebug'))[1];
	var delta = 40;
	if (t > 10){
		resizeTA2($('taDebug'), 40, t + delta, 50);
		resizeTA2($('taResult'), 40, t + delta, 50);
	}
	var taY = findPos($('talogs'))[1];
	if (taY > 10)
		resizeTA2($('talogs'), 40, taY + 30, 100);	
}
function showStack() {
    var curIx = $("nextStep").value;
    var win = window.open("blank.htm");
    var cmds = sahi().cmds;
    var s = "";
    for (var i = 0; i < cmds.length; i++) {
        var sel = (i == curIx - 1);
        s += "queue[" + i + "] = " + (sel?"<b>":"") + cmds[i] + (sel?"</b>":"") + "<br>";
    }
    s += "<br>Size: " + cmds.length;
    win.document.write(s);
    win.document.close();
}

function xsuggest(){
    var selectBox = $("suggestDD");
    var accessor = $("accessor").value;
    if (accessor.indexOf('.') != -1){
        var dot = accessor.lastIndexOf('.');
        var elStr = accessor.substring(0, dot);
        var prop = accessor.substring(dot + 1);
        var el = sahi()._eval(addSahi(elStr));
        selectBox.options.length = 0;
        for (var i in el){
            if (i.indexOf(prop) == 0)
                selectBox.options[selectBox.options.length] = new Option(i, i);
        }
    }
}

function appendToAccessor(){
    var accessor = $("accessor").value;
    if (accessor.indexOf('.') != -1){
        var dot = accessor.lastIndexOf('.');
        var elStr = accessor.substring(0, dot);
        var prop = accessor.substring(dot + 1);
        $("accessor").value = elStr + "." + $("suggestDD").value;
    }
}


// Suggest List start
var stripSahi = function (s){
    return s.replace(/sahi_/g, "_");
}
function getAccessorProps(str){
    var elStr = "window";
    var options = [];
    var dot = -1;
    if (str.indexOf('.') != -1){
        dot = str.lastIndexOf('.');
        elStr = str.substring(0, dot);
    }
    var prop = str.substring(dot + 1);
    var el = null;
    try{
        el = sahi()._eval(addSahi(elStr));
    }catch(e){}
    for (var i in el){
        i = stripSahi(i);
        if (i.indexOf(prop) == 0 && i != prop)
            options[options.length] = new Option(i, i);
    }
    return options;
}

function getScriptFiles(str){
    var options = [];
    var fileList = null;
    fileList = _scriptFileList;
    if(!str) str="";
    var strLC = str.toLowerCase(); 
    var fileName = "";
    if(fileList){
    	for (var i=0; i<fileList.length; i++){
    		fileName = fileList[i].replace(_selectedScriptDir, ""); 
    		var fileNameLC = fileName.toLowerCase();
        	if (fileNameLC.indexOf(strLC) != -1)
            	options[options.length] = new Option(fileName, fileName);
    	}
    }
    return options;
}

function getAPIs(str){
    var options = [];
    var el = null;
    try{
        el = sahi();
    }catch(e){}
    if (str == null || str == "") str = "_";
	if (str.indexOf("_") != 0) str = "_" + str;

    var d = "";

	var fns = [];
    for (var i in el){
        d += i + "<br>";
        if (i.indexOf(str) == 0 && el[i]){
            var val = i
            var fnStr = el[i].toString();
            if (fnStr.indexOf("function") == -1) continue;
            var args = trim(fnStr.substring(fnStr.indexOf("("), fnStr.indexOf("{")));
            if (args == "") continue;
            val = i + args;
            val = stripSahi(val);
            fns[fns.length] = val;
        }
    }
    fns = fns.sort();
    for (var i=0; i<fns.length; i++){
    	options[i] = new Option(fns[i], fns[i]);
    }
    //    alert(d);
    return options;
}
// Suggest List end
function xhideAllSuggests(e){
    if (!e) e = window.event;
    if (e.keyCode == Suggest.KEY_ESCAPE){
        Suggest.hideAll();
    }
}
function getBrowserName(){
		if (sahi()._isIE()) return "Microsoft Internet Explorer";
		else if (sahi()._isFF()) return "Mozilla Firefox";
		else if (sahi()._isSafari()) return "Safari";
		else if (sahi()._isChrome()) return "Google Chrome";
		else return navigator.appName;
}
function getDiagnostics(name){
	return sahi().getDiagnostics(name);
}
function displayInfoTab(){
	$("userAgent").innerHTML = getDiagnostics("UserAgent");
	//$("browserName").innerHTML = getDiagnostics("Browser Name");
	$("browserName").innerHTML = getBrowserName();
	$("browserVersion").innerHTML = getDiagnostics("Browser Version");
	$("xmlHttpRequest").innerHTML = getDiagnostics("Native XMLHttpRequest");
	$("javaEnabled").innerHTML = getDiagnostics("Java Enabled");
	$("cookieEnabled").innerHTML = getDiagnostics("Cookie Enabled");
	$("osName").innerHTML = getDiagnostics("osname");
	$("osVersion").innerHTML = getDiagnostics("osversion");
	$("osArchitecture").innerHTML = getDiagnostics("osarch");
	$("isTasklistAvailable").innerHTML = getDiagnostics("istasklistavailable");
	$("javaDirectory").innerHTML = getDiagnostics("javadir");
	$("javaVersion").innerHTML = getDiagnostics("javaversion");
	$("isKeytoolAvailable").innerHTML = getDiagnostics("iskeytoolavailable");	
}
var _version;
function getVersion(){
	if (!_version)
		_version = sahi().sendToServer("/_s_/dyn/ControllerUI_getSahiVersion");
	return _version;
}
function updateVersion(){
	var currentVersion = getVersion();
	window.open("http://sahi.co.in/w/version-check?v="+currentVersion, "_blank");
}
function sahiHandleException(e){}
function showProperties(){
    $("taDebug").value = sahi().list(sahi()._eval(addSahi($('accessor').value)));
}
function listProperties(str){
    return sahi()._eval(addSahi(str))
}
