-- https://www.sqlitetutorial.net/sqlite-create-table/

PRAGMA foreign_keys = ON;

-- dbicdump automatically includes this documentation in the class output
CREATE TABLE IF NOT EXISTS table_comments (
   id INTEGER PRIMARY KEY NOT NULL,
   table_name TEXT,
   comment_text TEXT); --  WITHOUT ROWID;

CREATE TABLE IF NOT EXISTS column_comments (
   id INTEGER PRIMARY KEY NOT NULL,
   table_name TEXT,
   column_name TEXT,
   comment_text TEXT); -- WITHOUT ROWID;

---------------------------------------- PICTURES
INSERT INTO table_comments (table_name, comment_text) VALUES
   ('pictures',	  'Picture files that hold images');

INSERT INTO column_comments (table_name, column_name, comment_text) VALUES
   ('pictures', 'filename', 'Path to the image file contents'),
   ('pictures', 'bytes',    'Size of the image file in bytes'),
   ('pictures', 'modified', 'Last modified timestamp of the image file'),
   ('pictures', 'time',     'Time image was taken if known from EXIF, else file create or modify time'),
   ('pictures', 'rotation', 'Stored clockwise rotation of the image in degrees: 0, 90, 180, 270'),
   ('pictures', 'width',    'Displayed horizontal width of the image in pixels'),
   ('pictures', 'height',   'Displayed vertical height of the image in pixels'),
   ('pictures', 'caption',  'EXIF caption or description');

CREATE TABLE IF NOT EXISTS pictures (
   file_id	INTEGER PRIMARY KEY NOT NULL, -- alias to fast: rowid, oid, _rowid_
   filename	TEXT UNIQUE NOT NULL,
   bytes	INTEGER,
   modified	INTEGER,
   time		INTEGER,
   rotation	INTEGER DEFAULT 0,
   width	INTEGER,
   height	INTEGER,
   caption	TEXT
   );
-- length	INTEGER,	-- support video files this way?

CREATE UNIQUE INDEX IF NOT EXISTS filenames ON pictures (filename);
CREATE INDEX IF NOT EXISTS picture_captions ON pictures (caption);

-- INSERT INTO pictures VALUES(1,'hello.jpg',1234,999,888,800,600,0);
-- INSERT INTO pictures VALUES(2,'world.jpg',9876,444,555,1920,1080,0);

---------------------------------------- TAGS
INSERT INTO table_comments (table_name, comment_text) VALUES
   ('tags', 'Tags in pictures (EXIF keywords or subject)');

INSERT INTO column_comments (table_name, column_name, comment_text) VALUES
   ('tags', 'string', 'Unique text of one tag');
   
CREATE TABLE IF NOT EXISTS tags (
   tag_id	INTEGER PRIMARY KEY NOT NULL,
   string	TEXT UNIQUE NOT NULL);

CREATE UNIQUE INDEX IF NOT EXISTS tag_strings ON tags (string);

---------------------------------------- PICTURE TAGS many2many
INSERT INTO table_comments (table_name, comment_text) VALUES
   ('picture_tags', 'Joins many pictures to many tags');
CREATE TABLE IF NOT EXISTS picture_tag (
   file_id INTEGER,
   tag_id INTEGER,
   PRIMARY KEY (file_id, tag_id),
   FOREIGN KEY (file_id) 
      REFERENCES pictures (file_id)
         ON DELETE CASCADE
         ON UPDATE CASCADE,
   FOREIGN KEY (tag_id) 
      REFERENCES tags (tag_id) 
         ON DELETE CASCADE 
         ON UPDATE CASCADE
);

---------------------------------------- ALBUMS
INSERT INTO table_comments (table_name, comment_text) VALUES
   ('albums', 'Logical collections of pictures');

INSERT INTO column_comments (table_name, column_name, comment_text) VALUES
   ('albums', 'name',        'Name of the Photo Album'),
   ('albums', 'date',        'Date of the Photo Album'),
   ('albums', 'place',       'Place Taken (optional)'),
   ('albums', 'description', 'Description (optional)');
   
CREATE TABLE IF NOT EXISTS albums (
   album_id	INTEGER PRIMARY KEY NOT NULL,
   name		TEXT UNIQUE NOT NULL,
   date		INTEGER,	-- YYMMDD, or epoch, or DateTime?
   place	TEXT,
   description	TEXT);

CREATE UNIQUE INDEX IF NOT EXISTS album_names ON albums (name);
CREATE INDEX IF NOT EXISTS album_places ON albums (place);
CREATE INDEX IF NOT EXISTS album_descriptions ON albums (description);

---------------------------------------- PICTURE ALBUM many2many
INSERT INTO table_comments (table_name, comment_text) VALUES
   ('picture_album', 'Joins many pictures to many albums');
CREATE TABLE IF NOT EXISTS picture_album (
   file_id INTEGER,
   album_id INTEGER,
   PRIMARY KEY (file_id, album_id),
   FOREIGN KEY (file_id) 
      REFERENCES pictures (file_id)
         ON DELETE CASCADE
         ON UPDATE CASCADE,
   FOREIGN KEY (album_id) 
      REFERENCES albums (album_id) 
         ON DELETE CASCADE 
         ON UPDATE CASCADE
);

---------------------------------------- 

