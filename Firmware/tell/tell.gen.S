/* made by tools/tell_build.py from tell.c: do not edit */
.file "tell.c";
	.text
	.align 4
.global _tell;
.type _tell, STT_FUNC;
_tell:
	[--sp] = ( r7:6, p5:4 );

	P2.H = 33029;
	LINK 128;
	P2.L = 40220;
	P5 = [P2];
	FP = R0;
	cc =P5==0;
	if !cc jump 4 (bp); jump.s .L1;
	cc =FP==0;
	if !cc jump 4 (bp); jump.s .L1;
	R0 = [FP+60];
	R1 = 16962 (X);
	cc =R0==R1;
	if cc jump 4; jump.s .L124;
	P2.H = 32770;
	P2.L = 33428;
	R7 = [P5+48];
	call (P2);
	P1.H = 52;
	P1.L = 24108;
	P5 = P5 + P1;
	[SP+36] = R0;
	R0 = 1 (X);
	B [SP+72] = R0;
	R0 = B [P5] (X);
	B [SP+73] = R0;
	P5.H = 32963;
	R0 = 0 (X);
	P0.H = 32963;
	B [SP+74] = R7;
	[SP+76] = R0;
	P5.L = 16236;
	P0.L = 16716;
	R2 = 0 (X);
	R1 = 0 (X);
	R3 = 0 (X);
	P2 = 168 (X);
	P1 = 8 (X);
	LSETUP (.L5, .L140) LC1 = P1;
.L5:
	R0 = [P0+160];
	cc =R0<=0;
	R0 = CC;
	BITTGL (R0, 0);
	R0 <<= R3;
	R1 = R0 | R1;
	B [SP+75] = R1;
	R0 = [P5];
	cc =R0<=0;
	R0 = CC;
	BITTGL (R0, 0);
	R0 <<= R3;
	R2 = R0 | R2;
	B [SP+76] = R2;
	R3 += 1;
	P0 = P0 + P2;
.L140:
	P5 += 60;
	cc =R7<=7 (iu);
	if !cc jump 4; jump.s .L125;
	I2.H = 32963;
	R6 = 0 (X);
	I2.L = 16236;
	[SP+40] = R6;
.L6:
	R6 = R7 << 1;
	R1 = ROT R6 BY 0 ||
	[SP+48] = R6 ||
	nop;
	R0.H = 32963;
	R1 = (R1 + R7) << 2;
	R0.L = 15892;
	P1 = 72 (X);
	R0 = R1 + R0;
	P1 = SP + P1;
	P4 = 80 (X);
	[SP+44] = R0;
	[SP+32] = P1;
	I1 = P1;
	P0 = SP + P4;
	P1 = R0;
	cc =R7<=7 (iu);
	R0 += 12;
	I0 = R0;
	P5 = P0;
	R2 = 0 (X);
	P2 = 12 (X);
	if cc jump .L8;
	LSETUP (.L7, .L139) LC1 = P2;
.L7:
.L139:
	B [P5++] = R2;
.L9:
	cc =R7<=7 (iu);
	if !cc jump .L13 (bp);
	P5.H = 32963;
	P5.L = 15808;
	R0 = B [P5] (X);
	P4 = I2;
	R0 = R0.B (Z);
	R1 = B [P4+45] (Z);
	R0 = -R0;
	R1 = -R1;
	R0 >>= 31;
	R1 >>= 31;
	R0 <<= 1;
	R0 = R1 | R0;
	B [SP+77] = R0;
	R6 = [SP+40];
	R0 = B [P4+44] (X);
	B [SP+78] = R0;
	cc =R6==0;
	R0 = B [SP+40] (X);
	B [SP+79] = R0;
	if cc jump .L13;
	R2 = W [SP+40] (Z);
	P2 = 72 (X);
	R2 <<= 2;
	P5 = P2 + SP;
	P2 = R2;
	P1 = I2;
	P5 += 20;
	P2 += -4;
	P2 = P2 >> 2;
	P2 += 1;
	LSETUP (.L14, .L138) LC1 = P2;
