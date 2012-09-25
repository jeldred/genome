package Genome::Model::MutationalSignificance;

use strict;
use warnings;

use Genome;

my @has_param;
my %module_input_exceptions;
my %parallel_by;

my $DONT_USE = "don't use this";

BEGIN {
    %parallel_by = (
        "Genome::Model::MutationalSignificance::Command::CreateMafFile" => "somatic_variation_build",
    );
    %module_input_exceptions = (
        'Genome::Model::MutationalSignificance::Command::MergeMafFiles' => {
            maf_files => ["Genome::Model::MutationalSignificance::Command::CreateMafFile", 'maf_file'],
            maf_path => ["input connector", "merged_maf_path"],
        },
        'Genome::Model::MutationalSignificance::Command::CreateMafFile' => {
            somatic_variation_build => ['input connector', 'somatic_variation_builds'],
            output_dir => ['input connector', 'create_maf_output_dir'],
            cosmic_dir => ["input connector", 'cosmic_dir'],
            review_file_dir => ["input connector", 'review_file_dir'],
        },
        'Genome::Model::MutationalSignificance::Command::CreateROI' => {
            annotation_build => ['input connector', 'annotation_build'], #input to model, not param
        },
        'Genome::Model::MutationalSignificance::Command::CreateBamList' => {
            somatic_variation_builds => ['input connector', 'somatic_variation_builds'],
            bam_list => ["input connector", "bam_list"],
        },
        'Genome::Model::MutationalSignificance::Command::PlayMusic' => {
            bam_list => ["Genome::Model::MutationalSignificance::Command::CreateBamList", "bam_list"],
            maf_file => ["Genome::Model::MutationalSignificance::Command::MergeMafFiles", "maf_path"],
            roi_file => ["Genome::Model::MutationalSignificance::Command::CreateROI", "roi_path"],
            reference_sequence => ['input connector', 'reference_sequence'],
            output_dir => ['input connector', 'output_dir'],
            log_directory => ['input connector', 'log_directory'],
            music_build => ['input connector', 'music_build'],
            somatic_variation_builds => ['input connector', 'somatic_variation_builds'],
        },
        'Genome::Model::MutationalSignificance::Command::CompileValidationList' => {
            significantly_mutated_gene_list => $DONT_USE,
            tiers_to_use => ['input connector', "tiers_to_use"],
            significant_variant_list => ['input connector', 'significant_variant_list'],
            somatic_variation_builds => ['input connector', 'somatic_variation_builds'],
            reference_sequence_build => ['input connector', 'reference_sequence_build'],
            exon_bed => ["Genome::Model::MutationalSignificance::Command::CreateROI", "roi_path"],
            regions_of_interest => ['input connector', 'regions_of_interest'],
        },
    );
    my %additional_params = (
        play_music => {
            is => 'Boolean',
            default => 0,
            doc => "Whether to run Play Music as a part of determining which mutations are significant",
        },
    );
    my %seen;
    my @modules = keys %module_input_exceptions;
    foreach my $module (@modules) {
        my $module_meta = UR::Object::Type->get($module);
        my @p = $module_meta->properties;
        for my $p (@p) {
            if ($p->can("is_input") and $p->is_input){
                my $name = $p->property_name;
                unless ($seen{$p->property_name} or $module_input_exceptions{$module}{$name}) {
                    my %data = %{ UR::Util::deep_copy($p) };
                    for my $key (keys %data) {
                        delete $data{$key} if $key =~ /^_/;
                    }
                    delete $data{id};
                    delete $data{db_committed};
                    delete $data{class_name};
                    delete $data{is_input};
                    $data{is_param} = 1;
                    push @has_param, $name, \%data;
                    $seen{$name} = 1;
                }
            }
        }    
    }
    foreach my $param (keys %additional_params) {
        push @has_param, $param, $additional_params{$param};
    }
}

