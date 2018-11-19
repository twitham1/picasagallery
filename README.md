# picasagallery

* NOTE that this has nothing to do with web galleries* - picasagallery
sees only the local filesystem

Picasagallery is a keyboard (remote) controlled local picture browser
similiar to mythgallery of mythtv, but aware of extra Picasa metadata
found in .picasa.ini files.  This allows the user to navigate or
filter the images by Age, Albums, People, Stars, Tags and so on.

# Picasa.pm

Behind [picasagallery](bin/picasagallery) is a
[Picasa.pm](lib/Picasa.pm) library for understanding Exif and
.picasa.ini metadata into a perl hash object.  This can be used for
other things like merging pictures and their metadata, see
[examples](examples) for sample code.

# Status / TODO

This is "works-for-me" ware - it may not work for you.  It was sort of
a quick hack to see if it could be done.  I would like to replace the
in memory database with a SQLite database to reduce the memory
footprint and simplify some code.  Then I would like to replace the
GUI with Prima for even better performance.  See [TODO].

# How to Use