.L14:
	R0 = B [P1+4] (X);
	B [P5] = R0;
	R0 = B [P1+5] (X);
	B [P5+1] = R0;
	R0 = B [P1+6] (X);
	B [P5+2] = R0;
	R0 = B [P1+7] (X);
	B [P5+3] = R0;
	P1 += 4;
.L138:
	P5 += 4;
	P2 = R2;
	P2 += 20;
.L12:
	P5.H = _told_ms;
	P4.H = _last_n;
	P5.L = _told_ms;
	R0 = [P5];
	P4.L = _last_n;
	R6 = [SP+36];
	R6 = R6 - R0;
	R1 = [P4];
	R0 = P2;
	cc =R1==R0;
	I3 = R6;
	if cc jump 4 (bp); jump.s .L15;
	P1 = 72 (X);
	P1 = P1 + SP;
	R0.H = _last;
	I0 = P1;
	M0 = P2;
	R0.L = _last;
	I0 += M0;
	P5 = P2;
	LSETUP (.L17, .L137) LC1 = P5;
.L17:
	P4 = R0;
	R1 = B [P1] (Z);
	R2 = B [P4] (Z);
	cc =R1==R2;
	if !cc jump .L16;
	P1 += 1;
.L137:
	R0 += 1;
	R1 = I3;
	R2 = 999 (X);
	cc =R1<=R2 (iu);
	if cc jump .L20;
.L19:
	P4 = [SP+32];
	P5.H = _last;
	P1 = I0;
	P5.L = _last;
	P1 -= P4;
	LSETUP (.L21, .L136) LC1 = P1;
.L21:
	P4 = I1;
	R0 = B [P4++] (X);
	I1 = P4;
.L136:
	B [P5++] = R0;
	P1.H = _told_ms;
	R6 = [SP+36];
	P1.L = _told_ms;
	P5.H = _last_n;
	[P1] = R6;
	P5.L = _last_n;
	P1.H = 33025;
	[P5] = P2;
	R1 = [FP+56];
	P1.L = 33568;
	R0 = [P1];
	[SP+20] = R1;
	R1 = [FP+52];
	R2 = P2;
	P2 = 72 (X);
	[SP+16] = R1;
	P2 = P2 + SP;
	R1 = 112 (X);
	P1.H = 32772;
	[SP+12] = R1;
	[SP+28] = R3;
	[SP+24] = P0;
	R1 = P2;
	P1.L = 7852;
	call (P1);
	P0 = [SP+24];
	R3 = [SP+28];
.L20:
	cc =R7<=7 (iu);
	if !cc jump .L1 (bp);
	P4 = R7;
	M0.H = 32963;
	M0.L = 16052;
	R6 = 8 (X);
	R0 = B [SP+73] (Z);
	P5 = P4 + (P4 << 2);
	P5 = P4 + (P5 << 1);
	I3 = P5;
	I3 += M0;
	P1 = I3;
	R1 = B [P1] (X);
	R2 = R1.B (Z);
	cc =R2<=R6 (iu);
	if cc jump .L22 (bp);
	R1 = 6 (X);
	cc =R0==R1;
	if !cc jump 4 (bp); jump.s .L126;
.L23:
	P1.H = _red_n;
	P1.L = _red_n;
	R0 = 0 (X);
	[P1] = R0;
.L42:
	R6 = [SP+48];
	R1 = R6 + R7;
	R0 = R1 << 3 ||
	R6 = [SP+36] ||
	nop;
	R0 = R0 - R1;
	R1.H = 32963;
	R0 <<= 3;
	R1.L = 16716;
	R1 = R0 + R1;
	P2 = R1;
	P4.H = _ball_ms;
	P4.L = _ball_ms;
	R0 = [P4];
	R0 = R6 - R0;
	P1 = [P2+160];
	R1 = P1;
	R1 += -1;
	cc =R1<=7 (iu);
	I2 = P1;
	if cc jump .L43 (bp);
	R1 = 34 (X);
	cc =R0<=R1 (iu);
	if cc jump .L1;
	P1.H = 32963;
	P1.L = 15888;
	R2 = [P1];
	cc =R2==-1;
	I3 = R2;
	if cc jump .L127;
	I2 = 0 (X);
