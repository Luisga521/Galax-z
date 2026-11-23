/* made by tools/pages_build.py from pages.c: do not edit */
.file "pages.c";
	.text
	.align 4
.type _sin31, STT_FUNC;
_sin31:
	R1 = R0;
	R0 = -1 (X);
	R0.H = 16383;
	cc = !BITTST (R1,30);
	R0 = R1 & R0;
	R3 = R1 >> 30;
	if !cc jump .L2 (bp);
	R1 = R0 >> 24;
	P2 = R1;
	P1.H = _sine;
	P1.L = _sine;
	P0 = P1 + (P2 << 1);
	R1 = W [P0] (X);
.L3:
	P2 = P1 + (P2 << 1);
	R2 = W [P2+2] (X);
	R0 >>= 8;
	R2 = R2 - R1;
	R0 = R0.L (Z);
	R2 *= R0;
.L4:
	R3 >>= 1;
	R0 = R1 << 16;
	cc =R3==0;
	R0 = R0 + R2;
	if cc jump .L1 (bp);
	R0 = -R0;
.L1:
	rts;
.L2:
	R1 = 1 (X);
	R1 <<= 30;
	R0 = R1 - R0;
	R1 = R0 >> 24;
	P2 = R1;
	P1.H = _sine;
	P1.L = _sine;
	P0 = P1 + (P2 << 1);
	R1 = W [P0] (X);
	P0 = 64 (X);
	cc =P2==P0;
	if !cc jump .L3;
	R2 = 0 (X);
	jump.s .L4;
	.size	_sin31, .-_sin31
	.align 4
.type _set_lock, STT_FUNC;
_set_lock:
	P2 = R0;
	[--sp] = ( r7:7, p5:5 );

	P0 = R1;
	R3 = R2;
	P1 = [P2+68];
	P2 = 159 (X);
	cc =P1<=P2 (iu);
	if !cc jump .L11;
	P5 = R2;
	P2 = P0 + (P0 << 1);
	I0.H = _locked;
	I0.L = _locked;
	P5 = P5 + (P2 << 2);
	P2 = P1 + (P1 << 1);
	R0 = P5;
	R1 = P2;
	R1 <<= 9;
	R0 <<= 4;
	R0 = R0 + R1;
	R1 = -8143 (X);
	R1 <<= 18;
	R0 = R0 + R1;
	R1 = P1;
	R1 <<= 3;
	P2 = R1;
	P5 = I0;
	P2 = (P2 + P0) << 1;
	P2 = P5 + P2;
	R2 = W [P2] (X);
	I1 = R2;
	R2 = R2.L (Z);
	R2 >>>= R3;
	cc = !BITTST (R2,0);
	if !cc jump .L13 (bp);
	P1 = R0;
	R2 = -1 (X);
	P2 = 16 (X);
	LSETUP (.L14, .L16) LC1 = P2;
.L14:
.L16:
	B [P1++] = R2;
	P1 = R1;
	R1 = 1 (X);
	R1 <<= R3;
	R2 = I1;
	R1 = R1 | R2;
	P0 = (P0 + P1) << 1;
	M0 = P0;
	I0 += M0;
	W [I0] = R1.L;
.L13:
	P1 = R0;
	P2 = [SP+20];
	R0 = [SP+24];
	R1 = 254 (X);
	R0 = min(R0,R1);
	P2 = P1 + P2;
	B [P2] = R0;
.L11:
	( r7:7, p5:5 ) = [sp++];

	rts;
	.size	_set_lock, .-_set_lock
	.align 4
.type _write, STT_FUNC;
_write:
	P1 = R0;
	[--sp] = ( r7:7, p5:5 );

	[--SP] = RETS;
	R2 = R0;
	SP += -36;
	R0 = [P1+68];
	R0 <<= 3;
	R0 = R2 + R0;
	P2 = R0;
	P0 = R1;
	R3 = [P2+1680];
	cc =R3==0;
	if cc jump .L17;
	R0 = B [P0+8] (Z);
	P1 = R0;
	P2.H = 33041;
	P2.L = 12520;
	I2 = R0;
	R1 = B [P0+9] (X);
	P1 = P2 + (P1 << 2);
	P5 = [P1];
	P1 = R0;
	R0 = W [P0] (X);
	I1 = R0;
	P2 = P2 + (P1 << 2);
	P1 = [P2+4];
	cc =P5<P1;
	if !cc jump .L27;
	R7 = I1;
	R0 = 55 (X);
	R0 = R7.L * R0.L (IS);
	R7 = P5;
	R0 = R0 + R7;
	R0 <<= 3;
	P2 = R0;
	R0 = 196 (X);
	R3 = R3 + R0;
	P5 = R3;
	R1 = R1.B (Z);
	P2 = P2 + P5;
	P5 = R7;
	P1 -= P5;
	LSETUP (.L20, .L28) LC1 = P1;
.L20:
	R0 = B [P2] (Z);
	cc =R0==R1;
	if cc jump .L17;
.L28:
	P2 += 8;
.L19:
	R0.H = 52;
	R0.L = 25184;
	R0 = R2 + R0;
	R2 = R2 -|- R2 ||
	[SP+20] = R1 ||
	nop;
	[SP+32] = R2;
	R2 = [P0+4];
	[SP+28] = R2;
	R2 = B [P0+10] (Z);
	R1 = W [P0+2] (X);
	[SP+24] = R2;
	R2 = I1;
	[SP+16] = R1;
	P2.H = 32785;
	R1 = R2.L (X);
	[SP+12] = R1;
	R2 = I2;
	R1 = 2 (X);
	P2.L = 52572;
	call (P2);
.L17:
	SP += 36;
	RETS = [SP++];
	( r7:7, p5:5 ) = [sp++];

	rts;
.L27:
	R1 = R1.B (Z);
	jump.s .L19;
	.size	_write, .-_write
	.align 4
.type _our_page, STT_FUNC;
_our_page:
	P2 = R0;
	cc =P2==0;
	if cc jump .L35;
	P1.H = 52;
	P1.L = 24108;
	P1 = P2 + P1;
	R0 = [P1];
	R1 = 4 (X);
	cc =R0==R1;
	if !cc jump .L31;
	R0 = [P2+48];
	cc =R0<=7 (iu);
	R0 = CC;
	R0 += -1;
.L29:
	rts;
.L31:
	R1 = 5 (X);
	cc =R0==R1;
	if !cc jump .L32;
	R1 = [P2+48];
	cc =R1<=7 (iu);
	R0 = 1 (X);
	if cc jump .L29 (bp);
.L35:
	R0 = -1 (X);
	rts;
.L32:
	R1 = 6 (X);
	cc =R0==R1;
	if !cc jump .L35;
	R1 = [P2+48];
	cc =R1<=7 (iu);
	R0 = 2 (X);
	if !cc jump .L35;
	rts;
	.size	_our_page, .-_our_page
	.align 4
.type _play.part.0, STT_FUNC;
_play.part.0:
	[--sp] = ( r7:4, p5:4 );

	P5 = R0;
	LINK 72;
	R6 = R1;
	P4 = R2;
	FP = [SP+116];
	R0 = [P5+68];
	R0 <<= 3;
	P0 = R0;
	R5 = [SP+120];
	P2 = P5 + P0;
	P2 = [P2+1680];
	cc =P2==0;
	if cc jump .L52;
	R1 = 12 (X);
	R1 = R1.L * R6.L (IS);
	P1 = R1;
	R1 = 9 (X);
	P2 = P2 + P1;
	R0 = B [P2+6] (X);
	R3 = R0.B (Z);
	cc =R3==R1;
	if cc jump .L51;
	R0 += -1;
	R0 = R0.B (Z);
	cc =R0<=7 (iu);
	if cc jump .L39;
.L52:
	R3 = 1 (X);
.L39:
	R7 = 0 (X);
	R2 = 31 (X);
	R0 = 0 (X);
	R4 = 1 (X);
	P2 = 32 (X);
	LSETUP (.L41, .L65) LC1 = P2;
.L41:
	R1 = R5;
	R1 >>= R2;
	R0 <<= 1;
	R1 = R1 & R4;
	R0 = R1 | R0;
	cc =R3<=R0 (iu);
	R7 <<= 1;
	if !cc jump .L40 (bp);
	R0 = R0 - R3;
	BITSET (R7, 0);
.L40:
.L65:
	R2 += -1;
	R0 = R0 -|- R0 ||
	[SP+24] = R7 ||
	nop;
	R1 = 8192 (X);
	[SP+48] = R0;
	[SP+44] = R0;
	[SP+40] = R1;
	[SP+32] = R0;
	R1 = -1 (X);
	R0 = 1 (X);
	P2.H = 32784;
	[SP+36] = R1;
	[SP+28] = R0;
	[SP+20] = FP;
	R0 = P5;
	[SP+16] = P4;
	[SP+12] = P4;
	R2 = P4;
	R1 = R6;
	P2.L = 51348;
	call (P2);
	R0 = B [P5+28] (Z);
	cc =R0==0;
	if cc jump .L38 (bp);
	R0 = B [P5+31] (X);
	R1 = B [P5+29] (X);
	R0 = R0 | R1;
	R0 = R0.B (Z);
	cc =R0==0;
	if cc jump .L38 (bp);
	R0 = [P5+48];
	cc =R6==R0;
	if cc jump .L62;
.L38:
	SP += 60;
	SP += 12;
	FP = [SP++];
	RETS = [SP++];
	( r7:4, p5:4 ) = [sp++];

	rts;
.L51:
	R3 = 16 (X);
	jump.s .L39;
.L62:
	R0 = [P5+124];
	R2 = 31 (X);
	cc =R0==R2;
	if !cc jump .L38 (bp);
	P2.H = 52;
	P2.L = 25200;
	P2 = P5 + P2;
	R0 = [P2];
	cc =R0==0;
	if !cc jump .L38 (bp);
	R0 = SP;
	R0 += 56;
	R2 = SP;
	P2.H = 32784;
	[SP+12] = R0;
	R1 = R6;
	R0 = P5;
	R2 += 52;
	P2.L = 44920;
	call (P2);
	R1 = [SP+52];
	R0 = 15 (X);
	cc =R1<=R0 (iu);
	if !cc jump .L38;
	P1.H = _ntakes;
	P1.L = _ntakes;
	P0 = [P1];
	cc =P0<=0;
	if cc jump .L43;
	R3.H = _takes;
	R3.L = _takes;
	P2 = R3;
	P1 = P0;
	LSETUP (.L45, .L64) LC1 = P1;
.L45:
	R0 = B [P2+8] (Z);
	cc =R6==R0;
	if cc jump .L63;
.L44:
.L64:
	P2 += 12;
	R0 = [SP+56];
	R1 = R1.L (Z);
	R5 = P4;
	P1 = 16 (X);
	R1.H = R0.L << 0;
	R5 <<= 8;
	R0 = R6.B (Z);
	cc =P0==P1;
	R2 = R1;
	R0 = R0 | R5;
	if cc jump .L48;
.L47:
	R1 = P0;
	P2.H = _ntakes;
	P2.L = _ntakes;
	P0 = P0 + (P0 << 1);
	R1 += 1;
	[P2] = R1;
	P2 = P0 << 2;
	P0 = R3;
	SP += 60;
	SP += 12;
	P1 = P0 + P2;
	W [P1+8] = R0;
	R0 = FP;
	B [P1+10] = R0;
	R0 = 0 (X);
	[P1] = R2;
	[P1+4] = R7;
	B [P1+11] = R0;
	FP = [SP++];
	RETS = [SP++];
	( r7:4, p5:4 ) = [sp++];

	rts;
.L63:
	R0 = W [P2] (X);
	cc =R1==R0;
	if !cc jump .L44 (bp);
	R0 = B [P2+9] (Z);
	R2 = P4;
	cc =R2==R0;
	if !cc jump .L44 (bp);
	jump.s .L38;
.L48:
	[SP+60] = R1;
	R1 = FP;
	W [SP+68] = R0;
	B [SP+70] = R1;
	R0 = 0 (X);
	R1 = SP;
	B [SP+71] = R0;
	R1 += 60;
	R0 = P5;
	[SP+64] = R7;
	call _write;
	jump.s .L38;
.L43:
	R0 = [SP+56];
	R1 = R1.L (Z);
	R5 = P4;
	R1.H = R0.L << 0;
	R5 <<= 8;
	R0 = R6.B (Z);
	R3.H = _takes;
	R2 = R1;
	R0 = R0 | R5;
	R3.L = _takes;
	jump.s .L47;
	.size	_play.part.0, .-_play.part.0
	.align 4
.global _pages_tick;
.type _pages_tick, STT_FUNC;
_pages_tick:
	[--sp] = ( r7:4, p5:3 );

	P4 = R0;
	LINK 148;
	cc =P4==0;
	if cc jump .L66;
	P5.H = _hands;
	P5.L = _hands;
	R0 = [P5];
	cc =R0==0;
	if cc jump .L433 (bp);
	P2.H = 32770;
	P2.L = 33428;
	call (P2);
	P3.H = _hand_ms;
	R5 = R0;
	P3.L = _hand_ms;
	R7 = 0 (X);
	R0 = B [P4+28] (Z);
.L72:
	R2 = [P5];
	R1 = R2;
	R1 >>>= R7;
	cc = !BITTST (R1,0);
	if cc jump .L70 (bp);
	R1 = [P3];
	R1 = R5 - R1;
	R3 = 999 (X);
	cc =R1<=R3 (iu);
	if !cc jump .L71 (bp);
	cc =R0==0;
	if cc jump .L71 (bp);
	R1 = B [P4+31] (X);
	R3 = B [P4+29] (X);
	R1 = R1 | R3;
	R1 = R1.B (Z);
	cc =R1==0;
	if cc jump .L71 (bp);
	P2.H = _hand_track;
	P2.L = _hand_track;
	P2 = [P2];
	R1 = [P4+48];
	R4 = P2;
	cc =R4==R1;
	if !cc jump 6 (bp); jump.l .L434;
.L71:
	R1 = 1 (X);
	R1 <<= R7;
	R1 = ~R1;
	R1 = R1 & R2;
	[P5] = R1;
.L70:
	R7 += 1;
	R1 = 12 (X);
	cc =R7==R1;
	P3 += 4;
	if !cc jump .L72 (bp);
	jump.s .L69;
.L256:
	P2.H = _touched;
	R0 = 0 (X);
	P2.L = _touched;
	B [P2] = R0;
	P2.H = _shift_held;
	P2.L = _shift_held;
	B [P2] = R0;
.L66:
	P1 = 148 (X);
	SP = SP + P1;
	FP = [SP++];
	RETS = [SP++];
	( r7:4, p5:3 ) = [sp++];

	rts;
.L433:
	R0 = B [P4+28] (Z);
.L69:
	M0.H = 52;
	P2.H = 65483;
	I2 = P4;
	M0.L = 23866;
	P2.L = 41670;
	I2 += M0;
	R7.H = _knob;
	P2 -= P4;
	FP.H = _locked;
	P3.H = 32964;
	I3.H = _now;
	R6 = I2;
	R7.L = _knob;
	I1 = P2;
	FP.L = _locked;
	P3.L = 0;
	I3.L = _now;
	I0 = 0 (X);
	P0 = 8 (X);
	LSETUP (.L307, .L480) LC0 = P0;
	jump.s .L76;
.L307:
	R0 = B [P4+28] (Z);
.L76:
	R3 = I0;
	R1 = I1;
	R2 = R3.L (Z);
	cc =R0==0;
	R5 = R1 + R6;
	R2 <<= 4;
	P0 = I3;
	R1 = 0 (X);
	P1 = 12 (X);
	LSETUP (.L306, .L479) LC1 = P1;
	if !cc jump .L435 (bp);
	jump.s .L73;
.L306:
	R0 = B [P4+28] (Z);
	cc =R0==0;
	if !cc jump .L435 (bp);
.L73:
	R0 = R7 + R1;
	P2 = R0;
	R0 = B [P2] (X);
.L74:
	B [P0++] = R0;
	R1 += 1;
.L479:
	R2 += 16;
	M0 = 12 (X);
	I0 += M0;
	R6 += 1;
	R7 += 12;
.L480:
	I3 += M0;
	R5.H = _ntakes;
	R5.L = _ntakes;
	P0 = R5;
	R0 = [P0];
	cc =R0==0;
	if cc jump 6 (bp); jump.l .L436;
.L78:
	P1.H = _euclids;
	P1.L = _euclids;
	R7 = 0 (X);
	P2 = 8 (X);
	LSETUP (.L84, .L478) LC1 = P2;
.L84:
	R0 = [P1];
	R7 = R7 | R0;
.L478:
	P1 += 60;
	R1 = B [P4+28] (X);
	R0 = R1.B (Z);
	cc =R0==0;
	if cc jump 6; jump.l .L85;
	P3.H = _waiting;
	P2.H = _was_playing;
	P3.L = _waiting;
	P2.L = _was_playing;
	[SP+48] = P3;
	B [P3] = R0;
	B [P2] = R0;
.L94:
	P3.H = _beat;
	P3.L = _beat;
	R0 = [P3];
	R0 += 1;
	[P3] = R0;
.L86:
	cc =R7==0;
	if cc jump .L144;
.L265:
	P5.H = _now+4;
	FP.H = _euclids;
	P5.L = _now+4;
	FP.L = _euclids;
	R5 = 0 (X);
	R7 = 1 (X);
.L143:
	R2 = [FP];
	cc =R2==0;
	I0 = R2;
	if cc jump .L100 (bp);
	R4 = 1796 (X);
	R0 = B [P5+3] (Z);
	R0 = R0.L * R4.L (IS) ||
	P1 = [P3] ||
	nop;
	R6.H = _DIV;
	R0 >>>= 16;
	R6.L = _DIV;
	R0 = R6 + R0;
	P0 = R0;
	R2 = 0 (X);
	R3 = 31 (X);
	R0 = 0 (X);
	P2 = 32 (X);
	R4 = B [P0] (Z);
	LSETUP (.L102, .L477) LC1 = P2;
.L102:
	R1 = P1;
	R1 >>= R3;
	R0 <<= 1;
	R1 = R1 & R7;
	R0 = R1 | R0;
	cc =R4<=R0 (iu);
	R2 <<= 1;
	if !cc jump .L101 (bp);
	R0 = R0 - R4;
	BITSET (R2, 0);
.L101:
.L477:
	R3 += -1;
	R2 *= R4;
	R0 = P1;
	cc =R0==R2;
	if !cc jump 6 (bp); jump.l .L437;
.L100:
	R5 += 1;
	R3 = 8 (X);
	cc =R5==R3;
	if cc jump .L142;
.L427:
	FP += 60;
	P5 += 12;
	jump.s .L143;
.L435:
	P2 = [P4+68];
	P5 = 159 (X);
	cc =P2<=P5 (iu);
	if !cc jump .L73;
	R0 = P2;
	R0 <<= 3;
	R0 = (R0 + R5) << 1;
	P5 = R0;
	P5 = FP + P5;
	R0 = W [P5] (Z);
	R0 >>>= R1;
	cc = !BITTST (R0,0);
	if cc jump .L73;
	P5 = R6;
	P2 = P2 + (P2 << 1);
	R0 = P2;
	R0 <<= 9;
	R0 = R0 + R2;
	R3 = B [P5] (Z);
	R3 >>= 4;
	R0 = R0 + R3;
	P2 = R0;
	R4 = 255 (X);
	P2 = P2 + P3;
	R0 = B [P2] (X);
	R3 = R0.B (Z);
	cc =R3==R4;
	if !cc jump .L74 (bp);
	jump.s .L73;
.L142:
	P0 = [SP+48];
	R0 = B [P0] (Z);
	cc =R0==0;
	if !cc jump .L95;
.L144:
	R0 = [P3];
	cc =R0==-1;
	if cc jump .L95;
.L266:
	FP.H = _gknob;
	P5.H = _grooves+1;
	FP.L = _gknob;
	P5.L = _grooves+1;
	R7 = 0 (X);
.L190:
	R0 = B [P5+-1] (Z);
	P1 = R0;
	cc =P1==0;
	if cc jump .L146;
	R0 = B [FP+1] (Z);
	R1 = 1796 (X);
	R0 = R0.L * R1.L (IS) ||
	R5 = [P3] ||
	nop;
	R2.H = _DIV;
	R2.L = _DIV;
	R0 >>>= 16;
	R0 = R2 + R0;
	P0 = R0;
	R2 = 0 (X);
	R3 = 31 (X);
	R0 = 0 (X);
	R4 = 1 (X);
	R6 = B [P0] (Z);
	P2 = 32 (X);
	LSETUP (.L148, .L476) LC1 = P2;
.L148:
	R1 = R5;
	R1 >>= R3;
	R0 <<= 1;
	R1 = R1 & R4;
	R0 = R1 | R0;
	cc =R6<=R0 (iu);
	R2 <<= 1;
	if !cc jump .L147 (bp);
	R0 = R0 - R6;
	BITSET (R2, 0);
