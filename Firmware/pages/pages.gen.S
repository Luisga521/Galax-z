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
.global _pages_screen;
.type _pages_screen, STT_FUNC;
_pages_screen:
	P2.H = 33029;
	P2.L = 40220;
	P1 = [P2];
	R2 = R0;
	R0 = R1;
	cc =P1==0;
	if cc jump .L78;
	cc =R2==2;
	if !cc jump .L78 (bp);
	cc =R1==0;
	if cc jump .L78;
	P2 = [P1+48];
	P0 = 15 (X);
	cc =P2<=P0 (iu);
	if !cc jump .L78;
	P0.H = _jog_slack;
	P0.L = _jog_slack;
	R1 = [P0];
	R0 = R0 + R1;
	cc =R0<=3;
	if cc jump .L68;
	R1 = 3 (X);
	R0 = R0 & R1;
	[P0] = R0;
	P0.H = 33041;
	P0.L = 12124;
	P2 = P0 + (P2 << 2);
	R1 = [P2];
	P2.H = 52;
	P2.L = 24108;
	P2 = P1 + P2;
	P2 = [P2];
	R0 = 1 (X);
.L69:
	R2 = R1;
	R2 += -2;
	cc =R2<=6 (iu);
	if !cc jump .L71;
	P0 = R0;
	P2 = P0 + P2;
	cc =P2<0;
	if cc jump .L80;
	R0 = P2;
	cc =R0<R1;
	if cc jump .L74 (bp);
	P2 = 0 (X);
.L74:
	P0.H = 52;
	P0.L = 24108;
	P1 = P1 + P0;
	[P1] = P2;
	P2.H = _jogged;
	P2.L = _jogged;
	R0 = 1 (X);
	B [P2] = R0;
.L71:
	R0 = 1 (X);
.L66:
	rts;
.L78:
	R0 = 0 (X);
	rts;
.L80:
	P2 = R1;
	P2 += -1;
	jump.s .L74;
.L68:
	cc =R0<-3;
	if !cc jump .L81;
	R2 = -4 (X);
	R1 = R2 - R0;
	R1 = R1 & R2;
	R0 += 4;
	R0 = R1 + R0;
	[P0] = R0;
	P0.H = 33041;
	P0.L = 12124;
	P2 = P0 + (P2 << 2);
	R1 = [P2];
	P2.H = 52;
	P2.L = 24108;
	P2 = P1 + P2;
	P2 = [P2];
	R0 = -1 (X);
	jump.s .L69;
.L81:
	[P0] = R0;
	R0 = 1 (X);
	jump.s .L66;
	.size	_pages_screen, .-_pages_screen
	.align 4
.global _pages_tick;
.type _pages_tick, STT_FUNC;
_pages_tick:
	[--sp] = ( r7:4, p5:3 );

	P3 = R0;
	LINK 152;
	cc =P3==0;
	if cc jump .L82;
	R0 = B [P3+39] (Z);
	cc =R0==0;
	if !cc jump 6 (bp); jump.l .L451;
.L86:
	P5.H = _hands;
	P5.L = _hands;
	R0 = [P5];
	cc =R0==0;
	if cc jump .L452 (bp);
	P2.H = 32770;
	P2.L = 33428;
	call (P2);
	P4.H = _hand_ms;
	R5 = R0;
	P4.L = _hand_ms;
	R7 = 0 (X);
	R0 = B [P3+28] (Z);
	jump.s .L91;
.L90:
	R1 = 1 (X);
	R1 <<= R7;
	R1 = ~R1;
	R1 = R1 & R2;
	[P5] = R1;
.L89:
	R7 += 1;
	R1 = 12 (X);
	cc =R7==R1;
	P4 += 4;
	if cc jump .L88;
.L91:
	R2 = [P5];
	R1 = R2;
	R1 >>>= R7;
	cc = !BITTST (R1,0);
	if cc jump .L89 (bp);
	R1 = [P4];
	R1 = R5 - R1;
	R3 = 999 (X);
	cc =R1<=R3 (iu);
	if !cc jump .L90 (bp);
	cc =R0==0;
	if cc jump .L90 (bp);
	R1 = B [P3+31] (X);
	R3 = B [P3+29] (X);
	R1 = R1 | R3;
	R1 = R1.B (Z);
	cc =R1==0;
	if cc jump .L90 (bp);
	P2.H = _hand_track;
	P2.L = _hand_track;
	P2 = [P2];
	R1 = [P3+48];
	R4 = P2;
	cc =R4==R1;
	if !cc jump .L90 (bp);
	R1 = [P3+124];
	R3 = 31 (X);
	cc =R1==R3;
	if !cc jump .L90 (bp);
	P1.H = 52;
	P1.L = 25200;
	P1 = P3 + P1;
	R1 = [P1];
	cc =R1==0;
	if !cc jump .L90 (bp);
	P0 = R7;
	P1.H = _hand;
	P1.L = _hand;
	R2 = R7;
	R1 = P2;
	P1 = P0 + P1;
	P0.H = 52;
	R0 = B [P1] (Z);
	P0.L = 23866;
	P1 = P3 + P2;
	[SP+16] = R0;
	P1 = P1 + P0;
	R0 = B [P1] (Z);
	R0 >>= 4;
	[SP+12] = R0;
	R0 = P3;
	call _set_lock;
	R0 = B [P3+28] (Z);
	jump.s .L89;
.L275:
	P2.H = _touched;
	R0 = 0 (X);
	P2.L = _touched;
	B [P2] = R0;
	P2.H = _shift_held;
	P2.L = _shift_held;
	B [P2] = R0;
.L82:
	P1 = 152 (X);
	SP = SP + P1;
	FP = [SP++];
	RETS = [SP++];
	( r7:4, p5:3 ) = [sp++];

	rts;
.L452:
	R0 = B [P3+28] (Z);
.L88:
	P2.H = 65483;
	P4.H = 52;
	P2.L = 41670;
	P4.L = 23866;
	R7.H = _knob;
	P2 -= P3;
	FP.H = _locked;
	I2.H = _now;
	P4 = P3 + P4;
	R7.L = _knob;
	R4 = 0 (X);
	I1 = P2;
	FP.L = _locked;
	I2.L = _now;
	P0 = 8 (X);
	LSETUP (.L327, .L492) LC0 = P0;
	jump.s .L95;
.L327:
	R0 = B [P3+28] (Z);
.L95:
	R1 = I1;
	R2 = P4;
	R6 = R1 + R2;
	cc =R0==0;
	R2 = R4.L (Z);
	R2 <<= 4;
	P0 = I2;
	R1 = 0 (X);
	P1 = 12 (X);
	LSETUP (.L326, .L491) LC1 = P1;
	if !cc jump .L453 (bp);
	jump.s .L92;
.L326:
	R0 = B [P3+28] (Z);
	cc =R0==0;
	if !cc jump .L453 (bp);
.L92:
	R0 = R7 + R1;
	P2 = R0;
	R0 = B [P2] (X);
.L93:
	B [P0++] = R0;
	R1 += 1;
.L491:
	R2 += 16;
	M1 = 12 (X);
	R4 += 12;
	P4 += 1;
	R7 += 12;
.L492:
	I2 += M1;
	R5.H = _ntakes;
	R5.L = _ntakes;
	P0 = R5;
	R0 = [P0];
	cc =R0==0;
	if cc jump 6 (bp); jump.l .L454;
.L97:
	P1.H = _euclids;
	P1.L = _euclids;
	R7 = 0 (X);
	P2 = 8 (X);
	LSETUP (.L103, .L490) LC1 = P2;
.L103:
	R0 = [P1];
	R7 = R7 | R0;
.L490:
	P1 += 60;
	R1 = B [P3+28] (X);
	R0 = R1.B (Z);
	cc =R0==0;
	if cc jump 4; jump.s .L104;
	P2.H = _waiting;
	P2.L = _waiting;
	B [P2] = R0;
	[SP+52] = P2;
	P2.H = _was_playing;
	P2.L = _was_playing;
	B [P2] = R0;
.L113:
	P4.H = _beat;
	P4.L = _beat;
	R0 = [P4];
	R0 += 1;
	[P4] = R0;
.L105:
	cc =R7==0;
	if cc jump .L164;
.L284:
	P5.H = _now+4;
	FP.H = _euclids;
	P5.L = _now+4;
	FP.L = _euclids;
	R5 = 0 (X);
	R7 = 1 (X);
.L163:
	R2 = [FP];
	cc =R2==0;
	I0 = R2;
	if cc jump .L119 (bp);
	R4 = 1796 (X);
	R0 = B [P5+3] (Z);
	R0 = R0.L * R4.L (IS) ||
	P1 = [P4] ||
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
	LSETUP (.L121, .L489) LC1 = P2;
.L121:
	R1 = P1;
	R1 >>= R3;
	R0 <<= 1;
	R1 = R1 & R7;
	R0 = R1 | R0;
	cc =R4<=R0 (iu);
	R2 <<= 1;
	if !cc jump .L120 (bp);
	R0 = R0 - R4;
	BITSET (R2, 0);
.L120:
.L489:
	R3 += -1;
	R2 *= R4;
	R0 = P1;
	cc =R0==R2;
	if !cc jump 6 (bp); jump.l .L455;
.L119:
	R5 += 1;
	R3 = 8 (X);
	cc =R5==R3;
	if cc jump .L162;
.L446:
	FP += 60;
	P5 += 12;
	jump.s .L163;
.L453:
	P2 = [P3+68];
	P5 = 159 (X);
	cc =P2<=P5 (iu);
	if !cc jump .L92;
	R0 = P2;
	R0 <<= 3;
	R0 = (R0 + R6) << 1;
	P5 = R0;
	P5 = FP + P5;
	R0 = W [P5] (Z);
	R0 >>>= R1;
	cc = !BITTST (R0,0);
	if cc jump .L92;
	P2 = P2 + (P2 << 1);
	R0 = P2;
	R3 = B [P4] (Z);
	R0 <<= 9;
	R3 >>= 4;
	R0 = R0 + R2;
	R0 = R0 + R3;
	P2 = R0;
	P5.H = 32964;
	P5.L = 0;
	R5 = 255 (X);
	P2 = P2 + P5;
	R0 = B [P2] (X);
	R3 = R0.B (Z);
	cc =R3==R5;
	if !cc jump .L93 (bp);
	jump.s .L92;
.L162:
	P0 = [SP+52];
	R0 = B [P0] (Z);
	cc =R0==0;
	if !cc jump .L114;
.L164:
	R0 = [P4];
	cc =R0==-1;
	if cc jump .L114;
.L285:
	FP.H = _gknob;
	P5.H = _grooves+1;
	FP.L = _gknob;
	P5.L = _grooves+1;
	R7 = 0 (X);
.L209:
	R0 = B [P5+-1] (Z);
	cc =R0==0;
	if cc jump .L166;
	R0 = B [FP+1] (Z);
	R1 = 1796 (X);
	R0 = R0.L * R1.L (IS) ||
	R5 = [P4] ||
	nop;
	R0 >>>= 16;
	P1 = R0;
	P0.H = _DIV;
	P0.L = _DIV;
	R2 = 0 (X);
	R3 = 31 (X);
	P2 = P0 + P1;
	R6 = B [P2] (Z);
	R0 = 0 (X);
	R4 = 1 (X);
	P2 = 32 (X);
	LSETUP (.L168, .L488) LC1 = P2;
.L168:
	R1 = R5;
	R1 >>= R3;
	R0 <<= 1;
	R1 = R1 & R4;
	R0 = R1 | R0;
	cc =R6<=R0 (iu);
	R2 <<= 1;
	if !cc jump .L167 (bp);
	R0 = R0 - R6;
	BITSET (R2, 0);
.L167:
.L488:
	R3 += -1;
	R3 = R6;
	R3 *= R2;
	R0 = 1 (X);
	R0 = R2 & R0;
	cc =R0==0;
	R3 = R5 - R3;
	if cc jump .L169 (bp);
	R1 = B [FP+7] (Z);
	R1 = R1.L * R6.L (FU);
	P2 = R1;
	P2 = P2 + (P2 << 1);
	R1 = P2;
	R0 = R1 << 3;
	R0 = R0 - R1;
	R0 <<= 2;
	R0 >>= 16;
.L169:
	cc =R3==R0;
	if cc jump .L456;
.L166:
	R7 += 1;
	R0 = 8 (X);
	cc =R7==R0;
	FP += 8;
	P5 += 11;
	if !cc jump .L209 (bp);
.L114:
	P1.H = _tumblers+160;
	P1.L = _tumblers+160;
	R0 = 0 (X);
	P0 = 168 (X);
	P2 = 8 (X);
	LSETUP (.L165, .L487) LC1 = P2;
.L165:
	R1 = [P1];
	R0 = R0 | R1;
.L487:
	P1 = P1 + P0;
	cc =R0==0;
	if !cc jump 4 (bp); jump.s .L457;
	P2.H = 32770;
	P2.L = 33428;
	call (P2);
	P2.H = _running;
	P2.L = _running;
	R1 = ROT R0 BY 0 ||
	R0 = B [P2] (Z) ||
	nop;
	cc =R0==0;
	if !cc jump .L458 (bp);
	R0 = 1 (X);
	B [P2] = R0;
	P2.H = _last_ms;
	P2.L = _last_ms;
	[P2] = R1;
	P2.H = _acc;
	P2.L = _acc;
	R0 = 0 (X);
	[P2] = R0;
	[SP+76] = P2;
	P2.H = _seed;
	R0 = R1;
	P2.L = _seed;
	BITSET (R0, 0);
	R1 = [P2];
	cc =R0==R1;
	if !cc jump 6 (bp); jump.l .L292;
	R0 = R0 ^ R1;
