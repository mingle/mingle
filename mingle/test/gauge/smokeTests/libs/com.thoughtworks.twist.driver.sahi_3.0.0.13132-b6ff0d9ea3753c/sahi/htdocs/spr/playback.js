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
__sahiDebug__("playback.js: start");
_sahi.removeEvent(window, "load", Sahi.onWindowLoad);
_sahi.removeEvent(window, "beforeunload", Sahi.onBeforeUnLoad);
_sahi.addEvent(window, "load", Sahi.onWindowLoad);
_sahi.addEvent(window, "beforeunload", Sahi.onBeforeUnLoad);
try{
if (!tried){
    if (_sahi.isWinOpen){
    	try{
    		if (_sahi.top() == window.top){
    			_sahi.top()._sahi.openWin();
    		}
        }catch(e){}
    }
    tried = true;
}
}catch(e){}
_sahi.initTimer = window.setTimeout("Sahi.onWindowLoad()", (_sahi.waitForLoad) * _sahi.INTERVAL);
__sahiDebug__("playback.js: end");