use utf8;
package LPDB::Schema::Result::Album;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

LPDB::Schema::Result::Album - Logical collections of pictures

=cut

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';

=head1 TABLE: C<Albums>

=cut

__PACKAGE__->table("Albums");

=head1 ACCESSORS

=head2 album_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 name

  data_type: 'text'
  is_nullable: 0

Name of the Photo Album

=head2 date

  data_type: 'integer'
  is_nullable: 1

Date of the Photo Album

=head2 place

  data_type: 'text'
  is_nullable: 1

Place Taken (optional)

=head2 description

  data_type: 'text'
  is_nullable: 1

Description (optional)

=cut

__PACKAGE__->add_columns(
  "album_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "name",
  { data_type => "text", is_nullable => 0 },
  "date",
  { data_type => "integer", is_nullable => 1 },
  "place",
  { data_type => "text", is_nullable => 1 },
  "description",
  { data_type => "text", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</album_id>

=back

=cut

__PACKAGE__->set_primary_key("album_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<name_unique>

=over 4

=item * L</name>

=back

=cut

__PACKAGE__->add_unique_constraint("name_unique", ["name"]);

=head1 RELATIONS

=head2 picture_albums

Type: has_many

Related object: L<LPDB::Schema::Result::PictureAlbum>

=cut

__PACKAGE__->has_many(
  "picture_albums",
  "LPDB::Schema::Result::PictureAlbum",
  { "foreign.album_id" => "self.album_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 files

Type: many_to_many

Composing rels: L</picture_albums> -> file

=cut

__PACKAGE__->many_to_many("files", "picture_albums", "file");


# Created by DBIx::Class::Schema::Loader v0.07048 @ 2019-11-25 18:39:31
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:cVmIkhWFep3u82jLSyApew


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
