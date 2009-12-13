#!/usr/bin/perl

use strict;
$^W = 1;

#use Test::More "no_plan";
 use Test::More tests => 91;

BEGIN {
    use_ok "Text::CSV_XS", ();
    plan skip_all => "Cannot load Text::CSV_XS" if $@;
    }

my $csv_file = "_test.csv";
END { unlink $csv_file }

my ($rt, %input, %desc);
while (<DATA>) {
    if (s/^�(\d+)�\s*-?\s*//) {
	chomp;
	$rt = $1;
	$desc{$rt} = $_;
	next;
	}
    s/\\([0-7]{1,3})/chr oct $1/ge;
    push @{$input{$rt}}, $_;
    }

# Regression Tests based on RT reports

{   # http://rt.cpan.org/Ticket/Display.html?id=24386
    # #24386: \t doesn't work in _XS, works in _PP

    $rt = 24386;
    my @lines = @{$input{$rt}};

    ok (my $csv = Text::CSV_XS->new ({ sep_char => "\t" }), "RT-$rt: $desc{$rt}");
    is ($csv->sep_char, "\t", "sep_char = TAB");
    foreach my $line (0 .. $#lines) {
	ok ($csv->parse ($lines[$line]), "parse line $line");
	ok (my @fld = $csv->fields, "Fields for line $line");
	is (scalar @fld, 25, "Line $line has 25 fields");
	# print STDERR "# $fld[2] - $fld[3]\t- $fld[4]\n";
	}
    }

{   # http://rt.cpan.org/Ticket/Display.html?id=21530
    # 21530: getline () does not return documented value at end of filehandle
    # IO::Handle  was first released with perl 5.00307
    $rt = 21530;
    open  FH, ">$csv_file";
    print FH @{$input{$rt}};
    close FH;
    ok (my $csv = Text::CSV_XS->new ({ binary => 1 }), "RT-$rt: $desc{$rt}");
    open  FH, "<$csv_file";
    my $row;
    foreach my $line (1 .. 5) {
	ok ($row = $csv->getline (*FH), "getline $line");
	is (ref $row, "ARRAY", "is arrayref");
	is ($row->[0], $line, "Line $line");
	}
    ok (eof FH, "EOF");
    is ($row = $csv->getline (*FH), undef, "getline EOF");
    close FH;
    unlink $csv_file;
    }

{   # http://rt.cpan.org/Ticket/Display.html?id=21530
    # 18703: Fails to use quote_char of '~'
    $rt = 18703;
    my ($csv, @fld);
    ok ($csv = Text::CSV_XS->new ({ quote_char => "~" }), "RT-$rt: $desc{$rt}");
    is ($csv->quote_char, "~", "quote_char is '~'");

    ok ($csv->parse ($input{$rt}[0]), "Line 1");
    ok (@fld = $csv->fields, "Fields");
    is (scalar @fld, 1, "Line 1 has only one field");
    is ($fld[0], "Style Name", "Content line 1");

    # The line has invalid escape. the escape should only be
    # used for the special characters
    ok (!$csv->parse ($input{$rt}[1]), "Line 2");
    }

{   # http://rt.cpan.org/Ticket/Display.html?id=15076
    # 15076: escape_char before characters that do not need to be escaped.
    $rt = 15076;
    my ($csv, @fld);
    ok ($csv = Text::CSV_XS->new ({
	sep_char		=> ";",
	escape_char		=> "\\",
	allow_loose_escapes	=> 1,
	}), "RT-$rt: $desc{$rt}");

    ok ($csv->parse ($input{$rt}[0]), "Line 1");
    ok (@fld = $csv->fields, "Fields");
    is (scalar @fld, 2, "Line 1 has two fields");
    is ($fld[0], "Example", "Content field 1");
    is ($fld[1], "It's an apostrophee", "Content field 2");
    }

{   # http://rt.cpan.org/Ticket/Display.html?id=34474
    # 34474: wish: integrate row-as-hashref feature from Parse::CSV
    $rt = 34474;
    open  FH, ">$csv_file";
    print FH @{$input{$rt}};
    close FH;
    ok (my $csv = Text::CSV_XS->new (),		"RT-$rt: $desc{$rt}");
    is ($csv->column_names, undef,		"No headers yet");
    open  FH, "<$csv_file";
    my $row;
    ok ($row = $csv->getline (*FH),		"getline headers");
    is ($row->[0], "code",			"Header line");
    $csv->column_names (@$row);
    is_deeply ([ $csv->column_names ], [ @$row ], "Keys set");
    while (my $hr = $csv->getline_hr (*FH)) {
	ok (exists $hr->{code},			"Line has a code field");
	like ($hr->{code}, qr/^[0-9]+$/,	"Code is numeric");
	ok (exists $hr->{name},			"Line has a name field");
	like ($hr->{name}, qr/^[A-Z][a-z]+$/,	"Name");
	}
    close FH;
    unlink $csv_file;
    }

