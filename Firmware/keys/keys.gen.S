/* made by tools/keys_build.py from keys.c: do not edit */
.file "keys.c";
	.text
	.align 4
.type _let_go, STT_FUNC;
_let_go:
	[--sp] = ( r7:4, p5:3 );

	P2.H = _nwaits;
	LINK 28;
	P2.L = _nwaits;
	P4 = [P2];
	[SP+64] = R0;
	R6 = R1;
	R5 = R2;
	cc =P4<=0;
	if cc jump .L8;
	cc =R1<0;
	P3.H = _waits;
	R4 = CC;
	cc =R2<0;
	P3.L = _waits;
	R0 = CC;
	P5 = P3;
	R7 = 0 (X);
	FP = 0 (X);
	B [SP+27] = R0;
	jump.s .L7;
.L11:
	R0 = R1.B (Z);
	cc =R0==R6;
	if cc jump .L3;
.L4:
	P1 = FP + (FP << 1);
	R2 = B [P5+11] (X);
	P2 = P3 + (P1 << 2);
	B [P2+11] = R2;
	R7 += 1;
	R2 = P4;
	R0 = I2;
	cc =R2==R7;
	[P2] = R0;
	[P2+4] = P0;
	W [P2+8] = R1;
	B [P2+10] = R3;
	FP += 1;
	P5 += 12;
	if cc jump .L2;
.L7:
	R2 = [P5];
	CC = R4;
	I2 = R2;
	P0 = [P5+4];
	R1 = W [P5+8] (X);
	R3 = B [P5+10] (X);
	if !cc jump .L11 (bp);
.L3:
	R2 = B [SP+27] (Z);
	CC = R2;
	R0 = R3.B (Z);
	if cc jump .L5;
	cc =R5==R0;
	if !cc jump .L4 (bp);
.L5:
	P2 = I2;
	R2 = R2 -|- R2 ||
	[SP+12] = P2 ||
	nop;
	R1 >>= 8;
	P2.H = 32784;
	[SP+20] = R2;
	R1 = R1.B (Z);
	R2 = ROT R0 BY 0 ||
	[SP+16] = P0 ||
	nop;
	R0 = [SP+64];
	P2.L = 58716;
	call (P2);
	R7 += 1;
	R2 = P4;
	cc =R2==R7;
	P5 += 12;
	if !cc jump .L7 (bp);
.L2:
	P2.H = _nwaits;
	P2.L = _nwaits;
	[P2] = FP;
	SP += 28;
	FP = [SP++];
	RETS = [SP++];
	( r7:4, p5:3 ) = [sp++];

	rts;
.L8:
	FP = 0 (X);
	jump.s .L2;
	.size	_let_go, .-_let_go
	.align 4
.global _keys_on;
.type _keys_on, STT_FUNC;
_keys_on:
	P2 = R0;
	[--SP] = RETS;
	SP += -24;
	R3 = R1;
	P1 = R2;
	cc =P2==0;
	if cc jump .L12;
	R0 = 15 (X);
	cc =R1<=R0 (iu);
	if !cc jump .L12;
	P0 = 127 (X);
	cc =P1<=P0 (iu);
	if !cc jump .L12;
	P0.H = _nwaits;
	P0.L = _nwaits;
	R0 = [P0];
	cc =R0==0;
	if !cc jump .L22;
.L16:
	cc =R3==0;
	if !cc jump .L12 (bp);
	P0.H = 33180;
	P0.L = 11188;
	R0 = B [P0] (X);
	cc = !BITTST (R0,0);
	if cc jump .L18 (bp);
	R0 = [P2+48];
	R0 += 1;
.L17:
	P2.H = _began;
	P2.L = _began;
	P2 = P2 + P1;
	B [P2] = R0;
.L12:
	SP += 24;
	RETS = [SP++];
	rts;
.L22:
	R0 = P2;
	[SP+20] = P2;
	[SP+16] = R1;
	[SP+12] = R2;
	call _let_go;
	P2 = [SP+20];
	P1 = [SP+12];
	R3 = [SP+16];
	jump.s .L16;
.L18:
	R0 = 1 (X);
	jump.s .L17;
	.size	_keys_on, .-_keys_on
	.align 4
