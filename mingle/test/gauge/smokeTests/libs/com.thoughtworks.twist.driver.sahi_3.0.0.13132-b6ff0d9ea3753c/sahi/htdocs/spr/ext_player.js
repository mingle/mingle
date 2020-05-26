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

function Player(browserPath, browserExecutable, browserOptions){
	this.browserPath = browserPath;
	this.browserExecutable = browserExecutable;
	this.browserOptions = browserOptions;
	this.sid = "sahi_" + Math.random(1000000000);
}
Player.prototype.createRequestObject = function () {
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
Player.prototype.sendToServer = function (url) {
    try {
        var rand = (new Date()).getTime() + Math.floor(Math.random() * (10000));
        var http = this.createRequestObject();
        url = url + (url.indexOf("?") == -1 ? "?" : "&") + "t=" + rand + "&sahisid=" + this.sid;
        var post = url.substring(url.indexOf("?") + 1);
        url = url.substring(0, url.indexOf("?"));
        http.open("POST", url, false);
        http.send(post);
        return http.responseText;
    } catch(ex) {
        //throw ex;
    	//this.handleException(ex);
    }
};

Player.prototype.xxx = function(){}

Player.prototype.launchRecorder = function(){
	var launchURL = "http://localhost:9999/_s_/dyn/Driver_launchAndRecord?browser=" + encodeURIComponent(this.browserPath) +
	"&browserOption=" + encodeURIComponent(this.browserOptions) + "&browserProcessName=" + encodeURIComponent(this.browserExecutable);
    this.sendToServer(launchURL);
}
Player.prototype.launchPlayback = function(){
	var launchURL = "http://localhost:9999/_s_/dyn/Driver_launchAndPlayback?browser=" + encodeURIComponent(this.browserPath) +
	"&browserOption=" + encodeURIComponent(this.browserOptions) + "&browserProcessName=" + encodeURIComponent(this.browserExecutable);
    this.sendToServer(launchURL);
}

Player.prototype.kill = function(){
	this.sendToServer("http://localhost:9999/_s_/dyn/Driver_kill");
}

Player.prototype.setStep = function(step){
	this.sendToServer("http://localhost:9999/_s_/dyn/Driver_setStep?step="+encodeURIComponent(step));
}

Player.prototype.getRecordedSteps = function(){
	return this.sendToServer("http://localhost:9999/_s_/dyn/Driver_getRecordedSteps");
}

Player.prototype.getAllRecordedSteps = function(){
	return this.sendToServer("http://localhost:9999/_s_/dyn/Driver_getAllRecordedSteps");
}

