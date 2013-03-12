#!/usr/bin/env genome-perl

#Written by Malachi Griffith

use strict;
use warnings;
use File::Basename;
use Cwd 'abs_path';

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
    $ENV{NO_LSF} = 1;
};

use Data::Dumper;
use above "Genome";
use Test::More tests=>16; 

#Test with GENOME_QUERY_POSTGRES=1 to use postgres database instead of Oracle

#This test performs a series of tests that cover common analysis use cases for command line usage of Genome listers, etc.
#If this test breaks it will most likely be because of one of the following.  Figure out which is the case and update appropriately:
#1.) If a code change is pushed that breaks one of these examples because of a desired improvement to the UI, please update the appropriate command below
#2.) Since many of these involve querying the database, if this test breaks it may simply require updating the test results 

#Create a temp dir for results
my $temp_dir = Genome::Sys->create_temp_directory();
ok($temp_dir, "created temp directory: $temp_dir");

#Define the test where expected results are stored
my $expected_output_dir = $ENV{"GENOME_TEST_INPUTS"} . "Genome-Model-ClinSeq-Command-TestGenomeCommands/2013-03-12/";
ok(-e $expected_output_dir, "Found test dir: $expected_output_dir") or die;

#CLIN-SEQ UPDATE-ANALYSIS
#Test clin-seq update-analysis - make sure the following command correctly obtains three expected samples (this has been broken in the past)
#genome model clin-seq update-analysis --individual='H_KA-306905' --samples='id in [2878747496,2878747497,2879495575]' --display-samples
my $cmd = "genome model clin-seq update-analysis --individual='H_KA-306905' --samples='id in [2878747496,2878747497,2879495575]' --display-samples";
print "\n$cmd\n";
$cmd .= " 2>$temp_dir/genome-model-clinseq-update-analysis.out";
my $r = Genome::Sys->shellcmd(cmd => $cmd);
ok ($r, "tested genome model clin-seq update-analysis");

#GENOME SAMPLE LIST
#genome sample list --filter 'name like "H_NJ-HCC1395-HCC1395%"' --show id,name,common_name,tissue_desc,extraction_type,extraction_label
$cmd = "genome sample list --filter \'name like \"H_NJ-HCC1395-HCC1395%\"\' --show id,name,common_name,tissue_desc,extraction_type,extraction_label";
print "\n$cmd\n";
$cmd .= " 1>$temp_dir/genome-sample-list1.out 2>$temp_dir/genome-sample-list1.err";
$r = Genome::Sys->shellcmd(cmd => $cmd);
ok ($r, "tested genome sample list1");

#GENOME MODEL CLIN-SEQ LIST
#genome model clin-seq list --filter model_groups.id=66909 --show wgs_model.last_succeeded_build.id,wgs_model.last_succeeded_build.data_directory
$cmd = "genome model clin-seq list --filter model_groups.id=66909 --show wgs_model.last_succeeded_build.id,wgs_model.last_succeeded_build.data_directory";
print "\n$cmd\n";
$cmd .= " 1>$temp_dir/genome-model-clinseq-list1.out 2>$temp_dir/genome-model-clinseq-list1.err";
$r = Genome::Sys->shellcmd(cmd => $cmd);
ok ($r, "tested genome model clin-seq list1");

#genome model clin-seq list --filter model_groups.id=66909 --style=tsv --show id,name,wgs_model,tumor_rnaseq_model,subject.common_name
$cmd = "genome model clin-seq list --filter model_groups.id=66909 --style=tsv --show id,name,wgs_model,tumor_rnaseq_model,subject.common_name";
print "\n$cmd\n";
$cmd .= " 1>$temp_dir/genome-model-clinseq-list2.out 2>$temp_dir/genome-model-clinseq-list2.err";
$r = Genome::Sys->shellcmd(cmd => $cmd);
ok ($r, "tested genome model clin-seq list2");

#genome model clin-seq list --style csv --filter model_groups.id=66909 --show wgs_model.last_succeeded_build.normal_build.subject.name,wgs_model.last_succeeded_build.normal_build.whole_rmdup_bam_file
$cmd = "genome model clin-seq list --style csv --filter model_groups.id=66909 --show wgs_model.last_succeeded_build.normal_build.subject.name,wgs_model.last_succeeded_build.normal_build.whole_rmdup_bam_file";
print "\n$cmd\n";
$cmd .= " 1>$temp_dir/genome-model-clinseq-list3.out 2>$temp_dir/genome-model-clinseq-list3.err";
$r = Genome::Sys->shellcmd(cmd => $cmd);
ok ($r, "tested genome model clin-seq list3");

#GENOME MODEL SOMATIC-VARIATION LIST
#genome model somatic-variation list --filter group_ids=50569 --show subject.patient_common_name,subject.name,id
$cmd = "genome model somatic-variation list --filter group_ids=50569 --show subject.patient_common_name,subject.name,id";
print "\n$cmd\n";
$cmd .= " 1>$temp_dir/genome-model-somatic-variation-list1.out 2>$temp_dir/genome-model-somatic-variation-list1.err";
$r = Genome::Sys->shellcmd(cmd => $cmd);
ok ($r, "tested genome model somatic-variation list1");