.L147:
.L476:
	R3 += -1;
	R3 = R6;
	R3 *= R2;
	R0 = 1 (X);
	R0 = R2 & R0;
	cc =R0==0;
	R3 = R5 - R3;
	if cc jump .L149 (bp);
	R1 = B [FP+7] (Z);
	R1 = R1.L * R6.L (FU);
	P2 = R1;
	P2 = P2 + (P2 << 1);
	R1 = P2;
	R0 = R1 << 3;
	R0 = R0 - R1;
	R0 <<= 2;
	R0 >>= 16;
.L149:
	cc =R3==R0;
	if cc jump .L438;
.L146:
	R7 += 1;
	R0 = 8 (X);
	cc =R7==R0;
	FP += 8;
	P5 += 11;
	if !cc jump .L190 (bp);
.L95:
	P1.H = _tumblers+160;
	P1.L = _tumblers+160;
	R0 = 0 (X);
	P0 = 168 (X);
	P2 = 8 (X);
	LSETUP (.L145, .L475) LC1 = P2;
.L145:
	R1 = [P1];
	R0 = R0 | R1;
.L475:
	P1 = P1 + P0;
	cc =R0==0;
	if !cc jump 6 (bp); jump.l .L439;
	P2.H = 32770;
	P2.L = 33428;
	call (P2);
	P2.H = _running;
	P2.L = _running;
	R1 = ROT R0 BY 0 ||
	R0 = B [P2] (Z) ||
	nop;
	cc =R0==0;
	if !cc jump .L440 (bp);
	R0 = 1 (X);
	B [P2] = R0;
	P2.H = _last_ms;
	P2.L = _last_ms;
	[P2] = R1;
	P2.H = _acc;
	P2.L = _acc;
	R0 = 0 (X);
	[P2] = R0;
	[SP+72] = P2;
	P2.H = _seed;
	R0 = R1;
	P2.L = _seed;
	BITSET (R0, 0);
	R1 = [P2];
	cc =R0==R1;
	if !cc jump 6 (bp); jump.l .L274;
	R0 = R0 ^ R1;
.L199:
	P3 = [SP+72];
	[P2] = R0;
	R0 = 0 (X);
	[P3] = R0;
	jump.s .L193;
.L438:
	R1 = 69 (X);
	R0 = B [FP] (Z);
	R0 = R0.L * R1.L (IS);
	R0 >>>= 8;
	P2 = R0;
	P0.H = _groove;
	R0 = 15 (X);
	P0.L = _groove;
	R2 = R2 & R0;
	P2 = P2 + (P2 << 1);
	R0 = 1 (X);
	P2 = P0 + (P2 << 1);
	R0 <<= R2;
	R1 = W [P2] (Z);
	R1 = R1 & R0;
	cc =R1==0;
	if cc jump .L146;
	R1 = W [P2+2] (Z);
	R1 = R1 & R0;
	cc =R1==0;
	if !cc jump 6; jump.l .L441;
	R3 = 118 (X);
	[SP+56] = R3;
.L151:
	R0 = B [FP+2] (X);
	cc =R7<=3;
	B1 = R0;
	if !cc jump 6; jump.l .L152;
	R0 = B [FP+4] (Z);
	R1 = 134 (X);
	R0 = R0.L * R1.L (IS);
	R0 >>>= 8;
	P0 = R0;
	cc =P0==0;
	if !cc jump 6 (bp); jump.l .L152;
	P1.H = _prog_at;
	P1.L = _prog_at;
	P2 = P1 + (P0 << 1);
	R1 = W [P2+-2] (Z);
	R0 = W [P2] (Z);
	R2 = B [FP+6] (Z);
	I3 = R1;
	R0 = R0 - R1;
	R2 >>= 6;
	R1 = 192 (X);
	R1 <<= R2;
	cc =R5==-1;
	P1 = R1;
	if !cc jump .L153 (bp);
	R5 = 0 (X);
.L153:
	R2 = 0 (X);
	I0 = 31 (X);
	R1 = 0 (X);
	P0 = 32 (X);
	LSETUP (.L155, .L474) LC1 = P0;
.L155:
	R1 <<= 1;
	B0 = R1;
	R3 = I0;
	R1 = R5;
	R1 >>= R3;
	R4 = 1 (X);
	R1 = R1 & R4;
	R3 = B0;
	R1 = R1 | R3;
	R4 = P1;
	cc =R4<=R1 (iu);
	R2 <<= 1;
	if !cc jump .L154 (bp);
	R1 = R1 - R4;
	BITSET (R2, 0);
.L154:
	M0 = -1 (X);
.L474:
	I0 += M0;
	R5 = 0 (X);
	P0 = 31 (X);
	R1 = 0 (X);
	P1 = 32 (X);
	LSETUP (.L157, .L473) LC1 = P1;
.L157:
	R1 <<= 1;
	I2 = R1;
	R3 = P0;
	R1 = R2;
	R1 >>= R3;
	R4 = 1 (X);
	R1 = R1 & R4;
	R3 = I2;
	R1 = R1 | R3;
	cc =R0<=R1 (iu);
	R5 <<= 1;
	if !cc jump .L156 (bp);
	R1 = R1 - R0;
	BITSET (R5, 0);
.L156:
.L473:
	P0 += -1;
	R5 *= R0;
	R4 = I3;
	R0 = R4 + R2;
	R0 = R0 - R5;
	P0 = R0;
	P1.H = _prog;
	P1.L = _prog;
	R1 = B [FP+5] (Z);
	R0 = 12 (X);
	P1 = P1 + P0;
	R3 = B [P1] (Z);
	R0 = R0.L * R1.L (IS);
	R1 = R3;
	R2 = 7 (X);
	R1 += -1;
	R1 = R1 & R2;
	P2 = R1;
	P1.H = _degree.1;
	P1.L = _degree.1;
	R0 >>>= 8;
	R5 = 31 (X);
	P1 = P1 + P2;
	R1 = B [P1] (Z);
	R0 = R0 + R1;
	R1 = R3 >> 7;
	R0 = R0 - R1;
	R0 += 12;
	I1 = R0;
	R1 = 0 (X);
	R2 = 0 (X);
	P1 = 32 (X);
	LSETUP (.L159, .L472) LC1 = P1;
.L159:
	P0 = R2;
	R0 = I1;
	R2 = 1 (X);
	R0 >>= R5;
	R0 = R0 & R2;
	P2 = P0 + P0;
	R4 = P2;
	R2 = R0 | R4;
	R0 = 11 (X);
	cc =R2<=R0 (iu);
	R1 <<= 1;
	if cc jump .L158 (bp);
	R2 += -12;
	BITSET (R1, 0);
.L158:
.L472:
	R5 += -1;
	P0 = R1;
	R2 = B [P5] (Z);
	I0 = R2;
	R2 = I1;
	R5 = 31 (X);
	P0 = P0 + (P0 << 1);
	R1 = P0;
	R1 <<= 2;
	R0 = R2 - R1;
	R4 = I0;
	R0 = R4 - R0;
	R1 = 120 (X);
	R1 = R0 + R1;
	I2 = R1;
	R2 = 0 (X);
	R1 = 0 (X);
	P1 = 32 (X);
	LSETUP (.L161, .L471) LC1 = P1;
.L161:
	P0 = R2;
	R0 = I2;
	R2 = 1 (X);
	R0 >>= R5;
	R0 = R0 & R2;
	P2 = P0 + P0;
	R4 = P2;
	R2 = R0 | R4;
	R0 = 11 (X);
	cc =R2<=R0 (iu);
	R1 <<= 1;
	if cc jump .L160 (bp);
	R2 += -12;
	BITSET (R1, 0);
.L160:
.L471:
	R5 += -1;
	P0 = R1;
	P1 = I0;
	R0 = I2;
	R1 = 15 (X);
	P0 = P0 + (P0 << 1);
	P0 = P1 + (P0 << 2);
	R2 = P0;
	R4 = R2 - R0;
	R0 = R3 >> 3;
	R0 = R0 & R1;
	R1 = 5 (X);
	R1 = R1.L * R0.L (FU);
	P1 = R1;
	R0 = SP;
	P0.H = _chord_notes;
	R1 = 124 (X);
	P0.L = _chord_notes;
	R3 = R0 + R1;
	P1 = P1 + P0;
	R5 = R3;
	R0 = 0 (X);
	P0 = 5 (X);
	LSETUP (.L162, .L470) LC1 = P0;
.L162:
	R1 = B [P1] (Z);
	R2 = 255 (X);
	cc =R1==R2;
	if !cc jump 6 (bp); jump.l .L442;
	R1 = R1 + R4;
	cc =R1<0;
	P1 += 1;
	if cc jump 6 (bp); jump.l .L428;
.L164:
	R1 += 12;
	cc =R1<0;
	if cc jump .L164 (bp);
.L165:
	P2 = R5;
	R0 += 1;
	B [P2++] = R1;
.L470:
	R5 = P2;
.L419:
	R1 = B [FP+3] (Z);
	R2 = 5 (X);
	R2 = R2.L * R1.L (IS);
	R2 >>>= 8;
.L169:
	R4 = B1;
	R1 = R4.B (Z);
	R5 = 218 (X);
	R1 = R1.L * R5.L (IS);
	R1 >>>= 8;
	R1 += 26;
	R6 = R1.L * R6.L (IS);
	cc =R2==0;
	R1 = 256 (X);
	R6 = max(R6,R1);
	if !cc jump 6 (bp); jump.l .L443;
	R4 = 4 (X);
	cc =R2==R4;
	if !cc jump 6 (bp); jump.l .L444;
	R1 = B [P5+8] (Z);
	B0 = R1;
	P0 = R1;
.L182:
	P2 = 0 (X);
	I0 = 31 (X);
	R5 = 0 (X);
	P1 = 32 (X);
	LSETUP (.L184, .L469) LC1 = P1;
.L184:
	R5 <<= 1;
	I3 = R5;
	R4 = P0;
	R5 = I0;
	R4 >>= R5;
	R1 = 1 (X);
	R4 = R4 & R1;
	R1 = I3;
	R5 = R4 | R1;
	cc =R0<=R5 (iu);
	P2 = P2 + P2;
	if !cc jump .L183 (bp);
	R4 = P2;
	BITSET (R4, 0);
	R5 = R5 - R0;
	P2 = R4;
.L183:
	M0 = -1 (X);
.L469:
	I0 += M0;
	R1 = P2;
	R1 *= R0;
	R4 = B0;
	R4 += 1;
	P1 = R1;
	B2 = R4;
	P2 = 0 (X);
	I1 = 31 (X);
	R5 = 0 (X);
	[--SP] = P0;
	P0 = 32 (X);
	LSETUP (.L186, .L468) LC1 = P0;
	P0 = [SP++];
.L186:
	R5 <<= 1;
	B1 = R5;
	R1 = I1;
	R5 = B2;
	R5 >>= R1;
	R4 = 1 (X);
	R5 = R5 & R4;
	R1 = B1;
	R5 = R5 | R1;
	R4 = 239 (X);
	cc =R5<=R4 (iu);
	P2 = P2 + P2;
	if cc jump .L185 (bp);
	R4 = P2;
	R1 = -240 (X);
	BITSET (R4, 0);
	R5 = R5 + R1;
	P2 = R4;
.L185:
	M0 = -1 (X);
.L468:
	I1 += M0;
	R5 = P2;
	R4 = P2;
	R5 <<= 4;
	R5 = R5 - R4;
	R5 <<= 4;
	R4 = B2;
	R1 = R4 - R5;
	cc =R2==2;
	B [P5+8] = R1;
	if !cc jump 6 (bp); jump.l .L187;
	P0 -= P1;
	R0 = P0;
.L188:
	R1 = [P4+1676];
	R2 = 39 (X);
	cc =R1<=R2;
	if !cc jump .L146;
	R3 = R3 + R0;
	P0 = R3;
	P1 = [SP+56];
	R1 = R7;
	R0 = B [P0] (Z);
	R2 = ROT R0 BY 0 ||
	[SP+16] = R6 ||
	nop;
	[SP+12] = P1;
	R0 = P4;
	call _play.part.0;
	jump.s .L146;
.L440:
	P1.H = _last_ms;
	P1.L = _last_ms;
	R0 = [P1];
	R2 = 33 (X);
	R0 = R1 - R0;
	cc =R0<=R2 (iu);
	P0.H = _acc;
	if !cc R0 = R2;
	P0.L = _acc;
	R2 = [P0];
	R0 <<= 8;
	R2 = R0 + R2;
	P2 = R2;
	[P1] = R1;
	P1 = 999 (X);
	[SP+72] = P0;
	[P0] = R2;
	cc =P2<=P1 (iu);
	if !cc jump 4 (bp); jump.s .L193;
	FP.H = _seed;
	FP.L = _seed;
	[SP+80] = P4;
.L197:
	P0 = [SP+72];
	P5 = -1000 (X);
	P2 = P2 + P5;
	P1.H = _now;
	[P0] = P2;
	P5 = 100 (X);
	P0 = 124 (X);
	P1.L = _now;
	P2.H = _tumblers;
	P3 = 0 (X);
	P5 = SP + P5;
	P0 = SP + P0;
	[SP+64] = P1;
	P2.L = _tumblers;
	[SP+68] = P3;
	[SP+44] = P5;
	[SP+40] = P0;
	jump.s .L241;
.L200:
	P1 = [SP+64];
	R3 = [SP+68];
	R3 += 1;
	R0 = 8 (X);
	P0 = 168 (X);
	P1 += 12;
	cc =R3==R0;
	[SP+68] = R3;
	P2 = P2 + P0;
	[SP+64] = P1;
	if !cc jump 4 (bp); jump.s .L445;
.L241:
	R6 = [P2+160];
	cc =R6==0;
	if cc jump .L200 (bp);
	P0 = [SP+64];
	R4 = 23037 (X);
	R0 = [P2+164];
	P1.H = 21845;
	R1 = B [P0] (X);
	R2 = B [P0+2] (Z);
	B [SP+60] = R1;
	R1 = B [P0+1] (X);
	B [SP+78] = R1;
	R1 = R2.L * R4.L (IS) ||
	[SP+56] = R6 ||
	nop;
	R0 = R1 + R0;
	P4 = R0;
	R3 = B [P0+3] (X);
	P1.L = 21845;
	P0.H = 54613;
	P0.L = 21846;
	P1 = P4 + P1;
	R7 = P1;
	P4 = P4 + P0;
	P1 = 124 (X);
	P0 = 100 (X);
	R4 = -1 (X);
	R6 = P4;
	[SP+48] = R2;
	B [SP+79] = R3;
	[P2+164] = R0;
	P5 = P0 + SP;
	R4 <<= 30;
	P4 = P1 + SP;
	R5 = P2;
.L201:
	R0 = R7;
	call _sin31;
	P3 = R0;
	[P5++] = R0;
	R0 = R7 + R4;
	call _sin31;
	R3.H = 10922;
	R3.L = 43691;
	R2 = P3;
	R7 = R7 + R3;
	[P4++] = R0;
	R1 = -R2;
	R0 = -R0;
	cc =R6==R7;
	[P5+8] = R1;
	[P4+8] = R0;
	if !cc jump .L201 (bp);
	R6 = [SP+56];
	cc =R6<=0;
	P2 = R5;
	if cc jump .L200;
	R0 = B [SP+60] (Z);
	R1 = 2570 (X);
	R0 = R0.L * R1.L (IS) ||
	R4 = [SP+48] ||
	nop;
	R1 = 3 (X);
	R1 <<= 15;
	R1 = R0 + R1;
	B1 = R1;
	R1.H = 79;
	R1.L = 43950;
	R0 = B [SP+78] (Z);
	R0 *= R1;
	R1.H = 9830;
	R1.L = 26214;
	R1 = R0 + R1;
	R0.H = 70;
	R0.L = 44267;
	R4 *= R0;
	[SP+56] = R1;
	R0 = B [SP+79] (Z);
	R1 = 52634 (Z);
	R0 *= R1;
	[SP+48] = R4;
	[SP+60] = R0;
	P1 = R5;
	I2 = 0 (X);
	I1 = R5;
	P2 = 0 (X);
.L213:
	P4 = [P1+8];
	P0 = [P1+12];
	P3 = B1;
	R6 = [P1];
	R0 = P4;
	P0 = P3 + P0;
	R0 >>>= 8;
	R6 = R6 + R0;
	R0 = P0;
	R1 = B [P1+17] (Z);
	R0 >>>= 8;
	R7 = [P1+4];
	cc =R1<5 (iu);
	R7 = R7 + R0;
	R2 = B [P1+17] (X);
	R0 = 5 (X);
	if !cc R0 = R2;
	R0 += -5;
	B [P1+17] = R0;
	R0 = B [P1+18] (X);
	R1 = R0.B (Z);
	cc =R1==0;
	[P1+12] = P0;
	[P1] = R6;
	[P1+4] = R7;
	if cc jump .L203 (bp);
	R0 += -1;
	B [P1+18] = R0;
.L203:
	P3 = 124 (X);
	R3 = [SP+40];
	R4 = [SP+44];
	P3 = P3 + SP;
	R0 = R3 - R4;
	B0 = P3;
	P3 = R0;
	P5 = 100 (X);
	P5 = P5 + SP;
	M2 = P2;
	P2 = I1;
	P3 += -4;
	P3 = P3 >> 2;
	P3 += 1;
	I3 = P5;
	[SP+20] = P2;
	[SP+28] = R7;
	[SP+24] = R6;
	M3 = P3;
	jump.s .L210;
.L309:
	R0 = [P1];
	R1 = [P1+4];
	[SP+24] = R0;
	[SP+28] = R1;
