# LPDB - Local Picture DataBase

LPDB is a local picture database.  This has nothing to do with web
galleries, as it sees pictures only in the local fileystem.  Metadata
of these pictures is stored in a local database so that we can
organize them in various ways and navigate them quickly.

# bin/lpgallery

lpgallery is a keyboard (remote) controlled local picture browser
similiar to mythgallery of mythtv for viewing local pictures on a big
screen from the comfort of your couch.  On Linux I use it with the
following:

	xrdb -merge <file> # where file is:
	Prima.Color: white
	Prima.Back: black
	Prima.HiliteBackColor: gray33
	Prima.Font: Helvetica-20

# Status / TODO

This is "works-for-me" ware under heavy development.  It should
someday do everything that picasagallery did (see below) and more,
only better and in a smaller memory footprint.

# How to use

This may or may not work to install the code

```
  dzil build
  cd <build>
  perl Makefile.PL
  make
  sudo make install
```

Now cd to the root of a directory with some pictures, ideally managed
by Picasa (but optional), and run lpgallery.  Answer yes to the prompt
and it should begin caching picture metadata and present the browser.
See lpgallery(1) manual page for more.


# older stuff, becoming obsolete and replaced by LPDB above

# bin/picasagallery

picasagallery is a keyboard (remote) controlled local picture browser
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
to submit to CPAN.  I may not bother until the SQLite/Prima re-write
is closer to completion.  Until then, this may or may not work

```
  dzil build
  cd <build>
  perl Makefile.PL
  make
  sudo make install
```

Now cd to the root of a directory with some pictures, ideally managed
by Picasa (but optional), and run picasagallery.  Answer yes to the
prompt and it should begin caching picture metadata and present the
browser.  See picasagallery(1) manual page for more.
