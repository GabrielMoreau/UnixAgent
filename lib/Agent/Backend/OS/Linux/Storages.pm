package Ocsinventory::Agent::Backend::OS::Linux::Storages;

#use vars qw($runAfter);
#$runAfter = ["Ocsinventory::Agent::Backend::OS::POSIX::Domains"];

sub check {1}

sub run {
	my $inventory = shift;

	my $partitions;
	my @values;


	foreach (glob ("/sys/block/*")) {# /sys fs style
		$partitions->{$1} = undef
			if (/^\/sys\/block\/([sh]d[a..z])$/)
	}
	foreach (`$fdisk_path -l`) {# call fdisk to list partitions
		chomp;
		next unless (/^\//);
		$partitions->{$1} = undef
			if (/^\/dev\/([sh]d[a..z])/);
	}

	foreach my $device (keys %$partitions) {
		my $manufacturer;
		my $model;
		my $description;
		my $media;
		my $type;
		my $capacity;

# Parse info from /sys
		if (open VENDOR, "/sys/block/$device/device/vendor") {
			chomp($manufacturer = <VENDOR>);
			$manufacturer =~ s/^(\w+)\W*/$1/;# remove spaces
				close VENDOR;
		}
		if (open MODEL, "/sys/block/$device/device/model") {
			chomp($model = <MODEL>);
			$model =~ s/^(\w+)\W*/$1/;
			close MODEL;
		}
		if (open REMOVABLE, "/sys/block/$device/removable") {
			chomp(my $removable = <REMOVABLE>);
# i guess it's an hard drive if the media is not removable
			$media = $removable?"removable":"disk";
			close REMOVABLE;
		}


# Old style, fetch data from /proc
		if(!$model) {
			if (open MODEL, "/proc/ide/$device/model") {
				chomp($model = <MODEL>);
				close MODEL;
			}
		}
		if (!$media) {
			if (open MEDIA, "/proc/ide/$device/media") {
				chomp($media = <MEDIA>);
				close MEDIA;
			}
		}

		if (!$manufacturer) {
			if($model =~ /(maxtor|western|sony|compaq|hewlett packard|ibm|seagate|toshiba|fujitsu|lg|samsung)/i){
				$manufacturer=$1;
			}
		}

		if ($device =~ /^s/) { # /dev/sd* are SCSI _OR_ SATA
			if ($manufacturer =~ /ATA/) {
				$description = "SATA";
			} else {
				$description = "SCSI";
			}
		} else {
			$description = "IDE";
		}
		chomp ($capacity = `/sbin/fdisk -s /dev/$device`);
		$capacity = int ($capacity/1000) if $capacity;

		$inventory->addStorages({
				MANUFACTURER => $manufacturer,
				MODEL => $model,
				DESCRIPTION => $description,
				TYPE => $media,
				DISKSIZE => $capacity
				});

	}




}

1;