.L210:
	P5 = I3;
	R5 = [P5++];
	R0 = W [SP+24] (X);
	A1 = R0.L * R5.L (FU) ||
	R1 = [SP+24] ||
	nop;
	A1 = A1 >> 16 ||
	R0 = W [SP+28] (X) ||
	nop;
	A0 = R1.H * R5.H, A1 += R1.H * R5.L (M);
	A1 += R5.H * R1.L (M) ||
	R1 = [SP+28] ||
	nop;
	P2 = B0;
	R2 = [P2++];
	A1 = A1 >>> 15;
	R3 = (A0 += A1);
	A1 = R0.L * R2.L (FU);
	A1 = A1 >> 16;
	A0 = R1.H * R2.H, A1 += R1.H * R2.L (M);
	A1 += R2.H * R1.L (M);
	A1 = A1 >>> 15;
	R0 = (A0 += A1);
	R4.H = 65364;
	R3 = R3 + R0;
	R4.L = 35118;
	R3 = R3 + R4;
	cc =R3<=0;
	I3 = P5;
	B0 = P2;
	if cc jump .L206;
	R6 = 13107 (X);
	A1 = R6.L * R5.L (FU);
	R7.H = 19;
	R7.L = 13107;
	A1 = A1 >> 16;
	A0 = R7.H * R5.H, A1 += R7.H * R5.L (M);
	A1 += R5.H * R7.L (M);
	A1 = A1 >>> 15;
	R7 = (A0 += A1);
	R4.H = 19;
	A1 = R6.L * R2.L (FU);
	R4.L = 13107;
	A1 = A1 >> 16;
	A0 = R4.H * R2.H, A1 += R4.H * R2.L (M);
	A1 += R2.H * R4.L (M);
	A1 = A1 >>> 15;
	R0 = -R5;
	R4 = (A0 += A1) ||
	R5 = [SP+28] ||
	nop;
	R4 = R5 + R4;
	R6 = W [SP+48] (X);
	A1 = R4.L * R6.L (FU) ||
	R5 = [SP+48] ||
	nop;
	A1 = A1 >> 16 ||
	R6 = [SP+24] ||
	nop;
	A0 = R4.H * R5.H, A1 += R4.H * R5.L (M);
	A1 += R5.H * R4.L (M);
	A1 = A1 >>> 15;
	R5 = R6 + R7;
	R4 = (A0 += A1);
	R7 = W [SP+48] (X);
	A1 = R5.L * R7.L (FU);
	R4 <<= 2;
	B3 = R4;
	A1 = A1 >> 16 ||
	R4 = [SP+48] ||
	nop;
	A0 = R5.H * R4.H, A1 += R5.H * R4.L (M);
	A1 += R4.H * R5.L (M);
	A1 = A1 >>> 15;
	R5 = (A0 += A1);
	P2 = R5;
	R6 = B3;
	R5 = P4;
	R4 = R5 + R6;
	A1 = R4.L * R0.L (FU);
	A1 = A1 >> 16;
	A0 = R4.H * R0.H, A1 += R4.H * R0.L (M);
	P5 = P2 << 2;
	R7 = P0;
	R6 = P5;
	A1 += R0.H * R4.L (M);
	R1 = -R2;
	R5 = R7 - R6;
	A1 = A1 >>> 15;
	R7 = (A0 += A1);
	A1 = R5.L * R1.L (FU);
	A1 = A1 >> 16;
	A0 = R5.H * R1.H, A1 += R5.H * R1.L (M);
	A1 += R1.H * R5.L (M);
	A1 = A1 >>> 15;
	R6 = (A0 += A1);
	A1 = R3.L * R0.L (FU);
	M1 = R6;
	I0 = R7;
	A1 = A1 >> 16 ||
	R6 = [SP+24] ||
	nop;
	A0 = R3.H * R0.H, A1 += R3.H * R0.L (M);
	A1 += R0.H * R3.L (M);
	A1 = A1 >>> 15;
	R7 = (A0 += A1);
	I0 += M1;
	I1 = R6;
	M1 = R7;
	A1 = R3.L * R1.L (FU) ||
	R6 = [SP+28] ||
	nop;
	A1 = A1 >> 16;
	A0 = R3.H * R1.H, A1 += R3.H * R1.L (M);
	A1 += R1.H * R3.L (M);
	I1 += M1;
	R7 = I1;
	A1 = A1 >>> 15 ||
	[P1] = R7 ||
	nop;
	R3 = (A0 += A1);
	R7 = I0;
	R3 = R6 + R3;
	cc =R7<0;
	[P1+4] = R3;
	if !cc jump .L206;
	R6.H = 65446;
	R6.L = 26215;
	cc =R7<R6;
	R3 = -R7;
	if cc jump 4; jump.s .L207;
	R7 = W [SP+56] (X);
	A1 = R3.L * R7.L (FU) ||
	R6 = [SP+56] ||
	nop;
	A1 = A1 >> 16;
	A0 = R3.H * R6.H, A1 += R3.H * R6.L (M);
	A1 += R6.H * R3.L (M);
	A1 = A1 >>> 15;
	R7 = (A0 += A1);
	R6 = I0;
	R7 = R7 - R6;
	A1 = R7.L * R0.L (FU);
	A1 = A1 >> 16;
	A0 = R7.H * R0.H, A1 += R7.H * R0.L (M);
	A1 += R0.H * R7.L (M);
	A1 = A1 >>> 15;
	R6 = (A0 += A1);
	A1 = R7.L * R1.L (FU);
	A1 = A1 >> 16;
	A0 = R7.H * R1.H, A1 += R7.H * R1.L (M);
	A1 += R1.H * R7.L (M);
	R6 = R4 + R6;
	A1 = A1 >>> 15;
	R7 = (A0 += A1);
	A1 = R6.L * R2.L (FU);
	A1 = A1 >> 16;
	A0 = R6.H * R2.H, A1 += R6.H * R2.L (M);
	A1 += R2.H * R6.L (M);
	R5 = R5 + R7;
	A1 = A1 >>> 15;
	R7 = (A0 += A1);
	A1 = R5.L * R0.L (FU);
	A1 = A1 >> 16;
	A0 = R5.H * R0.H, A1 += R5.H * R0.L (M);
	A1 += R0.H * R5.L (M);
	A1 = A1 >>> 15;
	R4 = (A0 += A1);
	R7 = R7 + R4;
	R4 = -10487 (X);
	A1 = R7.L * R4.L (FU);
	R4.H = 28835;
	R4.L = 55049;
	A1 = A1 >> 16;
	A0 = R7.H * R4.H, A1 += R7.H * R4.L (M);
	A1 += R4.H * R7.L (M);
	A1 = A1 >>> 15;
	R7 = (A0 += A1);
	P0 = R7;
	R7 = [FP];
	R4 = R7 << 13;
	R4 = R4 ^ R7;
	R7 = R4 >> 17;
	R7 = R7 ^ R4;
	R4 = R7 << 5;
	R4 = R4 ^ R7;
	R7 = W [SP+60] (X);
	A1 = R4.L * R7.L (FU) ||
	R7 = [SP+60] ||
	nop;
	A1 = A1 >> 16 ||
	[FP] = R4 ||
	nop;
	A0 = R4.H * R7.H, A1 += R4.H * R7.L (M);
	A1 += R7.H * R4.L (M);
	A1 = A1 >>> 15;
	R7 = (A0 += A1);
	A1 = R6.L * R0.L (FU);
	A1 = A1 >> 16;
	A0 = R6.H * R0.H, A1 += R6.H * R0.L (M);
	A1 += R0.H * R6.L (M);
	A1 = A1 >>> 15;
	R6 = (A0 += A1);
	A1 = R5.L * R1.L (FU);
	A1 = A1 >> 16;
	A0 = R5.H * R1.H, A1 += R5.H * R1.L (M);
	A1 += R1.H * R5.L (M);
	A1 = A1 >>> 15;
	R5 = (A0 += A1);
	R6 = R6 + R5;
	A1 = R6.L * R0.L (FU);
	A1 = A1 >> 16;
	A0 = R6.H * R0.H, A1 += R6.H * R0.L (M);
	R4 = P0;
	A1 += R0.H * R6.L (M);
	R7 = R4 + R7;
	A1 = A1 >>> 15;
	R5 = (A0 += A1);
	A1 = R7.L * R2.L (FU);
	A1 = A1 >> 16;
	A0 = R7.H * R2.H, A1 += R7.H * R2.L (M);
	A1 += R2.H * R7.L (M);
	A1 = A1 >>> 15;
	R2 = (A0 += A1);
	A1 = R6.L * R1.L (FU);
	A1 = A1 >> 16;
	A0 = R6.H * R1.H, A1 += R6.H * R1.L (M);
	A1 += R1.H * R6.L (M);
	P0 = R2;
	A1 = A1 >>> 15;
	R1 = (A0 += A1);
	A1 = R7.L * R0.L (FU);
	A1 = A1 >> 16;
	A0 = R7.H * R0.H, A1 += R7.H * R0.L (M);
	R4 = B3;
	R2 = R5 - R4;
	A1 += R0.H * R7.L (M);
	R5 = P0;
	R2 = R2 + R5;
	A1 = A1 >>> 15 ||
	[P1+8] = R2 ||
	nop;
	R6 = P5;
	R2 = (A0 += A1);
	R0 = R6 + R1;
	R0 = R0 + R2;
	[P1+12] = R0;
	R0 = B [P1+18] (Z);
	cc =R0==0;
	if !cc jump .L208 (bp);
	R7 = I2;
	R0 = 7 (X);
	cc =R7<=R0;
	if !cc jump .L208 (bp);
	P2 = 0 (X);
	P3 = I2;
	P2 = P2 + SP;
	P0 = P2 + P3;
	R0 = B [P1+16] (X);
	B [P0+84] = R0;
	R3 >>>= 16;
	R0 = 48 (X);
	R0 = R0.L * R3.L (IS);
	P5 = 0 (X);
	R0 >>>= 8;
	P5 = P5 + SP;
	R0 += 38;
	R1 = 127 (X);
	R0 = min(R0,R1);
	P0 = P5 + P3;
	B [P0+92] = R0;
	M1 = 1 (X);
	R0 = 10 (X);
	B [P1+18] = R0;
	I2 += M1;
.L208:
	R0 = -1 (X);
	B [P1+17] = R0;
	P0 = [P1+12];
	P4 = [P1+8];
.L206:
	R2 = M3;
	R2 += -1;
	M3 = R2;
	cc =R2==0;
	if !cc jump .L309 (bp);
	P3 = [SP+20];
	R0 = P0;
	P2 = M2;
	P0 = 4 (X);
	I1 = P3;
	R1 = P4;
	LSETUP (.L215, .L467) LC1 = P0;
.L215:
	R2 = R1 >>> 13;
	R3 = R0 >>> 13;
	R3 *= R3;
	R2 *= R2;
	R2 = R2 + R3;
	R3 = 25 (X);
	R3 <<= 22;
	cc =R2<=R3;
	if cc jump .L216;
	R2 = R1 >>> 3;
	R1 = R1 - R2;
	R2 = R0 >>> 3 ||
	[P1+8] = R1 ||
	nop;
	R0 = R0 - R2;
.L467:
	[P1+12] = R0;
.L216:
	P2 += 1;
	P0 = I1;
	R2 = [P0+160];
	R0 = P2;
	cc =R0<R2;
	P1 += 20;
	if !cc jump 4; jump.s .L213;
	cc =R2<=1;
	P2 = I1;
	if cc jump .L238;
	R0 = W [SP+56] (X);
	R1 = 13106 (X);
	A0 = R0.L * R1.L (FU);
	R0 = A0.w;
	[SP+48] = R0;
	R0 = A0.x;
	[SP+52] = R0;
	P0 += 20;
	R4 = 0 (X);
	P4 = 9830 (X);
	P5 = 1 (X);
	M0 = -103 (X);
.L237:
	R4 += 1;
	cc =R4<R2;
	if !cc jump .L220;
	P1 = P0;
	R5 = R4;
.L236:
	R0 = [P1];
	R6 = [P0+-20];
	R0 = R0 - R6;
	R0 >>>= 8;
	R3 = P4;
	I1 = R0;
	R7 = 19660 (X);
	R0 = R0 + R3;
	cc =R0<=R7 (iu);
	if !cc jump .L222;
	R0 = [P0+-16];
	R1 = [P1+4];
	R1 = R1 - R0;
	R1 >>>= 8;
	R7 = P4;
	I0 = R0;
	I3 = R1;
	R0 = R1 + R7;
	R1 = 19660 (X);
	cc =R0<=R1 (iu);
	if !cc jump .L222;
	R0 = I3;
	R3 = I1;
	R0 *= R0;
	R3 *= R3;
	R3 = R3 + R0;
	R0 = R3;
	R7.H = 1474;
	R0 += -64;
	R7.L = 28771;
	cc =R0<=R7 (iu);
	if !cc jump .L222 (bp);
	R0 = 1 (X);
	R0 <<= 30;
.L224:
	R0 >>= 2;
	cc =R3<R0 (iu);
	if cc jump .L224 (bp);
	R1 = 0 (X);
.L226:
	R2 = R0 + R1;
	cc =R2<=R3 (iu);
	R1 >>= 1;
	if !cc jump .L225 (bp);
	R3 = R3 - R2;
	R1 = R1 + R0;
.L225:
	R0 >>= 2;
	cc =R0==0;
	if !cc jump .L226 (bp);
	R3 = I1;
	R2 = -R3;
	R2 = max(R3,R2);
	R2 <<= 15;
	B1 = R0;
	R0 = R6;
	B0 = R2;
	R6 = R1;
	B2 = P2;
	R3 = 0 (X);
	R2 = 0 (X);
	R1 = 31 (X);
	P2 = 32 (X);
	B3 = R0;
	LSETUP (.L228, .L466) LC1 = P2;
.L228:
	R0 = B0;
	R0 >>= R1;
	R7 = P5;
	R2 <<= 1;
	R0 = R0 & R7;
	R2 = R0 | R2;
	cc =R6<=R2 (iu);
	R3 <<= 1;
	if !cc jump .L227 (bp);
	R2 = R2 - R6;
	BITSET (R3, 0);
.L227:
.L466:
	R1 += -1;
	R7 = I3;
	R2 = -R7;
	R2 = max(R7,R2);
	R2 <<= 15;
	R0 = B1;
	B0 = R2;
	B1 = R3;
	R2 = 0 (X);
	R3 = 31 (X);
	P2 = 32 (X);
	LSETUP (.L230, .L465) LC1 = P2;
.L230:
	R1 = B0;
	R1 >>= R3;
	R7 = P5;
	R0 <<= 1;
	R1 = R1 & R7;
	R0 = R1 | R0;
	cc =R6<=R0 (iu);
	R2 <<= 1;
	if !cc jump .L229 (bp);
	R0 = R0 - R6;
	BITSET (R2, 0);
.L229:
.L465:
	R3 += -1;
	R0 = 32767 (X);
	R3 = B1;
	R7 = I1;
	R3 = min(R3,R0);
	cc =R7<0;
	R1 = R6;
	P2 = B2;
	R6 = B3;
	R2 = min(R2,R0);
	R3 <<= 16;
	if !cc jump .L232 (bp);
	R3 = -R3;
.L232:
	R0 = I3;
	cc =R0<0;
	R0 = R2 << 16;
	if !cc jump .L234 (bp);
	R0 = -R0;
.L234:
	R2 = P4;
	R1 = R2 - R1;
	R1 <<= 7;
	A1 = R1.L * R3.L (FU);
	A1 = A1 >> 16;
	A0 = R1.H * R3.H, A1 += R1.H * R3.L (M);
	A1 += R3.H * R1.L (M);
	A1 = A1 >>> 15;
	R7 = (A0 += A1);
	A1 = R1.L * R0.L (FU);
	A1 = A1 >> 16;
	A0 = R1.H * R0.H, A1 += R1.H * R0.L (M);
	A1 += R0.H * R1.L (M);
	R6 = R6 - R7;
	A1 = A1 >>> 15;
	[P0+-20] = R6;
	R2 = (A0 += A1);
	R6 = I0;
	R1 = R6 - R2;
	[P0+-16] = R1;
	R1 = [P1];
	R1 = R1 + R7;
	[P1] = R1;
	R1 = [P1+4];
	R1 = R1 + R2;
	[P1+4] = R1;
	R7 = [P0+-12];
	R1 = [P1+8];
	R1 = R1 - R7;
	A1 = R1.L * R3.L (FU);
	A1 = A1 >> 16;
	A0 = R1.H * R3.H, A1 += R1.H * R3.L (M);
	A1 += R3.H * R1.L (M) ||
	R1 = [P1+12] ||
	nop;
	R6 = [P0+-8];
	R1 = R1 - R6;
	A1 = A1 >>> 15;
	R2 = (A0 += A1);
	A1 = R1.L * R0.L (FU);
	A1 = A1 >> 16;
	A0 = R1.H * R0.H, A1 += R1.H * R0.L (M);
	A1 += R0.H * R1.L (M);
	A1 = A1 >>> 15;
	R1 = (A0 += A1);
	R2 = R2 + R1;
	cc =R2<0;
	I0 = R7;
	if !cc jump .L429;
	R7 = [SP+48];
	A1.w = R7;
	R7 = [SP+52];
	A1.x = R7;
	R7.H = 29491;
	R1 = [SP+56];
	R7.L = 13106;
	A1 = A1 >> 16;
	A0 = R1.H * R7.H, A1 += R1.H * R7.L (M);
	A1 += R7.H * R1.L (M);
	A1 = A1 >>> 15;
	R1 = (A0 += A1);
	A1 = R2.L * R1.L (FU);
	A1 = A1 >> 16;
	A0 = R2.H * R1.H, A1 += R2.H * R1.L (M);
	A1 += R1.H * R2.L (M);
	A1 = A1 >>> 15;
	R1 = (A0 += A1);
	R1 = R2 + R1;
	R1 = -R1;
	R1 >>>= 1;
	A1 = R1.L * R3.L (FU);
	A1 = A1 >> 16;
	A0 = R1.H * R3.H, A1 += R1.H * R3.L (M);
	A1 += R3.H * R1.L (M);
	A1 = A1 >>> 15;
	R3 = (A0 += A1);
	A1 = R1.L * R0.L (FU);
	A1 = A1 >> 16;
	A0 = R1.H * R0.H, A1 += R1.H * R0.L (M);
	A1 += R0.H * R1.L (M);
	A1 = A1 >>> 15;
	R1 = (A0 += A1);
	R7 = I0;
	R7 = R7 - R3;
	R6 = R6 - R1;
	[P0+-12] = R7;
	[P0+-8] = R6;
	R0 = [P1+8];
	R0 = R0 + R3;
	[P1+8] = R0;
	R0 = [P1+12];
	R0 = R0 + R1;
	[P1+12] = R0;
	R0.H = 65382;
	R0.L = 26215;
	cc =R2<R0;
	if !cc jump .L429 (bp);
	R0 = B [P0+-3] (Z);
	R1 = 152 (X);
	cc =R0<=R1 (iu);
	if !cc jump .L235 (bp);
	R2 = M0;
	B [P0+-3] = R2;
.L235:
	R0 = B [P1+17] (Z);
	R3 = 152 (X);
	cc =R0<=R3 (iu);
	if !cc jump .L429 (bp);
	R6 = M0;
	B [P1+17] = R6;
.L429:
	R2 = [P2+160];
.L222:
	R5 += 1;
	cc =R5<R2;
	P1 += 20;
	if cc jump .L236 (bp);
.L220:
	R0 = R2;
	R0 += -1;
	cc =R4<R0;
	P0 += 20;
	if cc jump .L237 (bp);
.L238:
	R1 = I2;
	cc =R1==0;
	if !cc jump 4 (bp); jump.s .L200;
	P0 = 84 (X);
	P5 = SP + P0;
	R0 = SP;
	R1 = 92 (X);
	P0 = I2;
	R6 = R0 + R1;
	P4 = P0 + P5;
	R7 = 9216 (X);
	R5 = [SP+68];
	R4 = P2;
	P3 = [SP+80];
.L240:
	R0 = [P3+1676];
	R1 = 39 (X);
	cc =R0<=R1;
	P1 = P5;
	P2 = R6;
	P5 += 1;
	R6 += 1;
	if !cc jump .L239;
	R0 = B [P1] (Z);
	[SP+16] = R7;
	R1 = B [P2] (Z);
	[SP+12] = R1;
	R2 = R0;
	R1 = R5;
	R0 = P3;
	call _play.part.0;
.L239:
	cc =P4==P5;
	if !cc jump .L240 (bp);
	P2 = R4;
	jump.s .L200;
.L207:
	A1 = R3.L * R0.L (FU);
	A1 = A1 >> 16;
	A0 = R3.H * R0.H, A1 += R3.H * R0.L (M);
	A1 += R0.H * R3.L (M);
	A1 = A1 >>> 15;
	R0 = (A0 += A1);
	R0 = R4 + R0;
	R2 = 30407 (X);
	A1 = R0.L * R2.L (FU);
	R4.H = 32702;
	R4.L = 30407;
	A1 = A1 >> 16;
	A0 = R0.H * R4.H, A1 += R0.H * R4.L (M);
	A1 += R4.H * R0.L (M);
	A1 = A1 >>> 15;
	R2 = (A0 += A1);
	A1 = R3.L * R1.L (FU);
	A1 = A1 >> 16;
	A0 = R3.H * R1.H, A1 += R3.H * R1.L (M);
	A1 += R1.H * R3.L (M);
	A1 = A1 >>> 15;
	R0 = (A0 += A1);
	R0 = R5 + R0;
	R7 = 30407 (X);
	A1 = R0.L * R7.L (FU);
	A1 = A1 >> 16;
	A0 = R0.H * R4.H, A1 += R0.H * R4.L (M);
	A1 += R4.H * R0.L (M);
	A1 = A1 >>> 15;
	R6 = B3;
	R0 = (A0 += A1);
	R1 = P5;
	R2 = R2 - R6;
	R0 = R1 + R0;
	[P1+8] = R2;
	[P1+12] = R0;
	P0 = R0;
	P4 = R2;
	jump.s .L206;
.L445:
	P0.H = _tick4;
	P0.L = _tick4;
	R0 = B [P0] (X);
	R0 += 1;
	R1 = 3 (X);
	B [P0] = R0;
	R0 = R0 & R1;
	cc =R0==0;
	if !cc jump .L243 (bp);
	P5 = [SP+80];
	P2.H = 52;
	P2.L = 24108;
	R1 = 4 (X);
	P2 = P5 + P2;
	R0 = [P2];
	cc =R0==R1;
	if !cc jump .L243;
	P1 = [P5+48];
	cc =P1<=7 (iu);
	if !cc jump .L243;
	P5.H = _spark;
	P0.H = _glow;
	P5.L = _spark;
	P0.L = _glow;
	R0 = 0 (X);
	P2 = 4 (X);
	LSETUP (.L244, .L464) LC1 = P2;
.L244:
	[P5++] = R0;
.L464:
	[P0++] = R0;
	P1 = P1 + (P1 << 1);
	R0 = P1;
	R2 = P1;
	R0 <<= 3;
	R0 = R0 - R2;
	R0 <<= 3;
	P2 = R0;
	P0.H = _tumblers;
	P0.L = _tumblers;
	P1 = P0 + P2;
	P2 = [P1+160];
	cc =P2<=0;
	if cc jump .L243;
	P2 = P2 + (P2 << 2);
	P2 = P2 << 2;
	R0 = P2;
	R0 += -20;
	R1.H = 3276;
	R1.L = 52429;
	R0 >>= 2;
	R0 *= R1;
	R1 = -1 (X);
	R1.H = 16383;
	R0 = R0 & R1;
	P2 = R0;
	R4 = 2867 (X);
	R5 = 3840 (X);
	R7 = 256 (X);
	R3 = 110 (X);
	P2 += 1;
	LSETUP (.L250, .L463) LC1 = P2;
