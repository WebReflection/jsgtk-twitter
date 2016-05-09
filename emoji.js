var script = document.createElement('script');
script.onload = function () {
  twemoji.parse(document.body);
  [].forEach.call(
    document.querySelectorAll('img'),
    function (img) {
      img.onclick = this;
    },
    function onclick(e) {
      JSGTK.grabEmoji(this.alt);
    }
  );
};
script.src = 'https://twemoji.maxcdn.com/2/twemoji.min.js';
document.head.appendChild(script);