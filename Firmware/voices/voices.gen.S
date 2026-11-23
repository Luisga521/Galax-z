/* made by tools/voices_build.py from voices.c: do not edit */
.file "voices.c";
	.text
	.align 4
.global _voices_off;
.type _voices_off, STT_FUNC;
_voices_off:
	[--sp] = ( p5:3 );

	P5 = R0;
	LINK 12;
	P4 = 8360 (X);
	FP.H = 32786;
	FP.L = 57262;
	P4 = P5 + P4;
	P3 = 380 (X);
.L3:
	R0 = B [P5+16] (Z);
	R1 = 255 (X);
	cc =R0==R1;
	if cc jump .L2;
	R0 = P5;
	call (FP);
.L2:
	P5 = P5 + P3;
	cc =P5==P4;
	if !cc jump .L3 (bp);
	P5.H = _voice_records;
	P5.L = _voice_records;
	P4 = 15200 (X);
	FP.H = 32786;
	P4 = P5 + P4;
	FP.L = 57262;
	P3 = 380 (X);
.L5:
	R0 = B [P5+16] (Z);
	R1 = 255 (X);
	cc =R0==R1;
	if cc jump .L4;
	R0 = P5;
	call (FP);
.L4:
	P5 = P5 + P3;
	cc =P5==P4;
	if !cc jump .L5 (bp);
	SP += 12;
	FP = [SP++];
	RETS = [SP++];
	( p5:3 ) = [sp++];

	rts;
	.size	_voices_off, .-_voices_off
	.align 4
.global _voices_overload;
.type _voices_overload, STT_FUNC;
_voices_overload:
	R3 = R1;
	R1 = -1 (X);
	[--sp] = ( r7:7 );

	P2 = R0;
	R1.H = 32767;
	R2 = 0 (X);
	P0 = 380 (X);
	P1 = 22 (X);
	LSETUP (.L18, .L55) LC1 = P1;
.L18:
	R0 = B [P2+16] (Z);
	R7 = 255 (X);
	cc =R0==R7;
	if cc jump .L16;
	R0 = [P2+64];
	cc =R0<=3;
	if cc jump .L16;
	R0 = [P2+52];
	cc =R0<0;
	if cc jump .L50;
.L17:
	cc =R0<R1;
	if !cc jump .L16 (bp);
	R1 = R0;
	R2 = P2;
.L16:
.L55:
	P2 = P2 + P0;
	P2.H = _voice_records;
	P2.L = _voice_records;
	P0 = 380 (X);
	P1 = 40 (X);
	LSETUP (.L21, .L54) LC1 = P1;
.L21:
	R0 = B [P2+16] (Z);
	R7 = 255 (X);
	cc =R0==R7;
	if cc jump .L19;
	R0 = [P2+64];
	cc =R0<=3;
	if cc jump .L19;
	R0 = [P2+52];
	cc =R0<0;
	if cc jump .L51;
.L20:
	cc =R0<R1;
	if !cc jump .L19 (bp);
	R1 = R0;
	R2 = P2;
.L19:
.L54:
	P2 = P2 + P0;
	cc =R2==0;
	if cc jump .L52;
.L22:
	P2.H = 32786;
	R0 = R2;
	P2.L = 57262;
	( r7:7 ) = [sp++];

	jump (P2);
.L50:
	R7 = -1 (X);
	R7 <<= 31;
	cc =R0==R7;
	if cc jump .L16;
	R0 = -R0;
	jump.s .L17;
.L51:
	R7 = -1 (X);
	R7 <<= 31;
	cc =R0==R7;
	if cc jump .L19;
	R0 = -R0;
	jump.s .L20;
.L52:
	R0 = 10625 (X);
	R0 <<= 5;
	cc =R3<=R0 (iu);
	if cc jump .L15 (bp);
	P2.H = _voice_records;
	P2.L = _voice_records;
	R1 = 0 (X);
	P0 = 380 (X);
	P1 = 40 (X);
	LSETUP (.L25, .L53) LC1 = P1;
.L25:
	R0 = B [P2+16] (Z);
	R3 = 255 (X);
	cc =R0==R3;
	if cc jump .L24;
	R0 = [P2+64];
	cc =R0<=0;
	if cc jump .L24;
	R0 = [P2+24];
	cc =R0<=R1 (iu);
	if cc jump .L24 (bp);
	R2 = P2;
	R1 = R0;
.L24:
.L53:
	P2 = P2 + P0;
	cc =R2==0;
	if !cc jump .L22;
.L15:
	( r7:7 ) = [sp++];

	rts;
	.size	_voices_overload, .-_voices_overload