.L250:
	R0 = [P1];
	R1 = 2744 (X);
	R0 >>>= 12;
	R0 = R0 + R1;
	R0 *= R4;
	R0 >>>= 12;
	R2 = 0 (X);
	R0 = min(R0,R5);
	R0 = max(R0,R2);
	R6 = R0 >>> 8;
	P4 = R6;
	R1 = B [P1+17] (Z);
	P3 = R1;
	R1 >>= 1;
	R0 = R0.B (Z);
	R1 = R1 + R3;
	R2 = R7 - R0;
	R1 = R1.B (Z);
	I0.H = _glow;
	R6 = R2.L * R1.L (IS);
	I0.L = _glow;
	M0 = P4;
	R6 >>>= 8;
	I0 += M0;
	P5 = R6;
	P0 = I0;
	R6 = P3;
	R2 = R2.L * R6.L (IS) ||
	R6 = B [P0] (Z) ||
	nop;
	P0 = R6;
	R2 >>>= 8;
	cc =P0<P5;
	if !cc jump .L245 (bp);
	R6 = P5;
	P0 = I0;
	B [P0] = R6;
.L245:
	P0.H = _spark;
	P0.L = _spark;
	P5 = P0 + P4;
	R6 = B [P5] (Z);
	cc =R2<=R6;
	if cc jump .L246 (bp);
	B [P5] = R2;
.L246:
	P0 = 15 (X);
	P5 = P4;
	cc =P4==P0;
	P5 += 1;
	if cc jump .L247;
	P0.H = _glow;
	P0.L = _glow;
	R1 = R0.L * R1.L (IS);
	R2 = P3;
	P4 = P0 + P5;
	R0 = R0.L * R2.L (IS) ||
	R2 = B [P4] (Z) ||
	nop;
	R1 >>>= 8;
	cc =R1<=R2;
	R0 >>>= 8;
	if cc jump .L248 (bp);
	B [P4] = R1;
.L248:
	P3.H = _spark;
	P3.L = _spark;
	P5 = P3 + P5;
	R1 = B [P5] (Z);
	cc =R0<=R1;
	if cc jump .L247 (bp);
	B [P5] = R0;
.L247:
.L463:
	P1 += 20;
.L243:
	P1 = [SP+72];
	P3 = 999 (X);
	P2 = [P1];
	cc =P2<=P3 (iu);
	if cc jump 4; jump.s .L197;
	P4 = [SP+80];
.L193:
	P2.H = 52;
	P2.L = 24108;
	P2 = P4 + P2;
	R0 = [P2];
	R1 = 5 (X);
	cc =R0==R1;
	if cc jump 4 (bp); jump.s .L251;
	R7 = [P4+48];
	cc =R7<=7 (iu);
	if cc jump 4 (bp); jump.s .L276;
.L430:
	P5 = -1 (X);
.L252:
	P0.H = _grooves+10;
	P1.H = _euclids+45;
	P0.L = _grooves+10;
	P1.L = _euclids+45;
	R0 = 0 (X);
	R1 = 0 (X);
	P2 = 8 (X);
	LSETUP (.L255, .L462) LC1 = P2;
.L255:
	cc =R7==R0;
	if cc jump .L253;
	B [P1] = R1;
.L253:
	R3 = P5;
	cc =R3==R0;
	if cc jump .L254;
	B [P0] = R1;
.L254:
	R0 += 1;
	P0 += 11;
.L462:
	P1 += 60;
	R0 = B [P4+20] (Z);
	cc =R0==0;
	if !cc jump 6 (bp); jump.l .L256;
	R4 = P5;
	R0 = R7 & R4;
	cc =R0==-1;
	if !cc jump 6 (bp); jump.l .L256;
	P0.H = 57;
	P0.L = 49443;
	P4 = P4 + P0;
	R0 = B [P4] (Z);
	cc =R0==0;
	if cc jump .L258;
	P2.H = _touched;
	P2.L = _touched;
	R0 = B [P2] (Z);
	cc =R0==0;
	if !cc jump .L258;
	P3.H = _shift_held;
	P3.L = _shift_held;
	R0 = B [P3] (Z);
	cc =R0==2;
	if !cc jump 6 (bp); jump.l .L66;
	P2.H = 32770;
	P2.L = 33428;
	call (P2);
	R1 = ROT R0 BY 0 ||
	R0 = B [P3] (Z) ||
	nop;
	cc =R0==0;
	if !cc jump 4 (bp); jump.s .L446;
	P2.H = _shift_ms;
	P2.L = _shift_ms;
	R0 = [P2];
	R0 = R1 - R0;
	R2 = 1999 (X);
	cc =R0<=R2 (iu);
	if !cc jump 6 (bp); jump.l .L66;
	R0 = 2 (X);
	B [P3] = R0;
	cc =R7==-1;
	R0 = 0 (X);
	B [P4] = R0;
	if !cc jump 4 (bp); jump.s .L262;
	R3 = 60 (X);
	R0 = R7 << 4;
	R0 = R0 - R7;
	R3 = R3.L * R7.L (FU);
	P1 = R0;
	P2 = R3;
	P0.H = _euclids;
	P0.L = _euclids;
	P1 = P0 + (P1 << 2);
	P2 += 45;
	P2 = P0 + P2;
	R0 = B [P1+45] (X);
	jump.s .L263;
.L437:
	R6 = 0 (X);
	R2 = 31 (X);
	R0 = 0 (X);
	R3 = 1 (X);
	P2 = 32 (X);
	LSETUP (.L105, .L461) LC1 = P2;
.L105:
	R1 = P1;
	R1 >>= R2;
	R0 <<= 1;
	R1 = R1 & R3;
	R0 = R1 | R0;
	cc =R0<R4 (iu);
	R6 <<= 1;
	if cc jump .L104 (bp);
	R0 = R0 - R4;
	BITSET (R6, 0);
.L104:
.L461:
	R2 += -1;
	cc =R5<=3;
	if !cc jump 4 (bp); jump.s .L447;
	R1 = 3852 (X);
	R0 = B [P5] (Z);
	R0 = R0.L * R1.L (IS);
	R0 >>>= 16;
	R1 = R0;
	R1 += 2;
	R2 = B [P5+1] (Z);
	R2 = R2.L * R1.L (IS);
	R2 >>>= 8;
	R2 += 1;
	R2 = min(R2,R1);
	P1 = R0;
	B0 = R2;
	B1 = 0 (X);
	I1 = 31 (X);
	R0 = 0 (X);
	P0 = 32 (X);
	LSETUP (.L125, .L460) LC1 = P0;
.L125:
	R0 <<= 1;
	I3 = R0;
	R2 = I1;
	R0 = R6;
	R0 >>= R2;
	R3 = 1 (X);
	R0 = R0 & R3;
	R2 = I3;
	R3 = B1;
	R0 = R0 | R2;
	R3 <<= 1;
	cc =R0<R1 (iu);
	B1 = R3;
	if cc jump .L124 (bp);
	BITSET (R3, 0);
	R0 = R0 - R1;
	B1 = R3;
.L124:
	M0 = -1 (X);
.L460:
	I1 += M0;
	R3 = B1;
	R3 *= R1;
	R0 = B [P5+2] (Z);
	R0 = R0.L * R1.L (IS);
	R0 >>>= 8;
	R3 = R6 - R3;
	cc =R1<=R0;
	I2 = R3;
	if !cc jump .L126 (bp);
	R0 = P1;
	R0 += 1;
.L126:
	R2 = I2;
	R0 = R2 + R0;
	cc =R1<=R0;
	if !cc jump .L127;
.L128:
	R0 = R0 - R1;
	cc =R1<=R0;
	if cc jump .L128 (bp);
.L127:
	R3 = B0;
	R0 *= R3;
	cc =R1<=R0;
	if !cc jump .L129;
.L130:
	R0 = R0 - R1;
	cc =R1<=R0;
	if cc jump .L130 (bp);
.L129:
	R6 = B0;
	cc =R6<=R0;
	if !cc jump 6; jump.l .L100;
	R2 = B [P5+6] (Z);
	R0 = 253 (X);
	cc =R2<=R0;
	if !cc jump 4; jump.s .L131;
.L134:
	P1 = [FP+36];
	P0 = I0;
	cc =P0<=P1;
	if !cc jump 4; jump.s .L269;
	R2 = P1;
	R2 += 1;
.L132:
	R0 = R5 << 4;
	R0 = R0 - R5;
	P2 = R0;
	R1 = B [P5+7] (Z);
	P2 = P2 + P1;
	P1.H = _euclids;
	P1.L = _euclids;
	P2 = P1 + (P2 << 2);
	R0 = B [P2+4] (Z);
	P1 = R0;
	R0 = 1025 (X);
	R1 = R1.L * R0.L (IS) ||
	[FP+36] = R2 ||
	nop;
	R1 >>>= 16;
	cc =R1==0;
	R2 = [FP+40];
	if cc jump .L135 (bp);
	R1 += 1;
	B0 = R1;
	R0 = 0 (X);
	P0 = 31 (X);
	R6 = 0 (X);
	P2 = 32 (X);
	LSETUP (.L137, .L459) LC1 = P2;
.L137:
	R6 <<= 1;
	R3 = P0;
	R1 = R2;
	R1 >>= R3;
	R3 = R6;
	R6 = 1 (X);
	R1 = R1 & R6;
	R6 = R1 | R3;
	R1 = B0;
	cc =R6<R1 (iu);
	R0 <<= 1;
	if cc jump .L136 (bp);
	R6 = R6 - R1;
	BITSET (R0, 0);
.L136:
.L459:
	P0 += -1;
	R3 = B0;
	R0 *= R3;
	R0 = R2 - R0;
	P2 = R0;
	P2 = P2 + (P2 << 1);
	P1 = P1 + (P2 << 2);
.L135:
	R0 = R2;
	R0 += 1;
	P0 = 127 (X);
	R0 = R0.L (Z);
	cc =P1<=P0;
	[FP+40] = R0;
	if cc jump .L138;
.L139:
	P1 += -12;
	P2 = 127 (X);
	cc =P1<=P2;
	if !cc jump .L139 (bp);
.L138:
	R0 = I2;
	cc =R0==0;
	R2 = B [P5+5] (Z);
	if !cc jump 4; jump.s .L140;
	R0 = 57 (X);
	R0 = R0.L * R2.L (IS);
	R0 >>>= 8;
	R1 = 114 (X);
	R1 = R1 - R0;
.L141:
	R0 = [P4+1676];
	R2 = 39 (X);
	cc =R0<=R2;
	if cc jump 6 (bp); jump.l .L100;
	R0 = B [P5+4] (Z);
	R2 = 218 (X);
	R0 = R0.L * R2.L (IS) ||
	[SP+12] = R1 ||
	nop;
	R0 >>>= 8;
	R0 += 26;
	R0 = R0.L * R4.L (IS);
	R2 = 256 (X);
	R0 = max(R0,R2);
	[SP+16] = R0;
	R2 = P1;
	R1 = R5;
	R0 = P4;
	call _play.part.0;
	jump.l .L100;
.L439:
	P1.H = _running;
	P1.L = _running;
	R0 = B [P1] (Z);
	cc =R0==0;
	if cc jump .L195 (bp);
	P5.H = _spark;
	P0.H = _glow;
	P5.L = _spark;
	P0.L = _glow;
	R0 = 0 (X);
	P2 = 4 (X);
	LSETUP (.L194, .L458) LC1 = P2;
.L194:
	[P5++] = R0;
.L458:
	[P0++] = R0;
.L195:
	R0 = 0 (X);
	B [P1] = R0;
	jump.s .L193;
.L85:
	P2.H = _was_playing;
	P2.L = _was_playing;
	R0 = B [P2] (Z);
	cc =R0==0;
	if !cc jump .L448 (bp);
	P0.H = _waiting;
	P0.L = _waiting;
	R0 = 1 (X);
	B [P0] = R0;
	R0 = [P4+64];
	cc =R0==0;
	[SP+48] = P0;
	B [P2] = R1;
	if cc jump 6; jump.l .L95;
.L90:
	P1 = [SP+48];
	R0 = 0 (X);
	P3.H = _beat;
	P3.L = _beat;
	B [P1] = R0;
.L431:
	R0 = 0 (X);
	[P3] = R0;
.L98:
	cc =R7==0;
	if cc jump 6; jump.l .L265;
	jump.l .L266;
.L436:
	cc =R0<=0;
	if cc jump .L267;
	R4.H = _takes;
	R4.L = _takes;
	R0 = SP;
	R1 = 124 (X);
	P3.H = 32784;
	P5 = R4;
	FP = 0 (X);
	R7 = 0 (X);
	R6 = R0 + R1;
	P3.L = 44920;
	jump.s .L83;
.L80:
	R1 = P5;
	R0 = P4;
	call _write;
	P1 = R5;
	R7 += 1;
	P5 += 12;
	R0 = [P1];
	cc =R7<R0;
	if !cc jump .L79;
.L83:
	R0 = B [P4+28] (Z);
	cc =R0==0;
	if cc jump .L80;
	P0 = 100 (X);
	R0 = B [P5+8] (Z);
	P0 = P0 + SP;
	R1 = ROT R0 BY 0 ||
	[SP+12] = R6 ||
	nop;
	R0 = P4;
	R2 = P0;
	call (P3);
	R1 = W [P5] (X);
	R0 = [SP+100];
	cc =R1==R0;
	if !cc jump .L80 (bp);
	R1 = [SP+124];
	R0 = 7 (X);
	cc =R1<=R0;
	if cc jump .L81;
	R0 = W [P5+2] (X);
	R0 += 7;
	cc =R1<=R0;
	if !cc jump .L80 (bp);
.L81:
	P0 = R4;
	P2 = FP + (FP << 1);
	R7 += 1;
	FP += 1;
	P2 = P0 + (P2 << 2);
	P0 = P5;
	R0 = [P0++];
	P1 = P2;
	[P1++] = R0;
	R0 = [P5+4];
	[P2+4] = R0;
	R0 = [P0+4];
	[P1+4] = R0;
	P1 = R5;
	P5 += 12;
	R0 = [P1];
	cc =R7<R0;
	if cc jump .L83 (bp);
.L79:
	P2 = R5;
	[P2] = FP;
	jump.l .L78;
.L258:
	P2.H = _shift_held;
	P2.L = _shift_held;
	R0 = 2 (X);
	P1 = 148 (X);
	B [P2] = R0;
	SP = SP + P1;
	FP = [SP++];
	RETS = [SP++];
	( r7:4, p5:3 ) = [sp++];

	rts;
.L448:
	P5.H = _waiting;
	B [P2] = R1;
	R1 = [P4+64];
	P5.L = _waiting;
	cc =R1==0;
	[SP+48] = P5;
	R0 = B [P5] (X);
	if !cc jump .L449 (bp);
	R1 = [P4+56];
	cc =R1==0;
	R0 = R0.B (Z);
	if !cc jump .L450 (bp);
	cc =R0==0;
	if !cc jump .L90;
	P2 = [P4+60];
	P3.H = _beat;
	P3.L = _beat;
	R2 = [P3];
	R0 = P2;
	R0 += -1;
	R1 = 63 (X);
	R2 += 1;
	cc =R0<=R1 (iu);
	[P3] = R2;
	if cc jump 6; jump.l .L86;
	P2 = P2 + (P2 << 1);
	R0 = P2;
	R0 <<= 3;
	R3 = 0 (X);
	R6 = 31 (X);
	R1 = 0 (X);
	R4 = 1 (X);
	P2 = 32 (X);
	LSETUP (.L97, .L457) LC1 = P2;
.L97:
	R5 = R2;
	R5 >>= R6;
	R1 <<= 1;
	R5 = R5 & R4;
	R1 = R5 | R1;
	cc =R0<=R1 (iu);
	R3 <<= 1;
	if !cc jump .L96 (bp);
	R1 = R1 - R0;
	BITSET (R3, 0);
.L96:
.L457:
	R6 += -1;
	R0 *= R3;
	cc =R0==R2;
	if !cc jump .L431 (bp);
	jump.s .L98;
.L441:
	R1 = W [P2+4] (Z);
	R0 = R1 & R0;
	cc =R0==0;
	if cc jump .L271 (bp);
	P2 = 45 (X);
	[SP+56] = P2;
	jump.l .L151;
.L152:
	R0 = B [FP+3] (Z);
	R2 = 5 (X);
	R2 = R2.L * R0.L (IS);
	R5 = 124 (X);
	R2 >>>= 8;
	R4 = SP;
	R3 = R4 + R5;
	cc =R2==3;
	P0 = P5;
	R5 = R3;
	R0 = 0 (X);
	if !cc jump .L173;
	I0 = R5;
	jump.s .L171;
.L452:
	R4 = P1;
	R4 = R4 - R0;
	I2 = R4;
	P2 = I2;
	LSETUP (.L170, .L456) LC0 = P2;
.L170:
	R1 = B [P0] (Z);
	R4 = R5 - R3;
	P2 = R5;
	B0 = R1;
	I0 = R4;
	[--SP] = P0;
	P0 = I0;
	LSETUP (.L172, .L455) LC1 = P0;
	P0 = [SP++];
.L172:
	R1 = B [P2+-1] (X);
	R4 = R1.B (Z);
	I1 = R1;
	R1 = B0;
	cc =R4<=R1 (iu);
	if cc jump .L451;
	R1 = I1;
.L455:
	B [P2--] = R1;
.L173:
	I0 = R3;
.L171:
	R1 = B [P0] (X);
	P2 = I0;
	B [P2] = R1;
	R0 += 1;
	R1 = P1;
	cc =R1==R0;
	if !cc jump 6 (bp); jump.l .L169;
	cc =R2==3;
	P0 += 1;
	R5 += 1;
	if !cc jump .L452;
	I0 = R5;
	jump.s .L171;
.L451:
	R1 = B [P0++] (X);
	B [P2] = R1;
	R0 += 1;
.L456:
	R5 += 1;
	jump.l .L169;
.L443:
	R5 = R3;
	R4 = R3 + R0;
.L180:
	R0 = [P4+1676];
	R1 = 39 (X);
	cc =R0<=R1;
	P2 = R5;
	R5 += 1;
	if !cc jump .L179;
	R0 = B [P2] (Z);
	R3 = [SP+56];
	R2 = ROT R0 BY 0 ||
	[SP+16] = R6 ||
	nop;
	[SP+12] = R3;
	R1 = R7;
	R0 = P4;
	call _play.part.0;
.L179:
	cc =R5==R4;
	if !cc jump .L180 (bp);
	jump.l .L146;
.L449:
	R0 = R0.B (Z);
	cc =R0==0;
	if !cc jump 6; jump.l .L94;
	jump.l .L95;
.L447:
	R1 = I0;
	cc =R1<=0;
	if cc jump .L417;
	R3 = 0 (X);
	P0.H = _seed;
	P2 = FP;
	[SP+56] = R3;
	P0.L = _seed;
.L107:
	R3 = B [P2+5] (Z);
	R2 = 0 (X);
	R4 = 31 (X);
	R0 = 0 (X);
	P1 = 32 (X);
	LSETUP (.L110, .L454) LC1 = P1;
.L110:
	R1 = R6;
	R1 >>= R4;
	R0 <<= 1;
	R1 = R1 & R7;
	R0 = R1 | R0;
	cc =R3<=R0 (iu);
	R2 <<= 1;
	if !cc jump .L109 (bp);
	R0 = R0 - R3;
	BITSET (R2, 0);
.L109:
.L454:
	R4 += -1;
	R0 = R3;
	R0 *= R2;
	R1 = B [P2+7] (Z);
	R0 = R6 - R0;
	R1 = R1 + R0;
	cc =R3<=R1;
	R2 = B [P2+6] (Z);
	if !cc jump .L111;
.L112:
	R1 = R1 - R3;
	cc =R3<=R1;
	if cc jump .L112 (bp);
.L111:
	R1 *= R2;
	cc =R3<=R1;
	if !cc jump .L113;
.L114:
	R1 = R1 - R3;
	cc =R3<=R1;
	if cc jump .L114 (bp);
.L113:
	cc =R2<=R1;
	if cc jump .L116 (bp);
	R4 = B [P5+6] (Z);
	R1 = 253 (X);
	cc =R4<=R1;
	if !cc jump .L120 (bp);
	R2 = [P0];
	R1 = R2 << 13;
	R1 = R1 ^ R2;
	R2 = R1 >> 17;
	R2 = R2 ^ R1;
	R1 = R2 << 5;
	R1 = R1 ^ R2;
	[P0] = R1;
	R1 >>= 24;
	cc =R4<=R1;
	if cc jump .L116 (bp);
.L120:
	cc =R0==0;
	R1 = B [P5+5] (Z);
	if cc jump .L453 (bp);
	R0 = 51 (X);
	R0 = R0.L * R1.L (IS);
	R0 >>>= 8;
	R3 = 109 (X);
	R0 = R3 - R0;
.L122:
	R1 = [P4+1676];
	R2 = 39 (X);
	cc =R1<=R2;
	if !cc jump .L116;
	R1 = B [P2+4] (Z);
	R3 = 6144 (X);
	[SP+12] = R0;
	R2 = ROT R1 BY 0 ||
	[SP+16] = R3 ||
	nop;
	R1 = ROT R5 BY 0 ||
	[SP+32] = P0 ||
	nop;
	R0 = P4;
	[SP+36] = P2;
	call _play.part.0;
	R4 = [FP];
	I0 = R4;
	P2 = [SP+36];
	P0 = [SP+32];