.global _keys_off;
.type _keys_off, STT_FUNC;
_keys_off:
	cc =R0==0;
	R0 = R1;
	R1 = R2;
	if cc jump .L24;
	R2 = 15 (X);
	cc =R0<=R2 (iu);
	if !cc jump .L24;
	R3 = 127 (X);
	cc =R1<=R3 (iu);
	if !cc jump .L24;
	cc =R0==0;
	if cc jump .L36 (bp);
	R2 = R0;
.L25:
	P0 = R0;
	P2.H = _pedal;
	P2.L = _pedal;
	P2 = P2 + P0;
	R3 = B [P2] (Z);
	cc =R3==0;
	if cc jump .L29;
	P1.H = _nwaits;
	P1.L = _nwaits;
	P2 = [P1];
	P0 = 63 (X);
	cc =P2<=P0;
	if cc jump .L37;
.L29:
	R0 = R2;
.L24:
	rts;
.L36:
	P0 = R1;
	P2.H = _began;
	P2.L = _began;
	P2 = P2 + P0;
	R2 = B [P2] (Z);
	cc =R2==0;
	if cc jump .L26 (bp);
	R3 = 0 (X);
	R2 += -1;
	B [P2] = R3;
	R3 = 15 (X);
	cc =R2<=R3;
	if cc jump .L25;
.L26:
	R2 = 0 (X);
	jump.s .L25;
.L37:
	R3 = P2;
	P0.H = _waits;
	R3 += 1;
	P0.L = _waits;
	P2 = P2 + (P2 << 1);
	R2 <<= 8;
	R0 = R0.B (Z);
	[P1] = R3;
	R0 = R0 | R2;
	P1 = P0 + (P2 << 2);
	R3 = [SP+12];
	[P1] = R3;
	W [P1+8] = R0;
	R3 = [SP+16];
	R0 = 0 (X);
	B [P1+11] = R0;
	[P1+4] = R3;
	B [P1+10] = R1;
	R0 = -1 (X);
	rts;
	.size	_keys_off, .-_keys_off
	.align 4
.global _keys_control;
.type _keys_control, STT_FUNC;
_keys_control:
	[--SP] = RETS;
	cc =R0==0;
	P2 = R1;
	SP += -16;
	R1 = R2;
	if cc jump .L48;
	P1 = 15 (X);
	cc =P2<=P1 (iu);
	if !cc jump .L48;
	R2 = 64 (X);
	cc =R1==R2;
	if cc jump .L52;
	cc =R1==1;
	if cc jump .L53;
.L48:
	SP += 16;
	RETS = [SP++];
	R0 = 0 (X);
	rts;
.L53:
	cc =P2==0;
	if !cc jump .L48 (bp);
	P2.H = 33180;
	P2.L = 11188;
	R0 = B [P2] (X);
	cc = !BITTST (R0,0);
	if cc jump .L48 (bp);
	cc = !BITTST (R0,2);
	if !cc jump .L48 (bp);
	P2.H = _wheel;
	P2.L = _wheel;
	R0 = B [P2] (Z);
	cc =R0==0;
	if !cc jump .L42 (bp);
	R2 = [SP+32];
	cc =R2==0;
	if cc jump .L42 (bp);
	P1.H = 32770;
	P1.L = 33428;
	[SP+12] = P2;
	call (P1);
	P1.H = _wheel_ms;
	P1.L = _wheel_ms;
	[P1] = R0;
	P2 = [SP+12];
.L42:
	R0 = 127 (X);
	R1 = [SP+32];
	R0 = R1 & R0;
	B [P2] = R0;
.L41:
	R0 = 1 (X);
.L54:
	SP += 16;
	RETS = [SP++];
	rts;
.L52:
	R1 = [SP+32];
	R2 = 63 (X);
	cc =R1<=R2;
	P1.H = _pedal;
	R1 = CC;
	P1.L = _pedal;
	BITTGL (R1, 0);
	P1 = P1 + P2;
	B [P1] = R1;
	R1 = [SP+32];
	cc =R1<=R2;
	if !cc jump .L41 (bp);
	R2 = -1 (X);
	R1 = P2;
	call _let_go;
	R0 = 1 (X);
	jump.s .L54;
	.size	_keys_control, .-_keys_control
	.align 4
