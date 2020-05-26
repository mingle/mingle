<?php
$code = $_REQUEST["code"];
if ($code == "404") {
	header("HTTP/1.1 404 Not Found", true, 404);
	echo ("Generated ". $code ." page");
} else if ($code == "204") {
	header("HTTP/1.1 204 No Content", true, 204);
}
?>