.L116:
	P1 = [SP+56];
	R4 = I0;
	P2 += 4;
	P1 += 1;
	R3 = P1;
	cc =R3<R4;
	[SP+56] = P1;
	if cc jump .L107 (bp);
.L417:
	R5 += 1;
	jump.l .L427;
.L453:
	R0 = 18 (X);
	R0 = R0.L * R1.L (IS);
	R0 >>>= 8;
	R4 = 109 (X);
	R0 = R0 + R4;
	jump.s .L122;
.L434:
	R1 = [P4+124];
	R3 = 31 (X);
	cc =R1==R3;
	if cc jump 6; jump.l .L71;
	P1.H = 52;
	P1.L = 25200;
	P1 = P4 + P1;
	R1 = [P1];
	cc =R1==0;
	if cc jump 6; jump.l .L71;
	P0 = R7;
	P1.H = _hand;
	P1.L = _hand;
	R2 = R7;
	R1 = P2;
	P1 = P0 + P1;
	P0.H = 52;
	R0 = B [P1] (Z);
	P0.L = 23866;
	P1 = P4 + P2;
	[SP+16] = R0;
	P1 = P1 + P0;
	R0 = B [P1] (Z);
	R0 >>= 4;
	[SP+12] = R0;
	R0 = P4;
	call _set_lock;
	R0 = B [P4+28] (Z);
	jump.l .L70;
.L274:
	R0 = 1 (X);
	jump.l .L199;
.L271:
	R4 = 85 (X);
	[SP+56] = R4;
	jump.l .L151;
.L166:
	R1 += -12;
.L428:
	R2 = 127 (X);
	cc =R1<=R2;
	if !cc jump .L166 (bp);
	jump.l .L165;
.L442:
	cc =R0==0;
	if !cc jump 6; jump.l .L146;
	jump.l .L419;
.L262:
	P0 = P5 + (P5 << 2);
	P0 = P5 + (P0 << 1);
	P2 = P0;
	P1.H = _grooves;
	P1.L = _grooves;
	P2 += 10;
	P2 = P2 + P1;
	P1 = P1 + P0;
	R0 = B [P1+10] (X);
.L263:
	R2 = R0;
	BITTGL (R2, 0);
	B [P2] = R2;
	R2 = R0.B (Z);
	cc =R2==1;
	if cc jump .L264;
	R0 = 2 (X);
.L264:
	P2.H = _flashes;
	P2.L = _flashes;
	B [P2] = R0;
	P2.H = _flash_ms;
	P2.L = _flash_ms;
	[P2] = R1;
	jump.l .L66;
.L267:
	FP = 0 (X);
	jump.s .L79;
.L251:
	R2 = 6 (X);
	cc =R0==R2;
	if !cc jump .L276;
	P5 = [P4+48];
	R7 = -1 (X);
	cc =P5<=7 (iu);
	if !cc jump 4; jump.s .L252;
	jump.s .L430;
.L276:
	R7 = -1 (X);
	jump.s .L430;
.L269:
	R2 = 1 (X);
	P1 = 0 (X);
	jump.s .L132;
.L446:
	P2.H = _shift_ms;
	R0 = 1 (X);
	P2.L = _shift_ms;
	B [P3] = R0;
	[P2] = R1;
	jump.l .L66;
.L450:
	cc =R0==0;
	if !cc jump 6; jump.l .L94;
	jump.s .L90;
.L131:
	P2.H = _seed;
	P2.L = _seed;
	R1 = [P2];
	R0 = R1 << 13;
	R0 = R0 ^ R1;
	R1 = R0 >> 17;
	R1 = R1 ^ R0;
	R0 = R1 << 5;
	R0 = R0 ^ R1;
	[P2] = R0;
	R0 >>= 24;
	cc =R2<=R0;
	if cc jump 4; jump.s .L134;
	jump.l .L100;
.L444:
	P2.H = _seed;
	P2.L = _seed;
	R5 = [P2];
	R1 = R5 << 13;
	R1 = R1 ^ R5;
	R5 = R1 >> 17;
	R5 = R5 ^ R1;
	R1 = R5 << 5;
	R1 = R1 ^ R5;
	[P2] = R1;
	R5 = B [P5+8] (Z);
	R1 >>= 8;
	P0 = R1;
	B0 = R5;
	jump.l .L182;
.L187:
	R0 += -1;
	R5 = P0;
	R0 = R0 - R5;
	R1 = P1;
	R0 = R0 + R1;
	jump.l .L188;
.L140:
	R1 = 13 (X);
	R1 = R1.L * R2.L (IS);
	R1 >>>= 8;
	R0 = 114 (X);
	R1 = R1 + R0;
	jump.s .L141;
	.size	_pages_tick, .-_pages_tick
	.align 4
.global _pages_note;
.type _pages_note, STT_FUNC;
_pages_note:
	cc =R1<=7 (iu);
	P2 = R0;
	[--sp] = ( r7:7, p5:4 );

	R0 = R2;
	if !cc jump .L481;
	R2 = 127 (X);
	cc =R0<=R2 (iu);
	if !cc jump .L481;
	cc =P2==0;
	if cc jump .L481;
	P1.H = 52;
	P1.L = 24108;
	P1 = P2 + P1;
	R2 = [P1];
	R3 = 4 (X);
	cc =R2==R3;
	if !cc jump .L483;
	R3 = [P2+48];
	cc =R3<=7 (iu);
	if !cc jump .L481;
	cc =R1==R3;
	if cc jump .L539;
.L481:
	( r7:7, p5:4 ) = [sp++];

	rts;
.L539:
	R7 = R3 << 1;
	P0 = R7;
	P4 = R3;
	I1 = R7;
	I2.H = _tumblers;
	I2.L = _tumblers;
	P5 = 7 (X);
	P1 = P0 + P4;
	R2 = P1;
	R7 = P1;
	R2 <<= 3;
	R2 = R2 - R7;
	R2 <<= 3;
	P4 = R2;
	P0 = I2;
	P1 = P0 + P4;
	P0 = [P1+160];
	cc =P0<=P5;
	if !cc jump .L484 (bp);
	I0 = P0;
	M0 = 1 (X);
	I0 += M0;
.L485:
	R7 = I1;
	R2 = R7 + R3;
	R3 = R2 << 3;
	R3 = R3 - R2;
	R3 <<= 3;
	P5 = R3;
	P4 = I2;
	R2 = I0;
	P0 = P0 + (P0 << 2);
	P1 = P4 + P5;
	[P1+160] = R2;
	P1.H = _seed;
	P1.L = _seed;
	R3 = [P1];
	R2 = R3 << 13;
	R3 = R2 ^ R3;
	R2 = R3 >> 17;
	R2 = R2 ^ R3;
	R3 = R2 << 5;
	R2 = R3 ^ R2;
	R3 = 1 (X);
	R3 <<= 22;
	A1 = R2.L * R3.L (FU);
	A1 = A1 >> 16;
	A0 = R2.H * R3.H, A1 += R2.H * R3.L (M);
	A1 += R3.H * R2.L (M);
	A1 = A1 >>> 15;
	P1 = P5 + (P0 << 2);
	P1 = P4 + P1;
	R3 = (A0 += A1);
	[P1] = R3;
	R3.H = 65459;
	R3.L = 13108;
	[P1+4] = R3;
	R3 = R2 << 13;
	R3 = R3 ^ R2;
	R2 = R3 >> 17;
	R2 = R2 ^ R3;
	R3 = R2 << 5;
	R3 = R3 ^ R2;
	R2 = 1 (X);
	R2 <<= 23;
	A1 = R3.L * R2.L (FU);
	A1 = A1 >> 16;
	A0 = R3.H * R2.H, A1 += R3.H * R2.L (M);
	A1 += R2.H * R3.L (M);
	A1 = A1 >>> 15;
	R2 = (A0 += A1);
	[P1+8] = R2;
	R2 = R3 << 13;
	R2 = R2 ^ R3;
	R3 = R2 >> 17;
	R3 = R3 ^ R2;
	R2 = R3 << 5;
	R2 = R2 ^ R3;
	R3.H = 51;
	R3.L = 13107;
	A1 = R2.L * R3.L (FU);
	A1 = A1 >> 16;
	A0 = R2.H * R3.H, A1 += R2.H * R3.L (M);
	A1 += R3.H * R2.L (M);
	P0.H = _seed;
	P0.L = _seed;
	A1 = A1 >>> 15 ||
	[P0] = R2 ||
	nop;
	R3.H = 25;
	R2 = (A0 += A1);
	R3.L = 39321;
	R2 = R2 + R3;
	[P1+12] = R2;
	R2 = 0 (X);
	B [P1+17] = R2;
	B [P1+18] = R2;
	B [P1+16] = R0;
	P1.H = 52;
	P1.L = 24108;
	P1 = P2 + P1;
	R2 = [P1];
.L483:
	R3 = 5 (X);
	cc =R2==R3;
	if !cc jump .L487;
	R3 = [P2+48];
	cc =R3<=7 (iu);
	if !cc jump .L481;
	cc =R1==R3;
	if !cc jump .L481 (bp);
	I1.H = _euclids;
	I1.L = _euclids;
	R2.H = _grooves;
	R2.L = _grooves;
	P0 = I1;
	I0 = 0 (X);
	P1 = 8 (X);
	LSETUP (.L489, .L552) LC1 = P1;
.L489:
	P4 = R2;
	R7 = [P0];
	R2 += 11;
	P0 += 60;
	R1 = B [P4] (Z);
	R1 = R1 | R7;
	R7 = I0;
	R7 = R7 | R1;
.L552:
	I0 = R7;
	cc =R7==0;
	if cc jump .L540 (bp);
.L490:
	R1 = R3 << 4;
	I3 = R1;
	R1 = R1 - R3;
	R1 <<= 2;
	P1 = R1;
	P0 = I1;
	I2 = R1;
	P2 = P0 + P1;
	P4 = [P2];
	R1 = P4;
	cc =R1<=0;
	I0 = P4;
	if cc jump .L491;
	R2 = -1 (X);
	R1 = 0 (X);
	P1 = P4;
	LSETUP (.L493, .L551) LC1 = P1;
.L493:
	R7 = B [P2+4] (Z);
	cc =R0==R7;
	if !cc jump .L492 (bp);
	R2 = R1;
.L492:
	R1 += 1;
.L551:
	P2 += 4;
	cc =R2==-1;
	if cc jump .L494;
	cc =R3<=3;
	if !cc jump .L495;
	P0 = R3;
	P2 = I3;
	P1 = I1;
	P2 -= P0;
	P2 = P1 + (P2 << 2);
	R0 = B [P2+44] (Z);
	cc =R0==R2;
	if cc jump .L495;
	B [P2+44] = R2;
	jump.s .L481;
.L487:
	R3 = 6 (X);
	cc =R2==R3;
	if !cc jump .L481;
	R3 = [P2+48];
	cc =R3<=7 (iu);
	if !cc jump .L481;
	cc =R1==R3;
	if !cc jump .L481 (bp);
	I3.H = _grooves;
	R2.H = _euclids;
	I3.L = _grooves;
	R2.L = _euclids;
	P0 = I3;
	I0 = 0 (X);
	P1 = 8 (X);
	LSETUP (.L505, .L550) LC1 = P1;
.L505:
	P4 = R2;
	R1 = B [P0] (Z);
	R2 += 60;
	P0 += 11;
	R7 = [P4];
	R1 = R1 | R7;
	R7 = I0;
	R7 = R7 | R1;
.L550:
	I0 = R7;
	cc =R7==0;
	if cc jump .L541 (bp);
.L506:
	R1 = R3 << 2;
	I0 = R1;
	R1 = (R1 + R3) << 1;
	R1 = R1 + R3;
	P1 = R1;
	P0 = I3;
	I2 = R1;
	P2 = P0 + P1;
	R1 = B [P2] (X);
	R2 = R1.B (Z);
	cc =R2==0;
	B1 = R1;
	B0 = R2;
	if cc jump .L507;
	P0.H = _grooves+1;
	P0.L = _grooves+1;
	P0 = P0 + P1;
	B2 = P0;
	P1 = P0;
	P2 = 0 (X);
	P0 = R2;
	LSETUP (.L513, .L549) LC1 = P0;
.L513:
	R1 = B [P1] (Z);
	cc =R0==R1;
	if cc jump .L542;
	P1 += 1;
.L549:
	P2 += 1;
	cc =R3<=3;
	if cc jump .L514;
	R1 = R3 << 3;
	P5 = R1;
	P2.H = _gknob;
	P2.L = _gknob;
	R7 = 134 (X);
	P2 = P2 + P5;
	R1 = B [P2+4] (Z);
	R1 = R1.L * R7.L (IS);
	R1 >>>= 8;
	cc =R1==0;
	if cc jump .L514 (bp);
	B0 = 0 (X);
	B1 = 1 (X);
.L515:
	R1 = I0;
	R1 = (R1 + R3) << 1;
	R1 = R1 + R3;
	P5 = R1;
	P4 = I3;
	R1 = B1;
	P0 = B0;
	P2 = P4 + P5;
	B [P2] = R1;
	P2 = P2 + P0;
	B [P2+1] = R0;
	jump.s .L481;
.L540:
	R1 = B [P2+28] (Z);
	cc =R1==0;
	if !cc jump .L490 (bp);
	P2.H = _beat;
	P2.L = _beat;
	R1 = -1 (X);
	[P2] = R1;
	jump.s .L490;
.L484:
	P0 = 7 (X);
	LSETUP (.L486, .L548) LC0 = P0;
.L486:
	I0 = P1;
	M0 = 20 (X);
	P4 = P1;
	I0 += M0;
	P5 = 4 (X);
	R7 = [I0++]; lsetup (1f, 1f) LC1 = P5; 1: MNOP || [P4++] = R7 || R7 = [I0++]; [P4++] = R7;
.L548:
	P1 += 20;
	I0 = 8 (X);
	P0 = 7 (X);
	jump.s .L485;
.L541:
	R1 = B [P2+28] (Z);
	cc =R1==0;
	if !cc jump .L506 (bp);
	P2.H = _beat;
	P2.L = _beat;
	R1 = -1 (X);
	[P2] = R1;
	jump.s .L506;
.L495:
	R1 = I0;
	R1 += -1;
	cc =R1<=R2;
	if cc jump .L543;
	R7 = I3;
	R0 = R7 - R3;
	R2 = R2 + R0;
	R2 = R2.L (Z);
	P2 = R2;
	R2 = I0;
	P1.H = _euclids+4;
	R0 = R2 + R0;
	P1.L = _euclids+4;
	R0 = R0.L (Z);
	P2 = P1 + (P2 << 2);
	P1 = R0;
	P0 = I1;
	P1 = P0 + (P1 << 2);
	P1 -= P2;
	P1 += -4;
	P1 = P1 >> 2;
	P1 += 1;
	LSETUP (.L499, .L547) LC1 = P1;
.L499:
	R0 = [P2+4];
.L547:
	[P2++] = R0;
	P4 = R3;
	P2 = I3;
	P5 = I1;
	P2 -= P4;
	P2 = P5 + (P2 << 2);
	R0 = B [P2+44] (Z);
	cc =R1<=R0;
	[P2] = R1;
	if !cc jump .L481 (bp);
.L519:
	R0 = R1;
	R0 += -1;
.L501:
	P1 = R3;
	P2 = I3;
	P4 = I1;
	P2 -= P1;
	P2 = P4 + (P2 << 2);
	B [P2+44] = R0;
	jump.s .L481;
.L542:
	R0 = R2;
	R0 += -1;
	R1 = P2;
	cc =R0<=R1;
	if cc jump .L512;
	P5 = R2;
	P4 = B2;
	P0 = I2;
	P2 = P2 + P4;
	P4 = I3;
	P1 = P5 + P0;
	P1 = P1 + P4;
	P1 -= P2;
	LSETUP (.L511, .L546) LC1 = P1;
.L511:
	R0 = B [P2+1] (X);
.L546:
	B [P2++] = R0;
.L512:
	R0 = I0;
	R0 = (R0 + R3) << 1;
	R0 = R0 + R3;
	P1 = R0;
	P0 = I3;
	R0 = B1;
	R0 += -1;
	P2 = P0 + P1;
	B [P2] = R0;
	jump.s .L481;
.L514:
	R1 = 8 (X);
	cc =R2==R1;
	if !cc jump .L518;
	R1 = I0;
	R1 = (R1 + R3) << 1;
	R1 = R1 + R3;
	P1 = R1;
	P0.H = _grooves+1;
	P0.L = _grooves+1;
	P2 = P0 + P1;
	P1 = 7 (X);
	LSETUP (.L517, .L545) LC1 = P1;
.L517:
	R1 = B [P2+1] (X);
.L545:
	B [P2++] = R1;
	B0 = 7 (X);
	jump.s .L515;
.L494:
	R1 = I0;
	R2 = 8 (X);
	cc =R1==R2;
	if cc jump .L502;
.L491:
	P2.H = _fresh.0;
	P0 = I0;
	P2.L = _fresh.0;
	P2 = P2 + (P0 << 1);
	R2 = B [P2+1] (X);
	I2 = R2;
	R1 = B [P2] (X);
	P0 += 1;
	R2 = I0;
.L503:
	P2 = R3;
	P1 = I3;
	P4 = I0;
	P5 = I1;
	R1 <<= 8;
	P1 -= P2;
	P2 = P1 + P4;
	P2 += 1;
	R0 = R0.B (Z);
	P2 = P5 + (P2 << 2);
	R0 = R0 | R1;
	W [P2] = R0;
	R0 = I2;
	P1 = P5 + (P1 << 2);
	B [P2+2] = R0;
	R0 = 0 (X);
	B [P2+3] = R0;
	[P1] = P0;
	B [P1+44] = R2;
	jump.s .L481;
.L502:
	P2.H = _euclids+4;
	P2.L = _euclids+4;
	P0 = I2;
	P2 = P2 + P0;
	P1 = 7 (X);
	LSETUP (.L504, .L544) LC1 = P1;
.L504:
	R1 = [P2+4];
.L544:
	[P2++] = R1;
	P0 = 8 (X);
	R2 = 7 (X);
	I2 = 4 (X);
	R1 = 9 (X);
	I0 = 7 (X);
	jump.s .L503;
.L518:
	R2 = B1;
	R2 += 1;
	B1 = R2;
	jump.s .L515;
.L507:
	cc =R3<=3;
	if cc jump .L524 (bp);
	R1 = R3 << 3;
	P1 = R1;
	P2.H = _gknob;
	P2.L = _gknob;
	R2 = 134 (X);
	P2 = P2 + P1;
	R1 = B [P2+4] (Z);
	R1 = R1.L * R2.L (IS);
	R1 >>>= 8;
	cc =R1==0;
	if cc jump .L518 (bp);
.L524:
	B1 = 1 (X);
	jump.s .L515;
.L543:
	P4 = R3;
	P2 = I3;
	P5 = I1;
	P2 -= P4;
	P2 = P5 + (P2 << 2);
	R0 = B [P2+44] (Z);
	cc =R1<=R0;
	[P2] = R1;
	if cc jump 4 (bp); jump.s .L481;
	cc =R1==0;
	R0 = 0 (X);
	if cc jump .L501 (bp);
	jump.s .L519;
	.size	_pages_note, .-_pages_note
	.align 4
.global _pages_knob;
.type _pages_knob, STT_FUNC;
_pages_knob:
	[--sp] = ( r7:6, p5:4 );

	P1.H = 33029;
	[--SP] = RETS;
	P1.L = 40220;
	P1 = [P1];
	R3 = R1;
	SP += -52;
	P2 = R0;
	cc =P1==0;
	R1 = R2;
	if cc jump .L623;
	P0.H = 52;
	P0.L = 24108;
	P0 = P1 + P0;
	R0 = [P0];
	R2 = 4 (X);
	cc =R0==R2;
	if !cc jump .L555;
	P0 = [P1+48];
	cc =P0<=7 (iu);
	if !cc jump .L623;
	cc =P2<=7 (iu);
	if !cc jump .L623;
	cc =P2==P0;
	if cc jump .L665 (bp);
.L623:
	SP += 52;
	RETS = [SP++];
	R0 = 0 (X);
	( r7:6, p5:4 ) = [sp++];

	rts;
.L665:
	cc =R3<=3 (iu);
	if !cc jump .L623;
	R7 = [P1+124];
	R2 = 31 (X);
	cc =R7==R2;
	I0 = R7;
	if cc jump .L560;
	P0.H = 52;
	P0.L = 25196;
	P0 = P1 + P0;
	R0 = 0 (X);
	[P0] = R0;
	P0.H = 52;
	P0.L = 25205;
	P0 = P1 + P0;
	B [P0] = R0;
	I1 = R3;
