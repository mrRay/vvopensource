<!--
		this PHP page accompanies the VVCrashReporter class in the VVBasics framework.  if you open 
		this page in a browser, nothing will happen.
		
		the VVCrashReporter class automatically collects crash logs and related system 
		information and POSTs this data to a URL.  this page demonstrates one way to work with this 
		data: it writes everything to a file on disk, and sends an email to a given email address.
		
		this is just a quick-and-dirty example; more advanced uses would include parsing the 
		provided data to extract further information (which thread crashed, software versions, etc), 
		and inserting all this into a database (sorry, didn't feel like cleaning all that up)
		
	INSTRUCTIONS:
		1)- install PHP, and make sure it works on your machine.
		2)- if you're running OS X, put this file in "Sites"
		3)- make sure $f_handle has the address of a WRITABLE file on your machine.  the file should 
			already exist- i don't think PHP will always create the file (it seems to depend on the 
			OS/build of PHP)
		4)- if you un-comment out the email bit below, make sure you change the email addresses!
		5)- change line 12 of AppController.m in the "CrashReporterTestApp" target of the 
			VVOpenSource project so the "uploadURL" points to this file on your server/local machine
		6)- the first line of php below so the file being opened for writing is in a valid location 
			instead of in the non-existent "yourUserName" directory
		7)- build & run the CrashReporterTestApp- force a crash, then run a check (which will 
			automatically post the information to this page and write it to disk)
-->

<?php
	//	open a file handle for data logging- make sure that this file's permissions are set to writable in your OS!
	$f_handle = fopen("/Users/yourUserName/Sites/meh.txt", "a");
	
	//	parse the PHP form variables that were POSTed to this page by VVCrashReporter
	$email = $_POST['email'];
	$description = $_POST['description'];
	$crash = $_POST['crash'];
	$console = $_POST['console'];
	$hardware = $_POST['hardware'];
	$software = $_POST['software'];
	$usb = $_POST['usb'];
	$firewire = $_POST['firewire'];
	$graphics = $_POST['graphics'];
	$memory = $_POST['memory'];
	$pci = $_POST['pci'];
	
	$crash = str_replace("'","\"",$crash);
	$console = str_replace("'","\"",$console);
	
	//	write everything to the file
	fwrite($f_handle,"**********************************************************\n");
	fwrite($f_handle,"Date:\n".date("Y-m-d H:i:s")."\n");
	fwrite($f_handle,"Reason:\n".$bailReason."\n");
	fwrite($f_handle,"Email:\n".$email."\n");
	fwrite($f_handle,"Description:\n".$description."\n");
	fwrite($f_handle,"Crash:\n".$crash."\n");
	fwrite($f_handle,"Console:\n".$console."\n");
	fwrite($f_handle,"Hardware:\n".$hardware."\n");
	fwrite($f_handle,"Software:\n".$software."\n");
	fwrite($f_handle,"USB:\n".$usb."\n");
	fwrite($f_handle,"Firewire:\n".$firewire."\n");
	fwrite($f_handle,"Graphics:\n".$graphics."\n");
	fwrite($f_handle,"Memory:\n".$memory."\n");
	fwrite($f_handle,"PCI:\n".$pci."\n");
	
	//	if you un-comment it out, this bit assembles an email and sends it to a given address
	//	this doesn't work on my home machine (i'm guessing my ISP is blocking it), but it works on ever server i've tried it on
	/*
	//	now assemble a quick email, and send it to myself
	//	MIME BOUNDARY
	$mime_boundary = md5(time());
	//	MAIL HEADERS
	$headers = "From:\n";
	$headers .= "Reply-To: <your@email.com>\n";
	$headers .= "MIME-Version: 1.0\n";
	$headers .= "Content-Type: multipart/alternative; boundary=\"$mime_boundary\"\n";
	//	TEXT EMAIL PART
	$message = "--$mime_boundary\n";
	$message .= "Content-Type: text/plain; charset=UTF-8\n";
	$message .= "Content-Transfer-Encoding: 8bit\n\n";
	$message .= "there was an error writing a crash log to the DB\n";
	//	FINAL BOUNDARY
	$message .= "--$mime_boundary--\n\n";
	//	SEND MAIL
	$mail_sent = mail( "your@email.com", "Crash Reporter error", $message, $headers );
	*/
	fclose($f_handle);
?>
