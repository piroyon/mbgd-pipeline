#!/usr/bin/perl -s

use LWP::Simple;
use JSON;
use File::Path qw( make_path remove_tree );

$MBGDAPI = "https://mbgdapi.nibb.ac.jp";

@species = @ARGV;

$tmpdir = "tmp_mbgd_genetab" if (! $tmpdir);

$outname = "genomes";

make_path($tmpdir);

$hash_protseq = &get_proteinseq(@species);
&output_all(@species);
foreach $sp (@species) {
	foreach $suffix ("genetab", "faa") {
		my($infile) = "$tmpdir/$sp.$suffix";
		my($outfile) = "$outname.$suffix";
		open(F, "$infile") || die "Can't open $infile\n";
		open(O, ">$outfile") || die "Can't open $outfile for output\n";
		while (<F>) {
			print O $_;
		}
		close(F); close(O);
		if (! $keep_tmp) {
			unlink "$tmpdir/$sp.$suffix";
		}
	}
}
remove_tree($tmpdir) if (! $keep_tmp);

sub output_all {
	#output genetab and protseq
	my(@species) = @_;
	foreach $sp (@species) {
		my($genome) = &get_data($sp, 'genome');
		$genome = $genome->[0];

		my($outname) = "$tmpdir/$sp";
		open(GENETAB, ">$outname.genetab") || die "Can't open genetab for output\n";

		print GENETAB "##Genome\tsp:$genome->{sp}";
	       	print GENETAB "\tabbrev:$genome->{abbrev}" if ($genome->{abbrev});;
	       	print GENETAB "\torgname:$genome->{orgname}" if ($genome->{orgname});;
	       	print GENETAB "\tstrain:$genome->{strain}" if ($genome->{strain});;
		print GENETAB "\n";
	
		my($chromInfo) = &get_data($sp, 'chromosome');
		my($geneInfo) = &get_data($sp, 'gene');
		my(@chroms);
	
		foreach $c ( @{$chromInfo} ) {
			push(@chroms, $c);
		}
		@chroms = sort {$a->{seqno} <=> $b->{seqno}} @chroms;
		my(@genes);
		my($hash_genetab) = {};
	
		foreach $g ( @{$geneInfo} ) {
			if ($g->{type} eq 'CDS') {
				# output only when the gene is preset in protseq
				if ($hash_protseq->{$g->{name}}) {
					if (! $g->{aalen}) {
						$g->{aalen} = int( (($g->{to1} - 3) - $g->{from1} + 1) / 3 );
					}
					$g->{pos} = ($g->{from1} + ($g->{to1}-3)) / 2;
					push(@{$genes[$g->{seqno}-1]}, $g);
					$hash_genetab->{$g->{name}} = 1;
				}
			}
		}
		foreach $c (@chroms) {
			print GENETAB "##Chromosome\t";
			print GENETAB "name:$c->{name}" if ($c->{name});
			print GENETAB "\tseq_length:$c->{seq_length}" if ($c->{seq_length});
			print GENETAB "\n";
			foreach $g (@{ $genes[$c->{seqno} - 1] }) {
				print GENETAB join("\t", $g->{sp}, $g->{name}, $g->{from1}, $g->{to1}, $g->{aalen}, $g->{pos}, $g->{dir}), "\n"
			}
		}
		open(PROTSEQ, ">$outname.faa") || die "Can't open protseq for output\n";
		$pseq = &get_data($sp, 'proteinseq');
		foreach $g ( @{$pseq} ) {
			# output only when the gene is preset in genetab
			if ($hash_genetab->{$g->{name}}) {
				print PROTSEQ ">$g->{sp}:$g->{name} $g->{descr}\n";
				print PROTSEQ "$g->{seq}\n";
			}
		}
		close(GENETAB);
		close(PROTSEQ);
	}
}
sub get_proteinseq {
	my(@species) = @_;
	my(%hash_protseq);
	foreach $sp (@species) {
		$pseq = &get_data($sp, 'proteinseq');
		foreach $g ( @{$pseq} ) {
			$hash_protseq{$g->{name}} = $g;
		}
	}
	\%hash_protseq;
}
sub get_data {
	my($sp, $type) = @_;
	$content = get("$MBGDAPI/$type/$sp");
	decode_json($content);
}
