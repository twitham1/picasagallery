use utf8;
package LPDB::Schema::Result::Thumb;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

LPDB::Schema::Result::Thumb - Thumbnail images of [faces in] pictures

=cut

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';

=head1 TABLE: C<Thumbs>

=cut

__PACKAGE__->table("Thumbs");

=head1 ACCESSORS

=head2 file_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

ID of the image from Pictures table

=head2 contact_id

  data_type: 'integer'
  default_value: 0
  is_foreign_key: 1
  is_nullable: 0

ID of the cropped face, or 0 for no crop

=head2 image

  data_type: 'blob'
  is_nullable: 1

Binary thumbnail image content

=head2 modified

  data_type: 'integer'
  is_nullable: 1

Time of thumbnail image generation

=cut

__PACKAGE__->add_columns(
  "file_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "contact_id",
  {
    data_type      => "integer",
    default_value  => 0,
    is_foreign_key => 1,
    is_nullable    => 0,
  },
  "image",
  { data_type => "blob", is_nullable => 1 },
  "modified",
  { data_type => "integer", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</file_id>

=item * L</contact_id>

=back

=cut

__PACKAGE__->set_primary_key("file_id", "contact_id");

=head1 RELATIONS

=head2 contact

Type: belongs_to

Related object: L<LPDB::Schema::Result::Contact>

=cut

__PACKAGE__->belongs_to(
  "contact",
  "LPDB::Schema::Result::Contact",
  { contact_id => "contact_id" },
  { is_deferrable => 0, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 file

Type: belongs_to

Related object: L<LPDB::Schema::Result::Picture>

=cut

__PACKAGE__->belongs_to(
  "file",
  "LPDB::Schema::Result::Picture",
  { file_id => "file_id" },
  { is_deferrable => 0, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07048 @ 2020-01-07 16:03:51
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:2vY1PeZYLzO+9CVnrHkwYA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