.L218:
	P5 = [SP+76];
	[P2] = R0;
	R0 = 0 (X);
	[P5] = R0;
	jump.s .L212;
.L456:
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
	if cc jump .L166;
	R1 = W [P2+2] (Z);
	R1 = R1 & R0;
	cc =R1==0;
	if !cc jump 6; jump.l .L459;
	P2 = 118 (X);
	[SP+56] = P2;
.L171:
	R4 = B [FP+2] (X);
	cc =R7<=3;
	B1 = R4;
	if !cc jump 6; jump.l .L172;
	R0 = B [FP+4] (Z);
	R1 = 134 (X);
	R0 = R0.L * R1.L (IS);
	R0 >>>= 8;
	P1 = R0;
	cc =P1==0;
	if !cc jump 6 (bp); jump.l .L172;
	P0.H = _prog_at;
	P0.L = _prog_at;
	P2 = P0 + (P1 << 1);
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
	if !cc jump .L173 (bp);
	R5 = 0 (X);
.L173:
	R2 = 0 (X);
	I0 = 31 (X);
	R1 = 0 (X);
	P0 = 32 (X);
	LSETUP (.L175, .L486) LC1 = P0;
.L175:
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
	if !cc jump .L174 (bp);
	R1 = R1 - R4;
	BITSET (R2, 0);
.L174:
	M0 = -1 (X);
.L486:
	I0 += M0;
	R5 = 0 (X);
	P0 = 31 (X);
	R1 = 0 (X);
	P1 = 32 (X);
	LSETUP (.L177, .L485) LC1 = P1;
.L177:
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
	if !cc jump .L176 (bp);
	R1 = R1 - R0;
	BITSET (R5, 0);
.L176:
.L485:
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
	R5 = B [P1] (Z);
	R0 = R0.L * R1.L (IS);
	R1 = R5;
	R2 = 7 (X);
	R1 += -1;
	R1 = R1 & R2;
	P2 = R1;
	P1.H = _degree.1;
	P1.L = _degree.1;
	R0 >>>= 8;
	R3 = 31 (X);
	P1 = P1 + P2;
	R1 = B [P1] (Z);
	R0 = R0 + R1;
	R1 = R5 >> 7;
	R0 = R0 - R1;
	R0 += 12;
	I1 = R0;
	R1 = 0 (X);
	R2 = 0 (X);
	P1 = 32 (X);
	LSETUP (.L179, .L484) LC1 = P1;
.L179:
	P0 = R2;
	R0 = I1;
	R2 = 1 (X);
	R0 >>= R3;
	R0 = R0 & R2;
	P2 = P0 + P0;
	R4 = P2;
	R2 = R0 | R4;
	R0 = 11 (X);
	cc =R2<=R0 (iu);
	R1 <<= 1;
	if cc jump .L178 (bp);
	R2 += -12;
	BITSET (R1, 0);
.L178:
.L484:
	R3 += -1;
	P0 = R1;
	R2 = B [P5] (Z);
	I0 = R2;
	R2 = I1;
	P1 = 32 (X);
	P0 = P0 + (P0 << 1);
	R1 = P0;
	R1 <<= 2;
	R0 = R2 - R1;
	R3 = I0;
	R0 = R3 - R0;
	R1 = 120 (X);
	R1 = R0 + R1;
	I2 = R1;
	R3 = 31 (X);
	R1 = 0 (X);
	R2 = 0 (X);
	LSETUP (.L181, .L483) LC1 = P1;
.L181:
	P0 = R2;
	R0 = I2;
	R2 = 1 (X);
	R0 >>= R3;
	R0 = R0 & R2;
	P2 = P0 + P0;
	R4 = P2;
	R2 = R0 | R4;
	R0 = 11 (X);
	cc =R2<=R0 (iu);
	R1 <<= 1;
	if cc jump .L180 (bp);
	R2 += -12;
	BITSET (R1, 0);
.L180:
.L483:
	R3 += -1;
	P0 = R1;
	P1 = I0;
	R0 = I2;
	R1 = 15 (X);
	R2 = 128 (X);
	P0 = P0 + (P0 << 1);
	P0 = P1 + (P0 << 2);
	R3 = P0;
	R4 = R3 - R0;
	R0 = R5 >> 3;
	R0 = R0 & R1;
	R1 = 5 (X);
	R1 = R1.L * R0.L (FU);
	P1 = R1;
	P0.H = _chord_notes;
	R1 = SP;
	P0.L = _chord_notes;
	R0 = R1 + R2;
	P1 = P1 + P0;
	R5 = R0;
	R1 = 0 (X);
	P0 = 5 (X);
.L182:
	R2 = B [P1] (Z);
	R3 = 255 (X);
	cc =R2==R3;
	if !cc jump 6 (bp); jump.l .L189;
	R2 = R2 + R4;
	cc =R2<0;
	P1 += 1;
	if cc jump 6 (bp); jump.l .L447;
.L184:
	R2 += 12;
	cc =R2<0;
	if cc jump .L184 (bp);
	P2 = R5;
	R1 += 1;
	B [P2++] = R2;
	R5 = P2;
	P0 += -1;
	cc =P0==0;
	if !cc jump .L182;
	jump.s .L187;
.L458:
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
	[SP+76] = P0;
	[P0] = R2;
	cc =P2<=P1 (iu);
	if !cc jump 4 (bp); jump.s .L212;
	P4.H = _seed;
	P4.L = _seed;
	[SP+84] = P3;
.L216:
	P1 = [SP+76];
	P0 = -1000 (X);
	P2 = P2 + P0;
	P5 = 104 (X);
	[P1] = P2;
	P2.H = _now;
	P2.L = _now;
	P0 = 128 (X);
	[SP+68] = P2;
	P3 = 0 (X);
	P2.H = _tumblers;
	P5 = SP + P5;
	P0 = SP + P0;
	P2.L = _tumblers;
	[SP+72] = P3;
	[SP+48] = P5;
	[SP+44] = P0;
	jump.s .L260;
.L219:
	P1 = [SP+68];
	R3 = [SP+72];
	R3 += 1;
	R0 = 8 (X);
	P0 = 168 (X);
	P1 += 12;
	cc =R3==R0;
	[SP+72] = R3;
	P2 = P2 + P0;
	[SP+68] = P1;
	if !cc jump 4 (bp); jump.s .L460;
.L260:
	R6 = [P2+160];
	cc =R6==0;
	if cc jump .L219 (bp);
	P0 = [SP+68];
	R4 = 23037 (X);
	R0 = [P2+164];
	P1.H = 21845;
	R1 = B [P0] (X);
	R2 = B [P0+2] (Z);
	B [SP+56] = R1;
	R1 = B [P0+1] (X);
	B [SP+82] = R1;
	R1 = R2.L * R4.L (IS) ||
	[SP+52] = R6 ||
	nop;
	R0 = R1 + R0;
	P3 = R0;
	P1.L = 21845;
	R3 = B [P0+3] (X);
	P0.H = 54613;
	P0.L = 21846;
	P1 = P3 + P1;
	R7 = P1;
	P1 = 128 (X);
	P3 = P3 + P0;
	FP = P1 + SP;
	P0 = 104 (X);
	R4 = -1 (X);
	R6 = P3;
	[SP+60] = R2;
	B [SP+83] = R3;
	[P2+164] = R0;
	P5 = P0 + SP;
	R4 <<= 30;
	R5 = P2;
	P3 = FP;
.L220:
	R0 = R7;
	call _sin31;
	FP = R0;
	[P5++] = R0;
	R0 = R7 + R4;
	call _sin31;
	R3.H = 10922;
	R3.L = 43691;
	R2 = FP;
	R7 = R7 + R3;
	[P3++] = R0;
	R1 = -R2;
	R0 = -R0;
	cc =R7==R6;
	[P5+8] = R1;
	[P3+8] = R0;
	if !cc jump .L220 (bp);
	R6 = [SP+52];
	cc =R6<=0;
	P2 = R5;
	if cc jump .L219;
	R0 = B [SP+56] (Z);
	R1 = 2570 (X);
	R0 = R0.L * R1.L (IS) ||
	R4 = [SP+60] ||
	nop;
	R1 = 3 (X);
	R1 <<= 15;
	R1 = R0 + R1;
	B1 = R1;
	R1.H = 79;
	R1.L = 43950;
	R0 = B [SP+82] (Z);
	R0 *= R1;
	R1.H = 9830;
	R1.L = 26214;
	R1 = R0 + R1;
	R0.H = 70;
	R0.L = 44267;
	R4 *= R0;
	[SP+52] = R1;
	R0 = B [SP+83] (Z);
	R1 = 52634 (Z);
	R0 *= R1;
	[SP+60] = R4;
	[SP+56] = R0;
	P1 = R5;
	I0 = R5;
	FP = 0 (X);
	P2 = 0 (X);
.L232:
	P5 = [P1+8];
	P0 = [P1+12];
	P3 = B1;
	R3 = [P1];
	R0 = P5;
	P0 = P3 + P0;
	R0 >>>= 8;
	R3 = R3 + R0;
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
	[P1] = R3;
	[P1+4] = R7;
	if cc jump .L222 (bp);
	R0 += -1;
	B [P1+18] = R0;
.L222:
	P3 = 128 (X);
	P3 = P3 + SP;
	I3 = P3;
	R4 = [SP+44];
	P3 = 104 (X);
	R5 = [SP+48];
	P3 = P3 + SP;
	R0 = R4 - R5;
	M3 = P3;
	P3 = R0;
	P3 += -4;
	P3 = P3 >> 2;
	P3 += 1;
	M2 = P3;
	jump.s .L229;
.L329:
	R3 = [P1];
	R7 = [P1+4];
