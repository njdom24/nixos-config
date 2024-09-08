{ inputs, ... }: {
	imports = [ ./global ];

	programs = {
	  rofi.yoffset = 24;	
	};
}
