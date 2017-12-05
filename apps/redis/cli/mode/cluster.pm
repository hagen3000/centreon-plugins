#
# Copyright 2017 Centreon (http://www.centreon.com/)
#
# Centreon is a full-fledged industry-strength solution that meets
# the needs in IT infrastructure and application monitoring for
# service performance.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

package apps::redis::cli::mode::cluster;

use base qw(centreon::plugins::mode);

use strict;
use warnings;

my $thresholds = {
    global => [
        ['disabled', 'CRITICAL'],
        ['enabled', 'OK'],
    ],
};

my %map_status = (
    0 => 'disabled',
    1 => 'enabled',
);

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;

    $self->{version} = '1.0';

    $options{options}->add_options(arguments => 
                {
                    "threshold-overload:s@" => { name => 'threshold_overload' },
                });
    
    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::init(%options);
    
    $self->{overload_th} = {};
    foreach my $val (@{$self->{option_results}->{threshold_overload}}) {
        if ($val !~ /^(.*?),(.*)$/) {
            $self->{output}->add_option_msg(short_msg => "Wrong threshold-overload option '" . $val . "'.");
            $self->{output}->option_exit();
        }
        my ($section, $status, $filter) = ('global', $1, $2);
        if ($self->{output}->is_litteral_status(status => $status) == 0) {
            $self->{output}->add_option_msg(short_msg => "Wrong threshold-overload status '" . $val . "'.");
            $self->{output}->option_exit();
        }
        $self->{overload_th}->{$section} = [] if (!defined($self->{overload_th}->{$section}));
        push @{$self->{overload_th}->{$section}}, {filter => $filter, status => $status};
    }
}


sub get_severity {
    my ($self, %options) = @_;
    my $status = 'UNKNOWN'; # default 
    
    if (defined($self->{overload_th}->{$options{section}})) {
        foreach (@{$self->{overload_th}->{$options{section}}}) {            
            if ($options{value} =~ /$_->{filter}/i) {
                $status = $_->{status};
                return $status;
            }
        }
    }
    foreach (@{$thresholds->{$options{section}}}) {           
        if ($options{value} =~ /$$_[0]/i) {
            $status = $$_[1];
            return $status;
        }
    }
    
    return $status;
}

sub run {
    my ($self, %options) = @_;
    
    $self->{redis} = $options{custom};
    $self->{results} = $self->{redis}->get_info(); 

    my $exit = $self->get_severity(section => 'global', value => $map_status{$items->{cluster_enabled}});
   
    $self->{output}->output_add(severity => $exit, short_msg => sprintf("Cluster is '%s'", $map_status{$items->{cluster_enabled}}));
    $self->{output}->display();
    $self->{output}->exit();
}

1;

__END__

=head1 MODE

Check cluster status

=over 8

=item B<--threshold-overload>

Set to overload default threshold values (syntax: status,regexp)
Example: --threshold-overload='CRITICAL,disabled'

=back

=cut