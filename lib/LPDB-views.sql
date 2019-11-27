-- This magic single all in one view completes the many-to-many
-- relationships.  This enables navigate/filter/group/sort by
-- anything!  Query code must be careful to group_by what is needed

DROP VIEW IF EXISTS PathView;

CREATE VIEW PathView AS
   SELECT
      Paths.*,
      Pictures.*,
      (Pictures.width * Pictures.height) AS pixels,
      Tags.*
   FROM
      Paths
   LEFT JOIN PicturePath ON Paths.path_id = PicturePath.path_id
   LEFT JOIN Pictures ON Pictures.file_id = PicturePath.file_id
   LEFT JOIN PictureTag ON Pictures.file_id = PictureTag.file_id
   LEFT JOIN Tags ON Tags.tag_id = PictureTag.tag_id;
   -- TODO: add joins to picasa metadata here

-- original experimental views below no longer used
-- TODO: remove all this if it is not valuable

DROP VIEW IF EXISTS AllView;

DROP VIEW IF EXISTS PicturePathView;

-- CREATE VIEW PicturePathView AS
--    SELECT
--       path.path AS path,
--       pictures.*
--    FROM
--       pictures, path, picture_path
--    WHERE
--       pictures.file_id = picture_path.file_id
--       AND
--       path.path_id = picture_path.path_id;

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

-- CREATE VIEW PathTagView AS
--    SELECT
--       tags.string as string,
--       path.path AS path,
--       pictures.filename AS filename
--    FROM
--       pictures, tags, picture_tag, picture_path, path
--    WHERE
--       pictures.file_id = picture_tag.file_id
--       AND
--       tags.tag_id = picture_tag.tag_id
--       AND
--       pictures.file_id = picture_path.file_id
--       AND
--       path.path_id = picture_path.path_id;
