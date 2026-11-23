/* made by tools/chime_build.py from chime.c: do not edit */
.file "chime.c";
	.text
	.align 4
.global _chime_block;
.type _chime_block, STT_FUNC;
_chime_block:
	P0.H = _chime_at;
	[--sp] = ( r7:4, p5:3 );

	P0.L = _chime_at;
	P5 = [P0];
	P1 = 19183 (X);
	P1 = P1 + P1;
	P2 = R0;
	cc =P5<=P1 (iu);
	if !cc jump .L1;
	cc =P2==0;
	if cc jump .L1;
	P1 = 64 (X);
	P1 = P5 + P1;
	P3 = 11025 (X);
	cc =P1<=P3 (iu);
	[P0] = P1;
	if cc jump .L1;
	P0 = -10961 (X);
	R1 = P5;
	R0 = -11025 (X);
	P5 = P5 + P0;
	R6 = -1 (X);
	P0.H = _phase;
	R5 = -1 (X);
	P4.H = _sine;
	R0 = R1 + R0;
	P0.L = _phase;
	R6.H = 16383;
	R5.H = 32767;
	P4.L = _sine;
.L17:
	R1 = -11026 (X);
	cc =R0<=R1 (iu);
	if !cc jump .L4;
.L32:
	R2 = 16316 (X);
	cc =R0<=R2 (iu);
	if cc jump .L19 (bp);
	R4 = -16317 (X);
	R3 = R0 + R4;
	R7 = 11024 (X);
	cc =R3<=R7 (iu);
	if !cc jump .L30;
.L6:
	R1 = 511 (X);
	cc =R3<=R1 (iu);
	if cc jump .L8 (bp);
	R4 = -10513 (X);
	R2 = R3 + R4;
	cc =R2<=R1 (iu);
	if !cc jump .L20 (bp);
	R7 = 11024 (X);
	R3 = R7 - R3;
	R3 <<= 18;
.L9:
	R1 = [P0];
	R4 = R1 >> 30;
	cc = !BITTST (R1,30);
	R2 = R1 & R6;
	I3 = R4;
	if !cc jump .L10 (bp);
	R7 = R2 >> 24;
	P1 = R7;
	P3 = P4 + (P1 << 1);
	R1 = W [P3] (X);
.L11:
	P1 = P4 + (P1 << 1);
	R7 = W [P1+2] (X);
	R2 >>= 8;
	R7 = R7 - R1;
	R2 = R2.L (Z);
	R2 *= R7;
.L12:
	R1 <<= 16;
	R1 = R1 + R2;
	R2 = I3;
	R2 >>= 1;
	cc =R2==0;
	if cc jump .L13 (bp);
	R1 = -R1;
.L13:
	A1 = R1.L * R3.L (FU);
	A1 = A1 >> 16;
	A0 = R1.H * R3.H, A1 += R1.H * R3.L (M);
	A1 += R3.H * R1.L (M);
	R2 = 16316 (X);
	A1 = A1 >>> 15;
	cc =R0<=R2 (iu);
	R1 = (A0 += A1);
	if cc jump .L22 (bp);
	R2.H = 3678;
	R2.L = 2674;
.L14:
	P3 = R2;
	P1 = [P0];
	R3 = [P2];
	R2 = R3 + R1;
	R7 = R3 ^ R2;
	R4 = R1 ^ R2;
	R7 = R7 & R4;
	P1 = P1 + P3;
	cc =R7<0;
	[P0] = P1;
	if !cc jump .L15 (bp);
	R3 >>>= 31;
	R2 = R3 ^ R5;
.L15:
	R3 = [P2+4];
	[P2] = R2;
	R2 = R3 + R1;
	R7 = R3 ^ R2;
	R1 = R1 ^ R2;
	R1 = R7 & R1;
	cc =R1<0;
	if cc jump .L31;
.L16:
	[P2+4] = R2;
.L7:
	R0 += 1;
	R7 = P5;
	cc =R0==R7;
	if cc jump .L1;
	R1 = -11026 (X);
	cc =R0<=R1 (iu);
	P2 += 8;
	if cc jump .L32 (bp);
.L4:
	P2 += 8;
	R0 += 1;
	jump.s .L17;
.L1:
	( r7:4, p5:3 ) = [sp++];

	rts;
.L31:
	R3 >>>= 31;
	R2 = R3 ^ R5;
	jump.s .L16;
.L19:
	R3 = R0;
	R7 = 11024 (X);
	cc =R3<=R7 (iu);
	if cc jump .L6 (bp);
.L30:
	R1 = 0 (X);
	[P0] = R1;
	jump.s .L7;
.L22:
	R2.H = 3752;
	R2.L = 22588;
	jump.s .L14;
.L10:
	R1 = 1 (X);
	R1 <<= 30;
	R2 = R1 - R2;
	R4 = R2 >> 24;
	P1 = R4;
	P3 = P4 + (P1 << 1);
	R1 = W [P3] (X);
	P3 = 64 (X);
	cc =P1==P3;
	if !cc jump .L11;
	R2 = 0 (X);
	jump.s .L12;
.L8:
	R3 <<= 18;
	jump.s .L9;
.L20:
	R3 = 1 (X);
	R3 <<= 27;
	jump.s .L9;
	.size	_chime_block, .-_chime_block
	.align 4
.global _chime_start;
.type _chime_start, STT_FUNC;
_chime_start:
	P2.H = _phase;
	R0 = 0 (X);
	P2.L = _phase;
	[P2] = R0;
	P2.H = _chime_at;
	P2.L = _chime_at;
	[P2] = R0;
	rts;
	.size	_chime_start, .-_chime_start
	.text
	.align 4
	.type	_phase, @object
	.size	_phase, 4
_phase:
	.zero	4
.global _chime_at;
	.align 4
	.type	_chime_at, @object
	.size	_chime_at, 4
_chime_at:
	.long	38367
	.text
	.align 2
	.type	_sine, @object
	.size	_sine, 130
_sine:
	.short	0
	.short	804
	.short	1608
	.short	2410
	.short	3212
	.short	4011
	.short	4808
	.short	5602
	.short	6393
	.short	7179
	.short	7962
	.short	8739
	.short	9512
	.short	10278
	.short	11039
	.short	11793
	.short	12539
	.short	13279
	.short	14010
	.short	14732
	.short	15446
	.short	16151
	.short	16846
	.short	17530
	.short	18204
	.short	18868
	.short	19519
	.short	20159
	.short	20787
	.short	21403
	.short	22005
	.short	22594
	.short	23170
	.short	23731
	.short	24279
	.short	24811
	.short	25329
	.short	25832
	.short	26319
	.short	26790
	.short	27245
	.short	27683
	.short	28105
	.short	28510
	.short	28898
	.short	29268
	.short	29621
	.short	29956
	.short	30273
	.short	30571
	.short	30852
	.short	31113
	.short	31356
	.short	31580
	.short	31785
	.short	31971
	.short	32137
	.short	32285
	.short	32412
	.short	32521
	.short	32609
	.short	32678
	.short	32728
	.short	32757
	.short	32767