.L229:
	P3 = M3;
	R5 = [P3++];
	A1 = R3.L * R5.L (FU);
	A1 = A1 >> 16;
	A0 = R3.H * R5.H, A1 += R3.H * R5.L (M);
	M3 = P3;
	A1 += R5.H * R3.L (M);
	P3 = I3;
	R2 = [P3++];
	A1 = A1 >>> 15;
	R6 = (A0 += A1);
	A1 = R7.L * R2.L (FU);
	A1 = A1 >> 16;
	A0 = R7.H * R2.H, A1 += R7.H * R2.L (M);
	A1 += R2.H * R7.L (M);
	A1 = A1 >>> 15;
	R0 = (A0 += A1);
	R6 = R6 + R0;
	R0.H = 65364;
	R0.L = 35118;
	R0 = R6 + R0;
	cc =R0<=0;
	I3 = P3;
	[SP+32] = R0;
	if cc jump .L225;
	R4 = 13107 (X);
	A1 = R4.L * R5.L (FU);
	R6.H = 19;
	R6.L = 13107;
	A1 = A1 >> 16;
	A0 = R6.H * R5.H, A1 += R6.H * R5.L (M);
	A1 += R5.H * R6.L (M);
	A1 = A1 >>> 15;
	R6 = (A0 += A1);
	A1 = R4.L * R2.L (FU);
	R4.H = 19;
	R4.L = 13107;
	A1 = A1 >> 16;
	A0 = R4.H * R2.H, A1 += R4.H * R2.L (M);
	A1 += R2.H * R4.L (M);
	A1 = A1 >>> 15;
	R4 = (A0 += A1);
	R0 = -R5;
	R4 = R7 + R4;
	R5 = W [SP+60] (X);
	A1 = R4.L * R5.L (FU) ||
	R5 = [SP+60] ||
	nop;
	A1 = A1 >> 16;
	A0 = R4.H * R5.H, A1 += R4.H * R5.L (M);
	A1 += R5.H * R4.L (M);
	A1 = A1 >>> 15;
	R5 = R3 + R6;
	R4 = (A0 += A1);
	R6 = W [SP+60] (X);
	A1 = R5.L * R6.L (FU);
	R4 <<= 2;
	B2 = R4;
	A1 = A1 >> 16 ||
	R4 = [SP+60] ||
	nop;
	A0 = R5.H * R4.H, A1 += R5.H * R4.L (M);
	A1 += R4.H * R5.L (M);
	A1 = A1 >>> 15;
	R5 = (A0 += A1);
	R5 <<= 2;
	B0 = R5;
	R6 = B2;
	R5 = P5;
	R4 = R5 + R6;
	A1 = R4.L * R0.L (FU);
	R6 = B0;
	R5 = P0;
	A1 = A1 >> 16;
	R5 = R5 - R6;
	A0 = R4.H * R0.H, A1 += R4.H * R0.L (M) ||
	[SP+28] = R5 ||
	nop;
	A1 += R0.H * R4.L (M) ||
	R6 = W [SP+28] (X) ||
	nop;
	R1 = -R2;
	A1 = A1 >>> 15;
	R5 = (A0 += A1);
	A1 = R6.L * R1.L (FU);
	I2 = R5;
	A1 = A1 >> 16 ||
	R5 = [SP+28] ||
	nop;
	A0 = R5.H * R1.H, A1 += R5.H * R1.L (M);
	A1 += R1.H * R5.L (M);
	A1 = A1 >>> 15;
	R5 = W [SP+32] (X);
	R6 = (A0 += A1);
	A1 = R5.L * R0.L (FU);
	M0 = R6;
	A1 = A1 >> 16 ||
	R6 = [SP+32] ||
	nop;
	A0 = R6.H * R0.H, A1 += R6.H * R0.L (M);
	A1 += R0.H * R6.L (M);
	A1 = A1 >>> 15;
	R5 = (A0 += A1);
	R6 = W [SP+32] (X);
	R3 = R3 + R5;
	A1 = R6.L * R1.L (FU) ||
	[P1] = R3 ||
	nop;
	A1 = A1 >> 16 ||
	R3 = [SP+32] ||
	nop;
	A0 = R3.H * R1.H, A1 += R3.H * R1.L (M);
	A1 += R1.H * R3.L (M);
	I2 += M0;
	A1 = A1 >>> 15;
	R3 = (A0 += A1);
	R5 = I2;
	R3 = R7 + R3;
	cc =R5<0;
	[P1+4] = R3;
	if !cc jump .L225;
	R6.H = 65446;
	R6.L = 26215;
	cc =R5<R6;
	R3 = -R5;
	if cc jump 4; jump.s .L226;
	R7 = W [SP+52] (X);
	A1 = R3.L * R7.L (FU) ||
	R5 = [SP+52] ||
	nop;
	A1 = A1 >> 16;
	A0 = R3.H * R5.H, A1 += R3.H * R5.L (M);
	A1 += R5.H * R3.L (M);
	A1 = A1 >>> 15;
	R7 = (A0 += A1);
	R6 = I2;
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
	A1 = A1 >>> 15 ||
	R4 = [SP+28] ||
	nop;
	R7 = (A0 += A1);
	A1 = R6.L * R2.L (FU);
	A1 = A1 >> 16;
	A0 = R6.H * R2.H, A1 += R6.H * R2.L (M);
	A1 += R2.H * R6.L (M);
	R5 = R4 + R7;
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
	R7 = [P4];
	R4 = R7 << 13;
	R4 = R4 ^ R7;
	R7 = R4 >> 17;
	R7 = R7 ^ R4;
	R4 = R7 << 5;
	R4 = R4 ^ R7;
	R7 = W [SP+56] (X);
	A1 = R4.L * R7.L (FU) ||
	R7 = [SP+56] ||
	nop;
	A1 = A1 >> 16 ||
	[P4] = R4 ||
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
	A1 += R0.H * R6.L (M);
	R4 = P0;
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
	P5 = R2;
	A1 = A1 >>> 15;
	R1 = (A0 += A1);
	A1 = R7.L * R0.L (FU);
	A1 = A1 >> 16;
	A0 = R7.H * R0.H, A1 += R7.H * R0.L (M);
	R4 = B2;
	R2 = R5 - R4;
	A1 += R0.H * R7.L (M);
	R5 = P5;
	R2 = R2 + R5;
	A1 = A1 >>> 15 ||
	[P1+8] = R2 ||
	nop;
	R6 = B0;
	R2 = (A0 += A1);
	R0 = R6 + R1;
	R0 = R0 + R2;
	[P1+12] = R0;
	R0 = B [P1+18] (Z);
	cc =R0==0;
	if !cc jump .L227 (bp);
	P0 = 7 (X);
	cc =P2<=P0;
	if !cc jump .L227 (bp);
	P3 = 0 (X);
	P3 = P3 + SP;
	P0 = P3 + P2;
	R0 = B [P1+16] (X);
	B [P0+88] = R0;
	R3 >>>= 16;
	R0 = 48 (X);
	R0 = R0.L * R3.L (IS);
	P5 = 0 (X);
	R0 >>>= 8;
	P5 = P5 + SP;
	R0 += 38;
	R1 = 127 (X);
	P0 = P5 + P2;
	R0 = min(R0,R1);
	B [P0+96] = R0;
	R0 = 10 (X);
	B [P1+18] = R0;
	P2 += 1;
.L227:
	R0 = -1 (X);
	B [P1+17] = R0;
	P0 = [P1+12];
	P5 = [P1+8];
.L225:
	R2 = M2;
	R2 += -1;
	M2 = R2;
	cc =R2==0;
	if !cc jump .L329 (bp);
	R0 = P0;
	R2 = P5;
	P0 = 4 (X);
	LSETUP (.L234, .L482) LC1 = P0;
.L234:
	R1 = R2 >>> 13;
	R3 = R0 >>> 13;
	R1 *= R1;
	R3 *= R3;
	R6 = 25 (X);
	R1 = R1 + R3;
	R6 <<= 22;
	cc =R1<=R6;
	if cc jump .L235;
	R1 = R2 >>> 3;
	R2 = R2 - R1;
	R1 = R0 >>> 3 ||
	[P1+8] = R2 ||
	nop;
	R0 = R0 - R1;
.L482:
	[P1+12] = R0;
.L235:
	FP += 1;
	P0 = I0;
	R1 = [P0+160];
	R0 = FP;
	cc =R0<R1;
	P1 += 20;
	if !cc jump 4; jump.s .L232;
	cc =R1<=1;
	I2 = P2;
	P2 = I0;
	if cc jump .L257;
	R0 = W [SP+52] (X);
	R2 = 13106 (X);
	A0 = R0.L * R2.L (FU);
	R0 = A0.w;
	[SP+60] = R0;
	R0 = A0.x;
	[SP+64] = R0;
	P0 += 20;
	R4 = 0 (X);
	P5 = 9830 (X);
	I0 = 1 (X);
	FP = 32767 (X);
	M0 = -103 (X);
.L256:
	R4 += 1;
	cc =R4<R1;
	if !cc jump .L239;
	P1 = P0;
	P3 = R4;
.L255:
	R0 = [P1];
	R5 = [P0+-20];
	R0 = R0 - R5;
	R0 >>>= 8;
	R3 = P5;
	I3 = R0;
	R6 = 19660 (X);
	R0 = R0 + R3;
	cc =R0<=R6 (iu);
	if !cc jump .L241;
	R7 = [P0+-16];
	R2 = [P1+4];
	R2 = R2 - R7;
	R2 >>>= 8;
	R0 = R2 + R3;
	cc =R0<=R6 (iu);
	I1 = R7;
	if !cc jump .L241;
	R0 = R2;
	R3 = I3;
	R0 *= R2;
	R3 *= R3;
	R3 = R3 + R0;
	R0 = R3;
	R6.H = 1474;
	R0 += -64;
	R6.L = 28771;
	cc =R0<=R6 (iu);
	if !cc jump .L241 (bp);
	R6 = 1 (X);
	R6 <<= 30;
.L243:
	R6 >>= 2;
	cc =R3<R6 (iu);
	if cc jump .L243 (bp);
	R0 = 0 (X);
.L245:
	R1 = R6 + R0;
	cc =R1<=R3 (iu);
	R0 >>= 1;
	if !cc jump .L244 (bp);
	R3 = R3 - R1;
	R0 = R0 + R6;
.L244:
	R6 >>= 2;
	cc =R6==0;
	if !cc jump .L245 (bp);
	R7 = I3;
	R1 = -R7;
	R1 = max(R7,R1);
	R1 <<= 15;
	M1 = R1;
	R3 = 0 (X);
	B2 = 31 (X);
	M2 = R2;
	R1 = 0 (X);
	[--SP] = P0;
	P0 = 32 (X);
	LSETUP (.L247, .L481) LC1 = P0;
	P0 = [SP++];
.L247:
	R1 <<= 1;
	B0 = R1;
	R2 = B2;
	R1 = M1;
	R1 >>= R2;
	R7 = I0;
	R1 = R1 & R7;
	R2 = B0;
	R1 = R1 | R2;
	cc =R0<=R1 (iu);
	R3 <<= 1;
	if !cc jump .L246 (bp);
	R1 = R1 - R0;
	BITSET (R3, 0);
.L246:
	R7 = B2;
	R7 += -1;
.L481:
	B2 = R7;
	R2 = M2;
	R1 = -R2;
	R1 = max(R2,R1);
	R1 <<= 15;
	B0 = R1;
	B2 = 31 (X);
	R1 = 0 (X);
	[--SP] = P0;
	P0 = 32 (X);
	LSETUP (.L249, .L480) LC1 = P0;
	P0 = [SP++];
.L249:
	R6 <<= 1;
	M1 = R6;
	R7 = B2;
	R6 = B0;
	R6 >>= R7;
	R2 = I0;
	R6 = R6 & R2;
	R7 = M1;
	R6 = R6 | R7;
	cc =R0<=R6 (iu);
	R1 <<= 1;
	if !cc jump .L248 (bp);
	R6 = R6 - R0;
	BITSET (R1, 0);
.L248:
	R2 = B2;
	R2 += -1;
.L480:
	B2 = R2;
	R6 = FP;
	R7 = I3;
	R3 = min(R3,R6);
	cc =R7<0;
	R2 = M2;
	R1 = min(R1,R6);
	R3 <<= 16;
	if !cc jump .L251 (bp);
	R3 = -R3;
.L251:
	cc =R2<0;
	R1 <<= 16;
	if !cc jump .L253 (bp);
	R1 = -R1;
.L253:
	R2 = P5;
	R0 = R2 - R0;
	R0 <<= 7;
	A1 = R0.L * R3.L (FU);
	A1 = A1 >> 16;
	A0 = R0.H * R3.H, A1 += R0.H * R3.L (M);
	A1 += R3.H * R0.L (M);
	A1 = A1 >>> 15;
	R6 = (A0 += A1);
	A1 = R0.L * R1.L (FU);
	A1 = A1 >> 16;
	A0 = R0.H * R1.H, A1 += R0.H * R1.L (M);
	A1 += R1.H * R0.L (M);
	R5 = R5 - R6;
	A1 = A1 >>> 15;
	[P0+-20] = R5;
	R2 = (A0 += A1);
	R5 = I1;
	R0 = R5 - R2;
	[P0+-16] = R0;
	R0 = [P1];
	R0 = R0 + R6;
	[P1] = R0;
	R0 = [P1+4];
	R0 = R0 + R2;
	[P1+4] = R0;
	R5 = [P0+-12];
	R0 = [P1+8];
	R0 = R0 - R5;
	A1 = R0.L * R3.L (FU);
	A1 = A1 >> 16;
	A0 = R0.H * R3.H, A1 += R0.H * R3.L (M);
	A1 += R3.H * R0.L (M) ||
	R0 = [P1+12] ||
	nop;
	R6 = [P0+-8];
	R0 = R0 - R6;
	A1 = A1 >>> 15;
	R2 = (A0 += A1);
	A1 = R0.L * R1.L (FU);
	A1 = A1 >> 16;
	A0 = R0.H * R1.H, A1 += R0.H * R1.L (M);
	A1 += R1.H * R0.L (M);
	A1 = A1 >>> 15;
	R0 = (A0 += A1);
	R2 = R2 + R0;
	cc =R2<0;
	if !cc jump .L448;
	R7 = [SP+60];
	A1.w = R7;
	R7 = [SP+64];
	A1.x = R7;
	R7.H = 29491;
	R0 = [SP+52];
	R7.L = 13106;
	A1 = A1 >> 16;
	A0 = R0.H * R7.H, A1 += R0.H * R7.L (M);
	A1 += R7.H * R0.L (M);
	A1 = A1 >>> 15;
	R0 = (A0 += A1);
	A1 = R2.L * R0.L (FU);
	A1 = A1 >> 16;
	A0 = R2.H * R0.H, A1 += R2.H * R0.L (M);
	A1 += R0.H * R2.L (M);
	A1 = A1 >>> 15;
	R0 = (A0 += A1);
	R0 = R2 + R0;
	R0 = -R0;
	R0 >>>= 1;
	A1 = R0.L * R3.L (FU);
	A1 = A1 >> 16;
	A0 = R0.H * R3.H, A1 += R0.H * R3.L (M);
	A1 += R3.H * R0.L (M);
	A1 = A1 >>> 15;
	R3 = (A0 += A1);
	A1 = R0.L * R1.L (FU);
	A1 = A1 >> 16;
	A0 = R0.H * R1.H, A1 += R0.H * R1.L (M);
	A1 += R1.H * R0.L (M);
	A1 = A1 >>> 15;
	R1 = (A0 += A1);
	R5 = R5 - R3;
	R6 = R6 - R1;
	[P0+-12] = R5;
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
	if !cc jump .L448 (bp);
	R0 = B [P0+-3] (Z);
	R1 = 152 (X);
	cc =R0<=R1 (iu);
	if !cc jump .L254 (bp);
	R2 = M0;
	B [P0+-3] = R2;
.L254:
	R0 = B [P1+17] (Z);
	R3 = 152 (X);
	cc =R0<=R3 (iu);
	if !cc jump .L448 (bp);
	R5 = M0;
	B [P1+17] = R5;
.L448:
	R1 = [P2+160];
.L241:
	P3 += 1;
	R6 = P3;
	cc =R6<R1;
	P1 += 20;
	if cc jump .L255 (bp);
.L239:
	R0 = R1;
	R0 += -1;
	cc =R4<R0;
	P0 += 20;
	if cc jump .L256 (bp);
.L257:
	R1 = I2;
	cc =R1==0;
	if !cc jump 4 (bp); jump.s .L219;
	P0 = 88 (X);
	P5 = SP + P0;
	R0 = SP;
	R1 = 96 (X);
	P0 = I2;
	R6 = R0 + R1;
	P3 = P0 + P5;
	R7 = 9216 (X);
	R5 = [SP+72];
	R4 = P2;
	FP = [SP+84];
