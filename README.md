# A Desktop Client for Twitter Mobile
 ... if that makes any sense to you.

## WAT!?!
Twitter released a new https://mobild.twitter.com/ which looks pretty nice.
You can finally have it as stand-alone application on Linux Desktop too,
through a simple wrapper written in few hours of JavaScript writing and testing.

![jsGtk Twitter screenshot](http://webreflection.github.io/jsgtk-twitter/img/sc02.png?360)

This is the beauty of [writing native App with JavaScript](https://www.webreflection.co.uk/blog/2015/12/08/writing-native-apps-with-javascript).

## How To Install
The dependency number 1 is [jsgtk](https://github.com/WebReflection/jsgtk).
There are [few ways to install it](https://github.com/WebReflection/jsgtk#how-to-install), just pick your favorite.

The secondary dependency is `WebKit2GTK`, and on Linux [you should have no problems](https://github.com/WebReflection/jsgtk#dependencies).

At this point I haven't tested (yet) on OSX, if you have problems or errors with WebKit, I'm sorry about that, I swear [it's not my fault](https://github.com/Homebrew/legacy-homebrew/issues/47000).
You might get lucky with MacPorts though.

### How to run
I haven't yet created a proper [AUR](https://wiki.archlinux.org/index.php/Arch_User_Repository) or [npm](https://www.npmjs.com/) package yet, but I eventually will.
The simplest way to use this app is to clone this repository and then launch `./app`.

The first time only you'll need to login through the website.
This app doesn't hold, send, use, or analyze anything about you, your account, your twitter activity, or your credentials.

### How to install on Linux
There is an `app.install` which, if executed, should make the app available through the main Desktop environment, at least in ArchLinux and GNOME, [which is my primary OS of choice](http://archibold.io/).

### What's missing?
A simpified way to install this cross platform (meaning Linux and OSX, I'm afraid Windows decided to not simplify GTK UI development in its platform so ...)

The wrapper is ready to receives notifications, if they'll ever send them.
If there's some special functionality you'd like to have, give me a shout.

Please note this project was created mostly for personal need/usage, I'm not sure I'll have much time for it, I hope is good already enough.
Enjoy.

![jsGtk Twitter screenshot](http://webreflection.github.io/jsgtk-twitter/img/sc01.png?360)