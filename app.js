// generic handler triggered fromthe GTK world
// the currentTarget is always the window
function gtkHandler(e) {
  var detail = e.detail;
  switch (true) {
    case detail.hasOwnProperty('showNotification'):
      JSGTK.showNotification = detail.showNotification;
      break;
  }
}

// will enable them by default
// and fix the deprecated API
if (!Notification.requestPermission())
  Object.defineProperty(
    window,
    'Notification',
    {
      value: (function (_Notification) {
        function Notification(title, options) {
          switch (arguments.length) {
            case 0: return new _Notification();
            case 1: return new _Notification(title);
            default: return new _Notification(title, options);
          }
        }
        Notification.permission = _Notification.permission;
        Notification.requestPermission = function requestPermission() {
            return new Promise(function (resolve, reject) {
              setTimeout(function () {
                resolve(_Notification.permission);
              });
            });
          };
        Notification.prototype = _Notification.prototype;
        return Notification;
      }(Notification))
    }
  );

addEventListener('error', function (e) {
  JSGTK.error(e.message);
}, true);

// prevent remote webapp notifications
// when it's actually me doing nasty things
// to test this stuff
if (JSGTK.debug) {
  Object.defineProperties(
    window,
    {
      addEventListener: {
        value: (function (_addEventListener) {
          return function addEventListener(type) {
            if (type != 'error')
              _addEventListener.apply(window, arguments);
          };
        }(addEventListener))
      },
      onerror: {
        get: function () { return Object; },
        set: function (niceTry) {}
      }
    }
  );
}

document.addEventListener('click', function (e) {
  var target = e.target;
  if (target.nodeType === 1) {
    if (target.nodeName === 'IMG' && JSGTK.gallery) {
      target = e.target.closest('[role=article]');
      if (target) {
        var images = Array.prototype.map.call(
          target.querySelectorAll('img'),
          function (img) { return img.src + ':orig'; }
        ).filter(function (src) {
          return -1 < src.indexOf('/media/');
        });
        if (images.length) {
          nuf(e);
          JSGTK.gallery(images);
        }
      }
    } else {
      target = e.target.closest('a[target=_blank]');
      if (target) {
        nuf(e);
        // provided automagically
        // by the loader, injected upfront.
        // It uses a private UID as protocol channel
        JSGTK.open(target.href);
      }
    }
  }
}, true);

// only if the method is exposed
if (JSGTK.notify) {
  JSGTK.ni = setInterval(function (data) {
    // and only if notifications are enabled
    if (!JSGTK.showNotification) return;
    var
      notifications = document.querySelector('[href="/notifications"] span'),
      messages = document.querySelector('[href="/messages"] span'),
      length = !!notifications + !!messages
    ;
    if (length > data.length || !length) {
      data.length = length;
      if (length) {
        JSGTK.notify(
          parseFloat(notifications ? notifications.textContent : 0),
          parseFloat(messages ? messages.textContent : 0)
        );
      }
    }
  }, 2000, {length: 0});
}

// little helper to stop everything
function nuf(e) {
  e.preventDefault();
  e.stopPropagation();
}