#genome model somatic-variation list --filter group_ids=50569 --show subject.name,last_succeeded_build_directory  --noheaders
$cmd = "genome model somatic-variation list --filter group_ids=50569 --show subject.name,last_succeeded_build_directory  --noheaders";
print "\n$cmd\n";
$cmd .= " 1>$temp_dir/genome-model-somatic-variation-list2.out 2>$temp_dir/genome-model-somatic-variation-list2.err";
$r = Genome::Sys->shellcmd(cmd => $cmd);
ok ($r, "tested genome model somatic-variation list2");

#genome model somatic-variation list 'model_groups.id=50569' --show 'tumor_model.subject.name,tumor_model.subject.common_name' --style=csv
$cmd = "genome model somatic-variation list 'model_groups.id=50569' --show 'tumor_model.subject.name,tumor_model.subject.common_name' --style=csv";
print "\n$cmd\n";
$cmd .= " 1>$temp_dir/genome-model-somatic-variation-list3.out 2>$temp_dir/genome-model-somatic-variation-list3.err";
$r = Genome::Sys->shellcmd(cmd => $cmd);
ok ($r, "tested genome model somatic-variation list3");

#GENOME MODEL RNA-SEQ LIST
#genome model rna-seq list --filter 'genome_model_id=2888673504'
$cmd = "genome model rna-seq list --filter 'genome_model_id=2888673504'";
print "\n$cmd\n";
$cmd .= " 1>$temp_dir/genome-model-rnaseq-list1.out 2>$temp_dir/genome-model-rnaseq-list1.err";
$r = Genome::Sys->shellcmd(cmd => $cmd);
ok ($r, "tested genome model rna-seq list1");

#genome model rna-seq list group_ids=50554 --show id,name,processing_profile,last_succeeded_build.id,last_succeeded_build.alignment_result.bam_file --style tsv
$cmd = "genome model rna-seq list group_ids=50554 --show id,name,processing_profile,last_succeeded_build.id,last_succeeded_build.alignment_result.bam_file --style tsv";
print "\n$cmd\n";
$cmd .= " 1>$temp_dir/genome-model-rnaseq-list2.out 2>$temp_dir/genome-model-rnaseq-list2.err";
$r = Genome::Sys->shellcmd(cmd => $cmd);
ok ($r, "tested genome model rna-seq list2");


#GENOME INSTRUMENT-DATA LIST SOLEXA
#genome instrument-data list solexa --show id,flow_cell_id,lane,index_sequence,sample_name,library_name,clusters,read_length,bam_path --filter flow_cell_id=D1VCPACXX
$cmd = "genome instrument-data list solexa --show id,flow_cell_id,lane,index_sequence,sample_name,library_name,clusters,read_length,bam_path --filter flow_cell_id=D1VCPACXX";
print "\n$cmd\n";
$cmd .= " 1>$temp_dir/genome-instrument-data-list1.out 2>$temp_dir/genome-instrument-data-list1.err";
$r = Genome::Sys->shellcmd(cmd => $cmd);
ok ($r, "tested genome instrument-data list1");

#genome instrument-data list solexa --filter sample_name='H_NE-00264-264-03-A5-D1'
$cmd = "genome instrument-data list solexa --filter sample_name=\'H_NE-00264-264-03-A5-D1\'";
print "\n$cmd\n";
$cmd .= " 1>$temp_dir/genome-instrument-data-list2.out 2>$temp_dir/genome-instrument-data-list2.err";
$r = Genome::Sys->shellcmd(cmd => $cmd);
ok ($r, "tested genome instrument-data list2");

#GENOME MODEL-GROUP MEMBER LIST
#genome model-group member list --filter 'model_group_id=66909' --show model.wgs_model.id,model.wgs_model.subject.patient_common_name,model.last_succeeded_build,model.last_succeeded_build.data_directory 
$cmd = "genome model-group member list --filter 'model_group_id=66909' --show model.wgs_model.id,model.wgs_model.subject.patient_common_name,model.last_succeeded_build,model.last_succeeded_build.data_directory";
print "\n$cmd\n";
$cmd .= " 1>$temp_dir/genome-model-group-member-list1.out 2>$temp_dir/genome-model-group-member-list1.err";
$r = Genome::Sys->shellcmd(cmd => $cmd);
ok ($r, "tested genome model-group member list1");

#The first time we run this we will need to save our initial result to diff against
#Genome::Sys->shellcmd(cmd => "cp -r -L $temp_dir/* $expected_output_dir");


#Perform a diff between the stored results and those generated by this test
my @diff = `diff -r -x '*.err' $expected_output_dir $temp_dir`;
ok(@diff == 0, "Found only expected number of differences between expected results and test results")
or do { 
  diag("expected: $expected_output_dir\nactual: $temp_dir\n");
  diag("differences are:");
  diag(@diff);
  my $diff_line_count = scalar(@diff);
  print "\n\nFound $diff_line_count differing lines\n\n";
  Genome::Sys->shellcmd(cmd => "rm -fr /tmp/last-test-genome-commands-result/");
  Genome::Sys->shellcmd(cmd => "mv $temp_dir /tmp/last-test-genome-commands-result");
};