.L44:
	P1 = [SP+44];
	R1 = 1796 (X);
	R2 = 0 (X);
	P5 = 31 (X);
	R0 = B [P1+7] (Z);
	R0 = R0.L * R1.L (IS);
	R0 >>>= 16;
	P4 = R0;
	P1.H = _DIV;
	P1.L = _DIV;
	P1 = P1 + P4;
	R0 = B [P1] (Z);
	I1 = R0;
	P1 = 32 (X);
	R0 = 0 (X);
	LSETUP (.L48, .L135) LC1 = P1;
.L48:
	R6 = P5;
	R1 = I3;
	R1 >>= R6;
	R6 = 1 (X);
	R1 = R1 & R6;
	R0 <<= 1;
	R0 = R1 | R0;
	R1 = I1;
	cc =R1<=R0 (iu);
	R2 <<= 1;
	if !cc jump .L47 (bp);
	R0 = R0 - R1;
	BITSET (R2, 0);
.L47:
.L135:
	P5 += -1;
	R6 = [SP+40];
	cc =R6==0;
	if !cc jump .L49 (bp);
	R2 = 0 (X);
.L49:
	R0 = I2;
	cc =R0==0;
	if cc jump .L45 (bp);
	R1 = R2 >> 8;
	B0 = R1;
	R1 = R2 >> 16;
	I1 = R1;
	P5.H = _had;
	R1 = R2 >> 24;
	B2.H = _last_at;
	P1 = R1;
	I3 = R2;
	R1 = 1 (X);
	P5.L = _had;
	B2.L = _last_at;
.L46:
	B [P5] = R1;
	R0 = R0.B (Z);
	P5 = B2;
	R0 <<= 8;
	R1 = R7.B (Z);
	[P5] = R2;
	R2 = B [P2+166] (Z);
	R2 <<= 16;
	R1 = R1 | R0;
	R7 = B [P2+167] (Z);
	R7 <<= 24;
	R1 = R1 | R2;
	P4.H = _ball_ms;
	R1 = R1 | R7;
	R6 = [SP+36];
	R0 = B0;
	P4.L = _ball_ms;
	R2 = R0.B (Z);
	[P4] = R6;
	[SP+72] = R1;
	R6 = I1;
	R1 = I3;
	R2 <<= 8;
	R0 = R1.B (Z);
	R1 = R6.B (Z);
	R0 = R0 | R2;
	R1 <<= 16;
	R2 = P1;
	R2 <<= 24;
	R0 = R0 | R1;
	R7 = I2;
	R0 = R0 | R2;
	cc =R7==0;
	[SP+76] = R0;
	if cc jump .L51;
	R0 = 20 (X);
	R0 = R0.L * R7.L (FU);
	R0 += -20;
	R1.H = 3276;
	R1.L = 52429;
	R0 >>= 2;
	R0 *= R1;
	R1 = -1 (X);
	R1.H = 16383;
	R0 = R0 & R1;
	P1 = R0;
	P1 += 1;
	LSETUP (.L56, .L134) LC1 = P1;
.L56:
	R2 = -1 (X);
	R1 = [P2];
	R2.H = 255;
	cc =R1<=R2;
	R0 = R1 >>> 17;
	if !cc jump .L68;
	R6 = -127 (X);
	cc =R0<R6;
	if !cc jump .L52 (bp);
	R0 = -127 (X);
.L52:
	B [P0] = R0;
	R7 = -1 (X);
	R1 = [P2+4];
	R7.H = 255;
	cc =R1<=R7;
	R0 = R1 >>> 17;
	if !cc jump .L70;
	R1 = -127 (X);
	cc =R0<R1;
	if !cc jump .L53 (bp);
	R0 = -127 (X);
.L53:
	B [P0+1] = R0;
	R2 = -1 (X);
	R1 = [P2+8];
	R2.H = 2047;
	cc =R1<=R2;
	R0 = R1 >>> 20;
	if !cc jump .L72;
	R6 = -127 (X);
	cc =R0<R6;
	if !cc jump .L54 (bp);
	R0 = -127 (X);
.L54:
	B [P0+2] = R0;
	R7 = -1 (X);
	R1 = [P2+12];
	R7.H = 2047;
	cc =R1<=R7;
	R0 = R1 >>> 20;
	if !cc jump .L74;
	R1 = -127 (X);
	cc =R0<R1;
	if !cc jump .L55 (bp);
	R0 = -127 (X);
