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
		 id => 0,	# default id is last one
    };
    bless $self, $class;
    return $self;
}

sub pathpics {		     # return paths and pictures in given path
    my($self, $parent, $sort) = @_;
    my(@dirs, @pics);
    $parent =~ s{/+}{/};	# cleanup
    my $id = $self->{id};
    if ($parent and my $obj =
	$self->{schema}->resultset('Path')->find(
	    { path => $parent})) {
	$id =  $obj->path_id;
    }
    $self->{id} = $id;
    if (my $paths = $self->{schema}->resultset('Path')->search(
	    {parent_id => $id})) {
	push @dirs, $paths->all;
    }
    if (my $pics = $self->{schema}->resultset('Picture')->search(
	    {path_id => $id},
	    {order_by => $sort || [],
	     prefetch => [ 'picture_paths', 'dir' ],
	    })) {
	push @pics, $pics->all;
    }
    return \@dirs, \@pics;
}

sub related {			# paths related to given path or picture
    my($self, $path, $id) = @_;
    my %path = ( $path => 1 );
    if ($id and my $paths = $self->{schema}->resultset('PicturePath')->search(
    	    {"me.file_id" => $id},
	    {prefetch => [ 'path', 'file' ]},
	)) {
	while (my $one = $paths->next) { # can this be done without loop?
	    $path{$one->path->path . '/' . $one->file->pathtofile } = 1;
	}
    }
    my %root;
    $path =~ s{//.*}{};		# trim away pathtofile to list parents
    while ($path =~ s{[^/]+/?$}{}) {
	$root{$path} = 1 if length $path > 1;
    }
    return ((sort keys %path), (reverse sort keys %root));
}

# sub node {			# return Path or Picture of ID
#     my($self, $id) = @_;
#     my $obj;
#     if ($id < 0) {
# 	$obj = $self->{schema}->resultset('Path')->find(
# 	    { path_id => -1 * $id});
#     } else {
# 	$obj = $self->{schema}->resultset('Picture')->find(
# 	    { file_id => $id});
#     }
# #    warn "node $id = $obj\n";
#     return $obj;
# }

1;
