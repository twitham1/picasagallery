# picasagallery

* NOTE that this has *nothing* to do with web galleries -
picasagallery sees only the local filesystem.

Picasagallery is a keyboard (remote) controlled local picture browser
similiar to mythgallery of mythtv, but aware of extra Picasa metadata
found in .picasa.ini files.  This enables you to navigate and filter
the images by Age, Albums, People, Stars, Tags and so on.

# Picasa.pm

Behind [picasagallery](bin/picasagallery) is a
[Picasa.pm](lib/Picasa.pm) library for understanding Exif and
.picasa.ini metadata into a perl hash object.  This can be used for
other things like merging pictures and their metadata, see
[examples](examples) for sample code.

# Status / TODO

This is "works-for-me" ware - it may not work for you.  It was sort of
a quick hack to see if it could even be done.  I would like to replace
the in memory database with a SQLite database to reduce the memory
footprint and simplify some code.  And I would like to replace the GUI
with Prima for even better performance.  See [TODO](TODO).

# How to Install and Use

I never added tests and cleaned up the code to make this good enough
to submit to CPAN.  I may not bother until the SQLite/Prima re-write.
So until then, you can grab the latest .tar.gz build from my working
directory:

* http://twitham.homelinux.org/twitham/picasagallery/

Then simply install as usual:
```
  tar zxvf picasagallery-0.1.tar.gz
  cd picasagallery-0.1
  perl Makefile.PL
  make
  sudo make install
```
Now cd to the root of a directory with some pictures, ideally managed
by Picasa (but optional), and run picasagallery.  Answer yes to the
prompt and it should begin caching picture metadata and present the
browser.  See picasagallery(1) manual page for more.
