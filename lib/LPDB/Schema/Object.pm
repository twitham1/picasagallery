# here is how I can add methods to the DB objects (rows)!:

# use LPDB::Thumbnail;

package LPDB::Schema::Result::Picture;

sub pathtofile {
    my($self) = @_;
#    warn "pathtofile for $self\n";
    my $schema = $self->result_source->schema;
    my $pic = $schema->resultset('Picture')->find(
    	{file_id => $self->file_id},
    	{ prefetch => 'dir',
    	  columns => [ qw/basename dir.directory/]
    	});
    my $path = $pic->dir->directory . $pic->basename;
    return $path;
}

# sub thumbnail {
#     my($self) = @_;
#     warn "thumbnail for $self";
#     return LPDB::Thumbnail(
# }

1;