{   # http://rt.cpan.org/Ticket/Display.html?id=38960
    # 38960: print () on invalid filehandle warns and returns success
    $rt = 38960;
    open  FH, ">$csv_file";
    print FH "";
    close FH;
    my $err = "";
    open  FH, "<$csv_file";
    ok (my $csv = Text::CSV_XS->new (),		"RT-$rt: $desc{$rt}");
    local $SIG{__WARN__} = sub { $err = "Warning" };
    ok (!$csv->print (*FH, [ 1 .. 4 ]),		"print ()");
    is ($err, "Warning",			"IO::Handle triggered a warning");
    is (($csv->error_diag)[0], 2200,		"error 2200");
    close FH;
    unlink $csv_file;
    }

{   # http://rt.cpan.org/Ticket/Display.html?id=40507
    # 40507: Parsing fails on escaped null byte
    $rt = 40507;
    ok (my $csv = Text::CSV_XS->new ({ binary => 1 }), "RT-$rt: $desc{$rt}");
    my $str = $input{$rt}[0];
    ok ($csv->parse ($str),		"parse () correctly escaped NULL");
    is_deeply ([ $csv->fields ],
	[ qq{Audit active: "TRUE \0},
	  qq{Desired:},
	  qq{Audit active: "TRUE \0} ], "fields ()");
    $str = $input{$rt}[1];
    is ($csv->parse ($str), 0,		"parse () badly escaped NULL");
    my @diag = $csv->error_diag;
    is ($diag[0], 2023,			"Error 2023");
    is ($diag[2],   23,			"Position 23");
    $csv->allow_loose_escapes (1);
    ok ($csv->parse ($str),		"parse () badly escaped NULL");
    }

{   # http://rt.cpan.org/Ticket/Display.html?id=42642
    # 42642: failure on unusual quote/sep values
    $rt = 42642;
    SKIP: {
	$] < 5.008002 and skip "UTF8 unreliable in perl $]", 6;

	open  FH, ">$csv_file";
	print FH @{$input{$rt}};
	close FH;
	my ($sep, $quo) = ("\x14", "\xfe");
	chop ($_ = "$_\x{20ac}") for $sep, $quo;
	ok (my $csv = Text::CSV_XS->new ({ binary => 1, sep_char => $sep }), "RT-$rt: $desc{$rt}");
	ok ($csv->quote_char ($quo), "Set quote_char");
	open  FH, "<$csv_file";
	ok (my $row = $csv->getline (*FH),	"getline () with decode sep/quo");
	$csv->error_diag ();
	close FH;
	unlink $csv_file;
	is_deeply ($row, [qw( DOG CAT WOMBAT BANDERSNATCH )], "fields ()");
	ok ($csv->parse ($input{$rt}[1]),	"parse () with decoded sep/quo");
	is_deeply ([ $csv->fields ], [ 0..3 ],	"fields ()");
	}
    }

{   # http://rt.cpan.org/Ticket/Display.html?id=43927
    # 43927: Is bind_columns broken or am I using it wrong?
    $rt = 43927;
    SKIP: {
	open  FH, ">$csv_file";
	print FH @{$input{$rt}};
	close FH;
	my ($c1, $c2);
	ok (my $csv = Text::CSV_XS->new ({ binary => 1 }), "RT-$rt: $desc{$rt}");
	ok ($csv->bind_columns (\$c1, \$c2), "bind columns");
	open  FH, "<$csv_file";
	ok (my $row = $csv->getline (*FH), "getline () with bound columns");
	$csv->error_diag ();
	close FH;
	unlink $csv_file;
	is_deeply ($row, [], "should return empty ref");
	is_deeply ([ $c1, $c2], [ 1, 2 ], "fields ()");
	}
    }

__END__
�24386� - \t doesn't work in _XS, works in _PP
VIN	StockNumber	Year	Make	Model	MD	Engine	EngineSize	Transmission	DriveTrain	Trim	BodyStyle	CityFuel	HWYFuel	Mileage	Color	InteriorColor	InternetPrice	RetailPrice	Notes	ShortReview	Certified	NewUsed	Image_URLs	Equipment
1HGCM66573A030460	1621HA	2003	HONDA	ACCORD EX V-6	ACCORD	DOHC 16-Valve VTEC	3.0L	5-Speed Automatic		EX V-6	4DR	21	30	70940	Gray	Gray	15983	15983		AutoWeek calls the 2003 model the best Accord yet * Fun to hustle down a twisty road according to Road & Track * Sedan perfection according to Car and Driver * Named on the 2003 Car and Driver Ten Best List * Named a Consumer Guide Best Buy for 2003 *	0	0	http://vin.windowstickers.biz/incoming/w_1HGCM66573A030460_1.JPG, http://vin.windowstickers.biz/incoming/w_1HGCM66573A030460_2.JPG, http://vin.windowstickers.biz/incoming/w_1HGCM66573A030460_3.JPG, http://vin.windowstickers.biz/incoming/w_1HGCM66573A030460_4.JPG, http://vin.windowstickers.biz/incoming/w_1HGCM66573A030460_5.JPG, http://vin.windowstickers.biz/incoming/w_1HGCM66573A030460_6.JPG, http://vin.windowstickers.biz/incoming/w_1HGCM66573A030460_7.JPG, http://vin.windowstickers.biz/incoming/w_1HGCM66573A030460_8.JPG	120-Watt AM/FM Stereo System,3-Point Seat Belts,4-Wheel Double Wishbone Suspension,6-Disc In-Dash Compact Disc Changer,6-Speaker Audio System,8-Way Power Adjustable Driver's Seat,Air Conditioning w/Air-Filtration System,Anti-Lock Braking System,Automatic-Up/Down Driver's Window,Center Console Armrest w/Storage,Child Safety Rear Door Locks,Cruise Control,Driver & Front Passenger Dual-Stage Airbags,Electronic Remote Trunk Release,Emergency Trunk Release,Fold-Down Rear Seat Center Armrest,Fold-Down Rear Seatback w/Lock,Front Seat Side-Impact Airbags,Immobilizer Theft Deterrent System,LATCH Lower Anchor & Tethers For Children,Power Driver's Seat Height Adjustment,Power Exterior Mirrors,Power Moonroof w/Tilt Feature,Power Windows & Door Locks,Power-Assisted 4-Wheel Disc Brakes,Rear Window Defroster w/Timer,Remote Keyless Entry System w/Window Control,Security System,Tilt & Telescopic Steering Column,Traction Control System,Variable Intermittent Windshield Wipers,Variable-Assist Power Rack & Pinion Steering
1FTRW12W66KA65476	4110J	2006	FORD	F-150 XLT CREW 5.5SB 4X2	F-150	SOHC Triton V8	4.6L	4-Speed Automatic	4X2	XLT	CREW 5.5SB	15	19	20334	Black	Gray	22923	22923		Named a Consumer Guide 2005 & 2006 Best Buy * Named Best Pickup by Car and Driver * The Detroit Free Press calls F-150 the best pickup truck ever * The Detroit News calls F-150 the best America has to offer *	0	0	http://vin.windowstickers.biz/incoming/w_1FTRW12W66KA65476_1.JPG, http://vin.windowstickers.biz/incoming/w_1FTRW12W66KA65476_2.JPG, http://vin.windowstickers.biz/incoming/w_1FTRW12W66KA65476_3.JPG, http://vin.windowstickers.biz/incoming/w_1FTRW12W66KA65476_4.JPG, http://vin.windowstickers.biz/incoming/w_1FTRW12W66KA65476_5.JPG, http://vin.windowstickers.biz/incoming/w_1FTRW12W66KA65476_6.JPG, http://vin.windowstickers.biz/incoming/w_1FTRW12W66KA65476_7.JPG, http://vin.windowstickers.biz/incoming/w_1FTRW12W66KA65476_8.JPG, http://vin.windowstickers.biz/incoming/w_1FTRW12W66KA65476_9.JPG	4-Pin Trailer Tow Connector,Air Conditioning,AM/FM Stereo w/Single Compact Disc Player,Auxiliary Power Outlets,Cargo Box Light & Tie-Downs,Child Safety Seat Lower Anchors & Tether Anchors,Crash Severity Sensor,Cruise Control,Dual-Stage Driver & Front-Right Passenger Airbags,Electronic Brake Force Distribution,Exterior Temperature & Compass Display,Fail-Safe Engine Cooling System,Front Dome Light w/Integrated Map Lights,Front Power Points,Front Seat Personal Safety System,Front-Passenger Sensing System,Manual Day/Night Interior Rearview Mirror,Oil Pressure & Coolant Temperature Gauges,Power 4-Wheel Disc Anti-Lock Brakes,Power Door Locks,Power Exterior Mirrors,Power Front Windows w/One-Touch Driver Side,Power Rack & Pinion Steering,Remote Keyless Entry System,Removable Tailgate w/Key Lock,Securilock Passive Anti-Theft System,Spare Tire w/Wheel Lock,Speed-Dependent Interval Windshield Wipers,Tailgate Assist System,Tilt Steering Wheel,Visors w/Covered Vanity Mirrors
5GZCZ23D03S826657	2111A	2003	SATURN	VUE BASE FWD	VUE	DOHC 4-cylinder	2.2L	5-Speed Manual	FWD	BASE	5DR	23	28	74877	Silver	Gray	11598	11598		Edmunds 2003 Buyer's Guide calls Vue a well-thought-out and capable mini sport utility vehicle, with large doors for ease of entry and exit, extensive cabin space and excellent crash test scores *	0	0	http://vin.windowstickers.biz/incoming/w_5GZCZ23D03S826657_1.JPG, http://vin.windowstickers.biz/incoming/w_5GZCZ23D03S826657_2.JPG, http://vin.windowstickers.biz/incoming/w_5GZCZ23D03S826657_3.JPG, http://vin.windowstickers.biz/incoming/w_5GZCZ23D03S826657_4.JPG, http://vin.windowstickers.biz/incoming/w_5GZCZ23D03S826657_5.JPG, http://vin.windowstickers.biz/incoming/w_5GZCZ23D03S826657_6.JPG, http://vin.windowstickers.biz/incoming/w_5GZCZ23D03S826657_7.JPG, http://vin.windowstickers.biz/incoming/w_5GZCZ23D03S826657_8.JPG	70/30 Split Folding Rear Seatback,AM/FM Stereo System,Center Console w/Storage,Center High-Mounted Rear Stop Light,CFC-Free Air Conditioning,Cloth Upholstery,Daytime Running Lights,Dent-Resistant Polymer Body Panels,Distributorless Ignition System,Driver & Front Passenger Frontal Airbags,Electric Power Rack-And-Pinion Steering,Fold-Flat Front Passenger Seat,Front & Rear Crumple Zones,Front & Rear Cup Holders,Front Bucket Seats,Front-Wheel Drive,Independent Front & Rear Suspension,Interval Rear Window Wiper/Washer,Interval Windshield Wipers,LATCH Child Safety Seat Anchor System,Platinum-Tipped Spark Plugs,Power Front Disc/Rear Drum Brakes,Rear Privacy Glass,Rear Window Defogger,Remote Rear Liftgate Release,Roof Rack,Sequential Fuel Injection,Side-Impact Door Beams,Tachometer,Theft-Deterrent System,Tilt Adjustable Steering Wheel,Visor Vanity Mirrors
1FMZU67K15UB18754	4067T	2005	FORD	EXPLORER SPORT TRAC XLT 4X2	EXPLORER SPORT TRAC	Flex Fuel SOHC V6	4.0L	5-Speed Automatic	4X2	XLT	4DR	16	21	12758	Maroon	Gray	20995	20995		Consumer Guide 2005 reports Sport Trac offers more passenger space than other crew-cab pick-ups and is a good choice as a multipurpose vehicle * Consumer Guide 2005 credits Sport Trac with good in-cabin storage *	0	0	http://vin.windowstickers.biz/incoming/w_1FMZU67K15UB18754_1.JPG, http://vin.windowstickers.biz/incoming/w_1FMZU67K15UB18754_2.JPG, http://vin.windowstickers.biz/incoming/w_1FMZU67K15UB18754_3.JPG, http://vin.windowstickers.biz/incoming/w_1FMZU67K15UB18754_4.JPG, http://vin.windowstickers.biz/incoming/w_1FMZU67K15UB18754_5.JPG, http://vin.windowstickers.biz/incoming/w_1FMZU67K15UB18754_6.JPG, http://vin.windowstickers.biz/incoming/w_1FMZU67K15UB18754_7.JPG	3-Point Front & Rear Seatbelts,4-Speaker Audio System,Air Conditioning,AM/FM Stereo w/Compact Disc Player,Belt-Minder Safety Belt Reminder System,Child Safety Rear Door Locks,Cloth Upholstery,Cruise Control,Driver & Front Passenger Airbags,Driver Door Keyless Entry Keypad,Headlights-On Alert Chime,Height-Adjustable Front Seatbelts,LATCH Child Seat Lower Anchors & Tether Anchors,Locking Tailgate,Low-Back Front Bucket Seats,Lower Bodyside Moldings,Manual Day/Night Interior Rearview Mirror,Power 4-Wheel Disc Anti-Lock Brakes,Power Door Locks,Power Exterior Mirrors,Power Rack & Pinion Steering,Power Rear Window w/Anti-Pinch,Power Windows w/Driver One-Touch Down,Remote Keyless Entry System,Roof Rails,Securilock Passive Anti-Theft System,Side-Intrusion Door Beams,Sirius Satellite Radio/MP3 Capability,Solar-Tinted Glass Windows,Speed-Sensitive Intermittent Windshield Wipers,Tachometer,Tilt Steering Wheel
1J4GK48K96W108753	4068T	2006	JEEP	LIBERTY SPORT 4X2	LIBERTY	SOHC 12-valve V6	3.7L	4-Speed Automatic	4X2	SPORT	5DR	17	22	12419	Silver	Gray	16999	16999		Named on the Automobile Magazine 50 Great New Cars List * Motor Trend reports Liberty fulfills the original go-anywhere mission of SUVs without fail or compromise * A Consumer Guide 2005 & 2006 Recommended Buy *	0	0	http://vin.windowstickers.biz/incoming/w_1J4GK48K96W108753_1.JPG, http://vin.windowstickers.biz/incoming/w_1J4GK48K96W108753_2.JPG, http://vin.windowstickers.biz/incoming/w_1J4GK48K96W108753_3.JPG, http://vin.windowstickers.biz/incoming/w_1J4GK48K96W108753_4.JPG, http://vin.windowstickers.biz/incoming/w_1J4GK48K96W108753_5.JPG, http://vin.windowstickers.biz/incoming/w_1J4GK48K96W108753_6.JPG, http://vin.windowstickers.biz/incoming/w_1J4GK48K96W108753_7.JPG, http://vin.windowstickers.biz/incoming/w_1J4GK48K96W108753_8.JPG, http://vin.windowstickers.biz/incoming/w_1J4GK48K96W108753_9.JPG	12-Volt Cargo Area Power Outlet,65/35 Split-Folding Rear Bench Seat,6-Speaker Audio System,Advanced Multi-Stage Frontal Airbags,Air Conditioning,All-Wheel Traction Control System,AM/FM Stereo w/Compact Disc Player,Center Console 12-Volt Power Outlet,Child Safety Rear Door Locks,Cloth Sun Visors w/Pull-Out Sunshade,Cloth Upholstery,Coolant Temperature Gauge,Electric Rear Window Defroster,Electronic Stability Program,Enhanced Accident Response System,Halogen Headlights w/Delay-Off Feature,LATCH Child Safety Seat Anchor System,Manual Day/Night Interior Rearview Mirror,Power 4-Wheel Disc Anti-Lock Brake System,Power Door Locks,Power Exterior Mirrors,Power Rack & Pinion Steering,Power Windows w/Front One-Touch Down,Rear Window Wiper/Washer,Remote Keyless Entry System,Roof Side Rails,Sentry Key Engine Immobilizer,Spare Tire Carrier,Tachometer,Tilt Steering Column,Tinted Windshield Glass,Variable Speed Intermittent Windshield Wipers
�21530� - getline () does not return documented value at end of filehandle
1,1,2,3,4,5
2,1,2,3,4,5
3,1,2,3,4,5
4,1,2,3,4,5
5,1,2,3,4,5
�18703� - Fails to use quote_char of '~'
~Style Name~
~5dr Crew Cab 130" WB 2WD LS~
",~"~,~""~,~"""~,,~~,
�15076� - escape_char before characters that do not need to be escaped.
"Example";"It\'s an apostrophee"
�34474� - wish: integrate row-as-hashref feature from Parse::CSV
code,name,price,description
1,Dress,240.00,"Evening gown"
2,Drinks,82.78,"Drinks"
3,Sex,-9999.99,"Priceless"
�38960� - print () on invalid filehandle warns and returns success
�40507� - Parsing fails on escaped null byte
"Audit active: ""TRUE "0","Desired:","Audit active: ""TRUE "0"
"Audit active: ""TRUE "\0","Desired:","Audit active: ""TRUE "\0"
�42642� - failure on unusual quote/sep values
�DOG��CAT��WOMBAT��BANDERSNATCH�
�0��1��2��3�
�43927� - Is bind_columns broken or am I using it wrong?
1,2
