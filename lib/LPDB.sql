-- https://www.sqlitetutorial.net/sqlite-create-table/

-- this is per-connection so TODO: get LPDB to have this also:
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
   ('Pictures',	  'Picture files that hold images');

INSERT INTO column_comments (table_name, column_name, comment_text) VALUES
   ('Pictures', 'filename', 'Path to the image file contents'),
   ('Pictures', 'bytes',    'Size of the image file in bytes'),
   ('Pictures', 'modified', 'Last modified timestamp of the image file'),
   ('Pictures', 'time',     'Time image was taken if known from EXIF, else file create or modify time'),
   ('Pictures', 'rotation', 'Stored clockwise rotation of the image in degrees: 0, 90, 180, 270'),
   ('Pictures', 'width',    'Displayed horizontal width of the image in pixels'),
   ('Pictures', 'height',   'Displayed vertical height of the image in pixels'),
   ('Pictures', 'caption',  'EXIF caption or description');

CREATE TABLE IF NOT EXISTS Pictures (
   file_id	INTEGER PRIMARY KEY NOT NULL, -- alias to fast: rowid, oid, _rowid_
   basename	TEXT NOT NULL,
   dir_id	INTEGER,
   bytes	INTEGER,
   modified	INTEGER,
   time		INTEGER,
   rotation	INTEGER DEFAULT 0,
   width	INTEGER,
   height	INTEGER,
   caption	TEXT
   );
-- length	INTEGER,	-- support video files this way?

CREATE INDEX IF NOT EXISTS basename_index ON Pictures (basename);
CREATE INDEX IF NOT EXISTS caption_index ON Pictures (caption);
CREATE INDEX IF NOT EXISTS time_index ON Pictures (time);

---------------------------------------- Directories of pictures
INSERT INTO table_comments (table_name, comment_text) VALUES
   ('Directories', 'Physical collections of pictures');

INSERT INTO column_comments (table_name, column_name, comment_text) VALUES
   ('Directories', 'directory', 'Physical path to a collection of pictures'),
   ('Directories', 'parent_id', 'ID of parent directory');
   
CREATE TABLE IF NOT EXISTS Directories (
   dir_id	INTEGER PRIMARY KEY NOT NULL,
   directory	TEXT UNIQUE NOT NULL,
   parent_id	INTEGER
   );
CREATE INDEX IF NOT EXISTS dir_index ON Directories (directory, dir_id);
INSERT INTO Directories (directory, parent_id) VALUES ('/', 0);

---------------------------------------- Virtual File System
INSERT INTO table_comments (table_name, comment_text) VALUES
   ('Paths', 'Virtual logical collections of pictures');

INSERT INTO column_comments (table_name, column_name, comment_text) VALUES
   ('Paths', 'path', 'Logical path to a collection of pictures');
   
CREATE TABLE IF NOT EXISTS Paths (
   path_id	INTEGER PRIMARY KEY NOT NULL,
   path		TEXT UNIQUE NOT NULL);
CREATE INDEX IF NOT EXISTS path_index ON Paths (path, path_id);

---------------------------------------- PICTURE PATH many2many
INSERT INTO table_comments (table_name, comment_text) VALUES
   ('PicturePath', 'Joins many pictures to many virtual paths');
CREATE TABLE IF NOT EXISTS PicturePath (
   file_id INTEGER,
   path_id INTEGER,
   PRIMARY KEY (file_id, path_id),
   FOREIGN KEY (file_id) 
      REFERENCES Pictures (file_id)
         ON DELETE CASCADE
         ON UPDATE CASCADE,
   FOREIGN KEY (path_id) 
      REFERENCES Paths (path_id) 
         ON DELETE CASCADE 
         ON UPDATE CASCADE
) WITHOUT ROWID;
CREATE INDEX IF NOT EXISTS pp_pid_index ON PicturePath (path_id,file_id);
CREATE INDEX IF NOT EXISTS pp_fid_index ON PicturePath (file_id,path_id);

---------------------------------------- TAGS
INSERT INTO table_comments (table_name, comment_text) VALUES
   ('Tags', 'Tags in pictures (EXIF keywords or subject)');

INSERT INTO column_comments (table_name, column_name, comment_text) VALUES
   ('Tags', 'tag', 'Unique text of one tag');
   
CREATE TABLE IF NOT EXISTS Tags (
   tag_id	INTEGER PRIMARY KEY NOT NULL,
   tag		TEXT UNIQUE NOT NULL);

CREATE UNIQUE INDEX IF NOT EXISTS tag_index ON Tags (tag);

---------------------------------------- PICTURE TAGS many2many
INSERT INTO table_comments (table_name, comment_text) VALUES
   ('PictureTag', 'Joins many pictures to many tags');
CREATE TABLE IF NOT EXISTS PictureTag (
   file_id INTEGER,
   tag_id INTEGER,
   PRIMARY KEY (file_id, tag_id),
   FOREIGN KEY (file_id) 
      REFERENCES Pictures (file_id)
         ON DELETE CASCADE
         ON UPDATE CASCADE,
   FOREIGN KEY (tag_id) 
      REFERENCES Tags (tag_id) 
         ON DELETE CASCADE 
         ON UPDATE CASCADE
) WITHOUT ROWID;
CREATE INDEX IF NOT EXISTS pt_tid_index ON PictureTag (tag_id,file_id);
CREATE INDEX IF NOT EXISTS pt_fid_index ON PictureTag (file_id,tag_id);

---------------------------------------- ALBUMS
INSERT INTO table_comments (table_name, comment_text) VALUES
   ('Albums', 'Logical collections of pictures');

INSERT INTO column_comments (table_name, column_name, comment_text) VALUES
   ('Albums', 'name',        'Name of the Photo Album'),
   ('Albums', 'date',        'Date of the Photo Album'),
   ('Albums', 'place',       'Place Taken (optional)'),
   ('Albums', 'description', 'Description (optional)');
   
CREATE TABLE IF NOT EXISTS Albums (
   album_id	INTEGER PRIMARY KEY NOT NULL,
   name		TEXT UNIQUE NOT NULL,
   date		INTEGER,	-- YYMMDD, or epoch, or DateTime?
   place	TEXT,
   description	TEXT);

CREATE UNIQUE INDEX IF NOT EXISTS album_name_index ON Albums (name);
CREATE INDEX IF NOT EXISTS album_place_index ON Albums (place);
CREATE INDEX IF NOT EXISTS album_description_index ON Albums (description);

---------------------------------------- PICTURE ALBUM many2many
INSERT INTO table_comments (table_name, comment_text) VALUES
   ('PictureAlbum', 'Joins many pictures to many albums');
CREATE TABLE IF NOT EXISTS PictureAlbum (
   file_id INTEGER,
   album_id INTEGER,
   PRIMARY KEY (file_id, album_id),
   FOREIGN KEY (file_id) 
      REFERENCES Pictures (file_id)
         ON DELETE CASCADE
         ON UPDATE CASCADE,
   FOREIGN KEY (album_id) 
      REFERENCES Albums (album_id) 
         ON DELETE CASCADE 
         ON UPDATE CASCADE
) WITHOUT ROWID;
CREATE INDEX IF NOT EXISTS pa_aid_index ON PictureAlbum (album_id,file_id);
CREATE INDEX IF NOT EXISTS pa_fid_index ON PictureAlbum (file_id,album_id);

---------------------------------------- 
