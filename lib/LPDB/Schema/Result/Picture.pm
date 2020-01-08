use utf8;
package LPDB::Schema::Result::Picture;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

LPDB::Schema::Result::Picture - Picture files that hold images

=cut

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';

=head1 TABLE: C<Pictures>

=cut

__PACKAGE__->table("Pictures");

=head1 ACCESSORS

=head2 file_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 basename

  data_type: 'text'
  is_nullable: 0

=head2 dir_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 bytes

  data_type: 'integer'
  is_nullable: 1

Size of the image file in bytes

=head2 modified

  data_type: 'integer'
  is_nullable: 1

Last modified timestamp of the image file

=head2 time

  data_type: 'integer'
  is_nullable: 1

Time image was taken if known from EXIF, else file create or modify time

=head2 rotation

  data_type: 'integer'
  default_value: 0
  is_nullable: 1

Orientation of the camera in degrees: 0, 90, 180, 270

=head2 width

  data_type: 'integer'
  is_nullable: 1

Displayed horizontal width of the image in pixels, after rotation correction

=head2 height

  data_type: 'integer'
  is_nullable: 1

Displayed vertical height of the image in pixels, after rotation correction

=head2 caption

  data_type: 'text'
  is_nullable: 1

EXIF caption or description

=cut

__PACKAGE__->add_columns(
  "file_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "basename",
  { data_type => "text", is_nullable => 0 },
  "dir_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "bytes",
  { data_type => "integer", is_nullable => 1 },
  "modified",
  { data_type => "integer", is_nullable => 1 },
  "time",
  { data_type => "integer", is_nullable => 1 },
  "rotation",
  { data_type => "integer", default_value => 0, is_nullable => 1 },
  "width",
  { data_type => "integer", is_nullable => 1 },
  "height",
  { data_type => "integer", is_nullable => 1 },
  "caption",
  { data_type => "text", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</file_id>

=back

=cut

__PACKAGE__->set_primary_key("file_id");

=head1 RELATIONS

=head2 dir

Type: belongs_to

Related object: L<LPDB::Schema::Result::Directory>

=cut

__PACKAGE__->belongs_to(
  "dir",
  "LPDB::Schema::Result::Directory",
  { dir_id => "dir_id" },
  {
    is_deferrable => 0,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);

=head2 picture_albums

Type: has_many

Related object: L<LPDB::Schema::Result::PictureAlbum>

=cut

__PACKAGE__->has_many(
  "picture_albums",
  "LPDB::Schema::Result::PictureAlbum",
  { "foreign.file_id" => "self.file_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 picture_paths

Type: has_many

Related object: L<LPDB::Schema::Result::PicturePath>

=cut

__PACKAGE__->has_many(
  "picture_paths",
  "LPDB::Schema::Result::PicturePath",
  { "foreign.file_id" => "self.file_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 picture_tags

Type: has_many

Related object: L<LPDB::Schema::Result::PictureTag>

=cut

__PACKAGE__->has_many(
  "picture_tags",
  "LPDB::Schema::Result::PictureTag",
  { "foreign.file_id" => "self.file_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 thumbs

Type: has_many

Related object: L<LPDB::Schema::Result::Thumb>

=cut

__PACKAGE__->has_many(
  "thumbs",
  "LPDB::Schema::Result::Thumb",
  { "foreign.file_id" => "self.file_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 albums

Type: many_to_many

Composing rels: L</picture_albums> -> album

=cut

__PACKAGE__->many_to_many("albums", "picture_albums", "album");

=head2 paths

Type: many_to_many

Composing rels: L</picture_paths> -> path

=cut

__PACKAGE__->many_to_many("paths", "picture_paths", "path");

=head2 tags

Type: many_to_many

Composing rels: L</picture_tags> -> tag

=cut

__PACKAGE__->many_to_many("tags", "picture_tags", "tag");


# Created by DBIx::Class::Schema::Loader v0.07048 @ 2020-01-07 16:03:51
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:qB077qvRV6MWUATO8eA4cQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
