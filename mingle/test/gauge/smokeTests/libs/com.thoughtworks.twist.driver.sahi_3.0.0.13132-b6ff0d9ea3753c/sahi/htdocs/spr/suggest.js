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
Suggest.suggests = [];
function Suggest(textEl, selectEl, menuId, fixedLeft){
	this.textEl = textEl;
	this.selectEl = selectEl;
	this.menuId = menuId;
	this.fixedLeft = fixedLeft;
	Suggest.suggests[menuId] = this;
	this.textEl.onkeyup = this.wrap(this.textboxEvent);
	this.textEl.onfocus = function() {this.inFocus = true};
	this.textEl.onblur = function() {this.inFocus = false};
	this.selectEl.onclick = this.wrap(this.choose);
	this.selectEl.onkeydown = this.wrap(this.handleUpArrow);
	this.selectEl.onkeyup = this.wrap(this.selectEvent);	
}
Suggest.prototype.wrap = function (fn) {
	var el = this;
	return function(){return fn.apply(el, arguments);};
};
Suggest.prototype.suggestOnClick = function(){
	this.textEl.onclick = this.wrap(this.textboxEvent);
}
Suggest.prototype.reposition = function (x, y){
    el = this.selectEl;
    el.style.position = "absolute";
	el.style.left = x;
	el.style.top = y;
    el.style.display = "block";
}

Suggest.prototype.downArrow = function(e){
	try {
		this.selectEl.focus();
		this.selectEl.options[0].selected = true;
	} catch (e) {}
}

Suggest.prototype.handleUpArrow = function(e){
    if (!e) e = window.event;
    if (e.keyCode && e.keyCode == Suggest.KEY_ARROW_UP){
        if (this.selectEl.selectedIndex == 0){
            this.textEl.focus();
        }
    }
}

Suggest.prototype.escape = function(e){
	this.hide(true);
}

Suggest.hideAll = function (e){
    for (i in Suggest.suggests){
        Suggest.suggests[i].hide();
    }
}

Suggest.prototype.suggest = function (e){
    var str = this.textEl.value;

    this.selectEl.options.length = 0;

    var options = this.getOptions(str);
    for (var i=0; i<options.length; i++){
        this.selectEl.options[i] = options[i];
    }

    this.selectEl.size = (this.selectEl.options.length > 10) ? 10 : this.selectEl.options.length;

	if (this.selectEl.options.length > 0) {
		this.selectEl.options[0].selected = true;
		var offset = this.textEl.value.length * 4;
		var maxRight = 160;
		if (offset > maxRight){
			offset = maxRight;
		}
		var leftPos = (!this.fixedLeft) ? offset : 0;
		this.reposition(this.findPosX(this.textEl) + leftPos, this.findPosY(this.textEl)+20);
	} else {
		this.hide(true);
	}
}

Suggest.prototype.textboxEvent = function (e){
	if (!e) e = window.event;
	if (e.keyCode) {
		if (e.keyCode == Suggest.KEY_ARROW_DOWN) {
			this.downArrow();
			return;
		} else if (e.keyCode == Suggest.KEY_ESCAPE) {
			this.escape();
			return;
		} else if (e.keyCode == Suggest.KEY_ENTER){
            if (this.onchange) this.onchange();
            this.hide(true);
            return;
        }
    }
	this.suggest(e);
}

Suggest.KEY_ENTER = 13;
Suggest.KEY_TAB = 9;
Suggest.KEY_ESCAPE = 27;
Suggest.KEY_ARROW_DOWN = 40;
Suggest.KEY_ARROW_UP = 38;

Suggest.prototype.selectEvent = function (e){
	if (!e) e = window.event;
	if (e.keyCode){
		if (e.keyCode == Suggest.KEY_TAB || e.keyCode == Suggest.KEY_ENTER){
			this.choose();
		} else if (e.keyCode == Suggest.KEY_ESCAPE) {
			this.hide();
		}
	}
}

Suggest.prototype.choose = function () {
	var accessor = this.textEl.value;
	if (accessor.indexOf('.') != -1){
		var dot = accessor.lastIndexOf('.');
		var elStr = accessor.substring(0, dot);
		var prop = accessor.substring(dot + 1);
		this.textEl.value = elStr + "." + this.selectEl.value;
    }else{
		this.textEl.value = this.selectEl.value;
	}
	this.hide();
	this.textEl.focus();
    if (this.onchange) this.onchange();
}

Suggest.prototype.hide = function (force){
	if(force || !this.textEl.inFocus)
		this.selectEl.style.display = 'none';
}

Suggest.prototype.findPosY = function (obj)
{
    var curtop = 0;
    if (obj.offsetParent)
    {
        while (obj.offsetParent)
        {
            curtop += obj.offsetTop
            obj = obj.offsetParent;
        }
    }
    else if (obj.y)
        curtop += obj.y;
    return curtop;
}

Suggest.prototype.findPosX = function (obj)
{
    var curleft = 0;
    if (obj.offsetParent)
    {
        while (obj.offsetParent)
        {
            curleft += obj.offsetLeft
            obj = obj.offsetParent;
        }
    }
    else if (obj.x)
        curleft += obj.x;
    return curleft;
}
