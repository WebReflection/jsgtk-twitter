#!/usr/bin/env jsgtk

/*!
 * Copyright (c) 2016 Andrea Giammarchi - @WebReflection
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the Software
 * is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included
 * in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 * IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
 * DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
 * TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE
 * OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
!*/

const
  DEBUG = imports.jsgtk.constants.DEBUG,
  GLib = require('GLib'),
  Gtk = require('Gtk'),
  Gio = require('Gio'),
  Gdk = require('Gdk'),
  GdkPixbuf = require('GdkPixbuf'),
  WebKit2 = require('WebKit2'),
  fs = require('fs'),
  os = require('os'),
  path = require('path'),
  spawn = require('child_process').spawn,
  Notify = os.platform() === 'darwin' ?
    {
      init: Object,
      isInitted() { return true; },
      Notification(notification) {
        this.show = function show() {
          spawn('osascript', [
            '-e',
            `display notification "${
              notification.body
             }" with title "${
              notification.summary
             }"`
          ]);
        };
      }
    } :
    require('Notify')
;

({
  title: 'jsGtk Twitter',
  channel: 'jsgtk' + String(Math.random()).slice(2),
  cookies: path.join(__dirname, 'app.cookies'),
  json: path.join(__dirname, 'app.json'),
  icon: path.join(__dirname, 'app.png'),
  javascript: fs.readFileSync(path.join(__dirname, 'app.js')).toString(),
  defaults: {
    showNotification: true,
    windowPosition: Gtk.WindowPosition.NONE,
    uri: 'https://mobile.twitter.com/'
  },
  run(...args) {
    GLib.setPrgname(this.title);
    this.initInfo();
    this.app = new Gtk.Application()
      .once('startup', () => this.initUI())
      .once('shutdown', () => this.saveInfo())
      .on('activate', () => {
        this.window.on('configure-event', () => this.updateInfo());
        this.window.move(this.info.x, this.info.y);
        this.window.showAll();
      });
    this.app.run(args);
  },
  initInfo() {
    try {
      this.info = JSON.parse(fs.readFileSync(this.json));
    } catch(meh) {
      this.info = Object.assign({}, this.defaults);
    }
  },
  updateInfo() {
    let [x, y] = this.window.getPosition();
    let [width, height] = this.window.getSize();
    this.info.x = x;
    this.info.y = y;
    this.info.defaultWidth = width;
    this.info.defaultHeight = height;
  },
  saveInfo() {
    this.info.uri = this.webView.uri;
    fs.writeFileSync(this.json, JSON.stringify(this.info, null, '  '));
    this.cleanUp();
  },
  initUI() {
    const
      screen = Gdk.Screen.getDefault(),
      margin = 160,
      config = {
        application: this.app,
        defaultWidth: this.info.defaultWidth || 360,
        defaultHeight:  this.info.defaultHeight ||
                        Math.max(margin, screen.getHeight() - margin),
        windowPosition: this.info.windowPosition
      }
    ;
    this.window = new Gtk.ApplicationWindow(config);
    this.window.setIconFromFile(this.icon);
    this.window.on('delete_event', () => false);
    this.window.setTitlebar(this.header);
    this.window.add(this.webView);
    if (!this.info.hasOwnProperty('x')) {
      this.info.x = screen.getWidth() -
                    Math.floor(margin / 4 + config.defaultWidth);
    }
    if (!this.info.hasOwnProperty('y')) {
      this.info.y = Math.ceil(
        (screen.getHeight() - config.defaultHeight) / 2
      );
    }
    this.cleanUp();
  },
  cleanUp(files) {
    let cb = (files) => files.forEach(fileName => {
      if (fileName.slice(-5) === ':orig') {
        fs.unlink(fileName, Object);
      }
    });
    if (files) cb(files);
    else fs.readdir(__dirname, (err, files) => cb(files));
  },
  get webView() {
    if (!this._webView) {
      const
        webView = new WebKit2.WebView(),
        context = webView.getContext()
      ;
      if (DEBUG) {
        webView.getSettings().setEnableWriteConsoleMessagesToStdout(true);
        [
          'insecure-content-detected',
          'load-failed',
          'load-failed-with-tls-errors'
        ].forEach((type) => {
          webView.connect(type, () => {
            console.warn(type);
          });
        });
      }
      context.getCookieManager().setPersistentStorage(
        this.cookies,
        WebKit2.CookiePersistentStorage.TEXT
      );
      webView.loadUri(this.info.uri || this.defaults.uri);
      webView.on('decide-policy', (webView, policy, type) => {
        switch(type) {
          case WebKit2.PolicyDecisionType.NAVIGATION_ACTION:
            let
              uri = policy.getRequest().getUri(),
              channel = this.channel
            ;
            if (uri.indexOf(channel + ':') === 0) {
              this.jsAction(uri.slice(channel.length + 1));
              policy.ignore();
            } else if (DEBUG) console.info(uri);
            break;
        }
      });
      webView.on('permission-request', (webView, request, data) => {
        switch (true) {
          case request instanceof WebKit2.NotificationPermissionRequest &&
          this.info.showNotification:
            request.allow();
            break;
          default:
            request.deny();
            break;
        }
      });
      webView.on('load-changed', (webView, loadEvent, data) => {
        switch (loadEvent) {
          case 2: // FIGUREITOUT: where the hell is WEBKIT_LOAD_COMMITTED constant?
            let
              stringified = 'JSON.stringify(Array.prototype.slice.call(arguments, 0))',
              JSGTK = Object.keys(this.actions).map(
                key => typeof this.actions[key] === 'function' ?
                  `${key}: function ${key}() {
                    location.href = '${this.channel}:${key}(' +
                      encodeURIComponent(${stringified}) +
                    ')';
                  }` :
                  `${key}: ${JSON.stringify(this.actions[key])}`
              ).join(',\n')
            ;
            this.JSGTK = JSGTK;
            webView.runJavaScript(
              `(function(window, JSGTK){'use strict';
                ${this.javascript}
                ;window.addEventListener('${this.channel}', gtkHandler);
              }(this, {\nshowNotification: ${this.info.showNotification},\n${JSGTK}\n}));`,
              null,
              (webView, result) => {
                webView.runJavaScriptFinish(result);
              }
            );
            break;
        }
      });
      this._webView = webView;
    }
    return this._webView;
  },
  get menu() {
    if (!this._menu) {
      const
        MenuButton = new Gtk.MenuButton({
          image: new Gtk.Image({
            iconName: 'open-menu-symbolic',
            iconSize: Gtk.IconSize.SMALL_TOOLBAR
          })
        }),
        popMenu = new Gtk.Popover(),
        menu = new Gio.Menu()
      ;

      // group them via [{ ... }, { ... }] instead of { ... }, { ... }
      [
        {
          name: 'Show notifications',
          action: 'notifications',
          extras: {
            state: new GLib.Variant('b', this.info.showNotification)
          },
          callback: (action) => {
            let state = !action.getState().getBoolean();
            action.setState(new GLib.Variant('b', state));
            this.info.showNotification = state;
            this.runJavaScript(`{showNotification: ${state}}`);
          }
        },
        [{
          name: 'Show emoji',
          action: 'show-emoji',
          callback: () => {
            this.runJavaScript(`{showEmoji: true}`);
          }
        },{
          name: 'Grab emoji',
          action: 'grab-emoji',
          callback: () => {
            if (this.emojiShown) {
              this.emojiShown = false;
              this.window.remove(this.emoji);
              this.window.add(this.webView);
            } else {
              this.emojiShown = true;
              this.window.remove(this.webView);
              this.window.add(this.emoji);
            }
          }
        },{
          name: 'Grab current page uri',
          action: 'grab-page-uri',
          callback: () => {
            Gtk.Clipboard.getDefault(
              Gdk.Display.getDefault()
            ).setText(
              this.webView.uri.replace('mobile.', ''),
              -1
            );
          }
        }],
        {
          name: 'Close',
          action: 'close',
          callback: () => this.window.close()
        }
      ].forEach((group) => {
        let section = new Gio.Menu();
        [].concat(group).forEach((item) => {
          section.append(item.name, 'app.' + item.action);
          this.app.addAction(
            new Gio.SimpleAction(Object.assign(
                {},
                item.extras || {},
                {name: item.action}
            ))
            .on('activate', item.callback || Object)
          );
        });
        menu.appendSection(null, section);
      });

      MenuButton.setPopover(popMenu);
      popMenu.setSizeRequest(-1, -1);
      MenuButton.setMenuModel(menu);
      this._menu = MenuButton;

    }
    return this._menu;
  },
  get emoji() {
    if (!this._emoji) {
      const
        emoji = new WebKit2.WebView(),
        settings = emoji.getSettings()
      ;
      settings.setEnableJavascript(false);
      emoji.loadUri('https://twemoji.maxcdn.com/2/test/preview.html');
      emoji.on('decide-policy', (webView, policy, type) => {
        switch(type) {
          case WebKit2.PolicyDecisionType.NAVIGATION_ACTION:
            let
              uri = policy.getRequest().getUri(),
              channel = this.channel
            ;
            if (uri.indexOf(channel + ':') === 0) {
              this.jsAction(uri.slice(channel.length + 1));
              policy.ignore();
            } else if (DEBUG) console.info(uri);
            break;
        }
      });
      emoji.on('load-changed', (webView, loadEvent, data) => {
        switch (loadEvent) {
          case 3:
            settings.setEnableJavascript(true);
            webView.runJavaScript(
              `(function(window, JSGTK){'use strict';
                ${fs.readFileSync(path.join(__dirname, 'emoji.js')).toString()}
              }(this, {\n${this.JSGTK}\n}));`,
              null,
              (webView, result) => {
                webView.runJavaScriptFinish(result);
              }
            );
            break;
        }
      });
      emoji.show();
      this._emoji = emoji;
    }
    return this._emoji;
  },
  get button() {
    if (!this._button) {
      const button = {
        back: Gtk.ToolButton.newFromStock(Gtk.STOCK_GO_BACK),
        refresh: Gtk.ToolButton.newFromStock(Gtk.STOCK_REFRESH),
        menu: this.menu
      };
      button.back.on('clicked', () => this.webView.goBack());
      button.refresh.on('clicked', () => this.webView.reload());
      this._button = button;
    }
    return this._button;
  },
  get header() {
    if (!this._header) {
      this._header = new Gtk.HeaderBar({
        title: this.title,
        showCloseButton: false
      });
      this._header.packStart(this.button.back);
      this._header.packStart(this.button.refresh);
      this._header.packEnd(this.button.menu);
    }
    return this._header;
  },
  runJavaScript(detail) {
    this.webView.runJavaScript(
      `window.dispatchEvent(
        new CustomEvent(
          '${this.channel}',
          {detail: ${detail}}
        )
      );`,
      null,
      (webView, result, error) => {
        webView.runJavaScriptFinish(result);
      }
    );
  },
  jsAction(which) {
    const
      i = which.indexOf('('),
      method = which.slice(0, i),
      args = JSON.parse(decodeURIComponent(which.slice(i + 1, -1)))
    ;
    this.actions[method].apply(this, args);
  },
  calucalteSize(outer, inner, gap) {
    let
      mw = outer.getWidth() - gap,
      mh = outer.getHeight() - gap,
      cw = inner.getWidth(),
      ch = inner.getHeight()
    ;
    if (mw < cw) {
      ch = mw * ch / cw;
      cw = mw;
    }
    if (mh < ch) {
      cw = mh * cw / ch;
      ch = mh;
    }
    return [cw, ch];
  },
  actions: {
    debug: DEBUG,
    b64emoji(encode) {
      var result = {};
      function grab(icon) {
        spawn(
          'curl',
          ['-L', '-O', 'http://twemoji.maxcdn.com/2/svg/' + icon + '.svg'],
          {cwd: __dirname}
        ).once('close', () => {
          var chunks = [];
          spawn('base64', icon + '.svg')
            .once('close', () => {
              GLib.unlink(icon + '.svg');
              result[icon] = 'data:image/svg+xml;base64,' + chunks.join('');
              next();
            })
            .stdout.on('data', (data) => {
              chunks.push(data);
            });
        })
      }
      const next = () => {
        if (encode.length) {
          grab(encode.shift());
        } else {
          this.runJavaScript(JSON.stringify({
            b64: result
          }));
        }
      };
      next();
    },
    grabEmoji(text) {
      this.emojiShown = false;
      this.window.remove(this.emoji);
      this.window.add(this.webView);
      if (DEBUG) print(text);
      Gtk.Clipboard.getDefault(
        Gdk.Display.getDefault()
      ).setText(text, -1);
    },
    error() {
      console.error.apply(console, arguments);
    },
    notify(notifications, messages) {
      if (this.info.showNotification) {
        if (!Notify.isInitted())
          Notify.init(this.title);
        new Notify.Notification({
          summary: `You have ${notifications + messages} updates`,
          body: (
            (notifications ? `${notifications} notifications` : '') +
            (messages ?
              ((notifications ? ' and ' : '') + `${messages} messages`) : '')
          ),
          iconName: this.icon
        }).show();
      }
    },
    /* TODO: finish properly this gallery
    gallery(images) {
      let
        i = 0,
        screen = Gdk.Screen.getDefault(),
        files = images.map(src => path.join(__dirname, GLib.basename(src)))
      ;
      Promise.all(images.map(img => new Promise((res, rej) => {
        spawn('curl', ['-L', '-O', img], {cwd: __dirname}).once('close', res);
      }))).then(() => {
        new Promise((res, rej) => {
          spawn('sync', [], {}).once('close', res);
        }).then(() => {
          let
            margin = 0,
            window = new Gtk.Dialog({
              defaultWidth: screen.getWidth() - margin,
              defaultHeight: screen.getHeight() - margin,
              modal: true,
              useHeaderBar: false,
              decorated: false,
              // opacity: 0.5,
              transientFor: this.window
            })
            ,pixbuf = GdkPixbuf.Pixbuf.newFromFile(files[i])
          ;
          pixbuf = Gtk.Image.newFromPixbuf(pixbuf.scaleSimple.apply(
            pixbuf,
            this.calucalteSize(
              screen,
              pixbuf,
              margin
            ).concat(
              GdkPixbuf.InterpType.BILINEAR
            )
          ));
          window.once('delete_event', () => {
            this.cleanUp(files);
            window.destroy();
            window = null;
            pixbuf = null;
          });
          window.getContentArea().add(pixbuf);
          window.showAll();
        });
      });
    },
    //*/
    open(uri) {
      // problems with this operation on OSX
      if (os.platform() === 'darwin') {
        // fallback to a system call
        spawn('open', [uri]);
      } else {
        Gio.AppInfo.launchDefaultForUri(uri, null);
      }
    }
  }
}).run();
