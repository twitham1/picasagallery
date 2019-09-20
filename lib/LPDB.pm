# ABSTRACT: Local Picture Database

package LPDB;

sub new {
    my $class = shift;
    my $self = { hello => 'world' };
    return bless $self, $class;
}

1;
