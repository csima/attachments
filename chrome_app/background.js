/**
 * Listens for the app launching then creates the window
 *
 * @see http://developer.chrome.com/apps/app.window.html
 */
 console.log('hi');
 var head = document.getElementsByTagName('head')[0];
 var script = document.createElement('script');
 script.type = 'text/javascript';
 script.src = "https://apis.google.com/js/client.js?onload=checkAuth";
 head.appendChild(script);
 
chrome.app.runtime.onLaunched.addListener(function() {
  chrome.app.window.create('index.html', {
    id: 'main',
    bounds: { width: 620, height: 500 }
  });
});

