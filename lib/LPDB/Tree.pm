package LPDB::Tree;

=head1 NAME

LPDB::Tree - navigate a logical tree of pictures in sqlite

=cut

use strict;
use warnings;
use Image::Magick;
use LPDB::Schema;
use LPDB::Schema::Object;	# object extensions by twitham

sub new {
    my($class, $lpdb) = @_;
    my $self = { schema => $lpdb->schema,
		 conf => $lpdb->conf,
		 # tree => [],	# 2 dimensional row/column navigator
    };
    bless $self, $class;
    # $self->{tree}[0] = [$self->pathpics(0)];
    # # use Data::Dumper; print Dumper $self->{tree};
    return $self;
}

sub pathpics {		      # return paths and pictures in parent ID
    my($self, $id) = @_;
    my(@dirs, @pics);
    if (my $paths = $self->{schema}->resultset('Path')->search(
	    {parent_id => $id || 0},
	    {order_by => { -asc => 'path' },
	     columns => [qw/path path_id/],
	    })) {
	while (my $row = $paths->next) {
	    push @dirs, $row;
	}
    }
    if (my $pics = $self->{schema}->resultset('Picture')->search(
	    {path_id => $id || 0},
	    {order_by => { -asc => 'basename' },
	     prefetch => 'picture_paths',
	    })) {
	push @pics, $pics->all;
    }
    return \@dirs, \@pics;
}

1;