.L55:
	B [P0+3] = R0;
	R0 = B [P2+16] (X);
	B [P0+4] = R0;
	R0 = B [P2+17] (X);
	B [P0+5] = R0;
	P2 += 20;
.L134:
	P0 += 6;
	R3 = 6 (X);
	R2 = I2;
	R3 = R3.L * R2.L (FU);
	R3 += 8;
.L51:
	P2.H = 33025;
	R1 = [FP+56];
	P2.L = 33568;
	R0 = [P2];
	[SP+20] = R1;
	R1 = [FP+52];
	P1 = 72 (X);
	[SP+16] = R1;
	P1 = P1 + SP;
	R1 = 113 (X);
	P2.H = 32772;
	[SP+12] = R1;
	R2 = R3;
	R1 = P1;
	P2.L = 7852;
	call (P2);
.L1:
	P1 = 128 (X);
	SP = SP + P1;
	FP = [SP++];
	RETS = [SP++];
	( r7:6, p5:4 ) = [sp++];

	rts;
.L124:
	P2.H = _red_n;
	R0 = 0 (X);
	P2.L = _red_n;
	[P2] = R0;
	P2.H = _last_n;
	P2.L = _last_n;
	P1 = 128 (X);
	[P2] = R0;
	SP = SP + P1;
	FP = [SP++];
	RETS = [SP++];
	( r7:6, p5:4 ) = [sp++];

	rts;
.L8:
	R0 = B [P1++] (X);
	P2 = I0;
	cc =P1==P2;
	B [P5++] = R0;
	if cc jump .L9;
	R0 = B [P1++] (X);
	P2 = I0;
	cc =P1==P2;
	B [P5++] = R0;
	if !cc jump .L8 (bp);
	jump.s .L9;
.L125:
	R0 = R7 << 4;
	R0 = R0 - R7;
	P2 = R0;
	P0.H = 32963;
	P0.L = 16236;
	R0 = 8 (X);
	P2 = P0 + (P2 << 2);
	R6 = [P2];
	cc =R6<=R0 (iu);
	I2 = P2;
	[SP+40] = R6;
	if !cc jump 4 (bp); jump.s .L6;
	R6 = 0 (X);
	[SP+40] = R6;
	jump.s .L6;
.L13:
	P2 = 20 (X);
	jump.s .L12;
.L16:
	R6 = I3;
	R0 = 999 (X);
	cc =R6<=R0 (iu);
	if !cc jump .L19 (bp);
.L59:
	R0 = I3;
	R1 = 74 (X);
	cc =R0<=R1 (iu);
	if cc jump .L20 (bp);
.L121:
	P1 = 72 (X);
	P1 = P1 + SP;
	I0 = P1;
	M0 = P2;
	I0 += M0;
	jump.s .L19;
.L22:
	R6 = 6 (X);
	cc =R0==R6;
	if cc jump .L25;
	cc =R2==0;
	if cc jump .L23;
.L25:
	I0 = R2;
	M0 = 12 (X);
	I2 = R2;
	I0 += M0;
.L24:
	P1.H = 32963;
	P1.L = 15888;
	R0 = [P1];
	P1.H = 32963;
	P1.L = 15808;
	B1 = R0;
	R0 = B [P1] (X);
	R2 = R7.B (Z);
	R0 = R0.B (Z);
	R1 <<= 8;
	R1 = R2 | R1;
	P1 = I3;
	cc =R0==0;
	R2 = CC;
	W [SP+52] = R1;
	R1 = B [P1+10] (Z);
	R1 = -R1;
	BITTGL (R2, 0);
	R1 >>= 31;
	R2 <<= 1;
	R1 = R1 | R2;
	B [SP+54] = R1;
	R1 = R7 << 3;
	P1 = R1;
	P2.H = 32963;
	R1 = I2;
	P2.L = 15988;
	cc =R1==0;
	P1 = P1 + P2;
	if cc jump .L64 (bp);
	cc =R0==0;
	if cc jump .L128 (bp);
