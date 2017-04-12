#!/usr/bin/env perl

use Modern::Perl;
use File::Slurp;
use YAML::XS;
use Storable qw/dclone/;

opendir(my $dh, "zips") || die "can't open zips";

my $info = { en => {}, bg => {} };
my $artists = { en => [], bg => []};

while (readdir $dh) {
    next if /^\./;
    my $artist_url = $_;
    $artist_url =~ s/\.zip$//;

    print "artist: " . $artist_url . "\n";

    my $infotext = read_file("infos/$artist_url", binmode => ':utf8') || die "can't open $artist_url";

    my @infos = split(/\n\n/, $infotext);

    # artist English name
    push @{ $artists->{en} }, { "url-name" => $artist_url, "name" => shift @infos };

    # artist English info
    my $aitxt = shift @infos;
    $info->{en}{$artist_url}{info} = prep_artist_info($aitxt);

    system("unzip zips/$artist_url.zip -d temp");

    # english artworks
    my $en_artworks = [];

    prep_artworks(\@infos, $en_artworks);

    $info->{en}{$artist_url}{artworks} = dclone $en_artworks;

    # artist Bulgarian name
    push @{ $artists->{bg} }, { "url-name" => $artist_url, "name" => shift @infos };

    # artist Bulgarian info
    $aitxt = shift @infos;
    $info->{bg}{$artist_url}{info} = prep_artist_info($aitxt);

    # bulgarian artworks
    my $bg_artworks = [];
    prep_artworks(\@infos, $bg_artworks, $en_artworks);

    $info->{bg}{$artist_url}{artworks} = dclone $bg_artworks;

    system("rm temp/*");

    print $artist_url . "\n";
}

print Dump($artists);
#print Dump($info);


closedir($dh);
sub prep_artist_info {
    my $aitxt = shift;

    my @tmp = split ("\n", $aitxt);
    $tmp[-1] = "<a href=\"http://$tmp[-1]/\">$tmp[-1]</a>" if ($tmp[-1] =~ /\./);
    my $aihtml = join "<br>", @tmp;

    return $aihtml;
}

sub prep_artworks {
    my ($info_aref, $artworks_aref, $enaw_aref) = @_;

    my @files = `ls -1 temp`;

    my $txt;
    while (($txt = shift @{ $info_aref }) =~ /^\(\d\)/) {
        # remove number and store it to be used as an array index
        $txt =~ s/^\((\d)\)\s//;
        my $n = $1 - 1;


        # prep URL slug
        my $slug;
        if (defined $enaw_aref) {
            $slug = $enaw_aref->[$n]->{"url-name"};
        }
        else {
            ($slug) = (split /,/, $txt);
            $slug =~ s/[\s:]/-/g;
        }

        # prep info text
        $txt =~ s/\n/<br>/gm;

        # prep file name
        my $file = @files[$n];
        chomp $file;

        push @$artworks_aref, {
            "url-name" => $slug,
            "file" => $file,
            "info" => $txt
        }
    }

    unshift @{ $info_aref }, $txt;
}
