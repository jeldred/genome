#!/usr/bin/env genome-perl

BEGIN { 
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

use strict;
use warnings;

use above "Genome";
use Test::More;
use Sub::Install qw(reinstall_sub);
use Genome::Test::Factory::Sample;
use Genome::VariantReporting::Framework::Command::Wrappers::TestHelpers qw(get_build succeed_build);

my $pkg = "Genome::VariantReporting::Framework::Command::Wrappers::ModelPairFactory";

use_ok($pkg);

my $roi_name = "test roi";
my $roi2 = "test roi 2";
my $tumor_sample1 = Genome::Test::Factory::Sample->setup_object();
my $tumor_sample2 = Genome::Test::Factory::Sample->setup_object();
my $normal_sample1 = Genome::Test::Factory::Sample->setup_object();
my $build1 = get_build($roi_name, $tumor_sample1, $normal_sample1);
my $build2 = get_build($roi_name, $tumor_sample2, $normal_sample1);
my $build3 = get_build($roi_name, $tumor_sample2, $normal_sample1);
my $build4 = get_build($roi2, $tumor_sample1, $normal_sample1);
my $build5 = get_build($roi2, $tumor_sample2, $normal_sample1);

subtest "Only one model for an roi" => sub {

    my $factory = $pkg->create(models => [$build1->model],
        d0_sample => $tumor_sample1,
        d30_sample => $tumor_sample2,
        normal_sample => $normal_sample1,
        output_dir => Genome::Sys->create_temp_directory,
    );

    my @pairs = $factory->get_model_pairs;
    ok(@pairs == 0, "Factory with only one model returned no pairs");
    ok($factory->warning_message =~ /Skipping models for ROI $roi_name because there are not exactly two models/,
        "Warning message set correctly");
};

subtest "Three models for an roi" => sub {
    my $factory = $pkg->create(models => [$build1->model, $build2->model, $build3->model],
        d0_sample => $tumor_sample1,
        d30_sample => $tumor_sample2,
        normal_sample => $normal_sample1,
        output_dir => Genome::Sys->create_temp_directory,
    );

    my @pairs = $factory->get_model_pairs;
    ok(@pairs == 0, "Factory with only one model returned no pairs");
    ok($factory->warning_message =~ /Skipping models for ROI $roi_name because there are not exactly two models/,
        "Warning message set correctly");

};

subtest "Models for an roi don't have the right samples" => sub {
    my $bad_sample = Genome::Test::Factory::Sample->setup_object();
    my $factory = $pkg->create(models => [$build1->model, $build2->model],
        d0_sample => $tumor_sample1,
        d30_sample => $bad_sample,
        normal_sample => $normal_sample1,
        output_dir => Genome::Sys->create_temp_directory,
    );

    my @pairs = $factory->get_model_pairs;
    ok(@pairs == 0, "Factory with only one model returned no pairs");
    ok($factory->warning_message =~ /Incorrect discovery\/validation pairing for models for ROI \($roi_name\)/,
        "Warning message set correctly");
};

subtest "One model doesn't have last succeeded build" => sub {
    my $factory = $pkg->create(models => [$build1->model, $build2->model],
        d0_sample => $tumor_sample1,
        d30_sample => $tumor_sample2,
        normal_sample => $normal_sample1,
        output_dir => Genome::Sys->create_temp_directory,
    );

    my @pairs = $factory->get_model_pairs;
    ok(@pairs == 0, "Factory with only one model returned no pairs");
    ok($factory->warning_message =~ /No last succeeded build for discovery model/,

        "Warning message set correctly");
};

subtest "Two valid model pairs" => sub {
    succeed_build($build1);
    succeed_build($build2);
    succeed_build($build4);
    succeed_build($build5);
    my $factory = $pkg->create(models => [$build1->model, $build2->model, $build4->model, $build5->model],
        d0_sample => $tumor_sample1,
        d30_sample => $tumor_sample2,
        normal_sample => $normal_sample1,
        output_dir => Genome::Sys->create_temp_directory,
    );

    reinstall_sub({
        into => "Genome::VariantReporting::Framework::Command::Wrappers::ModelPair",
        as => "create",
        code => sub {
            return 1;
        },
    }
    );

    my @pairs = $factory->get_model_pairs;
    is(scalar @pairs, 4, "2 model pairs for 2 pairs of models returned");
};

done_testing;