.global _keys_bend;
.type _keys_bend, STT_FUNC;
_keys_bend:
	P2 = R0;
	P1 = 15 (X);
	cc =P2<=P1 (iu);
	if !cc jump .L55 (bp);
	R0 = R2 << 7;
	R2 = 16256 (X);
	R0 = R0 & R2;
	R2 = 127 (X);
	R1 = R1 & R2;
	P1.H = _bend;
	R0 = R0 | R1;
	P1.L = _bend;
	R1 = -8192 (X);
	P2 = P1 + (P2 << 2);
	R0 = R0 + R1;
	[P2] = R0;
.L55:
	rts;
	.size	_keys_bend, .-_keys_bend
	.align 4
.global _keys_tick;
.type _keys_tick, STT_FUNC;
_keys_tick:
	[--sp] = ( r7:7, p5:5 );

	P2.H = 33029;
	[--SP] = RETS;
	P2.L = 40220;
	P2 = [P2];
	SP += -24;
	cc =P2==0;
	if cc jump .L57;
	P1.H = 33180;
	P1.L = 11188;
	R0 = B [P1] (X);
	R3 = 1 (X);
	R2 = R0 & R3;
	cc = !BITTST (R2,0);
	R1 = R2;
	if !cc jump .L92 (bp);
	P1.H = _was_instrument;
	P1.L = _was_instrument;
	R2 = B [P1] (Z);
	R0 = R1.B (Z);
	cc =R2==R0;
	if cc jump .L93;
.L90:
	P5.H = _wheel;
	B [P1] = R1;
	R0 = 0 (X);
	P5.L = _wheel;
	P1.H = _pedal;
	P1.L = _pedal;
	B [P5] = R0;
	R0 = 0 (X);
	[P1] = R0;
	[P1+4] = R0;
	[P1+8] = R0;
	[P1+12] = R0;
	R2 = -1 (X);
	R0 = P2;
	R1 = -1 (X);
	[SP+16] = P2;
	call _let_go;
	P2 = [SP+16];
.L61:
	R3 = [P2+48];
	P2.H = _shaken;
	P2.L = _shaken;
	R1 = B [P2] (Z);
	cc =R1==0;
	if cc jump .L62 (bp);
	R0 = B [P5] (Z);
	cc =R0==0;
	R1 += -1;
	if cc jump .L63 (bp);
	cc =R3==R1;
	if cc jump .L67;
.L63:
	P1.H = _bend;
	P1.L = _bend;
	P0 = [P1];
	P1 = P0 + (P0 << 1);
	P1 = P0 + (P1 << 2);
	R0 = P1;
	R2 = P0;
	R0 <<= 5;
	R2 <<= 5;
	R0 >>>= 8;
	R0 = R0 + R2;
	R2 = -1 (X);
	R2.H = 3;
	cc =R0<=R2;
	if !cc jump .L74;
	R7 = -1 (X);
	R7 <<= 18;
	cc =R0<R7;
	if cc jump .L75;
	R0 <<= 13;
.L66:
	R2 = 0 (X);
	P1.H = 4496;
	[SP+12] = R2;
	P1.L = 0;
	R2 = ROT R0 BY 0 ||
	R0 = [P1] ||
	nop;
	P1.H = 32785;
	[SP+20] = R3;
	[SP+16] = P2;
	P1.L = 32988;
	call (P1);
	P2 = [SP+16];
	R0 = 0 (X);
	B [P2] = R0;
	R3 = [SP+20];
.L62:
	R0 = B [P5] (Z);
	cc =R0==0;
	if cc jump .L57;
