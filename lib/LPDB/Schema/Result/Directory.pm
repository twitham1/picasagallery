use utf8;
package LPDB::Schema::Result::Directory;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

LPDB::Schema::Result::Directory - Physical collections of pictures

=cut

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';

=head1 TABLE: C<Directories>

=cut

__PACKAGE__->table("Directories");

=head1 ACCESSORS

=head2 dir_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 directory

  data_type: 'text'
  is_nullable: 0

Physical path to a collection of pictures

=head2 parent_id

  data_type: 'integer'
  is_nullable: 1

ID of parent directory, 0 for / root

=cut

__PACKAGE__->add_columns(
  "dir_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "directory",
  { data_type => "text", is_nullable => 0 },
  "parent_id",
  { data_type => "integer", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</dir_id>

=back

=cut

__PACKAGE__->set_primary_key("dir_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<directory_unique>

=over 4

=item * L</directory>

=back

=cut

__PACKAGE__->add_unique_constraint("directory_unique", ["directory"]);

=head1 RELATIONS

=head2 pictures

Type: has_many

Related object: L<LPDB::Schema::Result::Picture>

=cut

__PACKAGE__->has_many(
  "pictures",
  "LPDB::Schema::Result::Picture",
  { "foreign.dir_id" => "self.dir_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07048 @ 2020-01-29 00:33:40
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:N1+i3+OGdaBYL8ggl8VlSg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
