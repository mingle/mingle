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
function sahiTrim(s){
    if (s==null) return s;
    if ((typeof s) != "string") return s;
    s = s.replace(/&nbsp;/g, ' ');
    s = s.replace(/\xA0/g, ' ');
    s = s.replace(/^[ \t\n\r]*/g, '');
    s = s.replace(/[ \t\n\r]*$/g, '');
    s = s.replace(/[\t\n\r]{1,}/g, ' ');
    return s;
}
function sahiList(el, p){
    var s="";
    var j=0;
    for (var i in el){
        if (!p || (""+i).indexOf(p)!=-1){
            s+=i+",";
            j++;
            if (j%4==0) s+="\n";
        }
    }
    alert(s);
}
function arrayCopy(ar1, ar2){
    var ar = new Array();
    for (var i=0; i<ar1.length; i++){
        ar[ar.length] = ar1[i];
    }
    for (var i=0; i<ar2.length; i++){
        ar[ar.length] = ar2[i];
    }
    return ar;
}
function getElementOrArray(ar){
    if (ar && ar.length==1) return ar[0];
    return ar;
}
function sahiFindInArray(ar, el){
    for (var i=0; i<ar.length; i++){
        if (ar[i] == el) return i;
    }
    return -1;
}
function sahiIsIE(){
    var browser = navigator.appName;
    return browser == "Microsoft Internet Explorer";
}
function sahiCreateRequestObject(){
    var obj;
    if(sahiIsIE()){
        obj = new ActiveXObject("Microsoft.XMLHTTP");
    }else{
        obj = new XMLHttpRequest();
    }
    return obj;
}
function sahiGetServerVar(name){
    var v = sahiSendToServer("/_s_/dyn/SessionState_getVar?name="+fixedEncodeURIComponent(name));
    if (v == "null") return null;
    return fixedDecodeURIComponent(v);
}
function sahiSetServerVar(name, value){
    sahiSendToServer("/_s_/dyn/SessionState_setVar?name="+fixedEncodeURIComponent(name)+"&value="+fixedEncodeURIComponent(value));
}
function sahiSendToServer(url){
	try {
	    var rand = (new Date()).getTime() + Math.floor(Math.random() * (10000));
	    var http = sahiCreateRequestObject();
	    url = url + (url.indexOf("?") == -1 ? "?" : "&") + "t=" + rand;
	    var post = url.substring(url.indexOf("?") + 1);
	    url = url.substring(0, url.indexOf("?"));
	    http.open("POST", url, false);
	    http.send(post);
	    return http.responseText;
	} catch(ex) {
		sahiHandleException(ex)
	}
}
function fixedEncodeURIComponent (str) {  
	  return encodeURIComponent(str).replace(/%20/g, '+').replace(/!/g, '%21').replace(/'/g, '%27').replace(/\(/g, '%28').  
	                                 replace(/\)/g, '%29').replace(/\*/g, '%2A');//.replace(/%81/g, "%3F");  
} 
function fixedDecodeURIComponent(msg){
	return decodeURIComponent(msg.replace(/[+]/g, ' '));	
}
function xsahiSendToServer(url){
    try{
        var rand = (new Date()).getTime() + Math.floor(Math.random()*(10000));
        var http = sahiCreateRequestObject();
        var url = url + (url.indexOf("?")==-1 ? "?" : "&") + "t=" + rand;
        http.open("GET", url, false);
        http.send(null);
        return http.responseText;
    }catch(ex){sahiHandleException(ex);}
}
function sahiLogErr(msg){
    return;
    sahiSendToServer("/_s_/dyn/Log?msg=" + fixedEncodeURIComponent(msg) + "&type=err" );
}

function sahiLogPlayBack(msg, st, debugInfo){
    sahiSendToServer("/_s_/dyn/Log?msg=" + fixedEncodeURIComponent(msg) + "&type=" + st + "&debugInfo=" + fixedEncodeURIComponent(debugInfo));
}
function sahiGetParentNode(el, tagName){
    var parent = el.parentNode;
    while (parent &&  parent.tagName.toLowerCase() != "body" && parent.tagName.toLowerCase() != "html"){
        if (parent.tagName.toLowerCase() == tagName.toLowerCase()) return parent;
        parent = parent.parentNode;
    }
    return null;
}
function s_v(v){
    var type = typeof v;
    if (type == "number") return v;
    else if (type == "string") return "\""+v+"\"";
    else return v;
}
function quoted(s){
    return '"' + s.replace(/"/g, '\\"') + '"';
}
function sahiHandleException(e){
//	alert(e);
//	throw e;
}
function sahiGetText(el){
    if (el.innerHTML)
        return sahiGetTextFromHTML(el.innerHTML);
    return null;
}
function sahiGetTextFromHTML(s){
    return s.replace(/<[^>]*>/g, "");
}