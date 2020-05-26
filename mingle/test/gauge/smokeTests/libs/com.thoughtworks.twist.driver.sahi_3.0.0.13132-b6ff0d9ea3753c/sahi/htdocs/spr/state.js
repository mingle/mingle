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
__sahiDebug__("state.js: start");
try {
    _sahi.sid = '$sessionId';
    _sahi.isWinOpen = $isWindowOpen;
    _sahi.createCookie('sahisid', '$sessionId');
    _sahi._isPaused = $isSahiPaused;
    _sahi._isPlaying = $isSahiPlaying;
    _sahi._isRecording = $isSahiRecording;
    _sahi.hotKey = '$hotkey';

    _sahi.INTERVAL = $interval;
    _sahi.ONERROR_INTERVAL = $onErrorInterval;
    _sahi.MAX_RETRIES = $maxRetries;
    _sahi.SAHI_MAX_WAIT_FOR_LOAD = $maxWaitForLoad;

    _sahi.waitForLoad = _sahi.SAHI_MAX_WAIT_FOR_LOAD;
    _sahi.interval = _sahi.INTERVAL;

    _sahi.__scriptName =  "$scriptName";
    _sahi.__scriptPath =  "$scriptPath";

    _sahi.strictVisibilityCheck = $strictVisibilityCheck;
    _sahi.STABILITY_INDEX = $stabilityIndex;
    _sahi.controllerMode = "$controllerMode";
    _sahi.setWaitForXHRReadyStates("$waitReadyStates");
    _sahi.escapeUnicode = $escapeUnicode;
    _sahi.commonDomain = "$commonDomain";
    _sahi.ignorableIdsPattern = new RegExp('$ignorableIdsPattern');
    _sahi.chromeExplicitCheckboxRadioToggle = $chromeExplicitCheckboxRadioToggle;
    _sahi.strictVisibilityCheck = $strictVisibilityCheck;
    _sahi.isSingleSession = $isSingleSession;
    // Pro start
} catch(e) {
}
__sahiDebug__("state.js: end");