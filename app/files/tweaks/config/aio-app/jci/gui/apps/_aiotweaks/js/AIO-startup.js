function applyTweaks() {
  var head = document.querySelector("head");
  var body = document.getElementsByTagName("body")[0];
  if (!window.jQuery) {
    utility.loadScript("addon-common/jquery.min.js");
  }
  var tweaks = localStorage.getItem("aio.tweaks") || "";
  if (tweaks.length > 0) {
    var AIOcss = document.createElement("link");
    AIOcss.href = "apps/_aiotweaks/css/_aiotweaksApp.css";
    AIOcss.rel = "stylesheet";
    AIOcss.type = "text/css";
    body.insertBefore(AIOcss, body.firstChild);
    body.className = tweaks;
  }
}

framework.transitionsObj._genObj._TEMPLATE_CATEGORIES_TABLE.AIOTweaksTmplt = "Detail with UMP";

applyTweaks();
/* ** Attempt to start speedometer app on boot **
   ** Works in the emulator but not in the car ** * /
setTimeout(function(){
  framework.sendEventToMmui("system","SelectApplications");
  setTimeout(function(){aioMagicRoute("_speedometer","Start");}, 4000);
}, 30000);
*/