.L64:
	I1 = -1 (X);
.L27:
	P2 = SP;
	P2 += 52;
	R2 = I1;
	R0 = P2;
	B [SP+55] = R2;
	R0 += 4;
	P5 = 8 (X);
	LSETUP (.L30, .L133) LC1 = P5;
.L30:
	P4 = R0;
	R1 = B [P1++] (X);
	B [P4++] = R1;
.L133:
	R0 = P4;
	R0 = I2;
	cc =R0==0;
	if cc jump .L35;
	P5 = I3;
	R0 = P2;
	P5 += 1;
	R0 += 12;
	P1 = I2;
	LSETUP (.L34, .L132) LC1 = P1;
.L34:
	P4 = R0;
	R1 = B [P5++] (X);
	B [P4++] = R1;
.L132:
	R0 = P4;
.L35:
	P1.H = _red_n;
	P1.L = _red_n;
	R0 = [P1];
	cc =R0==0;
	if !cc jump .L32 (bp);
	R1.H = _red_ms;
	R1.L = _red_ms;
.L33:
	R0 = 1 (X);
	R2 = I0;
	P5.H = _red_last;
	R2 = max(R0,R2);
	P5.L = _red_last;
	P1 = R2;
	LSETUP (.L41, .L131) LC1 = P1;
.L41:
	R0 = B [P2++] (X);
.L131:
	B [P5++] = R0;
	P1.H = _red_n;
	P2 = I0;
	P1.L = _red_n;
	[P1] = P2;
	P1 = R1;
	R6 = [SP+36];
	R2 = [FP+56];
	R1 = SP;
	R1 += 52;
	[P1] = R6;
	P1.H = 33025;
	P1.L = 33568;
	R0 = [P1];
	[SP+20] = R2;
	R2 = [FP+52];
	[SP+16] = R2;
	P1.H = 32772;
	R2 = 114 (X);
	[SP+12] = R2;
	[SP+28] = R3;
	[SP+24] = P0;
	R2 = I0;
	P1.L = 7852;
	call (P1);
	P0 = [SP+24];
	R3 = [SP+28];
	jump.s .L42;
.L43:
	R1 = 54 (X);
	cc =R0<=R1 (iu);
	if cc jump .L1;
	P1.H = 32963;
	P1.L = 15888;
	R2 = [P1];
	cc =R2==-1;
	I3 = R2;
	if !cc jump .L44 (bp);
	P5.H = _had;
	B2.H = _last_at;
	R0 = I2;
	P1 = 0 (X);
	I1 = 0 (X);
	B0 = 0 (X);
	I3 = 0 (X);
	R1 = 1 (X);
	R2 = 0 (X);
	P5.L = _had;
	B2.L = _last_at;
	jump.s .L46;
.L127:
	R2 = 0 (X);
.L45:
	P5.H = _had;
	P5.L = _had;
	R0 = B [P5] (Z);
	B2.H = _last_at;
	cc =R0==0;
	B2.L = _last_at;
	if !cc jump .L50 (bp);
	P1 = B2;
	R0 = [P1];
	cc =R0==R2;
	if cc jump .L1;
.L50:
	R0 = R2 >> 8;
	R1 = R2 >> 16;
	B0 = R0;
	R0 = R2 >> 24;
	I1 = R1;
	P1 = R0;
	I3 = R2;
	R0 = 0 (X);
	R1 = 0 (X);
	I2 = 0 (X);
	jump.s .L46;
.L32:
	R1 = I0;
	cc =R0==R1;
	if !cc jump .L36;
	B0.H = _red_last;
	R2 = I0;
	R0 = 1 (X);
	B0.L = _red_last;
	R2 = max(R0,R2);
	R1 = B0;
	P5 = P2;
	P1 = R2;
	LSETUP (.L38, .L130) LC1 = P1;
.L38:
	P4 = R1;
	R0 = B [P5] (Z);
	R2 = B [P4] (Z);
	cc =R2==R0;
	if !cc jump .L37;
	R1 += 1;
.L130:
	P5 += 1;
	R1.H = _red_ms;
	R1.L = _red_ms;
	P1 = R1;
	R6 = [SP+36];
	R2 = 999 (X);
	R0 = [P1];
	R0 = R6 - R0;
	cc =R0<=R2 (iu);
	if !cc jump .L33 (bp);
	jump.s .L42;
