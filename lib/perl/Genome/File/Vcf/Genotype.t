#!/gsc/bin/perl

BEGIN { 
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

use strict;
use warnings;

use above "Genome";
use Test::More;

my $pkg = "Genome::File::Vcf::Genotype";
use_ok($pkg);

my $wild_type = $pkg->new("A", \("T"), "0/0");
ok($wild_type->has_wildtype, "Wild type is wild type");
ok(!$wild_type->has_variant, "Wild type is not variant");
ok($wild_type->is_homozygous, "Wild type is homozygous");
ok(!$wild_type->is_heterozygous, "Wild type is not heterozygous");

my $hom_variant = $pkg->new("A", \("T"), "1/1");
ok($hom_variant->is_homozygous, "Hom is homozygous");
ok(!$hom_variant->is_heterozygous, "Hom is not heterozygous");
ok(!$hom_variant->has_wildtype, "Hom is not wildtype");
ok($hom_variant->has_variant, "Hom is variant");

my $het_variant = $pkg->new("A", \("T"), "0/1");
ok(!$het_variant->is_homozygous, "Het is not homozygous");
ok($het_variant->is_heterozygous, "Het is heterozygous");
ok($het_variant->has_wildtype, "Het is wildtype");
ok($het_variant->has_variant, "Het variant is variant");
my @alleles_from_het = $het_variant->get_alleles;
is_deeply(\@alleles_from_het, [0,1], "Correctly got alleles");

my @multi_alts = ("T", "C");
my $het2 = $pkg->new("A", \@multi_alts, "1/2");
ok(!$het2->is_homozygous, "Het2 is not homozygous");
ok($het2->is_heterozygous, "Het2 is heterozygous");
ok(!$het2->has_wildtype, "Het2 is not wildtype");
ok($het2->has_variant, "Het2 is variant");
ok(!$het2->is_phased, "Het2 is not phased");

my $missing = Genome::File::Vcf::Genotype->new("A", \("T"), ".");
ok($missing->is_missing, "Missing is missing");
ok(!$missing->is_homozygous, "Missing is not homozygous");
ok(!$missing->is_heterozygous, "Missing is not heterozygous");
ok(!$missing->has_wildtype, "Missing is not wildtype");
ok(!$missing->has_variant, "Missing is not variant");
is($missing->ploidy, 1, "Missing is haploid");

my $phased = Genome::File::Vcf::Genotype->new("A", \("T"), "0|0");
ok($phased->is_phased, "Phased genotype is phased");
my @alleles_from_phased = $phased->get_alleles;
is_deeply(\@alleles_from_phased, [0,0], "Correctly got alleles from phased");
is($phased->ploidy, 2, "Phased genotype is diploid");

my $triploid = Genome::File::Vcf::Genotype->new("A", \("T"), "0/0/1");
is($triploid->ploidy, 3, "Triploid genotype parsed ok");
is_deeply([$triploid->get_alleles], [0, 0, 1], "Got triploid alleles correctly");

eval {
    my $non_numeric = Genome::File::Vcf::Genotype->new("A", \("T"), "A/C");
};
ok($@, "Non-numeric genotypes cause errors");

done_testing;
