#!/usr/bin/env genome-perl

BEGIN { 
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

use strict;
use warnings;

use above "Genome";
use Test::More;

use Genome::Test::Factory::Sample;

use_ok('Genome::Model') or die;

class Genome::ProcessingProfile::Test {
    is => 'Genome::ProcessingProfile'
};

class Genome::Model::Test {
    is => 'Genome::Model',
};

my $test_subject = Genome::Test::Factory::Sample->setup_object();
ok($test_subject, 'created test subject') or die;

my $test_pp = Genome::ProcessingProfile::Test->create(
    name => 'test_pp',
);
ok($test_pp, 'created test processing profile') or die;

my $test_model = Genome::Model::Test->create(
    name => 'test_model',
    processing_profile => $test_pp,
    subject => $test_subject,
);
ok($test_model, 'successfully created test model') or die;

my $test_input_model = Genome::Model::Test->create(
    processing_profile => $test_pp,
    subject => $test_subject,
    name => 'test_input_model',
);
ok($test_input_model, 'successfully created test input model') or die;

$test_model->add_input(
    value => $test_input_model,
    name => 'input_model',
);
my @inputs = $test_model->inputs;
ok(@inputs == 1, 'found one input on model, as expected');

my @from_models = $test_model->from_models;
ok(scalar(@from_models) == 1, 'got 1 from model, as expected');
ok($from_models[0]->id eq $test_input_model->id, 'from model is test input model');

my @to_models = $test_input_model->to_models;
ok(scalar(@to_models) == 1, 'got 1 to model');
ok($to_models[0]->id eq $test_model->id, 'got expected to model');

done_testing();
