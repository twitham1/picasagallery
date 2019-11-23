DROP VIEW IF EXISTS PicturePathView;

CREATE VIEW PicturePathView AS
   SELECT
      path.path AS path,
      pictures.*
   FROM
      pictures, path, picture_path
   WHERE
      pictures.file_id = picture_path.file_id
      AND
      path.path_id = picture_path.path_id;

DROP VIEW IF EXISTS PictureTagView;

-- CREATE VIEW PictureTagView AS
--    SELECT
--       tags.string as string,
--       pictures.*
--    FROM
--       pictures, tags, picture_tag
--    WHERE
--       pictures.file_id = picture_tag.file_id
--       AND
--       tags.tag_id = picture_tag.tag_id;


DROP VIEW IF EXISTS PathTagView;

CREATE VIEW PathTagView AS
   SELECT
      tags.string as string,
      path.path AS path,
      pictures.filename AS filename
   FROM
      pictures, tags, picture_tag, picture_path, path
   WHERE
      pictures.file_id = picture_tag.file_id
      AND
      tags.tag_id = picture_tag.tag_id
      AND
      pictures.file_id = picture_path.file_id
      AND
      path.path_id = picture_path.path_id;


-- all in one - I think it multiplies too much, not yet used....
DROP VIEW IF EXISTS AllView;
DROP VIEW IF EXISTS PathView;

CREATE VIEW PathView AS
   SELECT
      path.*,
      pictures.*,
      tags.*
   FROM
      path
   LEFT JOIN picture_path ON path.path_id = picture_path.path_id
   LEFT JOIN pictures ON pictures.file_id = picture_path.file_id
   LEFT JOIN picture_tag on pictures.file_id = picture_tag.file_id
   LEFT JOIN tags on tags.tag_id = picture_tag.tag_id;
