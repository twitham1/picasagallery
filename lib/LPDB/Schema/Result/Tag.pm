use utf8;
package LPDB::Schema::Result::Tag;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

LPDB::Schema::Result::Tag - Tags in pictures (EXIF keywords or subject)

=cut

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';

=head1 TABLE: C<tags>

=cut

__PACKAGE__->table("tags");

=head1 ACCESSORS

=head2 tag_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 string

  data_type: 'text'
  is_nullable: 0

Unique text of one tag

=cut

__PACKAGE__->add_columns(
  "tag_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "string",
  { data_type => "text", is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</tag_id>

=back

=cut

__PACKAGE__->set_primary_key("tag_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<string_unique>

=over 4

=item * L</string>

=back

=cut

__PACKAGE__->add_unique_constraint("string_unique", ["string"]);

=head1 RELATIONS

=head2 picture_tags

Type: has_many

Related object: L<LPDB::Schema::Result::PictureTag>

=cut

__PACKAGE__->has_many(
  "picture_tags",
  "LPDB::Schema::Result::PictureTag",
  { "foreign.tag_id" => "self.tag_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 files

Type: many_to_many

Composing rels: L</picture_tags> -> file

=cut

__PACKAGE__->many_to_many("files", "picture_tags", "file");


# Created by DBIx::Class::Schema::Loader v0.07048 @ 2019-10-14 01:05:10
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:LmStCUfSDIkppV9kP44cow


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