.L259:
	R0 = [FP+1676];
	R1 = 39 (X);
	cc =R0<=R1;
	P1 = P5;
	P2 = R6;
	P5 += 1;
	R6 += 1;
	if !cc jump .L258;
	R0 = B [P1] (Z);
	[SP+16] = R7;
	R1 = B [P2] (Z);
	[SP+12] = R1;
	R2 = R0;
	R1 = R5;
	R0 = FP;
	call _play.part.0;
.L258:
	cc =P5==P3;
	if !cc jump .L259 (bp);
	P2 = R4;
	jump.s .L219;
.L226:
	A1 = R3.L * R0.L (FU) ||
	R7 = [SP+28] ||
	nop;
	A1 = A1 >> 16;
	A0 = R3.H * R0.H, A1 += R3.H * R0.L (M);
	A1 += R0.H * R3.L (M);
	A1 = A1 >>> 15;
	R2 = (A0 += A1);
	R2 = R4 + R2;
	R4 = 30407 (X);
	A1 = R2.L * R4.L (FU);
	R5.H = 32702;
	R5.L = 30407;
	A1 = A1 >> 16;
	A0 = R2.H * R5.H, A1 += R2.H * R5.L (M);
	A1 += R5.H * R2.L (M);
	A1 = A1 >>> 15;
	R2 = (A0 += A1);
	A1 = R3.L * R1.L (FU);
	A1 = A1 >> 16;
	A0 = R3.H * R1.H, A1 += R3.H * R1.L (M);
	A1 += R1.H * R3.L (M);
	A1 = A1 >>> 15;
	R1 = (A0 += A1);
	R1 = R7 + R1;
	A1 = R1.L * R4.L (FU);
	A1 = A1 >> 16;
	A0 = R1.H * R5.H, A1 += R1.H * R5.L (M);
	A1 += R5.H * R1.L (M);
	A1 = A1 >>> 15;
	R6 = B2;
	R0 = (A0 += A1);
	R1 = B0;
	R2 = R2 - R6;
	R0 = R1 + R0;
	[P1+8] = R2;
	[P1+12] = R0;
	P0 = R0;
	P5 = R2;
	jump.s .L225;
.L460:
	P0.H = _tick4;
	P0.L = _tick4;
	R0 = B [P0] (X);
	R0 += 1;
	R1 = 3 (X);
	B [P0] = R0;
	R0 = R0 & R1;
	cc =R0==0;
	if !cc jump .L262 (bp);
	P5 = [SP+84];
	P2.H = 52;
	P2.L = 24108;
	R1 = 4 (X);
	P2 = P5 + P2;
	R0 = [P2];
	cc =R0==R1;
	if !cc jump .L262;
	P1 = [P5+48];
	cc =P1<=7 (iu);
	if !cc jump .L262;
	P5.H = _spark;
	P0.H = _glow;
	P5.L = _spark;
	P0.L = _glow;
	R0 = 0 (X);
	P2 = 4 (X);
	LSETUP (.L263, .L479) LC1 = P2;
.L263:
	[P5++] = R0;
.L479:
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
	if cc jump .L262;
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
	LSETUP (.L269, .L478) LC1 = P2;
.L269:
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
	P3 = R6;
	R1 = B [P1+17] (Z);
	FP = R1;
	R1 >>= 1;
	R0 = R0.B (Z);
	R1 = R1 + R3;
	R2 = R7 - R0;
	R1 = R1.B (Z);
	I0.H = _glow;
	R6 = R2.L * R1.L (IS);
	I0.L = _glow;
	M0 = P3;
	R6 >>>= 8;
	I0 += M0;
	P5 = R6;
	P0 = I0;
	R6 = FP;
	R2 = R2.L * R6.L (IS) ||
	R6 = B [P0] (Z) ||
	nop;
	P0 = R6;
	R2 >>>= 8;
	cc =P0<P5;
	if !cc jump .L264 (bp);
	R6 = P5;
	P0 = I0;
	B [P0] = R6;
.L264:
	P0.H = _spark;
	P0.L = _spark;
	P5 = P0 + P3;
	R6 = B [P5] (Z);
	cc =R2<=R6;
	if cc jump .L265 (bp);
	B [P5] = R2;
.L265:
	P0 = 15 (X);
	P5 = P3;
	cc =P3==P0;
	P5 += 1;
	if cc jump .L266;
	P0.H = _glow;
	P0.L = _glow;
	R1 = R0.L * R1.L (IS);
	R2 = FP;
	P3 = P0 + P5;
	R0 = R0.L * R2.L (IS) ||
	R2 = B [P3] (Z) ||
	nop;
	R1 >>>= 8;
	cc =R1<=R2;
	R0 >>>= 8;
	if cc jump .L267 (bp);
	B [P3] = R1;
.L267:
	P3.H = _spark;
	P3.L = _spark;
	P5 = P3 + P5;
	R1 = B [P5] (Z);
	cc =R0<=R1;
	if cc jump .L266 (bp);
	B [P5] = R0;
.L266:
.L478:
	P1 += 20;
.L262:
	P1 = [SP+76];
	P3 = 999 (X);
	P2 = [P1];
	cc =P2<=P3 (iu);
	if cc jump 4; jump.s .L216;
	P3 = [SP+84];
.L212:
	P2.H = 52;
	P2.L = 24108;
	P2 = P3 + P2;
	R0 = [P2];
	R1 = 5 (X);
	cc =R0==R1;
	if cc jump 4 (bp); jump.s .L270;
	R7 = [P3+48];
	cc =R7<=7 (iu);
	if cc jump 4 (bp); jump.s .L294;
.L449:
	P5 = -1 (X);
.L271:
	P0.H = _grooves+10;
	P1.H = _euclids+45;
	P0.L = _grooves+10;
	P1.L = _euclids+45;
	R0 = 0 (X);
	R1 = 0 (X);
	P2 = 8 (X);
	LSETUP (.L274, .L477) LC1 = P2;
.L274:
	cc =R7==R0;
	if cc jump .L272;
	B [P1] = R1;
.L272:
	R3 = P5;
	cc =R3==R0;
	if cc jump .L273;
	B [P0] = R1;
.L273:
	R0 += 1;
	P0 += 11;
.L477:
	P1 += 60;
	R0 = B [P3+20] (Z);
	cc =R0==0;
	if !cc jump 4 (bp); jump.s .L275;
	R4 = P5;
	R0 = R7 & R4;
	cc =R0==-1;
	if !cc jump 4 (bp); jump.s .L275;
	P4.H = 57;
	P4.L = 49443;
	P4 = P3 + P4;
	R0 = B [P4] (Z);
	cc =R0==0;
	if cc jump .L277;
	P2.H = _touched;
	P2.L = _touched;
	R0 = B [P2] (Z);
	cc =R0==0;
	if !cc jump .L277;
	P3.H = _shift_held;
	P3.L = _shift_held;
	R0 = B [P3] (Z);
	cc =R0==2;
	if !cc jump 4 (bp); jump.s .L82;
	P2.H = 32770;
	P2.L = 33428;
	call (P2);
	R1 = ROT R0 BY 0 ||
	R0 = B [P3] (Z) ||
	nop;
	cc =R0==0;
	if !cc jump 4 (bp); jump.s .L461;
	P2.H = _shift_ms;
	P2.L = _shift_ms;
	R0 = [P2];
	R0 = R1 - R0;
	R5 = 1999 (X);
	cc =R0<=R5 (iu);
	if !cc jump 6 (bp); jump.l .L82;
	R0 = 2 (X);
	B [P3] = R0;
	cc =R7==-1;
	R0 = 0 (X);
	B [P4] = R0;
	if !cc jump 4 (bp); jump.s .L281;
	R6 = 60 (X);
	R0 = R7 << 4;
	R0 = R0 - R7;
	R6 = R6.L * R7.L (FU);
	P1 = R0;
	P2 = R6;
	P0.H = _euclids;
	P0.L = _euclids;
	P1 = P0 + (P1 << 2);
	P2 += 45;
	P2 = P0 + P2;
	R0 = B [P1+45] (X);
	jump.s .L282;
.L457:
	P1.H = _running;
	P1.L = _running;
	R0 = B [P1] (Z);
	cc =R0==0;
	if cc jump .L214 (bp);
	P5.H = _spark;
	P0.H = _glow;
	P5.L = _spark;
	P0.L = _glow;
	R0 = 0 (X);
	P2 = 4 (X);
	LSETUP (.L213, .L476) LC1 = P2;
.L213:
	[P5++] = R0;
.L476:
	[P0++] = R0;
.L214:
	R0 = 0 (X);
	B [P1] = R0;
	jump.s .L212;
.L277:
	P2.H = _shift_held;
	P2.L = _shift_held;
	R0 = 2 (X);
	P1 = 152 (X);
	B [P2] = R0;
	SP = SP + P1;
	FP = [SP++];
	RETS = [SP++];
	( r7:4, p5:3 ) = [sp++];

	rts;
.L104:
	P2.H = _was_playing;
	P2.L = _was_playing;
	R0 = B [P2] (Z);
	cc =R0==0;
	if cc jump .L106 (bp);
	P5.H = _waiting;
	B [P2] = R1;
	R1 = [P3+64];
	P5.L = _waiting;
	cc =R1==0;
	[SP+52] = P5;
	R0 = B [P5] (X);
	if cc jump 4; jump.s .L462;
	R1 = [P3+56];
	cc =R1==0;
	R0 = R0.B (Z);
	if !cc jump 4; jump.s .L111;
	cc =R0==0;
	if !cc jump 4; jump.s .L113;
.L109:
	P1 = [SP+52];
	R0 = 0 (X);
	P4.H = _beat;
	P4.L = _beat;
	B [P1] = R0;
.L450:
	R0 = 0 (X);
	[P4] = R0;
.L117:
	cc =R7==0;
	if cc jump 6; jump.l .L284;
	jump.s .L285;
.L451:
	P2.H = _jog_slack;
	P2.L = _jog_slack;
	R1 = 0 (X);
	[P2] = R1;
	P2.H = _jogged;
	P2.L = _jogged;
	R0 = B [P2] (Z);
	cc =R0==0;
	if !cc jump 6 (bp); jump.l .L86;
	R0 = 0 (X);
	B [P2] = R0;
	P2 = [P3+48];
	P0 = 15 (X);
	cc =P2<=P0 (iu);
	if cc jump 6 (bp); jump.l .L86;
	P1.H = 52;
	P1.L = 24108;
	P1 = P3 + P1;
	P1 = [P1];
	cc =P1<=7 (iu);
	if cc jump 6 (bp); jump.l .L86;
	P2 = P2 + (P2 << 1);
	P5.H = 33041;
	P2 = P1 + (P2 << 1);
	P5.L = 12748;
	P2 = P2 + P5;
	R0 = B [P2] (X);
	cc =R0<0;
	if !cc jump 6 (bp); jump.l .L86;
	P2.H = 33025;
	P2.L = 24220;
	R3 = [P2];
	[SP+24] = R1;
	[SP+20] = R1;
	R1.H = 33041;
	R1.L = 12492;
	R1 = R0 + R1;
	P2 = R1;
	R2 = 500 (X);
	R1 = 2 (X);
	R0 = B [P2] (Z);
	P2.H = 32771;
	[SP+16] = R0;
	[SP+12] = P1;
	R0 = R3;
	P2.L = 50700;
	call (P2);
	jump.l .L86;
.L106:
	P0.H = _waiting;
	P0.L = _waiting;
	R0 = 1 (X);
	B [P0] = R0;
	R0 = [P3+64];
	cc =R0==0;
	[SP+52] = P0;
	B [P2] = R1;
	if cc jump .L109 (bp);
	jump.s .L114;
.L455:
	R6 = 0 (X);
	R2 = 31 (X);
	R0 = 0 (X);
	R3 = 1 (X);
	P2 = 32 (X);
	LSETUP (.L124, .L475) LC1 = P2;
.L124:
	R1 = P1;
	R1 >>= R2;
	R0 <<= 1;
	R1 = R1 & R3;
	R0 = R1 | R0;
	cc =R0<R4 (iu);
	R6 <<= 1;
	if cc jump .L123 (bp);
	R0 = R0 - R4;
	BITSET (R6, 0);
.L123:
.L475:
	R2 += -1;
	cc =R5<=3;
	if !cc jump 4 (bp); jump.s .L463;
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
	LSETUP (.L144, .L474) LC1 = P0;
.L144:
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
	if cc jump .L143 (bp);
	BITSET (R3, 0);
	R0 = R0 - R1;
	B1 = R3;
.L143:
	M0 = -1 (X);
.L474:
	I1 += M0;
	R3 = B1;
	R3 *= R1;
	R0 = B [P5+2] (Z);
	R0 = R0.L * R1.L (IS);
	R0 >>>= 8;
	R3 = R6 - R3;
	cc =R1<=R0;
	I2 = R3;
	if cc jump .L464 (bp);
.L145:
	R2 = I2;
	R0 = R2 + R0;
	cc =R1<=R0;
	if !cc jump .L146;
.L147:
	R0 = R0 - R1;
	cc =R1<=R0;
	if cc jump .L147 (bp);
.L146:
	R3 = B0;
	R0 *= R3;
	cc =R1<=R0;
	if !cc jump .L148;
.L149:
	R0 = R0 - R1;
	cc =R1<=R0;
	if cc jump .L149 (bp);
.L148:
	R6 = B0;
	cc =R6<=R0;
	if !cc jump 6; jump.l .L119;
	R2 = B [P5+6] (Z);
	R0 = 253 (X);
	cc =R2<=R0;
	if !cc jump .L153 (bp);
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
	if !cc jump 6; jump.l .L119;