class Genome::Model::MutationalSignificance {
    is        => 'Genome::Model',
    has => [
        processing_profile => { is => 'Genome::ProcessingProfile', id_by => 'processing_profile_id', },
    ],
    has_input => [
        somatic_variation_models => {
            is    => 'Genome::Model::SomaticVariation',
            is_many => 1,
            doc => 'somatic variation models to evaluate',
        },
        annotation_build => {
            is => 'Genome::Model::Build::ImportedAnnotation',
            doc => 'annotation to use for roi file',
        },
        review_file_dir => {
            is => 'UR::Value::DirectoryPath',
            is_optional => 1,
        },
        regions_of_interest => {
            is => 'Genome::FeatureList',
            is_many => 1,
            doc => 'Lists of regions to include in validation',
        },
    ],
    has_param => \@has_param,
};

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
TO DO
EOS
}

sub help_detail_for_create_profile {
    return <<EOS
  TO DO
EOS
}

sub help_manual_for_define_model {
    return <<EOS
TO DO
EOS
}

sub _resolve_workflow_for_build {

    # This is called by Genome::Model::Build::start()
    # Returns a Workflow::Operation
    # By default, builds this from stages(), but can be overridden for custom workflow.
    my $self = shift;
$self->warning_message('The logic for building a MuSiC model is not yet functional.  Contact Allison Regier');
    my $build = shift;
    my $lsf_queue = shift; # TODO: the workflow shouldn't need this yet
    my $lsf_project = shift;
     
    my @input_properties;    

    if (!defined $lsf_queue || $lsf_queue eq '' || $lsf_queue eq 'inline') {
        $lsf_queue = 'apipe';
    }
    if (!defined $lsf_project || $lsf_project eq '') {
        $lsf_project = 'build' . $build->id;
    }
    my $meta = $self->__meta__;
    my $build_meta = $build->__meta__;
    my @input_params = $build_meta->properties(        
        class_name => $build->class,        
        is_input => 1,
    );

    map {my $name = $_->property_name; my @values = $build->$name; if (defined $values[0]){push @input_properties,   $name} }@input_params;

    @input_params = $meta->properties(
        class_name => $self->class,
        is_param => 1,
    );

    map {my $name = $_->property_name; my @values =  $self->$name; if (defined $values[0]){push @input_properties,   $name} }@input_params;

    push @input_properties, "output_dir";
    push @input_properties, "music_build";
    push @input_properties, "clinical_data_file";
    push @input_properties, "merged_maf_path";
    push @input_properties, "create_maf_output_dir";
    push @input_properties, "bam_list";
    push @input_properties, "reference_sequence";
    push @input_properties, "reference_sequence_build";
    push @input_properties, "log_directory";
    push @input_properties, "significant_variant_list";

    my @output_properties;
    if ($self->play_music) {
        @output_properties = ('smg_result','pathscan_result','mr_result','pfam_result',              
        'proximity_result', 'cosmic_result','cct_result');
    }
    else {
        @output_properties = ('roi_path', 'maf_path', 'bam_list');
    }
    push @output_properties, "significant_variant_list";

    my $workflow = Workflow::Model->create(
        name => $build->workflow_name,
        input_properties => \@input_properties,
        output_properties => \@output_properties,
    );

    my $log_directory = $build->log_directory;
    $workflow->log_dir($log_directory);
 
    my $output_connector = $workflow->get_output_connector;

    # For now, just get the ultra-high confidence variants.
    # TODO: figure out how to add in the manual review ones

=cut
    #Create clinical data file
    $command_module = 'Genome::Model::MutationalSignificance::Command::CreateClinicalData',
    my $clinical_data_operation = $workflow->add_operation(
        name => $command_module,
        operation_type => Workflow::OperationType::Command->create(
            command_class_name => $command_module,
        )
    );

    $link = $workflow->add_link(
        left_operation => $input_connector,
        left_property => 'clinical_data_file',
        right_operation => $clinical_data_operation,
        right_property => 'clinical_data_file',
    );
=cut

    my @commands = ('Genome::Model::MutationalSignificance::Command::CreateMafFile','Genome::Model::MutationalSignificance::Command::MergeMafFiles','Genome::Model::MutationalSignificance::Command::CreateROI','Genome::Model::MutationalSignificance::Command::CreateBamList','Genome::Model::MutationalSignificance::Command::CompileValidationList');

    for my $command_name (@commands) {
        $workflow = $self->_append_command_to_workflow($command_name,
            $workflow, $lsf_project, $lsf_queue) or return;
    }
    my $link;
    if ($self->play_music) {

        $workflow = $self->_append_command_to_workflow("Genome::Model::MutationalSignificance::Command::PlayMusic", $workflow, $lsf_project, $lsf_queue) or return;
        $link = $workflow->add_link(
            left_operation => $self->_get_operation_for_module_name('Genome::Model::MutationalSignificance::Command::PlayMusic',
                $workflow),
            left_property => 'proximity_result',
            right_operation => $output_connector,
            right_property => 'proximity_result',
        );
        $link = $workflow->add_link(
            left_operation => $self->_get_operation_for_module_name('Genome::Model::MutationalSignificance::Command::PlayMusic',
                $workflow),
            left_property => 'pfam_result',
            right_operation => $output_connector,
            right_property => 'pfam_result',
        );
        $link = $workflow->add_link(
            left_operation => $self->_get_operation_for_module_name('Genome::Model::MutationalSignificance::Command::PlayMusic',
                $workflow),
            left_property => 'mr_result',
            right_operation => $output_connector,
            right_property => 'mr_result',
        );
        $link = $workflow->add_link(
            left_operation => $self->_get_operation_for_module_name('Genome::Model::MutationalSignificance::Command::PlayMusic',
                $workflow),
            left_property => 'pathscan_result',
            right_operation => $output_connector,
            right_property => 'pathscan_result',
        );
        $link = $workflow->add_link(
            left_operation => $self->_get_operation_for_module_name('Genome::Model::MutationalSignificance::Command::PlayMusic',
                $workflow),
            left_property => 'smg_result',
            right_operation => $output_connector,
            right_property => 'smg_result',
        );
        $link = $workflow->add_link(
            left_operation => $self->_get_operation_for_module_name('Genome::Model::MutationalSignificance::Command::PlayMusic',
                $workflow),
            left_property => 'cosmic_result',
            right_operation => $output_connector,
            right_property => 'cosmic_result',
        );

        $link = $workflow->add_link(
            left_operation => $self->_get_operation_for_module_name('Genome::Model::MutationalSignificance::Command::PlayMusic',
                $workflow),
            left_property => 'cct_result',
            right_operation => $output_connector,
            right_property => 'cct_result',
        );
        $link = $workflow->add_link(
            left_operation => $self->_get_operation_for_module_name('Genome::Model::MutationalSignificance::Command::PlayMusic',
                $workflow),
            left_property => 'smg_result',
            right_operation => $self->_get_operation_for_module_name("Genome::Model::MutationalSignificance::Command::CompileValidationList",
                $workflow),
            right_property => "significantly_mutated_gene_list",
        );
    }
    else {
        $link = $workflow->add_link(
            left_operation => $self->_get_operation_for_module_name('Genome::Model::MutationalSignificance::Command::CreateBamList', $workflow),
            left_property => 'bam_list',
            right_operation => $output_connector,
            right_property => 'bam_list',
        );
        $link = $workflow->add_link(
            left_operation => $self->_get_operation_for_module_name('Genome::Model::MutationalSignificance::Command::MergeMafFiles', $workflow),
            left_property => 'maf_path',
            right_operation => $output_connector,
            right_property => 'maf_path',
        );
        $link = $workflow->add_link(
            left_operation => $self->_get_operation_for_module_name('Genome::Model::MutationalSignificance::Command::CreateROI', $workflow),
            left_property => 'roi_path',
            right_operation => $output_connector,
            right_property => 'roi_path',
        );
    }
    $link = $workflow->add_link(
        left_operation => $self->_get_operation_for_module_name('Genome::Model::MutationalSignificance::Command::CompileValidationList', $workflow),
        left_property => 'significant_variant_list',
        right_operation => $output_connector,
        right_property => 'significant_variant_list',
    );

    my @errors = $workflow->validate;
    
    unless ($workflow->is_valid) {
        my $message = join("\n", "Workflow is not valid:", @errors);
        $self->error_message($message);
        return;
    }

    return $workflow;
}

