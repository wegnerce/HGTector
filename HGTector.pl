#!/usr/bin/perl

# HGTector (version 0.2.2): Genome-wide detection of horizontal gene transfer based on sequence similarity search result distribution statistics
# Copyright (C) 2013-2017, Qiyun Zhu, Katharina Dittmar. All rights reserved.
# Licensed under BSD 2-clause license.

use warnings;
use strict;
use Cwd;
use Cwd 'abs_path';
$| = 1;

print "
+---------------------+
|   HGTector v0.2.2   |
+---------------------+
";

my $usage = "
Usage:
  1) Choose a working directory (say, wkdir).
  2) Create wkdir/input, and place your *.faa file(s) in it.
  3) Create a configuration file: wkdir/config.txt.
  4) Execute:
     perl HGTector.pl /path/to/wkdir

Please take a look at GUI.html, an interactive web interface that helps you to understand the whole pipeline and to generate configuration files for your analyses.

";

sub pipeline;

my $cwd = cwd;
my $db = abs_path($0); $db =~ s/HGTector\.pl$/db/;
my $scripts = abs_path($0); $scripts =~ s/HGTector\.pl$/scripts/;
my $wkDir = abs_path($0); $wkDir =~ s/HGTector\.pl$/sample/;

if (not @ARGV or $ARGV[0] eq "-h" or $ARGV[0] eq "--help") {
    if (-d $db) {
        print $usage;

    } else {
        print "\n";
        print "Welcome! This seems to be the first time you run HGTector on this computer.\n";
        print "I will guide you through the basics of the program.\n";

        print "\n";
        print "Would you like to test on a small sample dataset (yes/NO)? ";
        my $s = <STDIN>; chomp $s;
        if ($s =~ /^yes$/i or $s =~ /^y$/i) {
            print "\n";
            print "HGTector will connect the NCBI BLAST server to perform sequence similarity search and to identify taxonomy of hits. You don't need any local search tool, database or computing power. However, please be prepared that this process may take some time depending on how busy the server is.\n";
            print "Proceed (yes) or opt out (NO): ";
            $s = <STDIN>; chomp $s;
            if ($s =~ /^yes$/i or $s =~ /^y$/i) {
                print "\n";
                pipeline;
            }
        }
        print "The sample dataset and its configuration file, plus an archive of sample output can be found in the /sample subdirectory. You may take a look and get a general idea of how the input / output files are organized in an HGTector analysis.\n";
        print "\n";

        print "Now I will assist you to install optional dependencies.\n";
        print "HGTector by default works out-of-the-box, without relying on any third-party dependencies, whereas several optional modules will enhance HGTector's functionality.\n";
        print "These modules include Perl modules Statistics::R and Spreadsheet::WriteExcel, and R packages pastecs and diptest (you will need R first).\n";
        print "Proceed (yes/NO)? ";
        $s = <STDIN>; chomp $s;
        if ($s =~ /^yes$/i or $s =~ /^y$/i) {
            if ($^O eq "MSWin32") {
                print "You are using the Windows system, in which the installation script cannot be executed. You will need to manually install the dependencies.\n";
            } else {
                system "bash $scripts/installer.sh";
            }
        }
        print "\n";

        print "Now I will assist you to prepare a reference database.\n";
        print "Unless you plan to always use HGTector in remote mode, a local reference database is recommended for consistant and controllable analyses.\n";
        print "The database will have three components: a protein sequence database, a taxonomy database, and a protein-to-taxonomy dictionary.\n";
        print "Using proper databases is important for optimal results. Please consider reading about the details of choice of databases in the GUI.\n";
        print "\n";

        print "A pre-built database is available (see README.md for download link). Alternatively, I will build an up-to-date one for you now.\n";
        print "Proceed (YES/no)? ";
        $s = <STDIN>; chomp $s;
        if (not $s or $s =~ /^yes$/i or $s =~ /^y$/i) {
            print "\nPlease specify a location to store the databases (default: db/ in the program directory): ";
            $s = <STDIN>; chomp $s; $s =~ s/\/$//;
            $db = $s if $s;
            mkdir $db;
            chdir $db;
            print "\nBy default, I will download NCBI RefSeq proteomic data of microbial organisms (archaea, bacteria, fungi and protozoa), keep one proteome per species, plus all NCBI-defined representative proteomes. The data will be merged into a master multi-Fasta file, and compiled into a BLAST database.\n";
            print "As of 2015-10-25, the database contained around 30 million non-redundant protein sequences from more than 8000 organisms. Depending on the Internet connection quality, it may take up to 12 hr to download and compile.\n";
            my ($format, $range, $represent, $subsample, $out) = ("blast", "microbe", "auto", "1", "stdb");
            print "Accept (YES) or change options (no): ";
            $s = <STDIN>; chomp $s;
            if ($s =~ /^no$/i or $s =~ /^n$/i) {
                print "\nNCBI RefSeq genomes are categorized as: archaea, bacteria, fungi, invertebrate, plant, protozoa, vertebrate_mammalian, vertebrate_other, and viral. Type one or more desired categories separated by comma, or press Enter to accept the default (microbe): ";
                $s = <STDIN>; chomp $s; $s =~ s/\s+//g;
                $range = $s if $s;
                print "\nI will keep one representative organism per species by default, in order to save computing time. Otherwise, enter the number of organisms you want to keep, or type '0' to keep all organisms (no subsampling): ";
                $s = <STDIN>; chomp $s;
                if ($s eq "0") { $subsample = "0"; }
                elsif ($s and $s =~ /^\d+$/) { $subsample = $s; }
                print "\nAll NCBI-defined representative organisms will be kept. Press Enter to accept, type 'no' to opt out, or enter a file name that contains a list of TaxID you wish to keep: ";
                $s = <STDIN>; chomp $s;
                $represent = $s if $s;
                print "\nAfter downloading the proteomic data, do you want to build a BLAST database? Note: you need makeblastdb from the NCBI-BLAST+ package to enable this function. You may also build database manually using tools of choice later. (YES/no) ";
                $s = <STDIN>; chomp $s;
                $format = "none" if ($s =~ /^no$/i or $s =~ /^n$/i);
                print "\nEnter a stem file name for your database (default: 'stdb'): ";
                $s = <STDIN>; chomp $s;
                $out = $s if $s;
            }
            my $i = system "python $scripts/databaser.py -format=$format -range=$range -represent=$represent -subsample=$subsample -out=$out";
            chdir $cwd;
            print "\nThere appears to be some problems in database building.\n" unless -s "$db/$out.faa";
            print "\nNow that databases are created. Your may link HGTector to them in future analyses, by setting the following parameters in config.txt:\n";
            if ($format eq "blast") {
                print "protdb=$db/blast/$out\n";
            } else {
                print "# You still need to build a searchable database based on $db/$out.faa";
            }
            print "taxdump=$db/taxdump\n";
            print "prot2taxid=$db/prot2taxid.txt\n";
            print "\n";
        }
        print "You may start to use HGTector to analyze your data.\n";
        print $usage;
    }
} else {
    $wkDir = $ARGV[0];
    pipeline;
}
exit 0;