.L153:
	P1 = [FP+36];
	P0 = I0;
	cc =P0<=P1;
	if !cc jump 4; jump.s .L151;
	R2 = P1;
	R2 += 1;
.L154:
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
	if cc jump .L155 (bp);
	R1 += 1;
	B0 = R1;
	R0 = 0 (X);
	P0 = 31 (X);
	R6 = 0 (X);
	P2 = 32 (X);
	LSETUP (.L157, .L473) LC1 = P2;
.L157:
	R6 <<= 1;
	R3 = P0;
	R1 = R2;
	R1 >>= R3;
	R3 = R6;
	R6 = 1 (X);
	R1 = R1 & R6;
	R6 = R1 | R3;
	R1 = B0;
	cc =R1<=R6 (iu);
	R0 <<= 1;
	if !cc jump .L156 (bp);
	R6 = R6 - R1;
	BITSET (R0, 0);
.L156:
.L473:
	P0 += -1;
	R3 = B0;
	R0 *= R3;
	R0 = R2 - R0;
	P2 = R0;
	P2 = P2 + (P2 << 1);
	P1 = P1 + (P2 << 2);
.L155:
	R0 = R2;
	R0 += 1;
	P0 = 127 (X);
	R0 = R0.L (Z);
	cc =P1<=P0;
	[FP+40] = R0;
	if cc jump .L158;
.L159:
	P1 += -12;
	P2 = 127 (X);
	cc =P1<=P2;
	if !cc jump .L159 (bp);
.L158:
	R0 = I2;
	cc =R0==0;
	R2 = B [P5+5] (Z);
	if !cc jump 4; jump.s .L160;
	R0 = 57 (X);
	R0 = R0.L * R2.L (IS);
	R0 >>>= 8;
	R1 = 114 (X);
	R1 = R1 - R0;
.L161:
	R0 = [P3+1676];
	R2 = 39 (X);
	cc =R0<=R2;
	if cc jump 6 (bp); jump.l .L119;
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
	R0 = P3;
	call _play.part.0;
	jump.l .L119;
.L454:
	cc =R0<=0;
	if !cc jump 4 (bp); jump.s .L286;
	P4.H = _takes;
	P4.L = _takes;
	R0 = SP;
	R1 = 128 (X);
	P5 = P4;
	FP = 0 (X);
	R7 = 0 (X);
	R6 = R0 + R1;
	jump.s .L102;
.L99:
	R1 = P5;
	R0 = P3;
	call _write;
	P0 = R5;
	R7 += 1;
	P5 += 12;
	R0 = [P0];
	cc =R7<R0;
	if !cc jump .L98;
.L102:
	R0 = B [P3+28] (Z);
	cc =R0==0;
	if cc jump .L99;
	P0 = 104 (X);
	R0 = B [P5+8] (Z);
	P0 = P0 + SP;
	P1.H = 32784;
	R1 = ROT R0 BY 0 ||
	[SP+12] = R6 ||
	nop;
	R0 = P3;
	R2 = P0;
	P1.L = 44920;
	call (P1);
	R1 = W [P5] (X);
	R0 = [SP+104];
	cc =R1==R0;
	if !cc jump .L99 (bp);
	R1 = [SP+128];
	R0 = 7 (X);
	cc =R1<=R0;
	if cc jump .L100;
	R0 = W [P5+2] (X);
	R0 += 7;
	cc =R1<=R0;
	if !cc jump .L99 (bp);
.L100:
	P2 = FP + (FP << 1);
	P0 = P5;
	P2 = P4 + (P2 << 2);
	R0 = [P0++];
	P1 = P2;
	[P1++] = R0;
	R0 = [P5+4];
	[P2+4] = R0;
	R0 = [P0+4];
	P0 = R5;
	[P1+4] = R0;
	R7 += 1;
	FP += 1;
	P5 += 12;
	R0 = [P0];
	cc =R7<R0;
	if cc jump .L102 (bp);
.L98:
	P1 = R5;
	[P1] = FP;
	jump.l .L97;
.L459:
	R1 = W [P2+4] (Z);
	R0 = R1 & R0;
	cc =R0==0;
	if cc jump .L289 (bp);
	P1 = 45 (X);
	[SP+56] = P1;
	jump.l .L171;
.L172:
	R2 = B [FP+3] (Z);
	R1 = 5 (X);
	R1 = R1.L * R2.L (IS);
	R4 = SP;
	R5 = 128 (X);
	R1 >>>= 8;
	R0 = R4 + R5;
	P1 = P5;
	cc =R1==3;
	R3 = B [P1++] (X);
	R2 = R0;
	I1 = 0 (X);
	if !cc jump .L291;
.L196:
	P0 = R2;
.L191:
	M0 = 1 (X);
	B [P0] = R3;
	I1 += M0;
	R1 = B [P5+-1] (Z);
	R3 = I1;
	cc =R3<R1;
	if !cc jump .L189;
	R1 = B [FP+3] (Z);
	R4 = 5 (X);
	R1 = R4.L * R1.L (IS);
	R1 >>>= 8;
	I0 = P1;
	cc =R1==3;
	R2 += 1;
	I0 += M0;
	if !cc jump .L195;
	R3 = B [P1] (X);
	P1 = I0;
	jump.s .L196;
.L195:
	P1 = I0;
	R3 = B [P1+-1] (X);
	R1 = R3.B (Z);
	R4 = R2 - R0;
	P1 = R2;
	I3 = R1;
	P2 = R4;
	LSETUP (.L192, .L472) LC1 = P2;
.L192:
	R5 = B [P1+-1] (X);
	R1 = R5.B (Z);
	R4 = I3;
	cc =R4<R1 (iu);
	P0 = P1;
	if !cc jump .L193;
	B [P1] = R5;
	P1 = P0;
.L472:
	P1 += -1;
	P0 = I0;
	R3 = B [P0+-1] (X);
	P0 = R0;
.L193:
	P1 = I0;
	jump.s .L191;
.L189:
	cc =R1==0;
	if !cc jump 6 (bp); jump.l .L166;
.L187:
	R5 = B1;
	R3 = 218 (X);
	R2 = R5.B (Z);
	R2 = R2.L * R3.L (IS);
	R2 >>>= 8;
	R2 += 26;
	R6 = R2.L * R6.L (IS);
	R2 = 256 (X);
	R6 = max(R6,R2);
	R3 = B [FP+3] (Z);
	R2 = 5 (X);
	R2 = R2.L * R3.L (IS);
	R2 >>>= 8;
	P0 = R2;
	cc =P0==0;
	if cc jump .L465;
	P1 = 4 (X);
	cc =P0==P1;
	if cc jump .L466;
	R3 = B [P5+8] (Z);
	B0 = R3;
	P1 = R3;
.L201:
	R5 = 0 (X);
	I0 = 31 (X);
	R3 = 0 (X);
	P2 = 32 (X);
	LSETUP (.L203, .L471) LC1 = P2;
.L203:
	R3 <<= 1;
	R2 = I0;
	R4 = P1;
	R4 >>= R2;
	R2 = R3;
	R3 = 1 (X);
	R4 = R4 & R3;
	R3 = R4 | R2;
	cc =R1<=R3 (iu);
	R5 <<= 1;
	if !cc jump .L202 (bp);
	R3 = R3 - R1;
	BITSET (R5, 0);
.L202:
	M0 = -1 (X);
.L471:
	I0 += M0;
	R5 *= R1;
	R2 = B0;
	R2 += 1;
	P2 = R5;
	B2 = R2;
	R5 = 0 (X);
	I1 = 31 (X);
	R3 = 0 (X);
	[--SP] = P0;
	P0 = 32 (X);
	LSETUP (.L205, .L470) LC1 = P0;
	P0 = [SP++];
.L205:
	R3 <<= 1;
	B1 = R3;
	R4 = I1;
	R3 = B2;
	R3 >>= R4;
	R2 = 1 (X);
	R3 = R3 & R2;
	R4 = B1;
	R3 = R3 | R4;
	R2 = 239 (X);
	cc =R3<=R2 (iu);
	R5 <<= 1;
	if cc jump .L204 (bp);
	R4 = -240 (X);
	R3 = R3 + R4;
	BITSET (R5, 0);
.L204:
	M0 = -1 (X);
.L470:
	I1 += M0;
	R3 = R5 << 4;
	R3 = R3 - R5;
	R3 <<= 4;
	R4 = B2;
	R2 = R4 - R3;
	cc =P0==2;
	B [P5+8] = R2;
	if cc jump .L206;
	P1 -= P2;
	R1 = P1;
.L207:
	R2 = [P3+1676];
	R3 = 39 (X);
	cc =R2<=R3;
	if cc jump 6 (bp); jump.l .L166;
	R0 = R0 + R1;
	P0 = R0;
	P1 = [SP+56];
	R1 = R7;
	R0 = B [P0] (Z);
	R2 = ROT R0 BY 0 ||
	[SP+16] = R6 ||
	nop;
	[SP+12] = P1;
	R0 = P3;
	call _play.part.0;
	jump.l .L166;
.L465:
	R5 = R0;
	R4 = R0 + R1;
.L199:
	R0 = [P3+1676];
	R1 = 39 (X);
	cc =R0<=R1;
	P2 = R5;
	R5 += 1;
	if !cc jump .L198;
	R0 = B [P2] (Z);
	R3 = [SP+56];
	R2 = ROT R0 BY 0 ||
	[SP+16] = R6 ||
	nop;
	[SP+12] = R3;
	R1 = R7;
	R0 = P3;
	call _play.part.0;
.L198:
	cc =R4==R5;
	if !cc jump .L199 (bp);
	jump.l .L166;
.L289:
	R3 = 85 (X);
	[SP+56] = R3;
	jump.l .L171;
.L292:
	R0 = 1 (X);
	jump.l .L218;
.L464:
	R0 = P1;
	R0 += 1;
	jump.s .L145;
.L463:
	R1 = I0;
	cc =R1<=0;
	if cc jump .L438;
	R3 = 0 (X);
	P0.H = _seed;
	P2 = FP;
	[SP+56] = R3;
	P0.L = _seed;
.L126:
	R3 = B [P2+5] (Z);
	R2 = 0 (X);
	R4 = 31 (X);
	R0 = 0 (X);
	P1 = 32 (X);
	LSETUP (.L129, .L469) LC1 = P1;
.L129:
	R1 = R6;
	R1 >>= R4;
	R0 <<= 1;
	R1 = R1 & R7;
	R0 = R1 | R0;
	cc =R3<=R0 (iu);
	R2 <<= 1;
	if !cc jump .L128 (bp);
	R0 = R0 - R3;
	BITSET (R2, 0);
.L128:
.L469:
	R4 += -1;
	R0 = R3;
	R0 *= R2;
	R1 = B [P2+7] (Z);
	R0 = R6 - R0;
	R1 = R1 + R0;
	cc =R3<=R1;
	R2 = B [P2+6] (Z);
	if !cc jump .L130;
.L131:
	R1 = R1 - R3;
	cc =R3<=R1;
	if cc jump .L131 (bp);
.L130:
	R1 *= R2;
	cc =R3<=R1;
	if !cc jump .L132;
.L133:
	R1 = R1 - R3;
	cc =R3<=R1;
	if cc jump .L133 (bp);
.L132:
	cc =R2<=R1;
	if cc jump .L135 (bp);
	R4 = B [P5+6] (Z);
	R1 = 253 (X);
	cc =R4<=R1;
	if !cc jump .L139 (bp);
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
	if cc jump .L135 (bp);
.L139:
	cc =R0==0;
	R1 = B [P5+5] (Z);
	if cc jump .L467 (bp);
	R0 = 51 (X);
	R0 = R0.L * R1.L (IS);
	R0 >>>= 8;
	R3 = 109 (X);
	R0 = R3 - R0;
.L141:
	R1 = [P3+1676];
	R2 = 39 (X);
	cc =R1<=R2;
	if !cc jump .L135;
	R1 = B [P2+4] (Z);
	R3 = 6144 (X);
	[SP+12] = R0;
	R2 = ROT R1 BY 0 ||
	[SP+16] = R3 ||
	nop;
	R1 = ROT R5 BY 0 ||
	[SP+36] = P0 ||
	nop;
	R0 = P3;
	[SP+40] = P2;
	call _play.part.0;
	R4 = [FP];
	I0 = R4;
	P2 = [SP+40];
	P0 = [SP+36];
.L135:
	P1 = [SP+56];
	R4 = I0;
	P2 += 4;
	P1 += 1;
	R3 = P1;
	cc =R3<R4;
	[SP+56] = P1;
	if cc jump .L126 (bp);
.L438:
	R5 += 1;
	jump.l .L446;
.L467:
	R0 = 18 (X);
	R0 = R0.L * R1.L (IS);
	R0 >>>= 8;
	R4 = 109 (X);
	R0 = R0 + R4;
	jump.s .L141;
.L462:
	R0 = R0.B (Z);
	cc =R0==0;
	if !cc jump 6; jump.l .L113;
	jump.l .L114;
.L111:
	cc =R0==0;
	if cc jump 4 (bp); jump.s .L109;
	P2 = [P3+60];
	P4.H = _beat;
	P4.L = _beat;
	R2 = [P4];
	R0 = P2;
	R0 += -1;
	R1 = 63 (X);
	R2 += 1;
	cc =R0<=R1 (iu);
	[P4] = R2;
	if cc jump 6; jump.l .L105;
	P2 = P2 + (P2 << 1);
	R0 = P2;
	R0 <<= 3;
	R3 = 0 (X);
	R6 = 31 (X);
	R1 = 0 (X);
	R4 = 1 (X);
	P2 = 32 (X);
	LSETUP (.L116, .L468) LC1 = P2;
