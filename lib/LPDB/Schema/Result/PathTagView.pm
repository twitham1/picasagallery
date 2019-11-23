use utf8;
package LPDB::Schema::Result::PathTagView;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

LPDB::Schema::Result::PathTagView

=cut

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';
__PACKAGE__->table_class("DBIx::Class::ResultSource::View");

=head1 TABLE: C<PathTagView>

=cut

__PACKAGE__->table("PathTagView");

=head1 ACCESSORS

=head2 string

  data_type: 'text'
  is_nullable: 1

=head2 path

  data_type: 'text'
  is_nullable: 1

=head2 filename

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "string",
  { data_type => "text", is_nullable => 1 },
  "path",
  { data_type => "text", is_nullable => 1 },
  "filename",
  { data_type => "text", is_nullable => 1 },
);


# Created by DBIx::Class::Schema::Loader v0.07048 @ 2019-11-23 15:38:32
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:/QXUAe8dlwJ46slh9P6FIg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
