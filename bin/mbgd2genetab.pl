#!/usr/bin/perl -s

use LWP::Simple;
use JSON;

$MBGDAPI = "https://mbgdapi.nibb.ac.jp";

@species = @ARGV;

if ($out eq 'genetab') {
	&get_genetab(@species);
}
if ($out eq 'proteinseq') {
	&get_proteinseq(@species);
}

sub get_genetab {
	my(@species) = @_;
	foreach $sp (@species) {
		my($genome) = &get_data($sp, 'genome');
		$genome = $genome->[0];
	
		print "##Genome\tsp:$genome->{sp}";
	       	print "\tabbrev:$genome->{abbrev}" if ($genome->{abbrev});;
	       	print "\torgname:$genome->{orgname}" if ($genome->{orgname});;
	       	print "\tstrain:$genome->{strain}" if ($genome->{strain});;
		print "\n";
	
		my($chromInfo) = &get_data($sp, 'chromosome');
		my($geneInfo) = &get_data($sp, 'gene');
		my(@chroms);
	
		foreach $c ( @{$chromInfo} ) {
			push(@chroms, $c);
		}
		@chroms = sort {$a->{seqno} <=> $b->{seqno}} @chroms;
		my(@genes);
	
		foreach $g ( @{$geneInfo} ) {
			if ($g->{type} eq 'CDS') {
				if (! $g->{aalen}) {
					$g->{aalen} = int( (($g->{to1} - 3) - $g->{from1} + 1) / 3 );
				}
				$g->{pos} = ($g->{from1} + ($g->{to1}-3)) / 2;
				push(@{$genes[$g->{seqno}-1]}, $g);
			}
		}
		foreach $c (@chroms) {
			print "##Chromosome\t";
			print "name:$c->{name}" if ($c->{name});
			print "\tseq_length:$c->{seq_length}" if ($c->{seq_length});
			print "\n";
			foreach $g (@{ $genes[$c->{seqno} - 1] }) {
				print join("\t", $g->{sp}, $g->{name}, $g->{from1}, $g->{to1}, $g->{aalen}, $g->{pos}, $g->{dir}), "\n"
			}
		}
	
	}
}
sub get_proteinseq {
	my(@species) = @_;
	foreach $sp (@species) {
		$pseq = &get_data($sp, 'proteinseq');
		foreach $g ( @{$pseq} ) {
			print ">$g->{sp}:$g->{name} $g->{descr}\n";
			print "$g->{seq}\n";
		}
	}
}
sub get_data {
	my($sp, $type) = @_;
	$content = get("$MBGDAPI/$type/$sp");
	decode_json($content);
}