.L116:
	R5 = R2;
	R5 >>= R6;
	R1 <<= 1;
	R5 = R5 & R4;
	R1 = R5 | R1;
	cc =R0<=R1 (iu);
	R3 <<= 1;
	if !cc jump .L115 (bp);
	R1 = R1 - R0;
	BITSET (R3, 0);
.L115:
.L468:
	R6 += -1;
	R0 *= R3;
	cc =R0==R2;
	if cc jump 4; jump.s .L450;
	jump.s .L117;
.L291:
	P0 = R0;
	jump.s .L191;
.L461:
	P2.H = _shift_ms;
	R0 = 1 (X);
	P2.L = _shift_ms;
	B [P3] = R0;
	[P2] = R1;
	jump.l .L82;
.L186:
	R2 += -12;
.L447:
	R3 = 127 (X);
	cc =R2<=R3;
	if !cc jump .L186 (bp);
	P2 = R5;
	R1 += 1;
	B [P2++] = R2;
	R5 = P2;
	P0 += -1;
	cc =P0==0;
	if cc jump 6 (bp); jump.l .L182;
	jump.s .L187;
.L281:
	P0 = P5 + (P5 << 2);
	P0 = P5 + (P0 << 1);
	P2 = P0;
	P1.H = _grooves;
	P1.L = _grooves;
	P2 += 10;
	P2 = P2 + P1;
	P1 = P1 + P0;
	R0 = B [P1+10] (X);
.L282:
	R2 = R0;
	BITTGL (R2, 0);
	B [P2] = R2;
	R2 = R0.B (Z);
	cc =R2==1;
	if cc jump .L283;
	R0 = 2 (X);
.L283:
	P2.H = _flashes;
	P2.L = _flashes;
	B [P2] = R0;
	P2.H = _flash_ms;
	P2.L = _flash_ms;
	[P2] = R1;
	jump.l .L82;
.L294:
	R7 = -1 (X);
	jump.s .L449;
.L270:
	R2 = 6 (X);
	cc =R0==R2;
	if !cc jump .L294;
	P5 = [P3+48];
	R7 = -1 (X);
	cc =P5<=7 (iu);
	if !cc jump 4; jump.s .L271;
	jump.s .L449;
.L206:
	R1 += -1;
	R5 = P1;
	R1 = R1 - R5;
	R2 = P2;
	R1 = R1 + R2;
	jump.s .L207;
.L151:
	R0 = 0 (X);
	[FP+36] = R0;
	R2 = 1 (X);
	P1 = 0 (X);
	jump.s .L154;
.L466:
	P2.H = _seed;
	P2.L = _seed;
	R3 = [P2];
	R2 = R3 << 13;
	R2 = R2 ^ R3;
	R3 = R2 >> 17;
	R3 = R3 ^ R2;
	R2 = R3 << 5;
	R2 = R2 ^ R3;
	[P2] = R2;
	R2 >>= 8;
	P1 = R2;
	R2 = B [P5+8] (Z);
	B0 = R2;
	jump.s .L201;
.L286:
	FP = 0 (X);
	jump.s .L98;
.L160:
	R1 = 13 (X);
	R1 = R1.L * R2.L (IS);
	R1 >>>= 8;
	R0 = 114 (X);
	R1 = R1 + R0;
	jump.s .L161;
	.size	_pages_tick, .-_pages_tick
	.align 4
.global _pages_note;
.type _pages_note, STT_FUNC;
_pages_note:
	cc =R1<=7 (iu);
	P2 = R0;
	[--sp] = ( r7:7, p5:4 );

	R0 = R2;
	if !cc jump .L493;
	R2 = 127 (X);
	cc =R0<=R2 (iu);
	if !cc jump .L493;
	cc =P2==0;
	if cc jump .L493;
	P1.H = 52;
	P1.L = 24108;
	P1 = P2 + P1;
	R2 = [P1];
	R3 = 4 (X);
	cc =R2==R3;
	if !cc jump .L495;
	R3 = [P2+48];
	cc =R3<=7 (iu);
	if !cc jump .L493;
	cc =R1==R3;
	if cc jump .L551;
.L493:
	( r7:7, p5:4 ) = [sp++];

	rts;
.L551:
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
	if !cc jump .L496 (bp);
	I0 = P0;
	M0 = 1 (X);
	I0 += M0;
.L497:
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
.L495:
	R3 = 5 (X);
	cc =R2==R3;
	if !cc jump .L499;
	R3 = [P2+48];
	cc =R3<=7 (iu);
	if !cc jump .L493;
	cc =R1==R3;
	if !cc jump .L493 (bp);
	I1.H = _euclids;
	I1.L = _euclids;
	R2.H = _grooves;
	R2.L = _grooves;
	P0 = I1;
	I0 = 0 (X);
	P1 = 8 (X);
	LSETUP (.L501, .L564) LC1 = P1;
.L501:
	P4 = R2;
	R7 = [P0];
	R2 += 11;
	P0 += 60;
	R1 = B [P4] (Z);
	R1 = R1 | R7;
	R7 = I0;
	R7 = R7 | R1;
.L564:
	I0 = R7;
	cc =R7==0;
	if cc jump .L552 (bp);
.L502:
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
	if cc jump .L503;
	R2 = -1 (X);
	R1 = 0 (X);
	P1 = P4;
	LSETUP (.L505, .L563) LC1 = P1;
.L505:
	R7 = B [P2+4] (Z);
	cc =R0==R7;
	if !cc jump .L504 (bp);
	R2 = R1;
.L504:
	R1 += 1;
.L563:
	P2 += 4;
	cc =R2==-1;
	if cc jump .L506;
	cc =R3<=3;
	if !cc jump .L507;
	P0 = R3;
	P2 = I3;
	P1 = I1;
	P2 -= P0;
	P2 = P1 + (P2 << 2);
	R0 = B [P2+44] (Z);
	cc =R0==R2;
	if cc jump .L507;
	B [P2+44] = R2;
	jump.s .L493;
.L499:
	R3 = 6 (X);
	cc =R2==R3;
	if !cc jump .L493;
	R3 = [P2+48];
	cc =R3<=7 (iu);
	if !cc jump .L493;
	cc =R1==R3;
	if !cc jump .L493 (bp);
	I3.H = _grooves;
	R2.H = _euclids;
	I3.L = _grooves;
	R2.L = _euclids;
	P0 = I3;
	I0 = 0 (X);
	P1 = 8 (X);
	LSETUP (.L517, .L562) LC1 = P1;
.L517:
	P4 = R2;
	R1 = B [P0] (Z);
	R2 += 60;
	P0 += 11;
	R7 = [P4];
	R1 = R1 | R7;
	R7 = I0;
	R7 = R7 | R1;
.L562:
	I0 = R7;
	cc =R7==0;
	if cc jump .L553 (bp);
.L518:
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
	if cc jump .L519;
	P0.H = _grooves+1;
	P0.L = _grooves+1;
	P0 = P0 + P1;
	B2 = P0;
	P1 = P0;
	P2 = 0 (X);
	P0 = R2;
	LSETUP (.L525, .L561) LC1 = P0;
.L525:
	R1 = B [P1] (Z);
	cc =R0==R1;
	if cc jump .L554;
	P1 += 1;
.L561:
	P2 += 1;
	cc =R3<=3;
	if cc jump .L526;
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
	if cc jump .L526 (bp);
	B0 = 0 (X);
	B1 = 1 (X);
.L527:
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
	jump.s .L493;
.L552:
	R1 = B [P2+28] (Z);
	cc =R1==0;
	if !cc jump .L502 (bp);
	P2.H = _beat;
	P2.L = _beat;
	R1 = -1 (X);
	[P2] = R1;
	jump.s .L502;
.L496:
	P0 = 7 (X);
	LSETUP (.L498, .L560) LC0 = P0;
.L498:
	I0 = P1;
	M0 = 20 (X);
	P4 = P1;
	I0 += M0;
	P5 = 4 (X);
	R7 = [I0++]; lsetup (1f, 1f) LC1 = P5; 1: MNOP || [P4++] = R7 || R7 = [I0++]; [P4++] = R7;
.L560:
	P1 += 20;
	I0 = 8 (X);
	P0 = 7 (X);
	jump.s .L497;
.L553:
	R1 = B [P2+28] (Z);
	cc =R1==0;
	if !cc jump .L518 (bp);
	P2.H = _beat;
	P2.L = _beat;
	R1 = -1 (X);
	[P2] = R1;
	jump.s .L518;
.L507:
	R1 = I0;
	R1 += -1;
	cc =R1<=R2;
	if cc jump .L555;
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
	LSETUP (.L511, .L559) LC1 = P1;
.L511:
	R0 = [P2+4];
.L559:
	[P2++] = R0;
	P4 = R3;
	P2 = I3;
	P5 = I1;
	P2 -= P4;
	P2 = P5 + (P2 << 2);
	R0 = B [P2+44] (Z);
	cc =R1<=R0;
	[P2] = R1;
	if !cc jump .L493 (bp);
.L531:
	R0 = R1;
	R0 += -1;
.L513:
	P1 = R3;
	P2 = I3;
	P4 = I1;
	P2 -= P1;
	P2 = P4 + (P2 << 2);
	B [P2+44] = R0;
	jump.s .L493;
.L554:
	R0 = R2;
	R0 += -1;
	R1 = P2;
	cc =R0<=R1;
	if cc jump .L524;
	P5 = R2;
	P4 = B2;
	P0 = I2;
	P2 = P2 + P4;
	P4 = I3;
	P1 = P5 + P0;
	P1 = P1 + P4;
	P1 -= P2;
	LSETUP (.L523, .L558) LC1 = P1;
.L523:
	R0 = B [P2+1] (X);
.L558:
	B [P2++] = R0;
.L524:
	R0 = I0;
	R0 = (R0 + R3) << 1;
	R0 = R0 + R3;
	P1 = R0;
	P0 = I3;
	R0 = B1;
	R0 += -1;
	P2 = P0 + P1;
	B [P2] = R0;
	jump.s .L493;
.L526:
	R1 = 8 (X);
	cc =R2==R1;
	if !cc jump .L530;
	R1 = I0;
	R1 = (R1 + R3) << 1;
	R1 = R1 + R3;
	P1 = R1;
	P0.H = _grooves+1;
	P0.L = _grooves+1;
	P2 = P0 + P1;
	P1 = 7 (X);
	LSETUP (.L529, .L557) LC1 = P1;
.L529:
	R1 = B [P2+1] (X);
.L557:
	B [P2++] = R1;
	B0 = 7 (X);
	jump.s .L527;
.L506:
	R1 = I0;
	R2 = 8 (X);
	cc =R1==R2;
	if cc jump .L514;
.L503:
	P2.H = _fresh.0;
	P0 = I0;
	P2.L = _fresh.0;
	P2 = P2 + (P0 << 1);
	R2 = B [P2+1] (X);
	I2 = R2;
	R1 = B [P2] (X);
	P0 += 1;
	R2 = I0;
.L515:
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
	jump.s .L493;
.L514:
	P2.H = _euclids+4;
	P2.L = _euclids+4;
	P0 = I2;
	P2 = P2 + P0;
	P1 = 7 (X);
	LSETUP (.L516, .L556) LC1 = P1;
.L516:
	R1 = [P2+4];
.L556:
	[P2++] = R1;
	P0 = 8 (X);
	R2 = 7 (X);
	I2 = 4 (X);
	R1 = 9 (X);
	I0 = 7 (X);
	jump.s .L515;
.L530:
	R2 = B1;
	R2 += 1;
	B1 = R2;
	jump.s .L527;
.L519:
	cc =R3<=3;
	if cc jump .L536 (bp);
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
	if cc jump .L530 (bp);
.L536:
	B1 = 1 (X);
	jump.s .L527;
.L555:
	P4 = R3;
	P2 = I3;
	P5 = I1;
	P2 -= P4;
	P2 = P5 + (P2 << 2);
	R0 = B [P2+44] (Z);
	cc =R1<=R0;
	[P2] = R1;
	if cc jump 4 (bp); jump.s .L493;
	cc =R1==0;
	R0 = 0 (X);
	if cc jump .L513 (bp);
	jump.s .L531;
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
	if cc jump .L635;
	P0.H = 52;
	P0.L = 24108;
	P0 = P1 + P0;
	R0 = [P0];
	R2 = 4 (X);
	cc =R0==R2;
	if !cc jump .L567;
	P0 = [P1+48];
	cc =P0<=7 (iu);
	if !cc jump .L635;
	cc =P2<=7 (iu);
	if !cc jump .L635;
	cc =P2==P0;
	if cc jump .L677 (bp);
.L635:
	SP += 52;
	RETS = [SP++];
	R0 = 0 (X);
	( r7:6, p5:4 ) = [sp++];

	rts;
.L677:
	cc =R3<=3 (iu);
	if !cc jump .L635;
	R7 = [P1+124];
	R2 = 31 (X);
	cc =R7==R2;
	I0 = R7;
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
	I1 = R3;
.L573:
	R0 = B [P1+31] (X);
	R2 = B [P1+29] (X);
	R0 = R0 | R2;
	R0 = R0.B (Z);
	cc =R0==0;
	if !cc jump .L678 (bp);
	R3 = I0;
	R6 = 15 (X);
	cc =R3<=R6 (iu);
	if !cc jump .L611;
