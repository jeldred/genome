#!/usr/bin/env genome-perl

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
    $ENV{UR_COMMAND_DUMP_STATUS_MESSAGES} = 1;
}

use strict;
use warnings;

use above "Genome";

use Test::More;

use_ok('Genome::Sample::Command::Import') or die;
Genome::Sample::Command::Import::_create_import_command_for_config({
        nomenclature => 'TeSt',
        name_regexp => '(TeSt-\d+)\-[\w\d]+\-\d\w\-\d+',
        taxon_name => 'human',
        sample_attributes => [qw/ tissue_desc /],# tests array
        individual_attributes => { # tests hash
            gender => { valid_values => [qw/ male female /], }, # tests getting meta from individual
            individual_common_name => {
                calculate_from => [qw/ _individual_name /],
                calculate => sub{ my $_individual_name = shift; $_individual_name =~ s/^TEST\-//i; return $_individual_name; },
            },
        },
    });
my $meta = Genome::Sample::Command::Import::Test->__meta__;
ok($meta, 'class meta for command to import test namespace sample');
my $nomenclature_property = $meta->property_meta_for_name('nomenclature');
is($nomenclature_property->default_value, 'TeSt', 'set value on nomenclature property');
is_deeply([sort Genome::Sample::Command::Import->property_names_for_namespace_importer('Test')], [qw/ gender tissue_desc /], 'property names for namespace importer');
is(Genome::Sample::Command::Import->namespace_for_nomenclature('TeSt'), 'Test', 'namespace for nomenclature');

# attr names
my $sample_attribute_names_property = $meta->property_meta_for_name('_sample_attribute_names');
is_deeply($sample_attribute_names_property->default_value, [qw/ tissue_desc /], 'set value on _sample_attribute_names property');
my $individual_attribute_names_property = $meta->property_meta_for_name('_individual_attribute_names');
is_deeply($individual_attribute_names_property->default_value, [qw/ gender individual_common_name /], 'set value on _individual_attribute_names property');

# property meta
my $individual_meta = Genome::Individual->__meta__;
my $individual_gender_property = $individual_meta->property_meta_for_name('gender');
my $gender_property = $meta->property_meta_for_name('gender');
is($individual_gender_property->{is}, $gender_property->{is}, 'gender type (is)');
is($individual_gender_property->doc, $gender_property->doc, 'gender doc');
is_deeply($gender_property->valid_values, [qw/ male female /], 'gender valid_values');

my $patient_name = 'TeSt-1111';
my $name = $patient_name.'-A1A-1A-1111';
my %import_params = (
    gender => 'female',
    tissue_desc => 'blood',
    extraction_type => 'genomic dna',
    sample_attributes => [qw/ age_baseline=50 mi_baseline=11.45 /],
    individual_attributes => [ 'race=oompa loompa' ],
);
my $import = Genome::Sample::Command::Import::Test->create(
    name => $name,
    %import_params,
);
ok($import, 'create');
ok($import->execute, 'execute');

is($import->_individual->taxon->name, 'human', 'taxon name');
is($import->_individual->name, $patient_name, 'patient name');
is($import->_individual->upn, $patient_name, 'patient name');
is($import->_individual->nomenclature, 'TeSt', 'patient nomenclature');
is($import->_individual->gender, 'female', 'patient gender');
is($import->_individual->common_name, '1111', 'patient common_name');
is(eval{ $import->_individual->attributes(attribute_label => 'race')->attribute_value; }, 'oompa loompa', 'patient race');
is($import->_sample->name, $name, 'sample name');
is($import->_sample->nomenclature, 'TeSt', 'sample nomenclature');
is($import->_sample->extraction_label, $name, 'sample extraction label');
is($import->_sample->extraction_type, 'genomic dna', 'sample extraction type');
is($import->_sample->tissue_desc, 'blood', 'sample tissue');
is(eval{ $import->_sample->attributes(attribute_label => 'age_baseline')->attribute_value; }, 50, 'sample age_baseline');
is(eval{ $import->_sample->attributes(attribute_label => 'mi_baseline')->attribute_value; }, 11.45, 'sample mi_baseline');
is_deeply($import->_sample->source, $import->_individual, 'sample source');
my $library_name = $name.'-extlibs';
is($import->_library->name, $library_name, 'library name');
is_deeply($import->_library->sample, $import->_sample, 'library sample');
is(@{$import->_created_objects}, 3, 'created 3 objects');

# Fail - invalid name (nomenclature)
$import = Genome::Sample::Command::Import::Test->create(
    name => 'TEST-1111-A1A-1A-1111',
    %import_params,
);
ok($import, 'create');
ok(!$import->execute, 'execute fails b/c of invalid nomenclature');
is($import->error_message, "Name (TEST-1111-A1A-1A-1111) is invalid!", 'correct error message');

# Fail - invalid name (sample)
$import = Genome::Sample::Command::Import::Test->create(
    name => 'TeSt-1111-A1?A-1A-1111',
    %import_params,
);
ok($import, 'create');
ok(!$import->execute, 'execute fails b/c of invalid sample name');
is($import->error_message, "Name (TeSt-1111-A1?A-1A-1111) is invalid!", 'correct error message');

# Fail - invalid name (individual)
$import = Genome::Sample::Command::Import::Test->create(
    name => 'TeSt-1A11-A1A-1A-1111',
    %import_params,
);
ok($import, 'create');
ok(!$import->execute, 'execute fails b/c of invalid individual name');
is($import->error_message, "Name (TeSt-1A11-A1A-1A-1111) is invalid!", 'correct error message');

# Fail - invalid sample attrs
my %invalid_import_params = %import_params;
$invalid_import_params{sample_attributes} = [qw/ age_baseline= /];
$import = Genome::Sample::Command::Import::Test->create(
    name => $name,
    %invalid_import_params,
);
ok($import, 'create');
ok(!$import->execute, 'execute fails b/c of invalid sample attributes');
is($import->error_message, "Sample attribute label (age_baseline) does not have a value!", 'correct error message');

# Fail - invalid individual attrs
%invalid_import_params = %import_params;
$invalid_import_params{individual_attributes} = [qw/ eye_color= /];
$import = Genome::Sample::Command::Import::Test->create(
    name => $name,
    %invalid_import_params,
);
ok($import, 'create');
ok(!$import->execute, 'execute fails b/c of invalid individual attributes');
is($import->error_message, "Individual attribute label (eye_color) does not have a value!", 'correct error message');

done_testing();
