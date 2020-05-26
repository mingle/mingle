<html>
<body>
<?php
print_r("Multi = ".$_REQUEST["multi"]."<br/><br/>");
if ($_REQUEST["multi"] == "true") {
	$f = $_FILES["file"];
	//print_r ($_FILES["file"]);
	if ($f["error"][0] > 0){
		echo "Error: " . $f["error"][0] . "<br />";
	} else {
		for ($i=0; $i<count($f["name"]); $i++){
			echo "Type: <span id='type'>Array</span><br />";
			echo "Upload: <span id='file'>" . $f["name"][$i] . "</span><br />";
			echo "File Type: <span id='filetype'>" . $f["type"][$i] . "</span><br />";
			echo "Size: <span id='size'>" . ($f["size"][$i] / 1024) . " Kb</span><br />";
			echo "Stored in: <span id='tmp'>" . $f["tmp_name"][$i] . "</span><hr/>";
		}
	}
} else {
	$f = $_FILES["file"];
	if ($f["error"] > 0) {
		echo "Error: " . $f["error"] . "<br />";
	}
	else {
		echo "Type: <span id='type'>Single</span><br />";
		echo "Upload: <span id='file'>" . $f["name"] . "</span><br />";
		echo "File Type: <span id='filetype'>" . $f["type"] . "</span><br />";
		echo "Size: <span id='size'>" . ($f["size"] / 1024) . " Kb</span><br />";
		echo "Stored in: <span id='tmp'>" . $f["tmp_name"] . "</span><br/>";
	}
}
?>
<br/>
<a href="fileUpload.htm">Back to form</a>
</body>
</html>