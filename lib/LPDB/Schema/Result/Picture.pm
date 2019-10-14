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

=head1 TABLE: C<pictures>

=cut

__PACKAGE__->table("pictures");

=head1 ACCESSORS

=head2 file_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 filename

  data_type: 'text'
  is_nullable: 0

Path to the image file contents

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

Stored clockwise rotation of the image in degrees: 0, 90, 180, 270

=head2 width

  data_type: 'integer'
  is_nullable: 1

Displayed horizontal width of the image in pixels

=head2 height

  data_type: 'integer'
  is_nullable: 1

Displayed vertical height of the image in pixels

=head2 caption

  data_type: 'text'
  is_nullable: 1

EXIF caption or description

=cut

__PACKAGE__->add_columns(
  "file_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "filename",
  { data_type => "text", is_nullable => 0 },
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

=head1 UNIQUE CONSTRAINTS

=head2 C<filename_unique>

=over 4

=item * L</filename>

=back

=cut

__PACKAGE__->add_unique_constraint("filename_unique", ["filename"]);

=head1 RELATIONS

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

=head2 albums

Type: many_to_many

Composing rels: L</picture_albums> -> album

=cut

__PACKAGE__->many_to_many("albums", "picture_albums", "album");

=head2 tags

Type: many_to_many

Composing rels: L</picture_tags> -> tag

=cut

__PACKAGE__->many_to_many("tags", "picture_tags", "tag");


# Created by DBIx::Class::Schema::Loader v0.07048 @ 2019-10-14 01:36:29
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:TZ1M4/IQ5jMg0IQXLUgcrQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;