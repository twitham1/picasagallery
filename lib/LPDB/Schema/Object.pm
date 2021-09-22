# here is how I can add methods to the DB objects (rows)!:

# use LPDB::Thumbnail;

package LPDB::Schema::Result::Picture;

sub pathtofile {		# return full filesystem path to file
    my($self) = @_;
#    warn "pathtofile for $self\n";
    my $schema = $self->result_source->schema;
    my $dir = $schema->resultset('Directory')->find(
    	{dir_id => $self->dir_id},
    	{columns => [ qw/directory/]
    	});
    my $path = $dir->directory . $self->basename;
    return $path;
}

package LPDB::Schema::Result::Path;

sub firstlastID {	    # return first and last picture ID of path
    my($self) = @_;
    #    warn "firstlast for $self\n";
    my $schema = $self->result_source->schema; # any way to find both in 1 query?
    my $first = $schema->resultset('PathView')->find(
    	{path => { like => $self->path . '%'},
	 time => { '!=' => undef } },
	{order_by => { -asc => 'time' },
	 rows => 1,
	 columns => [ qw/file_id/],
    	});
    my $last = $schema->resultset('PathView')->find(
    	{path => { like => $self->path . '%'},
	 time => { '!=' => undef } },
	{order_by => { -desc => 'time' },
	 rows => 1,
	 columns => [ qw/file_id/],
    	});
    return $first->file_id, $last->file_id;
}

# sub thumbnail {
#     my($self) = @_;
#     warn "thumbnail for $self";
#     return LPDB::Thumbnail(
# }

1;