.L608:
	P0 = [P1+68];
	P4 = 159 (X);
	cc =P0<=P4 (iu);
	if !cc jump .L679;
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
	if cc jump .L680;
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
	if cc jump .L612;
	R0 = R1 + R0;
	R0 = min(R0,R2);
	R1 = 0 (X);
	R0 = max(R0,R1);
.L613:
	[SP+16] = R0;
	R0 = I0;
	[SP+12] = R0;
	R2 = I1;
	R1 = P2;
	R0 = P1;
	call _set_lock;
.L590:
	R0 = 1 (X);
.L682:
	SP += 52;
	RETS = [SP++];
	( r7:6, p5:4 ) = [sp++];

	rts;
.L678:
	P0.H = 52;
	P0.L = 25200;
	P0 = P1 + P0;
	R0 = [P0];
	cc =R0==0;
	if !cc jump .L621;
	R0 = I0;
	R2 = 15 (X);
	cc =R0<=R2 (iu);
	if cc jump .L608 (bp);
	R0 = B [P1+28] (Z);
	cc =R0==0;
	if cc jump .L681 (bp);
	P1.H = _knob;
	P2 = P2 + (P2 << 1);
	P1.L = _knob;
	P2 = P1 + (P2 << 2);
	P5 = I1;
	P2 = P2 + P5;
.L675:
	R0 = B [P2] (Z);
	R0 = R1 + R0;
	R1 = 255 (X);
	R0 = min(R0,R1);
	R1 = 0 (X);
	R0 = max(R0,R1);
	B [P2] = R0;
	R0 = 1 (X);
	jump.s .L682;
.L567:
	R6 = 5 (X);
	cc =R0==R6;
	if cc jump 4 (bp); jump.s .L569;
	R0 = [P1+48];
	R7 = P2;
	R2 = R7 | R0;
	cc =R2<=7 (iu);
	if !cc jump .L635;
	cc =R7==R0;
	if !cc jump .L635 (bp);
	cc =R3<=3 (iu);
	if !cc jump .L635;
	R6 = 60 (X);
	R6 *= R0;
	P0 = R6;
	I2.H = _euclids;
	I2.L = _euclids;
	P4 = I2;
	P0 = P4 + P0;
	R2 = B [P0+45] (Z);
	cc =R2==0;
	if cc jump .L574 (bp);
	P5 = [P1+124];
	R3 += 8;
	I1 = R3;
	R3 = 31 (X);
	R2 = P5;
	cc =R2==R3;
	I0 = P5;
	if cc jump .L584;
	P0.H = 52;
	P0.L = 25196;
	P0 = P1 + P0;
	R0 = 0 (X);
	[P0] = R0;
	P0.H = 52;
	P0.L = 25205;
	P0 = P1 + P0;
	B [P0] = R0;
	jump.s .L573;
.L572:
	R0 = B [P1+31] (X);
	R2 = B [P1+29] (X);
	R0 = R0 | R2;
	R0 = R0.B (Z);
	cc =R0==0;
	if !cc jump .L588 (bp);
.L589:
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
.L618:
	P1 = [SP+32];
	P4 = [SP+40];
	P5 = R3;
	R0 = 1 (X);
	P2 = (P2 + P1) << 2;
	P2 = P4 + P2;
	P2 = P2 + P5;
	B [P2] = R1;
	jump.s .L682;
.L679:
	P5 = P2 + P2;
	[SP+32] = P5;
.L612:
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
	jump.s .L613;
.L685:
	cc =R0<=3;
	if !cc jump .L584 (bp);
	cc =R3==3;
	if !cc jump .L591;
.L584:
	R0 = B [P1+29] (X);
	R2 = B [P1+31] (X);
	R0 = R0 | R2;
	R0 = R0.B (Z);
	cc =R0==0;
	R3 = I1;
	if cc jump .L589 (bp);
.L588:
	P0.H = 52;
	P0.L = 25200;
	P0 = P1 + P0;
	R0 = [P0];
	cc =R0==0;
	if !cc jump .L683;
	R0 = B [P1+28] (Z);
	cc =R0==0;
	if !cc jump .L619 (bp);
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
	jump.s .L618;
.L619:
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
	if cc jump .L684 (bp);
	P0 = [SP+36];
	cc =P2==P0;
	if cc jump .L616;
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
.L617:
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
	jump.s .L618;
.L683:
	I1 = R3;
.L621:
	R1 = [P1+68];
	R6 = 159 (X);
	R0 = 1 (X);
	R3 = I1;
	cc =R1<=R6 (iu);
	R0 <<= R3;
	if cc jump .L667 (bp);
	R0 = ~R0;
.L607:
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
	jump.s .L682;
.L684:
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
	if cc jump .L672;
	P4.H = _hand;
	P4.L = _hand;
	[SP+36] = P4;
	jump.s .L617;
.L680:
	P0 = P2 + P2;
	[SP+32] = P0;
	jump.s .L612;
.L667:
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
	jump.s .L607;
.L611:
	P1.H = _knob;
	P2 = P2 + (P2 << 1);
	P1.L = _knob;
	P2 = P1 + (P2 << 2);
	P0 = I1;
	P2 = P2 + P0;
	jump.s .L675;
.L672:
	P5.H = _hand;
	P5.L = _hand;
	P0 = [SP+48];
	[SP+36] = P5;
	jump.s .L617;
.L616:
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
	jump.s .L617;
.L681:
	P1.H = _knob;
	P1.L = _knob;
	P2 = P2 + (P2 << 1);
	P2 = P1 + (P2 << 2);
	P1 = I1;
	P2 = P2 + P1;
	jump.s .L675;
.L574:
	I1 = R3;
	R6 = [P1+124];
	R2 = 31 (X);
	cc =R6==R2;
	I0 = R6;
	I1 += 4;
	if cc jump .L685;
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
	if cc jump 4 (bp); jump.s .L573;
	cc =R3==3;
	if !cc jump 4; jump.s .L573;
.L591:
	P0 = P2 << 2;
	P0 = P0 << 2;
	P1 = P0;
	P1 -= P2;
	P4 = I2;
	I3 = P0;
	P0 = P4 + (P1 << 2);
	R0 = [P0];
	cc =R0==0;
	if cc jump .L590;
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
	if cc jump .L686;
	R2 = R0 >> 3;
	R1 = R2 << 3;
	R0 = R0 - R1;
	[P1] = R0;
.L593:
	R6 = -7 (X);
	cc =R0<R6;
	if !cc jump .L687;
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
	if cc jump .L595 (bp);
	cc =R3==1;
	if cc jump .L596;
	R0 = B [P1+3] (Z);
	R2 = R0 + R2;
	cc =R2<0;
	if !cc jump .L597;
	R0 = 0 (X);
.L603:
	R3 = I3;
	R6 = P2;
	R2 = R3 - R6;
	P4 = R2;
	P5 = I1;
	P1 = P4 + P5;
	P4 = I2;
	P1 = P4 + (P1 << 2);
	B [P1+7] = R0;
.L599:
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
	if !cc jump .L604 (bp);
	B [P1+2] = R1;
.L604:
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
	if cc jump 4; jump.s .L590;
	R0 = R1;
	R0 += -1;
	B [P2+3] = R0;
	R0 = 1 (X);
	jump.s .L682;
.L595:
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
	jump.s .L599;
.L596:
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
	if !cc jump .L601 (bp);
	R0 = 1 (X);
.L602:
	R3 = I3;
	R6 = P2;
	R2 = R3 - R6;
	P4 = R2;
	P5 = I1;
	P1 = P4 + P5;
	P4 = I2;
	P1 = P4 + (P1 << 2);
	B [P1+6] = R0;
	jump.s .L599;
.L687:
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
	if cc jump .L595 (bp);
	cc =R3==1;
	if cc jump .L596;
	R0 = B [P1+3] (Z);
	R2 = R0 + R2;
.L597:
	R0 = P0;
	R0 += -1;
	R0 = min(R0,R2);
	jump.s .L603;
.L686:
	[P1] = R0;
	R2 = 0 (X);
	jump.s .L593;
.L601:
	R2 = P0;
	R0 = min(R2,R0);
	jump.s .L602;
.L569:
	R2 = 6 (X);
	cc =R0==R2;
	if cc jump 4 (bp); jump.s .L635;
	R0 = [P1+48];
	R6 = P2;
	R2 = R6 | R0;
	cc =R2<=7 (iu);
	if cc jump 4 (bp); jump.s .L635;
	cc =R6==R0;
	if cc jump 4; jump.s .L635;
	cc =R3<=3 (iu);
	if cc jump 4 (bp); jump.s .L635;
	R2 = 60 (X);
	R0 *= R2;
	P4 = R0;
	P0.H = _euclids;
	P0.L = _euclids;
	P0 = P0 + P4;
	R0 = B [P0+45] (Z);
	cc =R0==0;
	R0 = [P1+124];
	if cc jump .L579 (bp);
	R2 = 31 (X);
	cc =R0==R2;
	if cc jump .L581;
.L580:
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
.L581:
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
	if cc jump .L688;
	R2 = 255 (X);
	cc =R1<=R2;
	if cc jump .L583 (bp);
	R1 = -1 (X);
.L583:
	R0 = R0 + R3;
	P0 = R0;
	R0 = 1 (X);
	P1 = P0 + P1;
	B [P1] = R1;
	jump.s .L682;
.L688:
	R1 = 0 (X);
	jump.s .L583;
.L579:
	R6 = 31 (X);
	cc =R0==R6;
	if !cc jump .L580 (bp);
	jump.s .L581;
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
	if cc jump .L725;
	P4.H = _flashes;
	P4.L = _flashes;
	R0 = B [P4] (Z);
	cc =R0==0;
	FP = [P5+48];
	if !cc jump .L751 (bp);
.L691:
	R5 = -1 (X);
.L692:
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
.L723:
	R2 = R4;
	cc =R7==0;
	R2 += -40;
	if !cc jump .L719;
	R1 = [P5+124];
	R3 = 15 (X);
	cc =R1<=R3 (iu);
	if cc jump .L752;
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
.L707:
	R2 = 255 (X);
	R0 = min(R1,R2);
	R0 += 1;
	P0 = 84 (X);
	R3 = 0 (X);
.L722:
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
	if !cc jump .L723 (bp);
.L718:
	SP += 32;
	FP = [SP++];
	R0 = 1 (X);
	RETS = [SP++];
	( r7:4, p5:3 ) = [sp++];

	rts;
.L701:
	P0 = [SP+24];
	P1.H = _now;
	P1.L = _now;
	P0 = (P0 + FP) << 2;
	P1 = P1 + P0;
	P0 = R2;
	P1 = P1 + P0;
.L750:
	R1 = B [P1] (Z);
	R1 += 1;
	R0 = 247 (X);
	R1 = R1.L * R0.L (IS);
	R1 >>>= 8;
	R1 += 8;
.L698:
	cc =R5==0;
	if !cc jump .L717 (bp);
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
	if cc jump .L718;
	R2 = R4;
	R2 += -39;
	R4 += 1;
.L719:
	R0 = B [P4+45] (Z);
	cc =R0==0;
	P0 = P3;
	R3 = R6;
	if cc jump .L729 (bp);
	R0 = 8 (X);
.L696:
	cc =R7==2;
	if cc jump .L753;
	R2 = R2 + R0;
	R1 = [P5+124];
	R0 = 15 (X);
	cc =R1<=R0 (iu);
	if cc jump .L699;
	cc =FP<=3;
	if !cc jump .L701 (bp);
	R0 = 6 (X);
	cc =R2<=R0;
	if !cc jump .L701;
	P2 = R6;
	R1 = 8 (X);
	P2 -= FP;
	P2 = P3 + (P2 << 2);
	R0 = [P2];
	cc =R0==0;
	if cc jump .L698;
.L724:
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
	if cc jump .L754;
	R3 = 5 (X);
	cc =R2==R3;
	if cc jump .L755;
	R1 = B [P1+3] (Z);
	R2 = 255 (X);
	R2 = R1.L * R2.L (FU);
	I1 = R2;
.L713:
	R0 = R0.B (Z);
	P2 = R0;
	R2 = 0 (X);
	P0 = 31 (X);
	R0 = 0 (X);
	P1 = 32 (X);
	P2 += -1;
	LSETUP (.L715, .L759) LC1 = P1;
.L715:
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
	if !cc jump .L714 (bp);
	R0 = R0 - R1;
	BITSET (R2, 0);
.L714:
.L759:
	P0 += -1;
	R2 += 1;
	R1 = R2 << 5;
	R1 = R1 - R2;
	R1 <<= 3;
	R1 = R1 - R2;
	cc =R1<0;
	if !cc jump .L716 (bp);
	R0 = 255 (X);
	R1 = R1 + R0;
.L716:
	R1 >>>= 8;
	R1 += 8;
.L709:
	cc =R7==0;
	if cc jump .L707 (bp);
	jump.s .L698;
.L751:
	P1.H = 32770;
	P1.L = 33428;
	call (P1);
	P1.H = _flash_ms;
	P1.L = _flash_ms;
	R1 = [P1];
	R0 = R0 - R1;
	R1 = 149 (X);
	cc =R0<=R1 (iu);
	if cc jump .L726 (bp);
	R2 = 299 (X);
	cc =R0<=R2 (iu);
	if cc jump .L727 (bp);
	R3 = 449 (X);
	cc =R0<=R3 (iu);
	if cc jump .L756 (bp);
	R1 = 599 (X);
	cc =R0<=R1 (iu);
	if !cc jump .L694 (bp);
	R0 = B [P4] (Z);
	cc =R0==2;
	R5 = 0 (X);
	if cc jump .L692 (bp);
	jump.s .L694;
