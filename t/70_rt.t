#!/usr/bin/perl

use strict;
$^W = 1;

#use Test::More "no_plan";
 use Test::More tests => 46;

BEGIN {
    use_ok "Text::CSV_XS", ();
    plan skip_all => "Cannot load Text::CSV_XS" if $@;
    }

my $rt_no;
my %input;
while (<DATA>) {
    if (m/^�(\d+)�/) {
	$rt_no = $1;
	next;
	}
    push @{$input{$rt_no}}, $_;
    }

# Regression Tests based on RT reports

{   # http://rt.cpan.org/Ticket/Display.html?id=24386
    # #24386: \t doesn't work in _XS, works in _PP

    use Data::Dumper;

    my @lines = @{$input{24386}};

    ok (my $csv = Text::CSV_XS->new ({ sep_char => "\t" }), "RT-24386: \\t doesn't work");
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
    use IO::Handle;
    open  FH, ">_test.csv";
    print FH @{$input{21530}};
    close FH;
    ok (my $csv = Text::CSV_XS->new ({ binary => 1 }), "RT-21530: getline () return at eof");
    open  FH, "<_test.csv";
    my $row;
    foreach my $line (1 .. 5) {
	ok ($row = $csv->getline (*FH), "getline $line");
	is (ref $row, "ARRAY", "is arrayref");
	is ($row->[0], $line, "Line $line");
	}
    ok (eof FH, "EOF");
    is ($row = $csv->getline (*FH), undef, "getline EOF");
    close FH;
    unlink "_test.csv";
    }

{   # http://rt.cpan.org/Ticket/Display.html?id=21530
    # 18703: Fails to use quote_char of '~'
    my ($csv, @fld);
    ok ($csv = Text::CSV_XS->new ({ quote_char => "~" }), "RT-18703: Fails to use quote_char of '~'");
    is ($csv->quote_char, "~", "quote_char is '~'");

    ok ($csv->parse ($input{18703}[0]), "Line 1");
    ok (@fld = $csv->fields, "Fields");
    is (scalar @fld, 1, "Line 1 has only one field");
    is ($fld[0], "Style Name", "Content line 1");

    # The line has invalid escape. the escape should only be
    # used for the special characters
    ok (!$csv->parse ($input{18703}[1]), "Line 2");
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
