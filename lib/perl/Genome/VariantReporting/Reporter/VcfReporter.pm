package Genome::VariantReporting::Reporter::VcfReporter;

use strict;
use warnings;
use Genome;
use Genome::File::Vcf::Writer;
use List::AllUtils qw(all);

class Genome::VariantReporting::Reporter::VcfReporter {
    is => 'Genome::VariantReporting::Framework::Component::Reporter::SingleFile',
    has_transient_optional => [
        vcf_file => {
            is => 'Genome::File::Vcf',
        },
        header => {
            is => 'Genome::Vcf::Header',
        },
    ],
};

sub name {
    return 'vcf';
}

sub requires_interpreters {
    return qw(vcf-entry ft-keep contains-tag);
}

sub allows_hard_filters {
    return 0;
}

sub report {
    my $self = shift;
    my $interpretations = shift;

    my %vcf_entry_interpretations = %{$interpretations->{'vcf-entry'}};
    # All the vcf-entry interpretations are duplicates due to the caveat of
    # having to pass interpretations for each passed alt allele
    # We just grab the first one
    my $entry = (values %vcf_entry_interpretations)[0]->{'vcf_entry'};

    unless (defined($self->header)) {
        $self->process_header($entry->{'header'});
    }

    $self->process_entry($entry, $interpretations);
}

sub process_header {
    my $self = shift;
    my $header = shift;

    $self->add_headers_for_soft_filters($header);
    $self->add_header_for_main_filter($header);
    $self->header($header);
    $self->print_vcf_header();
}

sub add_headers_for_soft_filters {
    my $self = shift;
    my $header = shift;

    for my $filter ($self->soft_filters) {
        $header->add_filter_str(sprintf(
            "<ID=%s,Description=\"%s\">",
            $filter->vcf_id,
            $filter->vcf_description,
        ));
    }
}

sub add_header_for_main_filter {
    my $self = shift;
    my $header = shift;

    my $filters = join(", ", map { $_->vcf_id } $self->soft_filters);

    $header->add_info_str(sprintf(
        "<ID=%s,Number=A,Type=Integer,Description=\"%s\">",
        'ALLFILTERSPASS',
        'Flags whether the alternate allele passed all the soft filters: ' . $filters
    ));
}

sub print_vcf_header {
    my $self = shift;

    $self->vcf_file(Genome::File::Vcf::Writer->fhopen($self->_output_fh, $self->file_name, $self->header));
}

sub process_entry {
    my $self = shift;
    my $entry = shift;
    my $interpretations = shift;

    my @final_results = $self->determine_final_results($interpretations, $entry);
    add_final_results($entry, @final_results);
    $self->vcf_file->write($entry);
}

sub determine_final_results {
    my $self = shift;
    my $interpretations = shift;
    my $entry = shift;

    my @final_results;
    for my $alt_allele (@{$entry->{alternate_alleles}}) {
        push(@final_results, $self->all_filters_passed_for_allele($interpretations, $alt_allele));
    }
    return @final_results;
}

sub all_filters_passed_for_allele {
    my $self = shift;
    my $interpretations = shift;
    my $allele = shift;

    return (all { $interpretations->{$_->name}->{$allele}->{filter_status} == 1} $self->soft_filters) || 0;
}

sub add_final_results {
    my $entry = shift;
    my @final_results = @_;
    $entry->set_info_field('ALLFILTERSPASS', join(',', @final_results));
}

sub soft_filters {
    my $self = shift;
    return grep { $_->isa('Genome::VariantReporting::Framework::Component::Filter') } values %{$self->interpreters};
}

1;
