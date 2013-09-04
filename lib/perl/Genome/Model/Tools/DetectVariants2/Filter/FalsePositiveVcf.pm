package Genome::Model::Tools::DetectVariants2::Filter::FalsePositiveVcf;

use warnings;
use strict;

use Genome;
use Workflow;
use Workflow::Simple;
use Carp;
use Data::Dumper;
use Genome::Utility::Vcf ('open_vcf_file', 'parse_vcf_line', 'deparse_vcf_line', 'get_vcf_header', 'get_samples_from_header');

class Genome::Model::Tools::DetectVariants2::Filter::FalsePositiveVcf {
    is => 'Genome::Model::Tools::DetectVariants2::Filter::FalsePositiveVcfBase',
    doc => "This module uses detailed readcount information from bam-readcounts to filter likely false positives",
};

##########################################################################################
# Capture filter for high-depth, lower-breadth datasets
# Contact: Dan Koboldt (dkoboldt@genome.wustl.edu)
##########################################################################################
sub _filter_variants {
    my $self = shift;

    unless ($self->bam_readcount_version) {
        die $self->error_message("Bam readcount version is not specified");
    }

    ## Determine the strandedness and read position thresholds ##

    ## Initialize counters ##
    my $stats;
    $stats->{'num_variants'}  = $stats->{'num_no_readcounts'} = $stats->{'num_pass_filter'} = $stats->{'num_no_allele'} = 0;
    $stats->{'num_fail_varcount'} = $stats->{'num_fail_varfreq'} = $stats->{'num_fail_strand'} = $stats->{'num_fail_pos'} = $stats->{'num_fail_mmqs'} = $stats->{'num_fail_mapqual'} = $stats->{'num_fail_readlen'} = $stats->{'num_fail_dist3'} = 0;
    $stats->{'num_MT_sites_autopassed'} = $stats->{'num_fail_homopolymer'} = 0;

    my $output_file = $self->_temp_staging_directory . "/snvs.raw.gz";
    my $output_fh = Genome::Sys->open_gzip_file_for_writing($output_file);

    #First, need to create a variant list file to use for generating the readcounts.
    # FIXME this will work after the polymuttdenovo filter, but not directly after polymutt due to the separate denovo and standard filenames

    # FIXME Things need to be cleaned up here...
    # We try to use the incoming snvs.hq file if it exists because of the refalign/normal pipelines
    # But currently, phenotype correlation only produces vcfs and nothing else... so fall back to using the vcf if snvs.hq doesnt exist.
    my $input_file;
    my $vcf_file = $self->input_directory . "/snvs.vcf.gz";
    my $hq_file = $self->input_directory . "/snvs.hq";
    if (-s $hq_file ) {
        $input_file = $hq_file;
    } elsif (-s $vcf_file) {
        $input_file = $vcf_file;
    } else {
        die $self->error_message("Could not find $vcf_file or $hq_file");
    }

    ## Build temp file for positions where readcounts are needed ##
    #my $region_path = $self->_temp_scratch_directory."/regions";
    my $region_path = $self->output_directory."/regions";

    $self->print_region_list($input_file, $region_path);

    ## Run BAM readcounts in batch mode to get read counts for all positions in file ##
    my $readcount_searcher_by_sample = $self->generate_and_run_readcounts_in_parallel($region_path);

    # Advance to the first variant line and print out the header
    my ($input_fh, $header) = $self->parse_vcf_header($input_file);
    #check here to see if header has FT format tag
    unless(grep { $_ =~/FORMAT=<ID=FT,/ } @$header) {
        my $col_header = $header->[-1];
        $header->[-1] = qq{##FORMAT=<ID=FT,Number=1,Type=String,Description="Per Sample Filter Status">\n};
        push @$header, $col_header;
    }
    #here embed the filter codes. This should be more centralized to be less craptastic
    $self->generate_filter_names;
    for my $filter (values %{$self->_filters}) {
        my $filter_name = $filter->[0];
        unless(grep {/$filter_name/} @$header) {
            $self->add_filter_to_vcf_header($header,@$filter);
        }
    }
    $output_fh->print(join("",@$header));
    my @sample_names = get_samples_from_header($header);

    ## Parse the variants file ##
    while(my $line = $input_fh->getline) {
        # FIXME should just pass in a single sample here instead of a whole line. Or a sample joined with a line to make a whole single sample vcf line?
        my $parsed_line = parse_vcf_line($line, \@sample_names);
        $self->filter_one_line($parsed_line, $readcount_searcher_by_sample, $stats, \@sample_names);
        $output_fh->print(deparse_vcf_line($parsed_line,\@sample_names));
    }

    $input_fh->close;
    $output_fh->close;
    $self->print_stats($stats);

    $self->_convert_to_standard_formats($output_file);

    return 1;
}

# Create snvs.hq snvs.lq and bed files
sub _convert_to_standard_formats {
    my ($self, $raw_file) = @_;


    # When multiple samples are present only VCF really makes sense. So don't convert to bed.
    my @alignment_results = $self->alignment_results;
    if ( @alignment_results and ( scalar(@alignment_results >= 2) )  ) {
        my $vcf_file = $self->_temp_staging_directory . "/snvs.vcf.gz";
        Genome::Sys->copy_file($raw_file, $vcf_file);
        unlink $raw_file;
        return 1;
    }

    # Get the header
    my ($header, $raw_fh) = get_vcf_header($raw_file);
    my @header_array = split "\n", $header;

    # Put header and only PASS variants in HQ file
    my $pass_snv_output_file = $self->_temp_staging_directory . "/snvs.hq";
    my $pass_fh = Genome::Sys->open_file_for_writing($pass_snv_output_file);
    $pass_fh->print($header);

    # Put header and only non PASS variants in LQ file
    my $fail_snv_output_file = $self->_temp_staging_directory . "/snvs.lq";
    my $fail_fh = Genome::Sys->open_file_for_writing($fail_snv_output_file);
    $fail_fh->print($header);

    my @sample_names = get_samples_from_header(\@header_array);

    while(my $line = $raw_fh->getline) {
        my $parsed_line = parse_vcf_line($line, \@sample_names);

        my $pass = 1;
        for my $sample_name (@sample_names) {
            unless ( $parsed_line->{sample}{$sample_name}{"FT"} eq 'PASS' or $parsed_line->{sample}{$sample_name}{"FT"} eq '.') {
                $pass = 0;
            }
        }

        if ($pass) {
            $pass_fh->print($line);
        } else {
            $fail_fh->print($line);
        }
    }

    $pass_fh->close;
    $fail_fh->close;

    # Convert both files to bed
    my $convert = Genome::Model::Tools::Bed::Convert::Snv::SamtoolsToBed->create(
        source => $pass_snv_output_file,
        output => $self->_temp_staging_directory . "/snvs.hq.bed",
    );
    unless($convert->execute){
        $self->error_message("Failed to convert filter output to bed.");
        die $self->error_message;
    }

    my $convert_lq = Genome::Model::Tools::Bed::Convert::Snv::SamtoolsToBed->create(
        source => $fail_snv_output_file,
        output => $self->_temp_staging_directory . "/snvs.lq.bed",
    );
    unless($convert_lq->execute){
        $self->error_message("Failed to convert failed-filter output to bed.");
        die $self->error_message;
    }

    return 1;
}

sub should_print_region_line {
    return 1;
}

sub open_input_file {
    my ($self, $input_file) = @_;

    return open_vcf_file($input_file);
}

#FIXME probably move this to a base class
# Format fields this filter requires, override in each filter
sub required_format_fields {
    return qw(GT);
}

# Given a parsed vcf line structure, filter each sample on the line
sub filter_one_line {
    my $self = shift;
    my $parsed_vcf_line = shift;
    my $readcount_searcher_by_sample = shift;
    my $stats = shift;
    my $samples = shift;

    # FIXME this will be only correct for the number of lines we have
    $stats->{'num_variants'}++;

    # FIXME run this for each sample in the line that is not "." and has a non ref GT
    for my $sample_name (@$samples) {
        $self->filter_one_sample($parsed_vcf_line, $readcount_searcher_by_sample, $stats, $sample_name);
    }

    return 1;
}

sub filter_sample_format_tag {
    return 'FT';
}

sub get_readcounts_from_vcf_line {
    my ($self, $parsed_vcf_line, $readcount_searcher_by_sample, $sample_name) = @_;

    my $readcount_searcher = $readcount_searcher_by_sample->{$sample_name};

    # This is a special case for when we are not considering two parents. #FIXME This is super hacky and should be improved somehow.
    if ((not defined $readcount_searcher) and (lc($sample_name) =~ m/fake_parent/i)) {
        $self->set_format_field($parsed_vcf_line, $sample_name,
            $self->filter_sample_format_tag, ".");
        return;
    }

    return $self->SUPER::get_readcounts_from_vcf_line($parsed_vcf_line,
        $readcount_searcher_by_sample, $sample_name);
}

sub update_variant_for_sample {
    my ($self, $parsed_vcf_line, $sample_name, $var) = @_;

    return $self->get_variant_for_sample($parsed_vcf_line->{alt},
        $parsed_vcf_line->{sample}->{$sample_name}->{GT},
        $parsed_vcf_line->{reference});
}

# In the line provided, set the sample provided to failed (FT)
sub fail_sample {
    my $self = shift;
    my $parsed_vcf_line = shift;
    my $sample_name = shift;
    my $filter_reason = shift;

    $self->status_message("Entering fail sample\n");
    # XXX @gsanders Are these options correct?
    $self->set_format_field($parsed_vcf_line, $sample_name,
        $self->filter_sample_format_tag, $filter_reason,
        append => 1, is_filter_fail => 1);
    return 1;
}

sub get_all_sample_names_and_bam_paths {
    my $self = shift;
    my @sample_names;
    my @bam_paths;

    if (!$self->aligned_reads_input) {
        for my $alignment_result ($self->alignment_results) {
            my $sample_name = $self->find_sample_name_for_alignment_result($alignment_result);
            push @sample_names, $sample_name;
            push @bam_paths, $alignment_result->merged_alignment_bam_path;
        }
    } else {
        push @bam_paths, $self->aligned_reads_input;
        push @sample_names, $self->aligned_reads_sample;
        if ($self->control_aligned_reads_input) {
            push @bam_paths, $self->control_aligned_reads_input;
            push @sample_names, $self->control_aligned_reads_sample;
        }
    }

    unless (scalar(@sample_names) == scalar(@bam_paths)) {
        die $self->error_message("Did not get the same number of sample names as bam paths.\n" . Data::Dumper::Dumper @sample_names . Data::Dumper::Dumper @bam_paths);
    }

    return (\@sample_names, \@bam_paths);
}

sub add_per_bam_params_to_input {
    my ($self, %inputs) = @_;

    my ($sample_names, $bam_paths) = $self->get_all_sample_names_and_bam_paths;

    for my $sample_name (@$sample_names) {
        my $bam_path = shift @$bam_paths;

        $self->status_message("Running BAM Readcounts for sample $sample_name...");
        my $readcount_file = $self->_temp_staging_directory . "/$sample_name.readcounts";  #this is suboptimal, but I want to wait until someone tells me a better way...multiple options exist
        if (-f $bam_path) {
            $inputs{"bam_${sample_name}"} = $bam_path;
        } else {
            die "merged_alignment_bam_path does not exist: $bam_path";
        }
        $inputs{"readcounts_${sample_name}"} = $readcount_file;
    }

    return %inputs;
}

sub generate_and_run_readcounts_in_parallel {
    my $self = shift;
    my $region_path = shift;

    my %inputs;

    #set up global readcount params
    $inputs{reference_fasta} = $self->reference_sequence_input;
    $inputs{region_list} = $region_path;
    $inputs{minimum_base_quality} = $self->bam_readcount_min_base_quality;
    $inputs{use_version} = $self->bam_readcount_version;

    my ($sample_names) = $self->get_all_sample_names_and_bam_paths;
    %inputs = $self->add_per_bam_params_to_input(%inputs);

    my $workflow = Workflow::Model->create(
        name=> "FalsePositiveVcf parallel readcount file creation",
        input_properties => [
        keys %inputs
        ],
        output_properties => [
        'output',
        ],
    );
    for my $sample (@$sample_names) {
        my $op = $workflow->add_operation(
            name=>"readcount creation for $sample",
            operation_type=>Workflow::OperationType::Command->get("Genome::Model::Tools::Sam::Readcount"),
        );
        $workflow->add_link(
            left_operation=>$workflow->get_input_connector,
            left_property=>"reference_fasta",
            right_operation=>$op,
            right_property=>"reference_fasta",
        );
        $workflow->add_link(
            left_operation=>$workflow->get_input_connector,
            left_property=>"region_list",
            right_operation=>$op,
            right_property=>"region_list",
        );
        $workflow->add_link(
            left_operation=>$workflow->get_input_connector,
            left_property=>"use_version",
            right_operation=>$op,
            right_property=>"use_version",
        );
        $workflow->add_link(
            left_operation=>$workflow->get_input_connector,
            left_property=>"minimum_base_quality",
            right_operation=>$op,
            right_property=>"minimum_base_quality",
        );
        $workflow->add_link(
            left_operation=>$workflow->get_input_connector,
            left_property=>"bam_$sample",
            right_operation=>$op,
            right_property=>"bam_file",
        );
        $workflow->add_link(
            left_operation=>$workflow->get_input_connector,
            left_property=>"readcounts_$sample",
            right_operation=>$op,
            right_property=>"output_file",
        );
        $workflow->add_link(
            left_operation=>$op,
            left_property=>"output_file",
            right_operation=>$workflow->get_output_connector,
            right_property=>"output",
        );
    }

    my $log_dir = $self->output_directory;
    if(Workflow::Model->parent_workflow_log_dir) {
        $log_dir = Workflow::Model->parent_workflow_log_dir;
    }
    $workflow->log_dir($log_dir);

    my @errors = $workflow->validate;
    if (@errors) {
        $self->error_message(@errors);
        die "Errors validating workflow\n";
    }
    $self->status_message("Now launching readcount generation jobs");
    my $result = Workflow::Simple::run_workflow_lsf( $workflow, %inputs);
    unless($result) {
        $self->error_message( join("\n", map($_->name . ': ' . $_->error, @Workflow::Simple::ERROR)) );
        die $self->error_message("parallel readcount generation workflow did not return correctly.");
    }

    #all succeeded so open files
    my $readcount_searcher_by_sample;
    for my $sample (@$sample_names) {
        $readcount_searcher_by_sample->{$sample} = $self->make_buffered_rc_searcher(Genome::Sys->open_file_for_reading($inputs{"readcounts_$sample"}));
    }
    return $readcount_searcher_by_sample;
}

#override the default scratch directories in order to allow for network available temp dirs

sub _create_temp_directories {
    my $self = shift;
    local %ENV = %ENV;
    $ENV{TMPDIR} = $self->output_directory;
    return $self->SUPER::_create_temp_directories(@_);
}

sub _promote_staged_data {
    my $self = shift;
    my $output_dir = $self->SUPER::_promote_staged_data(@_);

    #remove the staging directory before the reallocation occurs so that it doesn't get double counted.
    my $staging_dir = $self->_temp_staging_directory;
    Genome::Sys->remove_directory_tree($staging_dir);

    return $output_dir;
}

sub _check_native_file_counts {
    my $self = shift;
    return $self->_check_native_file_counts_vcf;
}

1;