sub _get_operation_for_module_name {
    my $self = shift;
    my $operation_name = shift;
    my $workflow = shift;

    foreach my $op ($workflow->operations) {
        if ($op->name eq $operation_name) {
            return $op;
        }
    }
    return;
}

sub _append_command_to_workflow {
    my $self = shift;
    my $command_module = shift;
    my $workflow = shift;
    my $lsf_project = shift;
    my $lsf_queue = shift;
    my $command_meta = $command_module->__meta__;
    my $operation_name = $command_module;
    my $operation;
    if ($parallel_by{$operation_name}) {
        $operation = $workflow->add_operation(
            name => $operation_name,
            operation_type => Workflow::OperationType::Command->create(
                command_class_name => $command_module,
            ),
            parallel_by => $parallel_by{$operation_name},
        );
    }
    else {
        $operation = $workflow->add_operation(
            name => $operation_name,
            operation_type => Workflow::OperationType::Command->create(
                command_class_name => $command_module,
            )
        );
    }
    $operation->operation_type->lsf_queue($lsf_queue);
    $operation->operation_type->lsf_project($lsf_project);
    for my $property ($command_meta->_legacy_properties()) {
        next unless exists $property->{is_input} and $property->{is_input};
        my $property_name = $property->property_name;
        my $property_def = $module_input_exceptions{$operation_name}{$property_name};
        if (defined $property_def and $property_def eq $DONT_USE) {
            $property_def = undef;
        }
        if (!$property_def) {
            if (grep {/^$property_name$/} @{$workflow->operation_type->input_properties}) {
                $property_def = [$workflow->get_input_connector->name, $property_name];
            }
        }
        if(!$property->is_optional) {
            if (not defined $property_def) {
                die ("Non-optional property ".$property->property_name." is not provided\n");
            }
            $workflow = $self->_add_link($property_name, $property_def, $operation, $workflow);
        }
        elsif (defined $property_def) { 
            if ($property_def->[0] eq $workflow->get_input_connector->name) {
                if (grep {/^$property_name$/} @{$workflow->operation_type->input_properties}) {
                    $workflow = $self->_add_link($property_name, $property_def, $operation, $workflow);
                }
            }
            else {
                $workflow = $self->_add_link($property_name, $property_def, $operation, $workflow);
            }
        }
    }
    return $workflow;
}

