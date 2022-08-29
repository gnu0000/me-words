use warnings;
use strict;
use Gnu::ArgParse;
use Gnu::Template qw(Template Usage);

my $SCANS = [
   ["Longest words"                     , \&LengthWeight       , 0],
   ["Longest alphabeticals"              , \&AlphabeticalWeight , 0],
   ["Longest reverse alphabeticals"      , \&RalphabeticalWeight, 0],
   ["Longest palendromics"               , \&PalendromeWeight   , 0],
   ["Most doubled letters"               , \&DoublesWeight      , 0],
   ["Most vowels percent (min len 5)"    , \&VowelWeight        , 5],
   ["Most vowels percent (min len 7)"    , \&VowelWeight        , 7],
   ["Most vowels percent (min len 9)"    , \&VowelWeight        , 9],
   ["Most consonants percent (min len 5)", \&ConsonantWeight    , 5],
   ["Most consonants percent (min len 7)", \&ConsonantWeight    , 7],
   ["Most consonants percent (min len 9)", \&ConsonantWeight    , 9],
   ["Early Letters (min len 5)"          , \&EarlyLetterWeight  , 5],
   ["Early Letters (min len 7)"          , \&EarlyLetterWeight  , 7],
   ["Early Letters (min len 9)"          , \&EarlyLetterWeight  , 9],
   ["Late Letters (min len 5)"           , \&LateLetterWeight   , 5],
   ["Late Letters (min len 7)"           , \&LateLetterWeight   , 7],
   ["Late Letters (min len 9)"           , \&LateLetterWeight   , 9],
   ["Close Letters (min len 5)"          , \&CloseLetterWeight  , 5],
   ["Close Letters (min len 7)"          , \&CloseLetterWeight  , 7],
   ["Close Letters (min len 9)"          , \&CloseLetterWeight  , 9],
   ["Far Letters (min len 5)"            , \&FarLetterWeight    , 5],
   ["Far Letters (min len 7)"            , \&FarLetterWeight    , 7],
   ["Far Letters (min len 9)"            , \&FarLetterWeight    , 9],
];

MAIN:
   $| = 1;
   ArgBuild("*^count= *^help *^debug");
   ArgParse(@ARGV) or die ArgGetError();
   ArgAddConfig() or die ArgGetError();
   Usage() if ArgIs("help") || !ArgIs();

   my @wstats = LoadWords(ArgGet());
   Scan(@wstats);
   exit(0);
   

sub LoadWords {
   my ($filespec) = @_;

   open (my $fh, "<", "$filespec") or die "can't open $filespec";
   my @wstats = ();
   while (my $word = <$fh>) {
      chomp $word;
      next if $word =~ /^#/;
      $word = lc $word;
      
      my $wstat = {
         word    => $word, 
         len     => length $word,
         vcount  => VowelCount($word), 
         charsum => CharPositionSum($word), 
         gapsum  => LetterGapSum($word), 
      };
      push (@wstats, $wstat);
   }
   return @wstats;
}


sub Scan {
   my (@wstats) = @_;

   my $count = ArgGet("count") || 10;

   foreach my $scan (@{$SCANS}) {
      my $fn  = $scan->[1];
      my $len = $scan->[2];

      @wstats = sort {&{$fn}($b, $len) <=> &{$fn}($a, $len)} @wstats;
      print "\n$scan->[0]:\n";
      map {print "   $_\n"} map{$_->{word}} @wstats[0..$count-1];
   }
}


sub LengthWeight {
   my ($stat) = @_;
   return $stat->{len};
}


sub AlphabeticalWeight {
   my ($stat) = @_;

   return 0 unless IsAlphabetical($stat->{word});
   return $stat->{len};
}


sub RalphabeticalWeight {
   my ($stat) = @_;

   return 0 unless IsAlphabetical(scalar reverse $stat->{word});
   return $stat->{len};
}


sub PalendromeWeight {
   my ($stat) = @_;

   return 0 unless IsPalendromic($stat->{word});
   return $stat->{len};
}


sub DoublesWeight {
   my ($stat, $minlen) = @_;

   my $last = ' ';
   my $sum  = 0;
   return 0 unless $stat->{len} >= $minlen;
   foreach my $char (split("", $stat->{word})) {
      $sum += 100 - $stat->{len} if $char eq $last;
      $last = $char;
   }
   return $sum;
}

sub VowelWeight {
   my ($stat, $minlen) = @_;

   return 0 unless $stat->{len} >= $minlen;
   return $stat->{vcount} / $stat->{len};
}


sub ConsonantWeight {
   my ($stat, $minlen) = @_;

   return 0 unless $stat->{len} >= $minlen;
   return ( $stat->{len} - $stat->{vcount}) / $stat->{len};
}


sub EarlyLetterWeight {
   my ($stat, $minlen) = @_;

   return -999 unless $stat->{len} >= $minlen;
   return - $stat->{charsum} / $stat->{len};
}


sub LateLetterWeight {
   my ($stat, $minlen) = @_;

   return 0 unless $stat->{len} >= $minlen;
   return $stat->{charsum} / $stat->{len};
}


sub CloseLetterWeight {
   my ($stat, $minlen) = @_;

   return -999 unless $stat->{len} >= $minlen;
   return - $stat->{gapsum} / $stat->{len};
}


sub FarLetterWeight {
   my ($stat, $minlen) = @_;

   return 0 unless $stat->{len} >= $minlen;
   return $stat->{gapsum} / $stat->{len};
}


sub IsAlphabetical {
   my ($word) = @_;

   my $last = ' ';
   foreach my $char (split("", $word)) {
      return 0 if $char lt $last;
      $last = $char
   }
   return 1;
}


sub IsPalendromic {
   my ($word) = @_;

   my $last = ' ';
   my @chars = split("", $word);
   my $len = length $word;
   for (my $i=0; $i< $len/2; $i++) {
      return 0 if $chars[$i] ne $chars[$len - $i - 1];
   }
   return 1;
}


sub VowelCount {
   my ($word) = @_;

   my $count = () = $word =~ /[aeiouy]/gi;
   return  $count;
}


sub CharPositionSum {
   my ($word) = @_;

   my $sum = 0;
   map {$sum += ord($_) - 96} split("", $word);
   return $sum;   
}


sub LetterGapSum {
   my ($word) = @_;

   my $sum = 0;
   my @chars = split("", $word);
   for (my $i=1; $i < scalar @chars; $i++) {
      $sum += abs(ord($chars[$i-1]) - ord($chars[$i]));
   }
   return $sum;
}


__DATA__

[usage]
scan.pl [options] [wordfile] 

example:
   scan words.txt
   scan -count=20 words.txt
