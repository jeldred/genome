package Genome::Model::Build::PhenotypeCorrelation;

#use default auto-generated build class
Genome::Model::Build->__extend_namespace__('PhenotypeCorrelation');

sub reference_being_replaced_for_input {
    my ($self, $input) = @_;

    if($input->name eq "roi_list"){
        my $rsb = $self->reference_sequence_build;
        my $roi_reference = $input->value->reference;
        unless ($roi_reference) {
            return;
        }

        if ($roi_reference and !$rsb->is_compatible_with($roi_reference)) {
            my $converter =  Genome::Model::Build::ReferenceSequence::Converter->get_with_lock(
                source_reference_build => $roi_reference,
                destination_reference_build => $rsb,
            );

            if ($converter) {
                return 1;
            }
        }
    }
    return;
}

# Return true if the qc failed for this build
sub qc_failed {
    my $self = shift;
    my $note = $self->notes(header_text => 'QC Failed');
    return (defined $note);
}
sub qc_succeeded { my $self = shift; return (!$self->qc_failed) }

1;
