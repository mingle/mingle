<html>
<head><title></title></head>
<body>
<div id="clock"></div>
<script>
var count = 1;
function clock(){
	var el = document.getElementById("clock");
	el.innerHTML = "" + (count++);
}
window.setInterval("clock()", 1000);
</script>
<a href="/demo/index.htm">Go home</a>
<iframe src="delayedLoadInner.php"></iframe>
</body>
</html>