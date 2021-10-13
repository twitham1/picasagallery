use utf8;
package LPDB::Schema::Result::ColumnComment;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

LPDB::Schema::Result::ColumnComment

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<column_comments>

=cut

__PACKAGE__->table("column_comments");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 table_name

  data_type: 'text'
  is_nullable: 1

=head2 column_name

  data_type: 'text'
  is_nullable: 1

=head2 comment_text

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "table_name",
  { data_type => "text", is_nullable => 1 },
  "column_name",
  { data_type => "text", is_nullable => 1 },
  "comment_text",
  { data_type => "text", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2021-10-13 00:56:51
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:QJ9ZjmdnMMoQCOZ4gMCDnw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
