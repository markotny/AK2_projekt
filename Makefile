prg:	prg.o
		ld -o prg prg.o
prg.o:	load.s
		as -gstabs -o prg.o load.s