sub _add_link {
    my $self = shift;
    my $property_name = shift;
    my $property_def = shift;
    my $operation = shift;
    my $workflow = shift;

    my $from_op = $self->_get_operation_for_module_name($property_def->[0], $workflow);
    if (!$from_op) {
        print "looking for left operation ".$property_def->[0]."\n";
        print "left property ".$property_def->[1]."\n";
        print "right operation ".$operation->name."\n";
        print "right property ".$property_name."\n";
        die ("Didn't get a from operation for the link\n");
    }
    my $link = $workflow->add_link(
        left_operation => $from_op,
        left_property => $property_def->[1],
        right_operation => $operation,
        right_property => $property_name,
    );
    return $workflow;
}

sub map_workflow_inputs {
    my $self = shift;
    my $build = shift;

    my %inputs;
 
    my $meta = $self->__meta__;
    my $build_meta = $build->__meta__;
    my @all_params = $build_meta->properties(
        class_name => $build->class,
        is_input => 1,
    );
    
    map {my $name = $_->property_name; my @values = $build->$name; if (defined $values[0]){my $value; if ($_->is_many){$value = \@values} else{$value = $values[0]} $inputs{$name} = $value}} @all_params;
    
    @all_params = $meta->properties(
        class_name => $self->class,
        is_param => 1,
    );

    map {my $name = $_->property_name; my @values = $self->$name; if (defined $values[0]){my $value; if ($_->is_many){$value = \@values} else{$value = $values[0]} $inputs{$name} = $value}} @all_params;
 
    my @builds = $build->somatic_variation_builds;
    my $base_dir = $build->data_directory;

    $inputs{review_file_dir} = $build->review_file_dir;
    $inputs{music_build} = $build;
    $inputs{log_directory} = $build->log_directory;
    $inputs{merged_maf_path} = $base_dir."/final.maf";
    $inputs{create_maf_output_dir} = $base_dir;
    $inputs{reference_sequence} = $builds[0]->reference_sequence_build->fasta_file;
    $inputs{reference_sequence_build} = $builds[0]->reference_sequence_build;
    $inputs{output_dir} = $base_dir;
    $inputs{bam_list} = $base_dir."/bam_list.txt";
    $inputs{clinical_data_file} = $base_dir."/clinical_data.txt";
    $inputs{significant_variant_list} = $base_dir."/significant_variant_list";

    return %inputs;
}

1;
