package Genome::Annotation::Plan;

use strict;
use warnings;
use Genome;
use YAML;

class Genome::Annotation::Plan {
    is => 'Genome::Annotation::Plan::Base',
    has => [
        expert_plans => {
            is => 'Genome::Annotation::Plan::ExpertPlan',
            is_many => 1,
        },
        reporter_plans => {
            is => 'Genome::Annotation::Plan::ReporterPlan',
            is_many => 1,
        },
    ],
};

sub object {
    # return the master workflow generator
    return;
}

sub children {
    my $self = shift;
    return ('experts' => [$self->expert_plans], 'reporters' => [$self->reporter_plans]);
}

sub create_from_file {
    my $class = shift;
    my $file = shift;

    my ($hashref, undef, undef) = YAML::LoadFile($file);

    return $class->create_from_hashref($hashref);
}

sub create_from_hashref {
    my $class = shift;
    my $hashref = shift;

    my $self = $class->SUPER::create(name => 'root');
    my @expert_plans;
    for my $expert_name (keys %{$hashref->{experts}}) {
        push @expert_plans, Genome::Annotation::Plan::ExpertPlan->create(
            name => $expert_name,
            params => $hashref->{experts}->{$expert_name},
        );
    }
    $self->expert_plans(\@expert_plans);

    my @reporter_plans;
    for my $reporter_name (keys %{$hashref->{reporters}}) {
        push @reporter_plans, Genome::Annotation::Plan::ReporterPlan->create_from_hashref(
            $reporter_name, $hashref->{reporters}->{$reporter_name},
        );
    }
    $self->reporter_plans(\@reporter_plans);

    return $self;
}

1;