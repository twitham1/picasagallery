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

sub first {		    # return first picture below path
    my($self) = @_;
    my $schema = $self->result_source->schema; # any way to find both in 1 query?
    return $schema->resultset('PathView')->find(
    	{path => { like => $self->path . '%'},
	 time => { '!=' => undef } },
	{order_by => { -asc => 'time' },
	 rows => 1,
    	});
}
sub last {			# return last picture below path
    my($self) = @_;
    my $schema = $self->result_source->schema; # any way to find both in 1 query?
    return $schema->resultset('PathView')->find(
    	{path => { like => $self->path . '%'},
	 time => { '!=' => undef } },
	{order_by => { -desc => 'time' },
	 rows => 1,
    	});
}

# sub thumbnail {
#     my($self) = @_;
#     warn "thumbnail for $self";
#     return LPDB::Thumbnail(
# }

1;