.L561:
	R0 = B [P1+31] (X);
	R2 = B [P1+29] (X);
	R0 = R0 | R2;
	R0 = R0.B (Z);
	cc =R0==0;
	if !cc jump .L666 (bp);
	R3 = I0;
	R6 = 15 (X);
	cc =R3<=R6 (iu);
	if !cc jump .L599;
.L596:
	P0 = [P1+68];
	P4 = 159 (X);
	cc =P0<=P4 (iu);
	if !cc jump .L667;
	R0 = P0;
	R2 = P2;
	R0 <<= 3;
	R0 = (R0 + R2) << 1;
	M0 = R0;
	I2.H = _locked;
	I2.L = _locked;
	R2 = I1;
	I2 += M0;
	R0.L = W [I2];
	R0 = R0.L (Z);
	R0 >>>= R2;
	cc = !BITTST (R0,0);
	if cc jump .L668;
	P4 = P2 + P2;
	[SP+32] = P4;
	P4 = (P4 + P2) << 2;
	R0 = P4;
	P0 = P0 + (P0 << 1);
	R0 = R0 + R2;
	R2 = P0;
	R2 <<= 9;
	R0 <<= 4;
	R0 = R0 + R2;
	P4 = R0;
	P5 = I0;
	R2 = 255 (X);
	P0 = P4 + P5;
	P4.H = 32964;
	P4.L = 0;
	P0 = P0 + P4;
	R0 = B [P0] (Z);
	cc =R0==R2;
	if cc jump .L600;
	R0 = R1 + R0;
	R0 = min(R0,R2);
	R1 = 0 (X);
	R0 = max(R0,R1);
.L601:
	[SP+16] = R0;
	R0 = I0;
	[SP+12] = R0;
	R2 = I1;
	R1 = P2;
	R0 = P1;
	call _set_lock;
.L578:
	R0 = 1 (X);
.L670:
	SP += 52;
	RETS = [SP++];
	( r7:6, p5:4 ) = [sp++];

	rts;
.L666:
	P0.H = 52;
	P0.L = 25200;
	P0 = P1 + P0;
	R0 = [P0];
	cc =R0==0;
	if !cc jump .L609;
	R0 = I0;
	R2 = 15 (X);
	cc =R0<=R2 (iu);
	if cc jump .L596 (bp);
	R0 = B [P1+28] (Z);
	cc =R0==0;
	if cc jump .L669 (bp);
	P1.H = _knob;
	P2 = P2 + (P2 << 1);
	P1.L = _knob;
	P2 = P1 + (P2 << 2);
	P5 = I1;
	P2 = P2 + P5;
.L663:
	R0 = B [P2] (Z);
	R0 = R1 + R0;
	R1 = 255 (X);
	R0 = min(R0,R1);
	R1 = 0 (X);
	R0 = max(R0,R1);
	B [P2] = R0;
	R0 = 1 (X);
	jump.s .L670;
.L555:
	R6 = 5 (X);
	cc =R0==R6;
	if cc jump 4 (bp); jump.s .L557;
	R0 = [P1+48];
	R7 = P2;
	R2 = R7 | R0;
	cc =R2<=7 (iu);
	if !cc jump .L623;
	cc =R7==R0;
	if !cc jump .L623 (bp);
	cc =R3<=3 (iu);
	if !cc jump .L623;
	R6 = 60 (X);
	R6 *= R0;
	P0 = R6;
	I2.H = _euclids;
	I2.L = _euclids;
	P4 = I2;
	P0 = P4 + P0;
	R2 = B [P0+45] (Z);
	cc =R2==0;
	if cc jump .L562 (bp);
	P5 = [P1+124];
	R3 += 8;
	I1 = R3;
	R3 = 31 (X);
	R2 = P5;
	cc =R2==R3;
	I0 = P5;
	if cc jump .L572;
	P0.H = 52;
	P0.L = 25196;
	P0 = P1 + P0;
	R0 = 0 (X);
	[P0] = R0;
	P0.H = 52;
	P0.L = 25205;
	P0 = P1 + P0;
	B [P0] = R0;
	jump.s .L561;
.L560:
	R0 = B [P1+31] (X);
	R2 = B [P1+29] (X);
	R0 = R0 | R2;
	R0 = R0.B (Z);
	cc =R0==0;
	if !cc jump .L576 (bp);
.L577:
	P4 = R3;
	P0 = P2 + P2;
	P1.H = _knob;
	[SP+32] = P0;
	P1.L = _knob;
	P0 = (P0 + P2) << 2;
	P1 = P1 + P0;
	P1 = P1 + P4;
	R0 = B [P1] (Z);
	R0 = R1 + R0;
	R1 = 255 (X);
	R0 = min(R0,R1);
	P5.H = _now;
	R1 = 0 (X);
	R1 = max(R0,R1);
	P5.L = _now;
	B [P1] = R1;
	[SP+40] = P5;
.L606:
	P1 = [SP+32];
	P4 = [SP+40];
	P5 = R3;
	R0 = 1 (X);
	P2 = (P2 + P1) << 2;
	P2 = P4 + P2;
	P2 = P2 + P5;
	B [P2] = R1;
	jump.s .L670;
.L667:
	P5 = P2 + P2;
	[SP+32] = P5;
.L600:
	P0 = [SP+32];
	P5 = I1;
	P0 = (P0 + P2) << 2;
	P4 = P0;
	P0.H = _knob;
	P0.L = _knob;
	P0 = P0 + P4;
	P0 = P0 + P5;
	R0 = B [P0] (Z);
	R0 = R1 + R0;
	R1 = 255 (X);
	R0 = min(R0,R1);
	R1 = 0 (X);
	R0 = max(R0,R1);
	jump.s .L601;
.L673:
	cc =R0<=3;
	if !cc jump .L572 (bp);
	cc =R3==3;
	if !cc jump .L579;
.L572:
	R0 = B [P1+29] (X);
	R2 = B [P1+31] (X);
	R0 = R0 | R2;
	R0 = R0.B (Z);
	cc =R0==0;
	R3 = I1;
	if cc jump .L577 (bp);
.L576:
	P0.H = 52;
	P0.L = 25200;
	P0 = P1 + P0;
	R0 = [P0];
	cc =R0==0;
	if !cc jump .L671;
	R0 = B [P1+28] (Z);
	cc =R0==0;
	if !cc jump .L607 (bp);
	R0 = 12 (X);
	R2 = P2;
	R0 *= R2;
	P0 = R0;
	P4 = R3;
	P1.H = _knob;
	P1.L = _knob;
	P5.H = _now;
	P1 = P1 + P0;
	P1 = P1 + P4;
	R0 = B [P1] (Z);
	R0 = R1 + R0;
	R1 = 255 (X);
	R0 = min(R0,R1);
	R1 = 0 (X);
	R1 = max(R0,R1);
	P5.L = _now;
	P0 = P2 + P2;
	B [P1] = R1;
	[SP+40] = P5;
	[SP+32] = P0;
	jump.s .L606;
.L607:
	P0.H = _now;
	P0.L = _now;
	P4 = P2 + P2;
	[SP+40] = P0;
	P5 = [SP+40];
	P0 = P4;
	[SP+32] = P4;
	P4 = R3;
	P0 = (P0 + P2) << 2;
	P0 = P5 + P0;
	P5.H = 52;
	P5.L = 23866;
	P0 = P0 + P4;
	R0 = B [P0] (Z);
	P0 = P1 + P2;
	P0 = P0 + P5;
	R2 = B [P0] (Z);
	P4.H = _hand_track;
	P0.H = _hands;
	P0.L = _hands;
	P4.L = _hand_track;
	R2 >>= 4;
	R6 = [P0];
	P4 = [P4];
	I0 = R2;
	[SP+48] = R6;
	R2 = 1 (X);
	R6 >>>= R3;
	R6 = R6 & R2;
	cc =R6==0;
	[SP+36] = P4;
	if cc jump .L672 (bp);
	P0 = [SP+36];
	cc =P2==P0;
	if cc jump .L604;
	R0 = R1 + R0;
	R1 = 255 (X);
	R0 = min(R0,R1) ||
	[SP+20] = R3 ||
	nop;
	R1 = R1 -|- R1 ||
	[SP+24] = P2 ||
	nop;
	R1 = max(R0,R1);
	P4 = I0;
	P5.H = _hand;
	[SP+44] = R1;
	[SP+16] = R1;
	R2 = ROT R3 BY 0 ||
	[SP+12] = P4 ||
	nop;
	R1 = P2;
	R0 = P1;
	P5.L = _hand;
	call _set_lock;
	P0 = 0 (X);
	[SP+36] = P5;
	R3 = [SP+20];
	P2 = [SP+24];
.L605:
	P5 = R3;
	P4 = [SP+36];
	R0 = 1 (X);
	P1.H = _hand_track;
	R0 <<= R3;
	R1 = P0;
	P1.L = _hand_track;
	[P1] = P2;
	R0 = R0 | R1;
	P1 = P4 + P5;
	R1 = B [SP+44] (X);
	P0.H = _hands;
	B [P1] = R1;
	P0.L = _hands;
	P1.H = 32770;
	[P0] = R0;
	P1.L = 33428;
	[SP+28] = R1;
	[SP+20] = R3;
	[SP+24] = P2;
	call (P1);
	R3 = [SP+20];
	P0 = R3;
	P1.H = _hand_ms;
	P1.L = _hand_ms;
	P1 = P1 + (P0 << 2);
	[P1] = R0;
	P2 = [SP+24];
	R1 = [SP+28];
	jump.s .L606;
.L671:
	I1 = R3;
.L609:
	R1 = [P1+68];
	R6 = 159 (X);
	R0 = 1 (X);
	R3 = I1;
	cc =R1<=R6 (iu);
	R0 <<= R3;
	if cc jump .L655 (bp);
	R0 = ~R0;
.L595:
	P1.H = _hands;
	P1.L = _hands;
	R1 = [P1];
	R0 = R0 & R1;
	[P1] = R0;
	P2 = P2 + (P2 << 1);
	P1.H = _now;
	P0 = P2 << 2;
	P1.L = _now;
	P2 = I1;
	P1 = P1 + P0;
	P1 = P1 + P2;
	P2.H = _knob;
	P2.L = _knob;
	P2 = P2 + P0;
	P4 = I1;
	P2 = P2 + P4;
	R0 = B [P2] (X);
	B [P1] = R0;
	R0 = 1 (X);
	jump.s .L670;
.L672:
	R0 = R1 + R0;
	R1 = 255 (X);
	R0 = min(R0,R1) ||
	[SP+20] = R3 ||
	nop;
	R1 = R1 -|- R1 ||
	[SP+24] = P2 ||
	nop;
	R1 = max(R0,R1) ||
	[SP+28] = R6 ||
	nop;
	R0 = I0;
	[SP+44] = R1;
	[SP+16] = R1;
	[SP+12] = R0;
	R2 = R3;
	R1 = P2;
	R0 = P1;
	call _set_lock;
	P2 = [SP+24];
	P1 = [SP+36];
	R3 = [SP+20];
	P0 = [SP+28];
	cc =P2==P1;
	if cc jump .L660;
	P4.H = _hand;
	P4.L = _hand;
	[SP+36] = P4;
	jump.s .L605;
.L668:
	P0 = P2 + P2;
	[SP+32] = P0;
	jump.s .L600;
.L655:
	R1 <<= 3;
	R7 = P2;
	R1 = (R1 + R7) << 1;
	P0 = R1;
	P1.H = _locked;
	P1.L = _locked;
	R0 = ~R0;
	P1 = P1 + P0;
	R1 = W [P1] (X);
	R1 = R0 & R1;
	W [P1] = R1;
	jump.s .L595;
.L599:
	P1.H = _knob;
	P2 = P2 + (P2 << 1);
	P1.L = _knob;
	P2 = P1 + (P2 << 2);
	P0 = I1;
	P2 = P2 + P0;
	jump.s .L663;
.L660:
	P5.H = _hand;
	P5.L = _hand;
	P0 = [SP+48];
	[SP+36] = P5;
	jump.s .L605;
.L604:
	P4 = R3;
	P0.H = _hand;
	P0.L = _hand;
	[SP+36] = P0;
	P5 = I0;
	P0 = P0 + P4;
	R0 = B [P0] (Z);
	R0 = R1 + R0;
	R1 = 255 (X);
	R0 = min(R0,R1) ||
	[SP+12] = P5 ||
	nop;
	R1 = R1 -|- R1 ||
	[SP+20] = R3 ||
	nop;
	R1 = max(R0,R1) ||
	[SP+24] = P2 ||
	nop;
	[SP+44] = R1;
	[SP+16] = R1;
	R2 = R3;
	R1 = P2;
	R0 = P1;
	call _set_lock;
	P0 = [SP+48];
	R3 = [SP+20];
	P2 = [SP+24];
	jump.s .L605;
.L669:
	P1.H = _knob;
	P1.L = _knob;
	P2 = P2 + (P2 << 1);
	P2 = P1 + (P2 << 2);
	P1 = I1;
	P2 = P2 + P1;
	jump.s .L663;
.L562:
	I1 = R3;
	R6 = [P1+124];
	R2 = 31 (X);
	cc =R6==R2;
	I0 = R6;
	I1 += 4;
	if cc jump .L673;
	P0.H = 52;
	P0.L = 25196;
	P0 = P1 + P0;
	R0 = 0 (X);
	[P0] = R0;
	P0.H = 52;
	P0.L = 25205;
	P0 = P1 + P0;
	cc =P2<=3;
	B [P0] = R0;
	if cc jump 4 (bp); jump.s .L561;
	cc =R3==3;
	if !cc jump 4; jump.s .L561;
.L579:
	P0 = P2 << 2;
	P0 = P0 << 2;
	P1 = P0;
	P1 -= P2;
	P4 = I2;
	I3 = P0;
	P0 = P4 + (P1 << 2);
	R0 = [P0];
	cc =R0==0;
	if cc jump .L578;
	R0 = B [P0+44] (Z);
	P0 = R3;
	I1 = R0;
	P1 = P1 + P0;
	P1 += 12;
	P1 = P4 + (P1 << 2);
	R0 = [P1];
	R0 = R1 + R0;
	R1 = 7 (X);
	cc =R0<=R1;
	if cc jump .L674;
	R2 = R0 >> 3;
	R1 = R2 << 3;
	R0 = R0 - R1;
	[P1] = R0;
.L581:
	R6 = -7 (X);
	cc =R0<R6;
	if !cc jump .L675;
	P0 = R0;
	P1 = -8 (X);
	R6 = I3;
	R7 = P2;
	R2 += -1;
	P1 -= P0;
	R1 = P1;
	R1 >>= 3;
	R2 = R2 - R1;
	R1 = R6 - R7;
	R6 = R1 + R3;
	P0 = R6;
	R7 = -8 (X);
	R6 = P1;
	P4 = I2;
	R6 = R6 & R7;
	R0 += 8;
	R0 = R0 + R6;
	P0 = P4 + (P0 << 2);
	[P0+48] = R0;
	R0 = I1;
	R1 = R1 + R0;
	P1 = R1;
	cc =R3==0;
	P1 += 1;
	P1 = P4 + (P1 << 2);
	R1 = B [P1+1] (X);
	R6 = R1.B (Z);
	P0 = R6;
	if cc jump .L583 (bp);
	cc =R3==1;
	if cc jump .L584;
	R0 = B [P1+3] (Z);
	R2 = R0 + R2;
	cc =R2<0;
	if !cc jump .L585;
	R0 = 0 (X);
.L591:
	R3 = I3;
	R6 = P2;
	R2 = R3 - R6;
	P4 = R2;
	P5 = I1;
	P1 = P4 + P5;
	P4 = I2;
	P1 = P4 + (P1 << 2);
	B [P1+7] = R0;
.L587:
	R2 = I3;
	R3 = P2;
	R0 = R2 - R3;
	R6 = I1;
	R0 = R0 + R6;
	P1 = R0;
	P4 = I2;
	R2 = P0;
	P1 += 1;
	P1 = P4 + (P1 << 2);
	R0 = B [P1+2] (Z);
	cc =R2<R0 (iu);
	if !cc jump .L592 (bp);
	B [P1+2] = R1;
.L592:
	R6 = P2;
	R3 = I3;
	R0 = R3 - R6;
	R7 = I1;
	R0 = R0 + R7;
	P2 = R0;
	P1 = I2;
	R2 = P0;
	P2 += 1;
	P2 = P1 + (P2 << 2);
	R0 = B [P2+3] (Z);
	cc =R2<=R0 (iu);
	if cc jump 4; jump.s .L578;
	R0 = R1;
	R0 += -1;
	B [P2+3] = R0;
	R0 = 1 (X);
	jump.s .L670;
.L583:
	R7 = P0;
	R0 = 16 (X);
	R2 = R7 + R2;
	R2 = min(R2,R0);
	R1 = 2 (X);
	R1 = max(R2,R1);
	R3 = P2;
	R2 = I3;
	R0 = R2 - R3;
	P0 = R0;
	P4 = I1;
	P5 = I2;
	R0 = R1.B (Z);
	P1 = P0 + P4;
	P1 = P5 + (P1 << 2);
	B [P1+5] = R1;
	P0 = R0;
	jump.s .L587;
.L584:
	R3 = I3;
	R6 = P2;
	R0 = R3 - R6;
	P4 = R0;
	P5 = I1;
	P1 = P4 + P5;
	P4 = I2;
	P1 = P4 + (P1 << 2);
	R0 = B [P1+6] (Z);
	R0 = R0 + R2;
	cc =R0<=0;
	if !cc jump .L589 (bp);
	R0 = 1 (X);
.L590:
	R3 = I3;
	R6 = P2;
	R2 = R3 - R6;
	P4 = R2;
	P5 = I1;
	P1 = P4 + P5;
	P4 = I2;
	P1 = P4 + (P1 << 2);
	B [P1+6] = R0;
	jump.s .L587;
.L675:
	R1 = P2;
	R7 = I3;
	R0 = R7 - R1;
	R6 = I1;
	R0 = R0 + R6;
	P1 = R0;
	P0 = I2;
	cc =R3==0;
	P1 += 1;
	P1 = P0 + (P1 << 2);
	R1 = B [P1+1] (X);
	R0 = R1.B (Z);
	P0 = R0;
	if cc jump .L583 (bp);
	cc =R3==1;
	if cc jump .L584;
	R0 = B [P1+3] (Z);
	R2 = R0 + R2;
.L585:
	R0 = P0;
	R0 += -1;
	R0 = min(R0,R2);
	jump.s .L591;
.L674:
	[P1] = R0;
	R2 = 0 (X);
	jump.s .L581;
.L589:
	R2 = P0;
	R0 = min(R2,R0);
	jump.s .L590;
.L557:
	R2 = 6 (X);
	cc =R0==R2;
	if cc jump 4 (bp); jump.s .L623;
	R0 = [P1+48];
	R6 = P2;
	R2 = R6 | R0;
	cc =R2<=7 (iu);
	if cc jump 4 (bp); jump.s .L623;
	cc =R6==R0;
	if cc jump 4; jump.s .L623;
	cc =R3<=3 (iu);
	if cc jump 4 (bp); jump.s .L623;
	R2 = 60 (X);
	R0 *= R2;
	P4 = R0;
	P0.H = _euclids;
	P0.L = _euclids;
	P0 = P0 + P4;
	R0 = B [P0+45] (Z);
	cc =R0==0;
	R0 = [P1+124];
	if cc jump .L567 (bp);
	R2 = 31 (X);
	cc =R0==R2;
	if cc jump .L569;
.L568:
	P0.H = 52;
	P0.L = 25196;
	P4.H = 52;
	P0 = P1 + P0;
	R0 = 0 (X);
	P4.L = 25205;
	[P0] = R0;
	P1 = P1 + P4;
	R0 = 0 (X);
	B [P1] = R0;
.L569:
	P0 = P2 + (P2 << 2);
	P1.H = _grooves;
	P0 = P2 + (P0 << 1);
	P1.L = _grooves;
	P1 = P1 + P0;
	R0 = B [P1+10] (Z);
	R0 = -R0;
	R0 >>= 31;
	P0 = R3;
	P1 = R0;
	R3 = P2;
	R0.H = _gknob;
	R0.L = _gknob;
	R3 <<= 3;
	R2 = R0 + R3;
	P1 = P0 + (P1 << 2);
	P0 = R2;
	P0 = P0 + P1;
	R2 = B [P0] (Z);
	R1 = R2 + R1;
	cc =R1<0;
	if cc jump .L676;
	R2 = 255 (X);
	cc =R1<=R2;
	if cc jump .L571 (bp);
	R1 = -1 (X);
.L571:
	R0 = R0 + R3;
	P0 = R0;
	R0 = 1 (X);
	P1 = P0 + P1;
	B [P1] = R1;
	jump.s .L670;
.L676:
	R1 = 0 (X);
	jump.s .L571;