.L726:
	R5 = 1 (X);
	jump.s .L692;
.L753:
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
	jump.s .L750;
.L729:
	R0 = 4 (X);
	jump.s .L696;
.L717:
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
	if cc jump .L757;
	R0 = 255 (X);
	R0 = min(R1,R0);
	R0 += 1;
	R3 *= R0;
	R3 >>>= 8;
	jump.s .L722;
.L752:
	P1 = [P5+68];
	P0 = 159 (X);
	cc =P1<=P0 (iu);
	if !cc jump .L758;
.L703:
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
	if cc jump .L705;
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
	if cc jump .L705;
.L706:
	cc =FP<=3;
	if !cc jump .L704 (bp);
	R1 = R2;
	R1 += -4;
	cc =R1<=2 (iu);
	if !cc jump .L704 (bp);
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
	if cc jump .L709 (bp);
	jump.s .L724;
.L699:
	P1 = [P5+68];
	P0 = 159 (X);
	cc =P1<=P0 (iu);
	if cc jump .L703 (bp);
.L705:
	P0 = [SP+24];
	P1.H = _knob;
	P1.L = _knob;
	P0 = (P0 + FP) << 2;
	P1 = P1 + P0;
	P0 = R2;
	P1 = P1 + P0;
	R0 = B [P1] (Z);
	jump.s .L706;
.L757:
	R0 = 256 (X);
	jump.s .L722;
.L725:
	SP += 32;
	FP = [SP++];
	R0 = 0 (X);
	RETS = [SP++];
	( r7:4, p5:3 ) = [sp++];

	rts;
.L758:
	P0 = [SP+24];
	P2 = R2;
	P1.H = _knob;
	P1.L = _knob;
	P0 = (P0 + FP) << 2;
	P1 = P1 + P0;
	P1 = P1 + P2;
	R0 = B [P1] (Z);
.L704:
	R0 += 1;
	R1 = 247 (X);
	R1 = R0.L * R1.L (IS);
	R1 >>>= 8;
	R1 += 8;
	jump.s .L709;
.L727:
	R5 = 0 (X);
	jump.s .L692;
.L756:
	R0 = B [P4] (Z);
	cc =R0==2;
	if cc jump .L726;
.L694:
	R0 = 0 (X);
	B [P4] = R0;
	jump.s .L691;
.L754:
	R0 = R0.B (Z);
	R1 = 18 (X);
	R1 = R1.L * R0.L (IS);
	R1 += -35;
	R0 = R1 << 5;
	R0 = R0 - R1;
	R0 <<= 3;
	R0 = R0 - R1;
	cc =R0<0;
	if !cc jump .L711 (bp);
	R1 = 255 (X);
	R0 = R0 + R1;
.L711:
	R1 = R0 >>> 8;
	R1 += 8;
	jump.s .L709;
.L755:
	R2 = B [P1+2] (Z);
	R2 += -1;
	R1 = R2 << 8;
	R1 = R1 - R2;
	I1 = R1;
	jump.s .L713;
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
	if cc jump .L763;
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
.L762:
	R0 = B [P2] (Z);
	R1 = B [P1++] (Z);
	R0 = R0.L * R3.L (IS);
	R1 = R1.L * R7.L (IS);
	R0 = R0 + R1;
	R0 >>>= 8;
	B [P2++] = R0;
	cc =P5==P2;
	if !cc jump .L762 (bp);
	R0 = B [P0+3] (Z);
	R0 = R0.L * R3.L (IS);
	R0 >>>= 8;
	B [P0+3] = R0;
	SP += 12;
	RETS = [SP++];
	R0 = 1 (X);
	( r7:7, p5:5 ) = [sp++];

	rts;
.L763:
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
	if cc jump .L765;
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
	if cc jump .L830 (bp);
.L765:
	SP += 32;
	RETS = [SP++];
	( r7:4, p5:5 ) = [sp++];

	rts;
.L830:
	cc =R7==0;
	P1 = [P0+48];
	if cc jump .L831 (bp);
	cc =R7==2;
	if cc jump .L832;
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
	if !cc jump .L779 (bp);
	cc =R1==0;
	if cc jump .L765;
	R1 = B [P2+44] (Z);
	R0 = R0 + R1;
	P2 = R0;
	P2 += 1;
	P2 = P5 + (P2 << 2);
	R0 = B [P2+3] (Z);
	R7 = B [P2+1] (Z);
	R4 = B [P2+2] (Z);
	I2 = R0;
.L780:
	P2.H = _waiting;
	P2.L = _waiting;
	R0 = B [P2] (Z);
	cc =R0==0;
	if !cc jump .L807 (bp);
	P2.H = _beat;
	P2.L = _beat;
	R1 = [P2];
	cc =R1==-1;
	I3 = R1;
	if !cc jump .L783 (bp);
	I3 = 0 (X);
.L783:
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
	LSETUP (.L785, .L838) LC1 = P2;
.L785:
	R2 = I3;
	R2 >>= R3;
	R5 = 1 (X);
	R0 <<= 1;
	R2 = R2 & R5;
	R0 = R2 | R0;
	cc =R6<=R0 (iu);
	R1 <<= 1;
	if !cc jump .L784 (bp);
	R0 = R0 - R6;
	BITSET (R1, 0);
.L784:
.L838:
	R3 += -1;
	R3 = 0 (X);
	R6 = 31 (X);
	R0 = 0 (X);
	R5 = 1 (X);
	P2 = 32 (X);
	LSETUP (.L787, .L837) LC1 = P2;
.L787:
	R2 = R1;
	R2 >>= R6;
	R0 <<= 1;
	R2 = R2 & R5;
	R0 = R2 | R0;
	cc =R7<=R0 (iu);
	R3 <<= 1;
	if !cc jump .L786 (bp);
	R0 = R0 - R7;
	BITSET (R3, 0);
.L786:
.L837:
	R6 += -1;
	R3 *= R7;
	R3 = R1 - R3;
	[SP+24] = R3;
	jump.s .L782;
.L831:
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
	if cc jump .L765 (bp);
	P2.H = _glow;
	P2.L = _glow;
	R5.H = _spark;
	R6 = P2;
	R5.L = _spark;
	R6 += 16;
	R4 = 255 (X);
	jump.s .L770;
.L769:
	R0 = P2;
	cc =R6==R0;
	R7 += 1;
	R5 += 1;
	if cc jump .L765;
.L770:
	R0 = B [P2++] (Z);
	R1 = 23 (X);
	cc =R0<=R1 (iu);
	if cc jump .L769 (bp);
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
	jump.s .L769;
.L779:
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
	if !cc jump .L781 (bp);
	R0 += 1;
	I2 = R0;
.L781:
	cc =R1==0;
	if !cc jump .L780;
.L807:
	R5 = -1 (X);
	[SP+24] = R5;
.L782:
	P0 = I0;
	P2.H = _euclids;
	P0 -= P1;
	P2.L = _euclids;
	P2 = P2 + (P0 << 2);
	R5 = I2;
	R6 = R6 -|- R6 ||
	[SP+28] = P2 ||
	nop;
	jump.s .L797;
.L833:
	R0 = 0 (X);
	[SP+16] = R0;
	[SP+12] = R0;
	R2 = 0 (X);
.L829:
	P2.H = 32771;
	R0 = R6;
	R1 = 0 (X);
	P2.L = 54206;
	call (P2);
	R6 += 1;
	R2 = 16 (X);
	cc =R6==R2;
	R5 += 1;
	if cc jump .L765;
.L797:
	cc =R6<R7;
	if !cc jump .L833 (bp);
	cc =R5<R7;
	R0 = R5;
	if cc jump .L790;
.L791:
	R0 = R0 - R7;
	cc =R0<R7;
	if !cc jump .L791 (bp);
.L790:
	R0 = R0.L * R4.L (IS);
	cc =R0<R7;
	if cc jump .L792;
.L793:
	R0 = R0 - R7;
	cc =R0<R7;
	if !cc jump .L793 (bp);
.L792:
	cc =R0<R4;
	if cc jump .L794 (bp);
	R0 = [SP+24];
	cc =R0==R6;
	R2 = 7 (X);
	R1 = 14 (X);
	if cc jump .L809;
.L828:
	R0 = 0 (X);
.L795:
	[SP+12] = R2;
	[SP+16] = R0;
	R2 = R1;
	jump.s .L829;
.L809:
	R0 = 70 (X);
	jump.s .L795;
.L794:
	P0 = [SP+28];
	R0 = [P0];
	cc =R0==0;
	if cc jump .L796 (bp);
	R0 = [SP+24];
	cc =R0==R6;
	R2 = 80 (X);
	R1 = 170 (X);
	if !cc jump .L828 (bp);
.L811:
	R0 = 255 (X);
	jump.s .L795;
.L796:
	R1 = [SP+24];
	cc =R1==R6;
	R2 = 42 (X);
	R1 = 90 (X);
	if !cc jump .L795 (bp);
	jump.s .L811;
.L832:
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
	if cc jump .L800 (bp);
	P2.H = _waiting;
	P2.L = _waiting;
	R1 = B [P2] (Z);
	cc =R1==0;
	if !cc jump .L800 (bp);
	P2.H = _beat;
	P2.L = _beat;
	R5 = [P2];
	cc =R5==-1;
	if cc jump .L800;
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
	LSETUP (.L774, .L836) LC1 = P2;
.L774:
	R1 = R5;
	R1 >>= R3;
	R0 <<= 1;
	R1 = R1 & R4;
	R0 = R1 | R0;
	cc =R7<=R0 (iu);
	R6 <<= 1;
	if !cc jump .L773 (bp);
	R0 = R0 - R7;
	BITSET (R6, 0);
.L773:
.L836:
	R3 += -1;
	R0 = 15 (X);
	R6 = R6 & R0;
.L772:
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
	jump.s .L778;
.L835:
	P0 = R5;
	R0 = W [P0+4] (Z);
	R0 = R0 & R1;
	cc =R0==0;
	if !cc jump .L802 (bp);
	R0 = W [P0] (Z);
	R0 = R0 & R1;
	cc =R0==0;
	if !cc jump .L803 (bp);
	R0 = 8 (X);
.L775:
	cc =R2==0;
	if !cc jump .L776 (bp);
	R0 >>>= 1;
.L776:
	cc =R6==R7;
	if cc jump .L834;
	R3 = 0 (X);
.L777:
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
	if cc jump .L765;
	P1 = [SP+24];
	P0.H = _grooves;
	P0.L = _grooves;
	P2 = P0 + P1;
	R2 = B [P2] (Z);
.L778:
	R1 = 1 (X);
	R1 <<= R7;
	R0 = R1 & R4;
	cc =R0==0;
	if cc jump .L835 (bp);
	R0 = 255 (X);
	jump.s .L775;
.L802:
	R0 = 50 (X);
	jump.s .L775;
.L834:
	P1 = R5;
	R2 = W [P1] (Z);
	R1 = R2 & R1;
	cc =R1==0;
	if !cc jump .L805 (bp);
	R3 = 70 (X);
	jump.s .L777;
.L803:
	R0 = 130 (X);
	jump.s .L775;
.L805:
	R3 = 255 (X);
	jump.s .L777;
.L800:
	R6 = -1 (X);
	jump.s .L772;
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
	if cc jump .L847;
	R0 = P5;
	call _our_page;
	cc =R0==-1;
	if cc jump .L842;
	cc =R0==2;
	P2 = [P5+48];
	if cc jump .L859;
	cc =R0==1;
	if cc jump .L860;
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
.L846:
	cc =R0==0;
	if cc jump .L842 (bp);
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
.L862:
	SP += 12;
	RETS = [SP++];
	( p5:4 ) = [sp++];

	rts;
.L842:
	R0 = B [P5+28] (Z);
	cc =R0==0;
	if cc jump .L861 (bp);
.L847:
	SP += 12;
	RETS = [SP++];
	R0 = 0 (X);
	( p5:4 ) = [sp++];

	rts;
.L861:
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
	LSETUP (.L848, .L863) LC1 = P2;
.L848:
	P4 = R0;
	[P0] = R1;
	B [P1] = R2;
	R0 += 60;
	P0 = P0 + P5;
	[P4] = R1;
.L863:
	P1 += 11;
	jump.s .L847;
.L859:
	P1 = P2 + (P2 << 2);
	P1 = P2 + (P1 << 1);
	P2.H = _grooves;
	P2.L = _grooves;
	P2 = P2 + P1;
	R0 = B [P2] (Z);
	cc =R0==0;
	if cc jump .L842 (bp);
	R0 = 0 (X);
	B [P2] = R0;
	R0 = 1 (X);
	jump.s .L862;
.L860:
	R0 = P2;
	R0 <<= 4;
	P1 = R0;
	P1 -= P2;
	P2 = P1;
	P1.H = _euclids;
	P1.L = _euclids;
	P2 = P1 + (P2 << 2);
	R0 = [P2];
	jump.s .L846;
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
	.type	_jogged, @object
	.size	_jogged, 1
_jogged:
	.zero	1
	.align 4
	.type	_jog_slack, @object
	.size	_jog_slack, 4
_jog_slack:
	.zero	4
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
