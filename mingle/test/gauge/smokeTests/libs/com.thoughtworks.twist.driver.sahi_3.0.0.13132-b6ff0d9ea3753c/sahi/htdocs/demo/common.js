function $(id){
	return document.getElementById(id);
}

function addEvent(el, ev, fn) {
    if (!el) return;
    if (el.attachEvent) {
        el.attachEvent("on" + ev, fn);
    } else if (el.addEventListener) {
        el.addEventListener(ev, fn, true);
    }
};