.L567:
	R6 = 31 (X);
	cc =R0==R6;
	if !cc jump .L568 (bp);
	jump.s .L569;
	.size	_pages_knob, .-_pages_knob
	.align 4
.global _pages_dials;
.type _pages_dials, STT_FUNC;
_pages_dials:
	[--sp] = ( r7:4, p5:3 );

	P2.H = 33029;
	LINK 32;
	P2.L = 40220;
	P5 = [P2];
	R0 = P5;
	call _our_page;
	cc =R0==-1;
	R7 = R0;
	if cc jump .L713;
	P4.H = _flashes;
	P4.L = _flashes;
	R0 = B [P4] (Z);
	cc =R0==0;
	FP = [P5+48];
	if !cc jump .L739 (bp);
.L679:
	R5 = -1 (X);
.L680:
	R6 = FP;
	R6 <<= 4;
	P4 = R6;
	P0 = FP + FP;
	P3.H = _euclids;
	[SP+24] = P0;
	P3.L = _euclids;
	P0 = (P0 + FP) << 2;
	P4 -= FP;
	[SP+28] = P0;
	R4 = 40 (X);
	P4 = P3 + (P4 << 2);
.L711:
	R2 = R4;
	cc =R7==0;
	R2 += -40;
	if !cc jump .L707;
	R1 = [P5+124];
	R3 = 15 (X);
	cc =R1<=R3 (iu);
	if cc jump .L740;
	P2 = R4;
	P0 = [SP+28];
	R0 = 247 (X);
	P1 = P2 + P0;
	P2.H = _now;
	P2.L = _now;
	P1 = P1 + P2;
	R1 = B [P1+-40] (Z);
	R1 += 1;
	R1 = R1.L * R0.L (IS);
	R1 >>>= 8;
	R1 += 8;
.L695:
	R2 = 255 (X);
	R0 = min(R1,R2);
	R0 += 1;
	P0 = 84 (X);
	R3 = 0 (X);
.L710:
	R2 *= R0;
	R1 = R2 >>> 8;
	R2 = 0 (X);
	[SP+16] = R2;
	R2 = P0;
	R0 *= R2;
	P1.H = 32771;
	R0 >>>= 8;
	[SP+12] = R0;
	R2 = R3;
	R0 = R4;
	P1.L = 54206;
	call (P1);
	R4 += 1;
	R3 = 44 (X);
	cc =R4==R3;
	if !cc jump .L711 (bp);
.L706:
	SP += 32;
	FP = [SP++];
	R0 = 1 (X);
	RETS = [SP++];
	( r7:4, p5:3 ) = [sp++];

	rts;
.L689:
	P0 = [SP+24];
	P1.H = _now;
	P1.L = _now;
	P0 = (P0 + FP) << 2;
	P1 = P1 + P0;
	P0 = R2;
	P1 = P1 + P0;
.L738:
	R1 = B [P1] (Z);
	R1 += 1;
	R0 = 247 (X);
	R1 = R1.L * R0.L (IS);
	R1 >>>= 8;
	R1 += 8;
.L686:
	cc =R5==0;
	if !cc jump .L705 (bp);
	R0 = 0 (X);
	P1.H = 32771;
	[SP+16] = R0;
	[SP+12] = R0;
	R2 = 0 (X);
	R1 = 0 (X);
	R0 = R4;
	P1.L = 54206;
	call (P1);
	R2 = 43 (X);
	cc =R4==R2;
	if cc jump .L706;
	R2 = R4;
	R2 += -39;
	R4 += 1;
.L707:
	R0 = B [P4+45] (Z);
	cc =R0==0;
	P0 = P3;
	R3 = R6;
	if cc jump .L717 (bp);
	R0 = 8 (X);
.L684:
	cc =R7==2;
	if cc jump .L741;
	R2 = R2 + R0;
	R1 = [P5+124];
	R0 = 15 (X);
	cc =R1<=R0 (iu);
	if cc jump .L687;
	cc =FP<=3;
	if !cc jump .L689 (bp);
	R0 = 6 (X);
	cc =R2<=R0;
	if !cc jump .L689;
	P2 = R6;
	R1 = 8 (X);
	P2 -= FP;
	P2 = P3 + (P2 << 2);
	R0 = [P2];
	cc =R0==0;
	if cc jump .L686;
.L712:
	P1 = R3;
	R1 = 4 (X);
	cc =R2==R1;
	P1 -= FP;
	P2 = P0 + (P1 << 2);
	R0 = B [P2+44] (Z);
	P2 = R0;
	P1 = P1 + P2;
	P1 += 1;
	P1 = P0 + (P1 << 2);
	R0 = B [P1+1] (X);
	if cc jump .L742;
	R3 = 5 (X);
	cc =R2==R3;
	if cc jump .L743;
	R1 = B [P1+3] (Z);
	R2 = 255 (X);
	R2 = R1.L * R2.L (FU);
	I1 = R2;
.L701:
	R0 = R0.B (Z);
	P2 = R0;
	R2 = 0 (X);
	P0 = 31 (X);
	R0 = 0 (X);
	P1 = 32 (X);
	P2 += -1;
	LSETUP (.L703, .L747) LC1 = P1;
.L703:
	R3 = P0;
	R1 = I1;
	R1 >>= R3;
	R3 = 1 (X);
	R1 = R1 & R3;
	R0 <<= 1;
	R0 = R1 | R0;
	R1 = P2;
	cc =R1<=R0 (iu);
	R2 <<= 1;
	if !cc jump .L702 (bp);
	R0 = R0 - R1;
	BITSET (R2, 0);
.L702:
.L747:
	P0 += -1;
	R2 += 1;
	R1 = R2 << 5;
	R1 = R1 - R2;
	R1 <<= 3;
	R1 = R1 - R2;
	cc =R1<0;
	if !cc jump .L704 (bp);
	R0 = 255 (X);
	R1 = R1 + R0;
.L704:
	R1 >>>= 8;
	R1 += 8;
.L697:
	cc =R7==0;
	if cc jump .L695 (bp);
	jump.s .L686;
.L739:
	P1.H = 32770;
	P1.L = 33428;
	call (P1);
	P1.H = _flash_ms;
	P1.L = _flash_ms;
	R1 = [P1];
	R0 = R0 - R1;
	R1 = 149 (X);
	cc =R0<=R1 (iu);
	if cc jump .L714 (bp);
	R2 = 299 (X);
	cc =R0<=R2 (iu);
	if cc jump .L715 (bp);
	R3 = 449 (X);
	cc =R0<=R3 (iu);
	if cc jump .L744 (bp);
	R1 = 599 (X);
	cc =R0<=R1 (iu);
	if !cc jump .L682 (bp);
	R0 = B [P4] (Z);
	cc =R0==2;
	R5 = 0 (X);
	if cc jump .L680 (bp);
	jump.s .L682;
.L714:
	R5 = 1 (X);
	jump.s .L680;
.L741:
	P0 = FP + (FP << 2);
	P1.H = _grooves;
	P0 = FP + (P0 << 1);
	P1.L = _grooves;
	P1 = P1 + P0;
	R0 = B [P1+10] (Z);
	R0 = -R0;
	R0 >>= 31;
	P1 = R0;
	R0 = FP;
	R0 <<= 3;
	P2 = R0;
	P0.H = _gknob;
	P0.L = _gknob;
	P0 = P0 + P2;
	P2 = R2;
	P0 = P0 + P2;
	P1 = P0 + (P1 << 2);
	jump.s .L738;
.L717:
	R0 = 4 (X);
	jump.s .L684;
.L705:
	R0 = 3 (X);
	R0 = R0.L * R7.L (FU);
	P0 = R0;
	P2.H = _colour;
	P2.L = _colour;
	cc =R5==1;
	P0 = P0 + P2;
	R0 = B [P0+2] (Z);
	R2 = B [P0] (Z);
	R3 = B [P0+1] (Z);
	P0 = R0;
	if cc jump .L745;
	R0 = 255 (X);
	R0 = min(R1,R0);
	R0 += 1;
	R3 *= R0;
	R3 >>>= 8;
	jump.s .L710;
.L740:
	P1 = [P5+68];
	P0 = 159 (X);
	cc =P1<=P0 (iu);
	if !cc jump .L746;
.L691:
	R0 = P1;
	R0 <<= 3;
	R3 = FP;
	R0 = (R0 + R3) << 1;
	P2 = R0;
	P0.H = _locked;
	P0.L = _locked;
	P0 = P0 + P2;
	R0 = W [P0] (Z);
	R0 >>>= R2;
	cc = !BITTST (R0,0);
	if cc jump .L693;
	R0 = [SP+28];
	R0 = R2 + R0;
	[SP+20] = R0;
	R3 = 1536 (X);
	R0 = P1;
	R3 = R0.L * R3.L (FU) ||
	R0 = [SP+20] ||
	nop;
	R0 <<= 4;
	R0 = R0 + R1;
	P0 = R0;
	P1 = R3;
	P2.H = 32964;
	P2.L = 0;
	R1 = 255 (X);
	P1 = P0 + P1;
	P1 = P1 + P2;
	R0 = B [P1] (Z);
	cc =R0==R1;
	if cc jump .L693;
.L694:
	cc =FP<=3;
	if !cc jump .L692 (bp);
	R1 = R2;
	R1 += -4;
	cc =R1<=2 (iu);
	if !cc jump .L692 (bp);
	R3 = FP;
	R3 <<= 4;
	P2 = R3;
	P0.H = _euclids;
	P0.L = _euclids;
	R1 = 8 (X);
	P2 -= FP;
	P2 = P0 + (P2 << 2);
	R0 = [P2];
	cc =R0==0;
	if cc jump .L697 (bp);
	jump.s .L712;
.L687:
	P1 = [P5+68];
	P0 = 159 (X);
	cc =P1<=P0 (iu);
	if cc jump .L691 (bp);
.L693:
	P0 = [SP+24];
	P1.H = _knob;
	P1.L = _knob;
	P0 = (P0 + FP) << 2;
	P1 = P1 + P0;
	P0 = R2;
	P1 = P1 + P0;
	R0 = B [P1] (Z);
	jump.s .L694;
.L745:
	R0 = 256 (X);
	jump.s .L710;
.L713:
	SP += 32;
	FP = [SP++];
	R0 = 0 (X);
	RETS = [SP++];
	( r7:4, p5:3 ) = [sp++];

	rts;
.L746:
	P0 = [SP+24];
	P2 = R2;
	P1.H = _knob;
	P1.L = _knob;
	P0 = (P0 + FP) << 2;
	P1 = P1 + P0;
	P1 = P1 + P2;
	R0 = B [P1] (Z);
.L692:
	R0 += 1;
	R1 = 247 (X);
	R1 = R0.L * R1.L (IS);
	R1 >>>= 8;
	R1 += 8;
	jump.s .L697;
.L715:
	R5 = 0 (X);
	jump.s .L680;
.L744:
	R0 = B [P4] (Z);
	cc =R0==2;
	if cc jump .L714;
.L682:
	R0 = 0 (X);
	B [P4] = R0;
	jump.s .L679;
.L742:
	R0 = R0.B (Z);
	R1 = 18 (X);
	R1 = R1.L * R0.L (IS);
	R1 += -35;
	R0 = R1 << 5;
	R0 = R0 - R1;
	R0 <<= 3;
	R0 = R0 - R1;
	cc =R0<0;
	if !cc jump .L699 (bp);
	R1 = 255 (X);
	R0 = R0 + R1;
.L699:
	R1 = R0 >>> 8;
	R1 += 8;
	jump.s .L697;
.L743:
	R2 = B [P1+2] (Z);
	R2 += -1;
	R1 = R2 << 8;
	R1 = R1 - R2;
	I1 = R1;
	jump.s .L701;
	.size	_pages_dials, .-_pages_dials
	.align 4
.global _pages_fade;
.type _pages_fade, STT_FUNC;
_pages_fade:
	[--sp] = ( r7:7, p5:5 );

	P2.H = 33029;
	[--SP] = RETS;
	P2.L = 40220;
	SP += -12;
	P5 = R0;
	R0 = [P2];
	R7 = R1;
	call _our_page;
	cc =R0==-1;
	R1 = R0;
	if cc jump .L751;
	R0 = 3 (X);
	R1 = R0.L * R1.L (FU);
	P1 = R1;
	P2.H = 2050;
	P5 = P5 + (P5 << 2);
	P2.L = 54180;
	P0 = P5 + P2;
	P5.H = _colour;
	P5.L = _colour;
	R3 = ~R7;
	P1 = P1 + P5;
	P5 = P0;
	R3 = R3.B (Z);
	R7 = R7.B (Z);
	P2 = P0;
	P5 += 3;
.L750:
	R0 = B [P2] (Z);
	R1 = B [P1++] (Z);
	R0 = R0.L * R3.L (IS);
	R1 = R1.L * R7.L (IS);
	R0 = R0 + R1;
	R0 >>>= 8;
	B [P2++] = R0;
	cc =P5==P2;
	if !cc jump .L750 (bp);
	R0 = B [P0+3] (Z);
	R0 = R0.L * R3.L (IS);
	R0 >>>= 8;
	B [P0+3] = R0;
	SP += 12;
	RETS = [SP++];
	R0 = 1 (X);
	( r7:7, p5:5 ) = [sp++];

	rts;
.L751:
	SP += 12;
	RETS = [SP++];
	R0 = 0 (X);
	( r7:7, p5:5 ) = [sp++];

	rts;
	.size	_pages_fade, .-_pages_fade
	.align 4
.global _pages_paint;
.type _pages_paint, STT_FUNC;
_pages_paint:
	[--sp] = ( r7:4, p5:5 );

	P2.H = 33029;
	[--SP] = RETS;
	P2.L = 40220;
	R6 = [P2];
	SP += -32;
	R0 = R6;
	call _our_page;
	cc =R0==-1;
	R7 = R0;
	if cc jump .L753;
	P0 = R6;
	P2.H = 52;
	P1.H = 52;
	P2.L = 25184;
	P1.L = 25532;
	P2 = P0 + P2;
	P1 = P0 + P1;
	R0 = [P1];
	R1 = P2;
	cc =R1==R0;
	if cc jump .L818 (bp);
.L753:
	SP += 32;
	RETS = [SP++];
	( r7:4, p5:5 ) = [sp++];

	rts;
.L818:
	cc =R7==0;
	P1 = [P0+48];
	if cc jump .L819 (bp);
	cc =R7==2;
	if cc jump .L820;
	P2 = P1 << 2;
	P2 = P2 << 2;
	R1 = P2;
	R2 = P1;
	R0 = R1 - R2;
	P0 = R0;
	P5.H = _euclids;
	P5.L = _euclids;
	I0 = P2;
	cc =P1<=3;
	P2 = P5 + (P0 << 2);
	R1 = [P2];
	if !cc jump .L767 (bp);
	cc =R1==0;
	if cc jump .L753;
	R1 = B [P2+44] (Z);
	R0 = R0 + R1;
	P2 = R0;
	P2 += 1;
	P2 = P5 + (P2 << 2);
	R0 = B [P2+3] (Z);
	R7 = B [P2+1] (Z);
	R4 = B [P2+2] (Z);
	I2 = R0;
.L768:
	P2.H = _waiting;
	P2.L = _waiting;
	R0 = B [P2] (Z);
	cc =R0==0;
	if !cc jump .L795 (bp);
	P2.H = _beat;
	P2.L = _beat;
	R1 = [P2];
	cc =R1==-1;
	I3 = R1;
	if !cc jump .L771 (bp);
	I3 = 0 (X);
.L771:
	P0.H = _now;
	P0.L = _now;
	P2 = P1 + (P1 << 1);
	P2 = P0 + (P2 << 2);
	R0 = B [P2+7] (Z);
	R1 = 1796 (X);
	R0 = R0.L * R1.L (IS);
	R0 >>>= 16;
	P0 = R0;
	P2.H = _DIV;
	P2.L = _DIV;
	R1 = 0 (X);
	R3 = 31 (X);
	P2 = P2 + P0;
	R6 = B [P2] (Z);
	R0 = 0 (X);
	P2 = 32 (X);
	LSETUP (.L773, .L826) LC1 = P2;
.L773:
	R2 = I3;
	R2 >>= R3;
	R5 = 1 (X);
	R0 <<= 1;
	R2 = R2 & R5;
	R0 = R2 | R0;
	cc =R6<=R0 (iu);
	R1 <<= 1;
	if !cc jump .L772 (bp);
	R0 = R0 - R6;
	BITSET (R1, 0);
.L772:
.L826:
	R3 += -1;
	R3 = 0 (X);
	R6 = 31 (X);
	R0 = 0 (X);
	R5 = 1 (X);
	P2 = 32 (X);
	LSETUP (.L775, .L825) LC1 = P2;
.L775:
	R2 = R1;
	R2 >>= R6;
	R0 <<= 1;
	R2 = R2 & R5;
	R0 = R2 | R0;
	cc =R7<=R0 (iu);
	R3 <<= 1;
	if !cc jump .L774 (bp);
	R0 = R0 - R7;
	BITSET (R3, 0);
.L774:
.L825:
	R6 += -1;
	R3 *= R7;
	R3 = R1 - R3;
	[SP+24] = R3;
	jump.s .L770;
.L819:
	P1 = P1 + (P1 << 1);
	R1 = P1;
	R0 = R1 << 3;
	R0 = R0 - R1;
	R0 <<= 3;
	P2 = R0;
	P0.H = _tumblers+160;
	P0.L = _tumblers+160;
	P2 = P2 + P0;
	R0 = [P2];
	cc =R0==0;
	if cc jump .L753 (bp);
	P2.H = _glow;
	P2.L = _glow;
	R5.H = _spark;
	R6 = P2;
	R5.L = _spark;
	R6 += 16;
	R4 = 255 (X);
	jump.s .L758;
.L757:
	R0 = P2;
	cc =R6==R0;
	R7 += 1;
	R5 += 1;
	if cc jump .L753;
.L758:
	R0 = B [P2++] (Z);
	R1 = 23 (X);
	cc =R0<=R1 (iu);
	if cc jump .L757 (bp);
	P0 = R5;
	R0 += 1;
	R1 = R0.L * R4.L (IS);
	R1 >>>= 8;
	R2 = B [P0] (Z);
	[SP+16] = R2;
	R2 = 84 (X);
	R0 = R0.L * R2.L (IS) ||
	[SP+20] = P2 ||
	nop;
	R0 >>>= 8;
	P0.H = 32771;
	[SP+12] = R0;
	R2 = 0 (X);
	R0 = R7;
	P0.L = 54206;
	call (P0);
	P2 = [SP+20];
	jump.s .L757;
.L767:
	P0.H = _now;
	P2 = P1 + (P1 << 1);
	P0.L = _now;
	P2 = P0 + (P2 << 2);
	R0 = B [P2+4] (Z);
	R2 = 3852 (X);
	R0 = R0.L * R2.L (IS);
	R0 >>>= 16;
	R7 = R0;
	R7 += 2;
	R4 = B [P2+5] (Z);
	R5 = B [P2+6] (Z);
	R4 = R4.L * R7.L (IS);
	R5 = R5.L * R7.L (IS);
	R5 >>>= 8;
	R4 >>>= 8;
	R4 += 1;
	cc =R7<=R5;
	R4 = min(R4,R7);
	I2 = R5;
	if !cc jump .L769 (bp);
	R0 += 1;
	I2 = R0;
.L769:
	cc =R1==0;
	if !cc jump .L768;
.L795:
	R5 = -1 (X);
	[SP+24] = R5;
.L770:
	P0 = I0;
	P2.H = _euclids;
	P0 -= P1;
	P2.L = _euclids;
	P2 = P2 + (P0 << 2);
	R5 = I2;
	R6 = R6 -|- R6 ||
	[SP+28] = P2 ||
	nop;
	jump.s .L785;
.L821:
	R0 = 0 (X);
	[SP+16] = R0;
	[SP+12] = R0;
	R2 = 0 (X);
.L817:
	P2.H = 32771;
	R0 = R6;
	R1 = 0 (X);
	P2.L = 54206;
	call (P2);
	R6 += 1;
	R2 = 16 (X);
	cc =R6==R2;
	R5 += 1;
	if cc jump .L753;
.L785:
	cc =R6<R7;
	if !cc jump .L821 (bp);
	cc =R5<R7;
	R0 = R5;
	if cc jump .L778;
.L779:
	R0 = R0 - R7;
	cc =R0<R7;
	if !cc jump .L779 (bp);
.L778:
	R0 = R0.L * R4.L (IS);
	cc =R0<R7;
	if cc jump .L780;
.L781:
	R0 = R0 - R7;
	cc =R0<R7;
	if !cc jump .L781 (bp);
.L780:
	cc =R0<R4;
	if cc jump .L782 (bp);
	R0 = [SP+24];
	cc =R0==R6;
	R2 = 7 (X);
	R1 = 14 (X);
	if cc jump .L797;
.L816:
	R0 = 0 (X);
.L783:
	[SP+12] = R2;
	[SP+16] = R0;
	R2 = R1;
	jump.s .L817;
