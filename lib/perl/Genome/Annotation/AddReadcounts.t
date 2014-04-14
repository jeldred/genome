#!/usr/bin/env genome-perl

use strict;
use warnings FATAL => 'all';

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
};

use above "Genome";
use Sub::Install;
use Set::Scalar;
use Genome::Model::Tools::DetectVariants2::Result::Vcf;
use Genome::Model::Tools::Vcf::AnnotateWithReadcounts;
use Genome::Annotation::AddReadcounts::Result;

use Test::More;

my $cmd_class = 'Genome::Annotation::AddReadcounts';
use_ok($cmd_class) or die;

my ($cmd, $tool_args) = generate_test_cmd();

ok($cmd->execute(), 'Command executed');
is(ref($cmd->software_result), 'Genome::Annotation::AddReadcounts::Result', 'Found software result after execution');
test_cmd_and_result_are_in_sync($cmd);

my $expected_tool_args = {
    vcf_file => 'test_vcf',
    readcount_file_and_sample_idx => ['rc_file1:1', 'rc_file2:2'],
};
is_deeply($tool_args, $expected_tool_args, 'Called Genome::Model::Tools::Vcf::AnnotateWithReadcounts with expected args');

done_testing();

sub test_cmd_and_result_are_in_sync {
    my $cmd = shift;

    my $cmd_set = Set::Scalar->new($cmd->input_names);
    my $sr_set = Set::Scalar->new($cmd->software_result->param_names,
        $cmd->software_result->metric_names, $cmd->software_result->input_names);
    is_deeply($cmd_set - $sr_set, Set::Scalar->new(), 'All command inputs are persisted SoftwareResult properties');
}

sub generate_test_cmd {
    my $tool_args = {}; # gets filled in by $cmd->execute()
    Sub::Install::reinstall_sub({
        into => 'Genome::Model::Tools::Vcf::AnnotateWithReadcounts',
        as => '_execute_body',
        code => sub {
            my $self = shift;
            my $file = $self->output_file;
            `touch $file`;
            $tool_args->{vcf_file} = $self->vcf_file;
            $tool_args->{readcount_file_and_sample_idx} = [$self->readcount_file_and_sample_idx];
    }});

    my $vcf_result = Genome::Model::Tools::DetectVariants2::Result::Vcf::Combine->__define__();
    Sub::Install::reinstall_sub({
        into => 'Genome::Model::Tools::DetectVariants2::Result::Vcf',
        as => 'get_vcf',
        code => sub {return 'test_vcf';},
    });

    my $rc_result1 = Genome::Annotation::Readcount::Result->__define__();
    my $rc_result2 = Genome::Annotation::Readcount::Result->__define__();

    Sub::Install::reinstall_sub({
        into => 'Genome::Annotation::AddReadcounts::Result',
        as => 'readcount_file_and_sample_idxs',
        code => sub {my $self = shift; return ['rc_file1:1', 'rc_file2:2'];},
    });

    my %params = (
        readcount_results => [$rc_result1, $rc_result2],
        input_vcf_result => $vcf_result,
        variant_type => 'snvs',
    );
    my $cmd = $cmd_class->create(%params);
    return $cmd, $tool_args;
}