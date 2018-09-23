/*
    File:       rc_std.js

    Purpose:    Provides standard functionality available for all
                successive javascripts.

    Remarks:    Present support:

                    1. Presently out-of-date browser sniffer.
                    2. debug-mode variable that probably should not be in here,
                       since I have to edit this file to turn it on and off.

*/

function hello() {
	alert("rc-standard.js says hello.");
}

var initFunctions = new Array(); // declaring var type crashes javascript interpreter.

/*
	Register function to be called once body is loaded.
	The idea here is that javascript modules that need initialization
	that depends on body elements, can register and then after body
	loads initialization proceeds in an orderly fashion.
*/
function registerForInit(initFunction) {
	initFunctions.push(initFunction);
}

// called from body tag's onload handler - overwrite as desired.
function init() {
	if (initFunctions) {
		for (var j = 0; j < initFunctions.length; j++) {
			var initFunction = initFunctions[j];
			if (initFunction) {
				//alert("Init function #" + j);
				initFunction();
			}
		}
	} else {
		alert("****** ERROR: Javascript not initialized.");
	}
}

/*
	Supports Adobe Captivate content.
*/	
function writeDocument(s){document.write(s);}


/*
This is a simplified version of the JavaScript Client Sniffer code
found at developer.nextscape.com/docs/examples/javascript/browser_type.html
(link is obsolete!)
*/
function Is() {
	// convert all characters to lowercase to simplify testing
    var agt=navigator.userAgent.toLowerCase();

    // *** BROWSER VERSION ***
    // Note: On IE5, these return 4, so use is.ie5up to detect IE5.
    this.major = parseInt(navigator.appVersion);
    this.minor = parseFloat(navigator.appVersion);

    this.nav  = ((agt.indexOf('mozilla')!=-1) && (agt.indexOf('spoofer')==-1) && (agt.indexOf('compatible') == -1) && (agt.indexOf('opera')==-1) && (agt.indexOf('webtv')==-1));
    this.nav3 = (this.nav && (this.major == 3));
    this.nav4 = (this.nav && (this.major == 4));
    this.nav4up = (this.nav && (this.major >= 4));
    this.navonly  = (this.nav && ((agt.indexOf(";nav") != -1) || (agt.indexOf("; nav") != -1)));
    this.nav5 = (this.nav && (this.major == 5));
    this.nav5up = (this.nav && (this.major >= 5));

    this.ie   = (agt.indexOf("msie") != -1);
    this.ie3  = (this.ie && (this.major < 4));
    this.ie4  = (this.ie && (this.major == 4) && (agt.indexOf("msie 5.0")==-1) );
    this.ie4up  = (this.ie  && (this.major >= 4));
    this.ie5  = (this.ie && (this.major == 4) && (agt.indexOf("msie 5.0")!=-1) );
    this.ie5up  = (this.ie  && !this.ie3 && !this.ie4);

    this.aol   = (agt.indexOf("aol") != -1);
    this.aol3  = (this.aol && this.ie3);
    this.aol4  = (this.aol && this.ie4);

    this.opera = (agt.indexOf("opera") != -1);
    this.webtv = (agt.indexOf("webtv") != -1);

    // *** PLATFORM ***
    this.win = ( (agt.indexOf("win")!=-1) || (agt.indexOf("16bit")!=-1) );
    this.mac = (agt.indexOf("mac")!=-1);
}

// var is = new Is(); - create on as-needed basis.

// debug mode support - used by rdc-debug.js
var debug_mode = 0;
function set_debug_mode(debugMode) {
    debug_mode = debugMode;
}
function get_debug_mode() {
    return debug_mode;
}


/**
 *  Should match email-addr-helper::check-addr function in com.robcole.sharedcomp.mail package.
**/
function isEmailAddrOK(addr) {
  var atPos = addr.indexOf('@');
  var atPos2 = addr.lastIndexOf('@');
  var dotPos = addr.indexOf('.', atPos + 1);
  var dotPos2 = addr.lastIndexOf('.');
  var dotDotPos = addr.indexOf('..');
  if ((atPos > 0) && (atPos == atPos2) && (dotPos > 0) && (dotPos < (addr.length - 1)) && (dotDotPos < 0) && (dotPos2 < (addr.length - 1))) {
	 return true;
  } else {
	 return false;
  }
}

function nospam(p1, p2, p3, subj, bod)
{
  var url = "mail" + "to:" + p1 + "@" + p2 + "." + p3
  if (arguments.length > 3)
     url += "?" + "subject" + "=" + subj
  if (arguments.length > 4)
     url += "&" + "body" + "=" + bod
  location.href=url
}

function refreshCurrentRage()
{
    //  This version of the refresh function requires
    //  browsers that support JavaScript version 1.2
    
    //  The argument to the location.reload function determines
    //  if the browser should retrieve the document from the
    //  web-server.  In our example all we need to do is cause
    //  the JavaScript block in the document body to be
    //  re-evaluated.  If we needed to pull the document from
    //  the web-server again (such as where the document contents
    //  change dynamically) we would pass the argument as 'true'.
    //  
    window.location.reload(true);
}

/*
     FILE ARCHIVED ON 05:28:54 Jan 21, 2015 AND RETRIEVED FROM THE
     INTERNET ARCHIVE ON 03:46:25 Sep 23, 2018.
     JAVASCRIPT APPENDED BY WAYBACK MACHINE, COPYRIGHT INTERNET ARCHIVE.

     ALL OTHER CONTENT MAY ALSO BE PROTECTED BY COPYRIGHT (17 U.S.C.
     SECTION 108(a)(3)).
*/
/*
playback timings (ms):
  LoadShardBlock: 123.41 (3)
  esindex: 0.006
  captures_list: 139.762
  CDXLines.iter: 12.854 (3)
  PetaboxLoader3.datanode: 60.658 (4)
  exclusion.robots: 0.182
  exclusion.robots.policy: 0.17
  RedisCDXSource: 0.741
  PetaboxLoader3.resolve: 58.3
  load_resource: 77.199
*/