.L797:
	R0 = 70 (X);
	jump.s .L783;
.L782:
	P0 = [SP+28];
	R0 = [P0];
	cc =R0==0;
	if cc jump .L784 (bp);
	R0 = [SP+24];
	cc =R0==R6;
	R2 = 80 (X);
	R1 = 170 (X);
	if !cc jump .L816 (bp);
.L799:
	R0 = 255 (X);
	jump.s .L783;
.L784:
	R1 = [SP+24];
	cc =R1==R6;
	R2 = 42 (X);
	R1 = 90 (X);
	if !cc jump .L783 (bp);
	jump.s .L799;
.L820:
	R0 = P1;
	R1.H = _gknob;
	R1.L = _gknob;
	R0 <<= 3;
	R0 = R0 + R1;
	P0 = R0;
	P2 = P1 << 2;
	I0 = P2;
	P5.H = _grooves;
	P2 = (P2 + P1) << 1;
	P2 = P2 + P1;
	P5.L = _grooves;
	R1 = B [P0] (Z);
	R2 = 69 (X);
	P2 = P5 + P2;
	R1 = R1.L * R2.L (IS) ||
	R2 = B [P2] (Z) ||
	nop;
	R1 >>>= 8;
	cc =R2==0;
	P0 = R1;
	if cc jump .L788 (bp);
	P2.H = _waiting;
	P2.L = _waiting;
	R1 = B [P2] (Z);
	cc =R1==0;
	if !cc jump .L788 (bp);
	P2.H = _beat;
	P2.L = _beat;
	R5 = [P2];
	cc =R5==-1;
	if cc jump .L788;
	P2 = R0;
	R1 = 1796 (X);
	R6 = 0 (X);
	R3 = 31 (X);
	R4 = 1 (X);
	R0 = B [P2+1] (Z);
	R0 = R0.L * R1.L (IS);
	R0 >>>= 16;
	P5 = R0;
	P2.H = _DIV;
	P2.L = _DIV;
	R0 = 0 (X);
	P2 = P2 + P5;
	R7 = B [P2] (Z);
	P2 = 32 (X);
	LSETUP (.L762, .L824) LC1 = P2;
.L762:
	R1 = R5;
	R1 >>= R3;
	R0 <<= 1;
	R1 = R1 & R4;
	R0 = R1 | R0;
	cc =R7<=R0 (iu);
	R6 <<= 1;
	if !cc jump .L761 (bp);
	R0 = R0 - R7;
	BITSET (R6, 0);
.L761:
.L824:
	R3 += -1;
	R0 = 15 (X);
	R6 = R6 & R0;
.L760:
	P2.H = _groove;
	P0 = P0 + (P0 << 1);
	P2.L = _groove;
	P2 = P2 + (P0 << 1);
	R5 = P2;
	R4 = W [P2+2] (Z);
	P2 = I0;
	P2 = (P2 + P1) << 1;
	P2 = P2 + P1;
	R7 = R7 -|- R7 ||
	[SP+24] = P2 ||
	nop;
	jump.s .L766;
.L823:
	P0 = R5;
	R0 = W [P0+4] (Z);
	R0 = R0 & R1;
	cc =R0==0;
	if !cc jump .L790 (bp);
	R0 = W [P0] (Z);
	R0 = R0 & R1;
	cc =R0==0;
	if !cc jump .L791 (bp);
	R0 = 8 (X);
.L763:
	cc =R2==0;
	if !cc jump .L764 (bp);
	R0 >>>= 1;
.L764:
	cc =R6==R7;
	if cc jump .L822;
	R3 = 0 (X);
.L765:
	R0 += 1;
	[SP+16] = R3;
	R2 = 255 (X);
	R3 = 30 (X);
	R1 = 90 (X);
	R2 = R0.L * R2.L (IS);
	R1 = R0.L * R1.L (IS);
	R0 = R3.L * R0.L (IS);
	R0 >>>= 8;
	P2.H = 32771;
	[SP+12] = R0;
	R2 >>>= 8;
	R0 = R7;
	R1 >>>= 8;
	P2.L = 54206;
	call (P2);
	R7 += 1;
	R0 = 16 (X);
	cc =R7==R0;
	if cc jump .L753;
	P1 = [SP+24];
	P0.H = _grooves;
	P0.L = _grooves;
	P2 = P0 + P1;
	R2 = B [P2] (Z);
.L766:
	R1 = 1 (X);
	R1 <<= R7;
	R0 = R1 & R4;
	cc =R0==0;
	if cc jump .L823 (bp);
	R0 = 255 (X);
	jump.s .L763;
.L790:
	R0 = 50 (X);
	jump.s .L763;
.L822:
	P1 = R5;
	R2 = W [P1] (Z);
	R1 = R2 & R1;
	cc =R1==0;
	if !cc jump .L793 (bp);
	R3 = 70 (X);
	jump.s .L765;
.L791:
	R0 = 130 (X);
	jump.s .L763;
.L793:
	R3 = 255 (X);
	jump.s .L765;
.L788:
	R6 = -1 (X);
	jump.s .L760;
	.size	_pages_paint, .-_pages_paint
	.align 4
.global _pages_stop;
.type _pages_stop, STT_FUNC;
_pages_stop:
	[--sp] = ( p5:4 );

	P2.H = 33029;
	[--SP] = RETS;
	P2.L = 40220;
	P5 = [P2];
	SP += -12;
	cc =P5==0;
	if cc jump .L835;
	R0 = P5;
	call _our_page;
	cc =R0==-1;
	if cc jump .L830;
	cc =R0==2;
	P2 = [P5+48];
	if cc jump .L847;
	cc =R0==1;
	if cc jump .L848;
	P2 = P2 + (P2 << 1);
	R1 = P2;
	R0 = R1 << 3;
	R0 = R0 - R1;
	R0 <<= 3;
	P2 = R0;
	P4.H = _tumblers+160;
	P4.L = _tumblers+160;
	P2 = P2 + P4;
	R0 = [P2];
.L834:
	cc =R0==0;
	if cc jump .L830 (bp);
	R0 = 0 (X);
	[P2] = R0;
	R1 = [P5+48];
	R0 = R1 << 4;
	R0 = R0 - R1;
	P2 = R0;
	P1.H = _euclids;
	P1.L = _euclids;
	R0 = 0 (X);
	P2 = P1 + (P2 << 2);
	B [P2+44] = R0;
	R0 = 1 (X);
.L850:
	SP += 12;
	RETS = [SP++];
	( p5:4 ) = [sp++];

	rts;
.L830:
	R0 = B [P5+28] (Z);
	cc =R0==0;
	if cc jump .L849 (bp);
.L835:
	SP += 12;
	RETS = [SP++];
	R0 = 0 (X);
	( p5:4 ) = [sp++];

	rts;
.L849:
	R0.H = _euclids;
	P0.H = _tumblers+160;
	P1.H = _grooves;
	R0.L = _euclids;
	P0.L = _tumblers+160;
	P1.L = _grooves;
	R1 = 0 (X);
	R2 = 0 (X);
	P5 = 168 (X);
	P2 = 8 (X);
	LSETUP (.L836, .L851) LC1 = P2;
.L836:
	P4 = R0;
	[P0] = R1;
	B [P1] = R2;
	R0 += 60;
	P0 = P0 + P5;
	[P4] = R1;
.L851:
	P1 += 11;
	jump.s .L835;
.L847:
	P1 = P2 + (P2 << 2);
	P1 = P2 + (P1 << 1);
	P2.H = _grooves;
	P2.L = _grooves;
	P2 = P2 + P1;
	R0 = B [P2] (Z);
	cc =R0==0;
	if cc jump .L830 (bp);
	R0 = 0 (X);
	B [P2] = R0;
	R0 = 1 (X);
	jump.s .L850;
.L848:
	R0 = P2;
	R0 <<= 4;
	P1 = R0;
	P1 -= P2;
	P2 = P1;
	P1.H = _euclids;
	P1.L = _euclids;
	P2 = P1 + (P2 << 2);
	R0 = [P2];
	jump.s .L834;
	.size	_pages_stop, .-_pages_stop
	.text
	.type	_fresh.0, @object
	.size	_fresh.0, 16
_fresh.0:
	.ascii	"\020\004"
	.ascii	"\020\003"
	.ascii	"\f\005"
	.ascii	"\020\007"
	.ascii	"\n\003"
	.ascii	"\020\005"
	.ascii	"\016\003"
	.ascii	"\t\004"
	.align 4
	.type	_degree.1, @object
	.size	_degree.1, 8
_degree.1:
	.base64	"AAIEBQcJCwA="
	.align 4
	.type	_DIV, @object
	.size	_DIV, 7
_DIV:
	.base64	"YEAwIBgQDA=="
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
	.text
	.type	_tick4, @object
	.size	_tick4, 1
_tick4:
	.zero	1
	.align 4
	.type	_spark, @object
	.size	_spark, 16
_spark:
	.zero	16
	.align 4
	.type	_glow, @object
	.size	_glow, 16
_glow:
	.zero	16
	.type	_running, @object
	.size	_running, 1
_running:
	.zero	1
	.align 4
	.type	_ntakes, @object
	.size	_ntakes, 4
_ntakes:
	.zero	4
	.align 4
	.type	_takes, @object
	.size	_takes, 192
_takes:
	.zero	192
	.align 4
	.type	_seed, @object
	.size	_seed, 4
_seed:
	.long	1779033703
	.align 4
	.type	_acc, @object
	.size	_acc, 4
_acc:
	.zero	4
	.align 4
	.type	_last_ms, @object
	.size	_last_ms, 4
_last_ms:
	.zero	4
	.align 2
	.type	_locked, @object
	.size	_locked, 2560
_locked:
	.zero	2560
.global _touched;
	.type	_touched, @object
	.size	_touched, 1
_touched:
	.zero	1
	.type	_flashes, @object
	.size	_flashes, 1
_flashes:
	.zero	1
	.type	_shift_held, @object
	.size	_shift_held, 1
_shift_held:
	.zero	1
	.type	_was_playing, @object
	.size	_was_playing, 1
_was_playing:
	.zero	1
	.type	_waiting, @object
	.size	_waiting, 1
_waiting:
	.zero	1
	.align 4
	.type	_hand_track, @object
	.size	_hand_track, 4
_hand_track:
	.zero	4
	.align 4
	.type	_hands, @object
	.size	_hands, 4
_hands:
	.zero	4
	.align 4
	.type	_hand_ms, @object
	.size	_hand_ms, 48
_hand_ms:
	.zero	48
	.align 4
	.type	_hand, @object
	.size	_hand, 12
_hand:
	.zero	12
	.align 4
	.type	_flash_ms, @object
	.size	_flash_ms, 4
_flash_ms:
	.zero	4
	.align 4
	.type	_shift_ms, @object
	.size	_shift_ms, 4
_shift_ms:
	.zero	4
	.align 4
	.type	_beat, @object
	.size	_beat, 4
_beat:
	.zero	4
	.type	_now, @object
	.size	_now, 96
_now:
	.zero	96
.global _gknob;
	.text
	.type	_gknob, @object
	.size	_gknob, 64
_gknob:
	.base64	"AJmZAAAAQAA="
	.base64	"AJmZAAAAQAA="
	.base64	"AJmZAAAAQAA="
	.base64	"AJmZAAAAQAA="
	.base64	"AJmZAAAAQAA="
	.base64	"AJmZAAAAQAA="
	.base64	"AJmZAAAAQAA="
	.base64	"AJmZAAAAQAA="
.global _grooves;
	.text
	.type	_grooves, @object
	.size	_grooves, 88
_grooves:
	.zero	88
.global _knob;
	.text
	.type	_knob, @object
	.size	_knob, 96
_knob:
	.string	"s\231@&sM"
	.base64	"mYBN/wA="
	.string	"s\231@&sM"
	.base64	"mYBN/wA="
	.string	"s\231@&sM"
	.base64	"mYBN/wA="
	.string	"s\231@&sM"
	.base64	"mYBN/wA="
	.string	"s\231@&sM"
	.base64	"mYBN/wA="
	.string	"s\231@&sM"
	.base64	"mYBN/wA="
	.string	"s\231@&sM"
	.base64	"mYBN/wA="
	.string	"s\231@&sM"
	.base64	"mYBN/wA="
.global _euclids;
	.text
	.align 4
	.type	_euclids, @object
	.size	_euclids, 480
_euclids:
	.zero	480
.global _tumblers;
	.align 4
	.type	_tumblers, @object
	.size	_tumblers, 1344
_tumblers:
	.zero	1344
	.text
	.type	_chord_notes, @object
	.size	_chord_notes, 65
_chord_notes:
	.base64	"AAQH//8="
	.base64	"AAMH//8="
	.base64	"AAMG//8="
	.base64	"AAQHCv8="
	.base64	"AAQHC/8="
	.base64	"AAMHCv8="
	.base64	"AAUH//8="
	.base64	"AAQHDv8="
	.base64	"AAMHCg4="
	.base64	"AAQHCw4="
	.base64	"AAQHCg4="
	.base64	"AAIH//8="
	.base64	"AAQI//8="
	.align 2
	.type	_prog_at, @object
	.size	_prog_at, 268
_prog_at:
	.short	0
	.short	4
	.short	8
	.short	13
	.short	17
	.short	21
	.short	25
	.short	29
	.short	33
	.short	41
	.short	45
	.short	48
	.short	52
	.short	56
	.short	58
	.short	70
	.short	75
	.short	91
	.short	99
	.short	103
	.short	111
	.short	115
	.short	119
	.short	123
	.short	131
	.short	135
	.short	139
	.short	143
	.short	147
	.short	155
	.short	163
	.short	165
	.short	173
	.short	177
	.short	193
	.short	201
	.short	209
	.short	213
	.short	217
	.short	221
	.short	225
	.short	229
	.short	237
	.short	245
	.short	253
	.short	257
	.short	261
	.short	269
	.short	273
	.short	289
	.short	321
	.short	325
	.short	329
	.short	333
	.short	337
	.short	341
	.short	345
	.short	347
	.short	351
	.short	355
	.short	359
	.short	367
	.short	371
	.short	375
	.short	379
	.short	383
	.short	391
	.short	395
	.short	403
	.short	407
	.short	411
	.short	415
	.short	419
	.short	423
	.short	427
	.short	429
	.short	433
	.short	437
	.short	441
	.short	443
	.short	447
	.short	451
	.short	455
	.short	459
	.short	471
	.short	475
	.short	479
	.short	483
	.short	487
	.short	491
	.short	495
	.short	499
	.short	503
	.short	511
	.short	513
	.short	515
	.short	519
	.short	523
	.short	525
	.short	527
	.short	529
	.short	533
	.short	537
	.short	541
	.short	545
	.short	549
	.short	553
	.short	557
	.short	561
	.short	565
	.short	573
	.short	577
	.short	581
	.short	585
	.short	589
	.short	593
	.short	597
	.short	601
	.short	605
	.short	609
	.short	610
	.short	618
	.short	622
	.short	626
	.short	634
	.short	638
	.short	646
	.short	650
	.short	654
	.short	658
	.short	662
	.short	664
	.short	668
	.short	672
	.type	_prog, @object
	.size	_prog, 672
_prog:
	.base64	"BAULDg4EBQEkGy4tGQEFDgQOBAEFBAUOAQQBBQ4BDgQFAQUOCwQBBAUBCwQMKh0hDgUEGwGHBAEBBBkZGRkcHBkZHRwZHSQbLi0ZJAUrDioFARkkBSsOKjUBASQFKw4kBQEBLiQ5BSErJB0uKyQ1ARsODEJVSS4hKyQsARkEDAEuKh0hLiodKpohIQGGhwEhLJ8hAQoLBAUOBDUBBQ4LBAEKBSEkDgQBBQ4EChs5XC48DgQBBQ4EAQUEDAEOKoaHAQ4FBAUOBQQbATwBNQ48AQUBNS48ATwBNTwBBS4uPAE1ASorPAEFDgUEASo1BAUOAQQFDjUBBAEFDgQ1AVk8"
	.base64	"LjwEDAEBAQEuLjw8NQUOAQUEAQE8PC41PDwBBS48AQUuPAEBPDwuNTw8AQUuPAEFLjwEBQ4BBAUONQEFLjwBNTwBAQQOBQEEBQQBBQoEAQ4KBQEDBAwEBQ4FDgQBBQQEAQQBBQoFAQ4BBQ4ECgQ1BSQdKy4OBAUOBAUOCyoFKw4EDCsOKjUBARcbLi4qHSEkFxsuLiQrKiErLiodISorKiQrKisqKyQFSUZCVUZMRkJVSQQFDg4qKyQFLioODgQFDgQFCyQFLisZHBkdLi4uLioqLi4cGy4bBQQBAQELBAQOBAUFAQWHBAECAQIOCwQBDgsFAg4EChsEBQsOCgUB"
	.base64	"AS4aDocOChsODg4EGwGHDgsOCiEaKh0BBAUBDgodIQ4FBAUkOTUuTCtGBUJVK0YOAQQFOSs8NQQBBQ4EAQUbRiRCKy4FJAUqHSEkKgQuBQQOAQUuKyQFDgQKC0wrQlUkISouLg4EAQUOBAoFDgUBBA4EDgUOBAEFDgQFGw4ODocEBQ4LBAUBAS4kISsuKi4rDgQOCw6HDgUOgy4kBQVGIUxM"
	.align 2
	.type	_groove, @object
	.size	_groove, 414
_groove:
	.short	18761
	.short	257
	.short	0
	.short	-28087
	.short	4097
	.short	0
	.short	21065
	.short	4097
	.short	0
	.short	10537
	.short	257
	.short	0
	.short	21157
	.short	4097
	.short	0
	.short	-21141
	.short	257
	.short	0
	.short	-19275
	.short	4113
	.short	0
	.short	9281
	.short	1
	.short	0
	.short	17545
	.short	1
	.short	0
	.short	-2799
	.short	4369
	.short	0
	.short	-8739
	.short	4369
	.short	0
	.short	-1
	.short	4369
	.short	0
	.short	16705
	.short	257
	.short	0
	.short	20753
	.short	257
	.short	0
	.short	21845
	.short	16705
	.short	0
	.short	17481
	.short	16449
	.short	0
	.short	-26215
	.short	4369
	.short	-30584
	.short	19789
	.short	17473
	.short	260
	.short	9289
	.short	1089
	.short	0
	.short	5193
	.short	1025
	.short	0
	.short	-2487
	.short	4161
	.short	0
	.short	19789
	.short	16705
	.short	0
	.short	23901
	.short	4369
	.short	1028
	.short	-13108
	.short	17476
	.short	0
	.short	22357
	.short	4369
	.short	0
	.short	13107
	.short	257
	.short	0
	.short	-26215
	.short	4369
	.short	0
	.short	11565
	.short	257
	.short	0
	.short	20817
	.short	4369
	.short	0
	.short	5911
	.short	4369
	.short	0
	.short	-22103
	.short	257
	.short	8224
	.short	4369
	.short	4369
	.short	0
	.short	17476
	.short	17476
	.short	0
	.short	-27500
	.short	4112
	.short	0
	.short	19593
	.short	1025
	.short	8
	.short	21845
	.short	17476
	.short	0
	.short	17601
	.short	1025
	.short	0
	.short	-18725
	.short	4113
	.short	0
	.short	9545
	.short	257
	.short	8192
	.short	5193
	.short	4161
	.short	0
	.short	5257
	.short	4225
	.short	0
	.short	9289
	.short	1025
	.short	0
	.short	28013
	.short	257
	.short	0
	.short	22873
	.short	4369
	.short	16448
	.short	21705
	.short	4161
	.short	128
	.short	19865
	.short	273
	.short	0
	.short	1025
	.short	1
	.short	0
	.short	-683
	.short	257
	.short	0
	.short	9509
	.short	257
	.short	0
	.short	18761
	.short	65
	.short	2048
	.short	17569
	.short	1025
	.short	32
	.short	1799
	.short	257
	.short	0
	.short	13107
	.short	4369
	.short	0
	.short	3855
	.short	257
	.short	0
	.short	255
	.short	17
	.short	0
	.short	-12019
	.short	4353
	.short	0
	.short	841
	.short	257
	.short	584
	.short	1
	.short	1
	.short	0
	.short	257
	.short	257
	.short	0
	.short	4161
	.short	4097
	.short	0
	.short	1025
	.short	1
	.short	0
	.short	2177
	.short	1
	.short	0
	.short	2056
	.short	2056
	.short	0
	.short	21845
	.short	4369
	.short	0
	.short	-31711
	.short	1
	.short	0
	.short	16513
	.short	1
	.short	0
	.short	-23487
	.short	1
	.short	0
	.short	1099
	.short	1
	.short	0
	.short	-18725
	.short	4161
	.short	0
	.type	_colour, @object
	.size	_colour, 9
_colour:
	.base64	"/wBU"
	.base64	"AP94"
	.base64	"Wv8e"
