#! /usr/bin/perl -w

use strict;
use GD::Graph::bars;
use GD::Graph::hbars;
use GD::Graph::Data; 

my $dir = $ARGV[0];
my $mode = $ARGV[1];
my @files; #holds all log files
my @files2; #holds selected log files
#names for the two images that we are creating
my @imageName = ("stats.png", "stats_short.png"); 
my $max = 20; #log files with a digit (or no digit)higher than this will be skipped
my $min = 5; #don't show domains with counts fewer than this


if (!defined($ARGV[0]) ) { 
	print "\nUsage: squid_image.pl /directory/to/logs/ MODE\n\n";
	print "If 'MODE' has any value, then all log files will be read and lots of memory will be needed\n\n";
	exit;
}

chdir($dir) or die "Can't change to directory: $ARGV[0] - $!\n";
@files = <access.*>; #grabs all log files

if(defined($mode)){
	#read all logS
	$min = 50;
	&getWorking(\@files, $imageName[0]);
	exit;
}

foreach my $item (@files){#rip out files we don't want and make another image
	if($item =~ m/.*\.log\.(\d*)/){
		#delete elements if digit is higher than max
		push(@files2, $item) if $1 < $max;
	}
	else{
		push(@files2, $item);
	}
}
undef(@files);

&getWorking(\@files2, $imageName[1]);


########################	Functions	#########################

#use regex to push a url onto array ref
sub get_url
{
  my ($line,$array) = @_;
  if($line =~ m{GET http://(.+?)/}i){
	  push(@{$array},$1);
  }
}

#reads files stored in @files, pulls out all url's from files and counts 
sub getWorking
{
  my ($files,$imageName) = @_; #ref to array of files to read
	
  my @lines; #array of every line from log files
  my %domains; #hash of domain name, value is count
  my @keys;  #domain names
  my @values;  #domain name counts
  my $total = 0; #used to store total hits

  foreach my $file (@{$files}){ 
	if($file =~ m/gz$/i){ #if log is compress, read with zcat
		open FILE, "zcat $file|" or die $!;
		while(<FILE>){
			&get_url($_, \@lines);
		}
	}
	else{ #read uncompressed files
		open FILE, $file or die "not found: $file Error: $!";
		while(<FILE>){
			&get_url($_, \@lines);
		}
	}
	close(FILE);
  }

  foreach my $line (@lines){
	my @splits;
	my $i;
	my $str = "";
	my ($sub, $dom, $tld);

	@splits = split(/\./,$line); #split domain into sub domains
	$i = scalar(@splits);
	if($i == 2){ #if there is not a sub domain...
		($dom, $tld) = ($splits[$i-2], $splits[$i-1]);
	}
	else{
		($sub, $dom, $tld) = ($splits[$i-3], $splits[$i-2], $splits[$i-1]);
	}
	if($tld =~ m/\d/){ #skip if tld is an ip address
		 next;
	}
	#remove a sub domain if it is "www" or less than 3 chars
	if(defined($sub) and ($sub eq "www" or $sub !~ m/\w\w\w+/)){
		$sub = undef;
	}
	#put domain back together
	$str = $sub . "." if (defined($sub));
	$str = $str . $dom . "." . $tld;
	#Count how many times each domain appears
	if(not defined($domains{$str})){
		$domains{$str} = 1;
	}
	else{
		$domains{$str} = $domains{$str} + 1;
	}

  }
  undef(@lines); #delete giant array
  #delete domains that are less than $min in count
  foreach my $key (keys %domains){
	#print full list
	#print $key . ": " . $domains{$key} . "\n";
	$total = $total + $domains{$key};
	if($domains{$key} < $min){
		delete($domains{$key});
	}
  }

  #take a list of domain names and sort them
  @keys = sort { $domains{$b} <=> $domains{$a} } keys %domains;

  #use sorted domain list to get a sorted array of domain counts
  foreach my $key (@keys){
	push(@values, $domains{$key});
  }

  undef(%domains); #delete hash
  #build data structure for graph using domains and counts
  my @data = ( [@keys],[@values] );
  #give each domain 20 pixels on graph
  my $my_graph = GD::Graph::hbars->new(2000,scalar(@keys) * 20);

  $my_graph->set(
	x_label => 'Browsed Sites',
	y_label => 'Count',
	long_ticks => '1',
	show_values => '1',
	x_ticks => '0',
	title => "Sites Visited On Network | Total hits: $total",
	y_max_value => 5000,
	y_tick_number => 10,
	# shadows
	bar_spacing => 20,
	bar_width => 8,
	shadow_depth => 2,
	shadowclr => 'dred',
	transparent => 0,
  )

  or warn $my_graph->error;
  $my_graph->set_y_axis_font(GD::Font->MediumBold,22) or warn $my_graph->error;
  $my_graph->set_x_axis_font(GD::Font->MediumBold,22) or warn $my_graph->error;
  $my_graph->set_x_label_font(GD::Font->Giant,28) or warn $my_graph->error;
  $my_graph->set_y_label_font(GD::Font->Giant,28) or warn $my_graph->error;
  $my_graph->set_title_font(GD::Font->Giant,32) or warn $my_graph->error;

  my $gd = $my_graph->plot(\@data) or die $my_graph->error;

  #change to HOME and write image
  chdir($ENV{HOME});
  open(IMG, '>', $imageName) or die $!;
  binmode IMG;
  print IMG $gd->png;
  close(IMG);
  chdir($dir);
}

