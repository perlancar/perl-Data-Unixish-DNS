package Data::Unixish::DNS::resolve;

# DATE
# VERSION

use 5.010001;
use strict;
use syntax 'each_on_array'; # to support perl < 5.12
use warnings;
use Log::ger;

use Data::Unixish::Util qw(%common_args);
use Net::DNS::Async;

our %SPEC;

$SPEC{resolve} = {
    v => 1.1,
    summary => 'Resolve DNS',
    description => <<'_',

Note that by default names are resolved in parallel (`queue_size` is 30) and the
results will not be shown in the order they are received. If you want the same
order, you can set `order` to true, but currently you will have to wait until
the whole list is resolved.

_
    args => {
        %common_args,
        type => {
            schema => 'str*',
            default => 'A',
        },
        order => {
            schema => 'bool*',
        },
        queue_size => {
            schema => ['posint*'],
            default => 30,
        },
        retries => {
            schema => ['uint*'],
            default => 2,
        },
        server => {
            schema => 'net::hostname*',
            cmdline_aliases => {s=>{}},
        },
    },
    tags => [qw/text dns itemfunc/],
};
sub resolve {
    require Net::DNS::Async;

    my %args = @_;
    my ($in, $out) = ($args{in}, $args{out});
    my $type = $args{type} // 'A';

    my $resolver = Net::DNS::Async->new(
        QueueSize => $args{queue_size} // 30,
        Retries   => $args{retries}    // 2,
    );

    while (my ($index, $item) = each @$in) {
        chomp $item;
        $resolver->add({
            (Nameservers => [$args{server}]) x !!defined($args{server}),
            Callback    => sub {
                my $pkt = shift;
                return unless defined $pkt;
                my @rr = $pkt->answer;
                my %addrs;
                for my $r (@rr) {
                    my $k = $r->owner;
                    next unless $r->type eq $type;
                    $addrs{$k} //= "";
                    $addrs{$k} .=
                        (length($addrs{$k}) ? ", ":"") .
                        $r->address;
                }
                for (sort keys %addrs) {
                    push @$out, "$item: $addrs{$_}\n";
                }
            }, $item, $type
        });
    }
    $resolver->await;

    [200, "OK"];
}

1;
# ABSTRACT:

=head1 SYNOPSIS

In Perl:

 use Data::Unixish qw(lduxl);
 $addresses = lduxl(['DNS::resolved' => {}], "example.com", "www.example.com"); # => ["example.com: 1.2.3.4","www.example.com: 1.2.3.5"]

In command line:

 % echo -e "example.com\nwww.example.com" | dux DNS::resolve
 example.com: 1.2.3.4
 www.example.com: 1.2.3.5

=cut
