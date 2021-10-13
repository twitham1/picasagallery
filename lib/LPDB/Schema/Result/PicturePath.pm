use utf8;
package LPDB::Schema::Result::PicturePath;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

LPDB::Schema::Result::PicturePath - Joins many pictures to many virtual paths

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<PicturePath>

=cut

__PACKAGE__->table("PicturePath");

=head1 ACCESSORS

=head2 file_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 path_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "file_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "path_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</file_id>

=item * L</path_id>

=back

=cut

__PACKAGE__->set_primary_key("file_id", "path_id");

=head1 RELATIONS

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

=head2 path

Type: belongs_to

Related object: L<LPDB::Schema::Result::Path>

=cut

__PACKAGE__->belongs_to(
  "path",
  "LPDB::Schema::Result::Path",
  { path_id => "path_id" },
  { is_deferrable => 0, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2021-10-13 00:56:51
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:xNAsz+YBk+mvgo3LO3C2OA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
