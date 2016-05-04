// will enable them by default
// and fix the deprecated API
if (!Notification.requestPermission())
  Object.defineProperty(
    window,
    'Notification',
    {
      value: (function (Notification) {
        return {
          permission: Notification.permission,
          requestPermission: function requestPermission() {
            return new Promise(function (resolve, reject) {
              setTimeout(function () {
                resolve(Notification.permission);
              });
            });
          }
        };
      }(Notification))
    }
  );

document.addEventListener('click', function (e) {
  if (e.target.nodeType === 1) {
    var a = e.target.closest('a');
    if (a && /^(?:_blank)$/.test(a.target)) {
      e.preventDefault();
      e.stopPropagation();
      // provided automagically
      // by the loader, injected upfront.
      // It uses a private UID as protocol channel
      JSGTK.open(a.href);
    }
  }
}, true);