sub pipeline {
    print "\nValidating task...\n";
    die "Error: Invalid working directory $wkDir.\n" unless -d $wkDir;
    my $interactive = 1;
    if (-e "$wkDir/config.txt") {
        open IN, "<$wkDir/config.txt" or die "Error: Invalid configuration file $wkDir/config.txt.\n";
        while (<IN>) {
            s/#.*$//; s/\s+$//; s/^\s+//; next unless $_;
            $interactive = 0 if /^interactive=0$/;
        }
    } else {
        print "Warning: Configuration file $wkDir/config.txt is not found. HGTector will use default settings.\n";
        if ($interactive) {
            print "Press Enter to proceed, or Ctrl+C to exit:";
            my $s = <STDIN>;
        }
    }
    die "Error: Input folder $wkDir/input is not found. Please prepare input data before running HGTector.\n" unless -d "$wkDir/input";
    print "Done.\n\n";

    print "Step 1: Searcher - batch protein sequence homology search.\n";
    die "Error: searcher.pl is not found in the scripts/ subdirectory.\n" unless -e "$scripts/searcher.pl";
    my $i = system "$^X $scripts/searcher.pl $wkDir";
    die "Error: Execution of searcher.pl failed. HGTector exists.\n" if $i;
    die "Error: No search result detected. HGTector exists.\n" unless -d "$wkDir/search";
    print "\n";

    print "Step 2: Analyzer - predict HGT based on hit distribution statistics.\n";
    die "Error: analyzer.pl is not found in the scripts/ subdirectory.\n" unless -e "$scripts/analyzer.pl";
    $i = system "$^X $scripts/analyzer.pl $wkDir";
    die "Execution of analyzer.pl failed.\n" if $i;
    die "Error: No analysis result detected. HGTector exists.\n" unless -d "$wkDir/result";
    print "\n";

    print "Step 3: Reporter - generate report for prediction results.\n";
    die "Error: reporter.pl is not found in the scripts/ subdirectory.\n" unless -e "$scripts/reporter.pl";
    $i = system "$^X $scripts/reporter.pl $wkDir";
    die "Execution of analyzer.pl failed.\n" if $i;
    print "\n";

    print "All steps completed.\n";
}