.L37:
	R1.H = _red_ms;
	R1.L = _red_ms;
	P1 = R1;
	R6 = [SP+36];
	R2 = 999 (X);
	R0 = [P1];
	R0 = R6 - R0;
	cc =R0<=R2 (iu);
	if !cc jump .L33 (bp);
.L58:
	R2 = I1;
	R2 = R2.B (Z);
	P1 = B0;
	R6 = R2;
	R2 = B [P1+3] (Z);
	cc =R6==R2;
	if cc jump .L65 (bp);
	R2 = 35 (X);
.L40:
	cc =R2<=R0 (iu);
	if cc jump .L33 (bp);
	jump.s .L42;
.L128:
	R2 = B1;
	cc =R2==-1;
	if cc jump .L64;
	R2 = 1796 (X);
	R1 = B [P1+1] (Z);
	R1 = R1.L * R2.L (IS);
	R1 >>>= 16;
	P2 = R1;
	P5.H = _DIV;
	P5.L = _DIV;
	R2 = 0 (X);
	P5 = P5 + P2;
	R1 = B [P5] (Z);
	B0 = R1;
	P2 = 31 (X);
	P5 = 32 (X);
	LSETUP (.L29, .L129) LC1 = P5;
.L29:
	R6 = P2;
	R1 = B1;
	R1 >>= R6;
	R6 = 1 (X);
	R1 = R1 & R6;
	R0 <<= 1;
	R0 = R1 | R0;
	R1 = B0;
	cc =R0<R1 (iu);
	R2 <<= 1;
	if cc jump .L28 (bp);
	R0 = R0 - R1;
	BITSET (R2, 0);
.L28:
.L129:
	P2 += -1;
	R0 = 15 (X);
	R0 = R2 & R0;
	I1 = R0;
	jump.s .L27;
.L74:
	R0 = 127 (X);
	jump.s .L55;
.L68:
	R0 = 127 (X);
	jump.s .L52;
.L72:
	R0 = 127 (X);
	jump.s .L54;
.L70:
	R0 = 127 (X);
	jump.s .L53;
.L126:
	I0 = 12 (X);
	I2 = 0 (X);
	R1 = 0 (X);
	jump.s .L24;
.L15:
	cc =R1==0;
	if cc jump .L121 (bp);
	R1 = 999 (X);
	cc =R6<=R1 (iu);
	if cc jump .L59 (bp);
	jump.s .L121;
.L65:
	R2 = 75 (X);
	jump.s .L40;
.L36:
	R1.H = _red_ms;
	R1.L = _red_ms;
	P4 = R1;
	R6 = [SP+36];
	R2 = 999 (X);
	R0 = [P4];
	R0 = R6 - R0;
	cc =R0<=R2 (iu);
	if !cc jump .L33 (bp);
	B0.H = _red_last;
	B0.L = _red_last;
	jump.s .L58;
	.size	_tell, .-_tell
	.text
	.align 4
	.type	_red_ms, @object
	.size	_red_ms, 4
_red_ms:
	.zero	4
	.align 4
	.type	_red_n, @object
	.size	_red_n, 4
_red_n:
	.zero	4
	.align 4
	.type	_red_last, @object
	.size	_red_last, 20
_red_last:
	.zero	20
	.text
	.align 4
	.type	_DIV, @object
	.size	_DIV, 7
_DIV:
	.base64	"YEAwIBgQDA=="
	.text
	.type	_had, @object
	.size	_had, 1
_had:
	.zero	1
	.align 4
	.type	_last_at, @object
	.size	_last_at, 4
_last_at:
	.zero	4
	.align 4
	.type	_ball_ms, @object
	.size	_ball_ms, 4
_ball_ms:
	.zero	4
	.align 4
	.type	_told_ms, @object
	.size	_told_ms, 4
_told_ms:
	.zero	4
	.align 4
	.type	_last_n, @object
	.size	_last_n, 4
_last_n:
	.zero	4
	.align 4
	.type	_last, @object
	.size	_last, 56
_last:
	.zero	56
