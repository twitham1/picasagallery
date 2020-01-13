-- image thumnails in sqlite, only one size for simplicity

-- by twitham@sbcglobal.net, 2019/12

INSERT INTO table_comments (table_name, comment_text) VALUES
   ('Thumbs',	  'Thumbnail images of [faces in] pictures');

INSERT INTO column_comments (table_name, column_name, comment_text) VALUES
   ('Thumbs', 'image',		'Binary thumbnail image content'),
   ('Thumbs', 'file_id',	'ID of the image from Pictures table'),
   ('Thumbs', 'contact_id',	'ID of the cropped face, or 0 for no crop'),
   ('Thumbs', 'modified',	'Time of thumbnail image generation');

DROP TABLE IF EXISTS Thumbs;
CREATE TABLE Thumbs (
   file_id	INTEGER NOT NULL,
   contact_id	INTEGER DEFAULT 0,
   image	BLOB,
   modified	INTEGER,
   PRIMARY KEY (file_id, contact_id),
   FOREIGN KEY (file_id)
      REFERENCES Pictures (file_id)
         ON DELETE CASCADE
         ON UPDATE CASCADE,
   FOREIGN KEY (contact_id) 
      REFERENCES Contacts (contact_id)
         ON DELETE CASCADE
         ON UPDATE CASCADE
   );
CREATE INDEX IF NOT EXISTS thumb_id_index ON Thumbs (file_id, contact_id);
