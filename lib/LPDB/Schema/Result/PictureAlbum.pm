use utf8;
package LPDB::Schema::Result::PictureAlbum;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

LPDB::Schema::Result::PictureAlbum - Joins many pictures to many albums

=cut

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';

=head1 TABLE: C<picture_album>

=cut

__PACKAGE__->table("picture_album");

=head1 ACCESSORS

=head2 file_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 album_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "file_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "album_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</file_id>

=item * L</album_id>

=back

=cut

__PACKAGE__->set_primary_key("file_id", "album_id");

=head1 RELATIONS

=head2 album

Type: belongs_to

Related object: L<LPDB::Schema::Result::Album>

=cut

__PACKAGE__->belongs_to(
  "album",
  "LPDB::Schema::Result::Album",
  { album_id => "album_id" },
  { is_deferrable => 0, on_delete => "CASCADE", on_update => "NO ACTION" },
);

=head2 file

Type: belongs_to

Related object: L<LPDB::Schema::Result::Picture>

=cut

__PACKAGE__->belongs_to(
  "file",
  "LPDB::Schema::Result::Picture",
  { file_id => "file_id" },
  { is_deferrable => 0, on_delete => "CASCADE", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07048 @ 2019-10-14 00:40:14
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:iHUqvTn2LA+WA9+fA3q5eQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