.L67:
	cc =R3<=7 (iu);
	if !cc jump .L57;
	P1.H = 32770;
	P1.L = 33428;
	[SP+20] = R3;
	[SP+16] = P2;
	call (P1);
	P0.H = _wheel_ms;
	P1 = R0;
	P0.L = _wheel_ms;
	P0 = [P0];
	R3 = [SP+20];
	P2 = [SP+16];
	P1 -= P0;
	P1 = P1 + (P1 << 1);
	R0 = P1;
	P1.H = _bend;
	P1.L = _bend;
	P0 = [P1];
	R2 = R0 << 4;
	R2 = R2 - R0;
	R2 <<= 3;
	P1 = P0 + (P0 << 1);
	P1 = P0 + (P1 << 2);
	R1 = P1;
	R0 = P0;
	R1 <<= 5;
	R0 <<= 5;
	R1 >>>= 8;
	R1 = R1 + R0;
	R0 = abs R2 (V);
	R0 = R0.L (Z);
	R7 = R0;
	R0 = 32768 (Z);
	R0 = R0 - R7;
	R2 = R2.L (X);
	R0 *= R2;
	R7 = 2064 (X);
	R2 = B [P5] (Z);
	R2 = R2.L * R7.L (IS);
	R2 >>>= 4;
	R0 >>>= 13;
	R0 *= R2;
	R7 = -1 (X);
	R7.H = 3;
	R2 = R3;
	cc =R1<=R7;
	R0 >>>= 4;
	R2 += 1;
	if !cc jump .L68;
	R7 = -1 (X);
	R7 <<= 18;
	cc =R1<R7;
	if cc jump .L94;
	R1 <<= 13;
	R1 >>>= 4;
	R0 = R1 + R0;
	R1 = -1 (X);
	R1.H = 2047;
	cc =R0<=R1;
	B [P2] = R2;
	if cc jump .L70;
.L73:
	R0 = -1 (X);
	R0.H = 32767;
.L71:
	R1 = 0 (X);
	P2.H = 4496;
	[SP+12] = R1;
	P2.L = 0;
	R2 = ROT R0 BY 0 ||
	R0 = [P2] ||
	nop;
	P2.H = 32785;
	R1 = R3;
	P2.L = 32988;
	call (P2);
.L57:
	SP += 24;
	RETS = [SP++];
	( r7:7, p5:5 ) = [sp++];

	rts;
.L92:
	R0 = R0.B (Z);
	R0 >>= 2;
	R1 = R0 & R3;
	P1.H = _was_instrument;
	BITTGL (R1, 0);
	P1.L = _was_instrument;
	R2 = B [P1] (Z);
	R0 = R1.B (Z);
	cc =R2==R0;
	if !cc jump .L90 (bp);
.L93:
	P5.H = _wheel;
	P5.L = _wheel;
	jump.s .L61;
.L94:
	R1 = -1 (X);
	R1 <<= 27;
	R0 = R0 + R1;
	B [P2] = R2;
.L70:
	R2 = -1 (X);
	R2 <<= 27;
	cc =R0<R2;
	if !cc jump .L72;
	R0 = -1 (X);
	R0 <<= 31;
	jump.s .L71;
.L68:
	R1 = -1 (X);
	R1.H = 2047;
	R0 = R0 + R1;
	cc =R0<=R1;
	B [P2] = R2;
	if !cc jump .L73 (bp);
.L72:
	R0 <<= 4;
	jump.s .L71;
.L74:
	R0 = -1 (X);
	R0.H = 32767;
	jump.s .L66;
.L75:
	R0 = -1 (X);
	R0 <<= 31;
	jump.s .L66;
	.size	_keys_tick, .-_keys_tick
	.text
	.align 4
	.type	_wheel_ms, @object
	.size	_wheel_ms, 4
_wheel_ms:
	.zero	4
	.align 4
	.type	_bend, @object
	.size	_bend, 64
_bend:
	.zero	64
	.type	_was_instrument, @object
	.size	_was_instrument, 1
_was_instrument:
	.zero	1
	.type	_shaken, @object
	.size	_shaken, 1
_shaken:
	.zero	1
	.type	_wheel, @object
	.size	_wheel, 1
_wheel:
	.zero	1
	.align 4
	.type	_began, @object
	.size	_began, 128
_began:
	.zero	128
	.align 4
	.type	_pedal, @object
	.size	_pedal, 16
_pedal:
	.zero	16
	.align 4
	.type	_nwaits, @object
	.size	_nwaits, 4
_nwaits:
	.zero	4
	.align 4
	.type	_waits, @object
	.size	_waits, 768
_waits:
	.zero	768
