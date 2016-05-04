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
  GLib = require('GLib'),
  Gtk = require('Gtk'),
  Gio = require('Gio'),
  Gdk = require('Gdk'),
  WebKit2 = require('WebKit2'),
  fs = require('fs'),
  path = require('path')
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
        if (this.info.hasOwnProperty('x') && this.info.hasOwnProperty('y')) {
          this.window.move(this.info.x, this.info.y);
        }
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
  },
  initUI() {
    const screen = Gdk.Screen.getDefault();
    this.window = new Gtk.ApplicationWindow({
      application: this.app,
      defaultWidth: this.info.defaultWidth || 360,
      defaultHeight:  this.info.defaultHeight ||
                      Math.max(160, screen.getHeight() - 160),
      windowPosition: this.info.windowPosition
    });
    this.window.setIconFromFile(this.icon);
    this.window.on('delete_event', () => false);
    this.window.setTitlebar(this.header);
    this.window.add(this.webView);
  },
  get webView() {
    if (!this._webView) {
      const webView = new WebKit2.WebView();
      webView.getContext().getCookieManager().setPersistentStorage(
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
            }
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
      if (this.info.showNotification) {
        webView.on('show-notification', (webView, notification, data) => {
          this._header.setSubtitle(notification.title);
          notification.once('clicked', () => {
            this.window.setKeepAbove(true);
            setTimeout(() => {
              this.window.setKeepAbove(false);
            }, 100);
          });
        });
      }
      webView.on('load-changed', (webView, loadEvent, data) => {
        switch (loadEvent) {
          case 2: // FIGUREITOUT: where the hell is WEBKIT_LOAD_COMMITTED constant?
            webView.runJavaScript(
              `(function(window, JSGTK){"use strict";
                ${this.javascript}
              }(this,{
                open: function open(uri) {
                  location.href = '${this.channel}:open(' +
                    encodeURIComponent(JSON.stringify([uri])) +
                  ')';
                }
              }));`,
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
            let state = action.getState().getBoolean();
            action.setState(new GLib.Variant('b', !state));
            this.info.showNotification = !state;
          }
        },
        {
          name: 'Copy current page uri',
          action: 'copy-page-uri',
          callback: () => {
            Gtk.Clipboard.getDefault(
              Gdk.Display.getDefault()
            ).setText(
              this.webView.uri,
              this.webView.uri.length
            );
          }
        },
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
            .on('activate', item.callback)
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
        showCloseButton: false,
        hasSubtitle: true
      });
      this._header.packStart(this.button.back);
      this._header.packStart(this.button.refresh);
      this._header.packEnd(this.button.menu);
    }
    return this._header;
  },
  jsAction(which) {
    const
      i = which.indexOf('('),
      method = which.slice(0, i),
      args = JSON.parse(decodeURIComponent(which.slice(i + 1, -1)))
    ;
    this.actions[method].apply(this, args);
  },
  actions: {
    open: function (uri) {
      Gio.AppInfo.launchDefaultForUri(uri, null);
    }
  }
}).run();
