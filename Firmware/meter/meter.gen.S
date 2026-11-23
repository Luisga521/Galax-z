/* made by tools/meter_build.py from meter.c: do not edit */
.file "meter.c";
	.text
	.align 4
.global _meter_frame;
.type _meter_frame, STT_FUNC;
_meter_frame:
	[--sp] = ( r7:4, p5:5 );

	P2.H = 33029;
	LINK 60;
	P2.L = 40220;
	R7 = [P2];
	cc =R7==0;
	if cc jump .L1;
	P2.H = _on;
	P2.L = _on;
	R0 = B [P2] (Z);
	cc =R0==0;
	if cc jump .L4 (bp);
	P2.H = 32770;
	P2.L = 33428;
	call (P2);
	B0 = R0;
	P2.H = _frame_ms;
	P2.L = _frame_ms;
	P1.H = _report;
	R0 = [P2];
	R1 = B0;
	P1.L = _report;
	R0 = R1 - R0;
	[P2] = R1;
	R1 = [P1+32];
	cc =R0<=R1 (iu);
	if cc jump .L5 (bp);
	[P1+32] = R0;
.L5:
	P0 = R7;
	R1 = [P1+28];
	R0 = [P0+1676];
	cc =R0<=R1 (iu);
	if cc jump .L6 (bp);
	R1 = 999 (X);
	cc =R0<=R1 (iu);
	if cc jump .L84 (bp);
.L6:
	P2.H = _meter_kills;
	P2.L = _meter_kills;
	R1 = [P2];
	P2.H = _kills_seen;
	P2.L = _kills_seen;
	R2 = [P2];
	cc =R1==R2;
	if cc jump .L7;
	R0 = [P1+24];
	[P2] = R1;
	R0 = R1 + R0;
	P2.H = _kill_ms;
	R0 = R0 - R2;
	P2.L = _kill_ms;
	R2 = B0;
	[P1+24] = R0;
	[P2] = R2;
.L7:
	P2.H = _last_ms;
	P2.L = _last_ms;
	R0 = [P2];
	R3 = B0;
	R0 = R3 - R0;
	R4 = 99 (X);
	cc =R0<=R4 (iu);
	if cc jump .L81 (bp);
	[P2] = R3;
// 77 "meter.c" 1
	CLI R1;
// 0 "" 2
	P2.H = _meter_stage;
	P2.L = _meter_stage;
	P5 = [P2];
	R0 = R0 -|- R0 ||
	R2 = [P2+4] ||
	nop;
	R4 = [P2+8];
	I0 = R2;
	[P2+8] = R0;
	I1 = P5;
	[P2+4] = R0;
	[SP+48] = P5;
	[SP+52] = R2;
	I2 = R4;
	[SP+56] = R4;
	[P2] = R0;
// 80 "meter.c" 1
	STI R1;
// 0 "" 2
// 77 "meter.c" 1
	CLI R1;
// 0 "" 2
	P2.H = _meter_total;
	P2.L = _meter_total;
	R5 = [P2];
	R6 = [P2+4];
	P5 = [P2+8];
	[SP+36] = R5;
	[P2+8] = R0;
	[SP+40] = R6;
	[P2+4] = R0;
	I3 = P5;
	[SP+44] = P5;
	[P2] = R0;
// 80 "meter.c" 1
	STI R1;
// 0 "" 2
	R3 = 34463 (Z);
	R0 = R6;
	R0 += -1;
	BITSET (R3, 16);
	cc =R0<=R3 (iu);
	if !cc jump .L81;
	R1 = 0 (X);
	R3 = 31 (X);
	R0 = 0 (X);
	P2 = 32 (X);
	LSETUP (.L12, .L95) LC1 = P2;
.L12:
	R2 = R5;
	R2 >>= R3;
	R4 = 1 (X);
	R0 <<= 1;
	R2 = R2 & R4;
	R0 = R2 | R0;
	cc =R6<=R0 (iu);
	R1 <<= 1;
	if !cc jump .L11 (bp);
	R0 = R0 - R6;
	BITSET (R1, 0);
.L11:
.L95:
	R3 += -1;
	FP.H = _total;
	R0 = I0;
	FP.L = _total;
	cc =R0==0;
	[FP] = R1;
	R2 = 0 (X);
	if cc jump .L13 (bp);
	R6 = 31 (X);
	R0 = 0 (X);
	R5 = 1 (X);
	P2 = 32 (X);
	LSETUP (.L15, .L94) LC1 = P2;
.L15:
	R3 = I1;
	R3 >>= R6;
	R3 = R3 & R5;
	R0 <<= 1;
	R0 = R3 | R0;
	R3 = I0;
	cc =R3<=R0 (iu);
	R2 <<= 1;
	if !cc jump .L14 (bp);
	R0 = R0 - R3;
	BITSET (R2, 0);
.L14:
.L94:
	R6 += -1;
.L13:
	P5.H = _stage_top;
	P2.H = _stage;
	P5.L = _stage_top;
	P2.L = _stage;
	R0 = [P5];
	R4 = I2;
	[P2] = R2;
	cc =R4<R0 (iu);
	P2.H = _top_ms;
	P2.L = _top_ms;
	if !cc jump .L16 (bp);
	R0 = [P2];
	R3 = B0;
	R0 = R3 - R0;
	R4 = 1500 (X);
	cc =R0<=R4 (iu);
	if !cc jump .L16 (bp);
.L17:
	R0 = [P1+12];
	R3 = I2;
	cc =R3<=R0 (iu);
	if cc jump .L18 (bp);
	[P1+12] = R3;
.L18:
	R0 = [P1+20];
	R4 = I3;
	cc =R0<R4 (iu);
	if !cc jump .L19 (bp);
	[P1+20] = R4;
.L19:
	R6.H = _stage_acc;
	R6.L = _stage_acc;
	P0 = R6;
	P2 = R6;
	R0 = [P1+4];
	R0 += 1;
	[P1+4] = R0;
	R0 = [P0];
	R0 = R2 + R0;
	[P2] = R0;
	P5.H = _total_acc;
	P2.H = _acc_n;
	P5.L = _total_acc;
	P2.L = _acc_n;
	R2 = [P5];
	R3 = [P2];
	R1 = R1 + R2;
	R3 += 1;
	R2 = 4095 (X);
	cc =R3<=R2 (iu);
	P0 = R0;
	[P5] = R1;
	[P2] = R3;
	if cc jump .L20 (bp);
	P5 = R6;
	P0 = P0 >> 1;
	R1 >>= 1;
	R3 >>= 1;
	[P2] = R3;
	[P5] = P0;
	P5.H = _total_acc;
	P5.L = _total_acc;
	[P5] = R1;
.L20:
	R6 = 0 (X);
	R5 = 31 (X);
	R0 = 0 (X);
	P2 = 32 (X);
	LSETUP (.L22, .L93) LC1 = P2;
.L22:
	R2 = P0;
	R2 >>= R5;
	R4 = 1 (X);
	R0 <<= 1;
	R2 = R2 & R4;
	R0 = R2 | R0;
	cc =R3<=R0 (iu);
	R6 <<= 1;
	if !cc jump .L21 (bp);
	R0 = R0 - R3;
	BITSET (R6, 0);
.L21:
.L93:
	R5 += -1;
	[P1+8] = R6;
	R5 = 31 (X);
	R6 = 0 (X);
	R0 = 0 (X);
	P2 = 32 (X);
	LSETUP (.L24, .L92) LC1 = P2;
.L24:
	R2 = R1;
	R2 >>= R5;
	R4 = 1 (X);
	R0 <<= 1;
	R2 = R2 & R4;
	R0 = R2 | R0;
	cc =R0<R3 (iu);
	R6 <<= 1;
	if cc jump .L23 (bp);
	R0 = R0 - R3;
	BITSET (R6, 0);
.L23:
.L92:
	R5 += -1;
	[P1+16] = R6;
	jump.s .L9;
.L43:
	R0 = 0 (X);
	P2.H = 32771;
	[SP+16] = R0;
	[SP+12] = R0;
	R2 = 0 (X);
	R0 = 43 (X);
	P2.L = 54206;
	call (P2);
.L4:
	FP.H = _telling;
	FP.L = _telling;
	R0 = [FP];
	cc =R0<0;
	if cc jump .L1;
	cc =R0==0;
	if !cc jump .L85;
	P2.H = _report;
	P2.L = _report;
	R0 = B [P2] (X);
	R1 = 24 (X);
.L48:
	R0 = R0.B (Z);
	R0 >>= 4;
	R0 += 1;
.L49:
	P2.H = 33180;
	P2.L = 10900;
	R2 = B [P2] (Z);
	[SP+24] = R2;
	R2 = 1 (X);
	[SP+20] = R2;
	R2 = 8192 (X);
	[SP+16] = R2;
	P2.H = 32772;
	R2 = -1 (X);
	[SP+12] = R2;
	P2.L = 8512;
	R2 = R0.B (Z);
	R0 = 0 (X);
	call (P2);
	R0 = [FP];
	R0 += 1;
	[FP] = R0;
.L1:
	SP += 60;
	FP = [SP++];
	RETS = [SP++];
	( r7:4, p5:5 ) = [sp++];

	rts;
.L85:
	P2.H = 33180;
	P2.L = 10900;
	R1 = B [P2] (Z);
	R0 += -1;
	R7 = 63 (X);
	[SP+20] = R1;
	R0 = R0 & R7;
	R1 = 1 (X);
	R0 += 24;
	[SP+16] = R1;
	P2.H = 32772;
	R1 = 8192 (X);
	[SP+12] = R1;
	R2 = -1 (X);
	R1 = R0;
	P2.L = 8632;
	R0 = 0 (X);
	call (P2);
	R2 = [FP];
	R1 = 79 (X);
	cc =R2<=R1;
	if cc jump .L47;
	R0 = -1 (X);
	[FP] = R0;
	SP += 60;
	FP = [SP++];
	RETS = [SP++];
	( r7:4, p5:5 ) = [sp++];

	rts;
.L81:
	FP.H = _total;
	FP.L = _total;
.L9:
	P0 = R7;
	P1.H = 52;
	R0.H = 52;
	P1.L = 25532;
	R0.L = 25184;
	R0 = R7 + R0;
	P1 = P0 + P1;
	R1 = ROT R0 BY 0 ||
	R0 = [P1] ||
	nop;
	cc =R0==R1;
	if cc jump .L25;
.L34:
	R5 = R5 -|- R5 ||
	R0 = [FP] ||
	nop;
	cc =R0<=R5 (iu);
	R6 = 0 (X);
	P5 = 0 (X);
	if cc jump .L51 (bp);
.L87:
	R1 = 14051 (X);
	R0 = R0 - R5;
	BITSET (R1, 17);
	cc =R0<=R1 (iu);
	if !cc jump .L52 (bp);
	R4 = R0 << 8;
	R4 = R4 - R0;
	R2 = 0 (X);
	R3 = 31 (X);
	R0 = 0 (X);
	R7 = 1 (X);
	P2 = 32 (X);
	LSETUP (.L42, .L91) LC1 = P2;
.L42:
	R1 = R4;
	R1 >>= R3;
	R1 = R1 & R7;
	R0 <<= 1;
	R0 = R1 | R0;
	R1 = 14051 (X);
	BITSET (R1, 17);
	cc =R0<=R1 (iu);
	R2 <<= 1;
	if cc jump .L41 (bp);
	R1.H = 65533;
	R1.L = 51484;
	R0 = R0 + R1;
	BITSET (R2, 0);
.L41:
.L91:
	R3 += -1;
	R1 = R2;
.L40:
	cc =R6==3;
	if cc jump .L43;
	R3 = R6;
	cc =R6==2;
	R3 += 40;
	if cc jump .L86;
	R0 = 0 (X);
.L44:
	P0.H = 32771;
	R2 = ROT R1 BY 0 ||
	[SP+16] = P5 ||
	nop;
	R1 = ROT R0 BY 0 ||
	[SP+12] = P5 ||
	nop;
	R0 = R3;
	P0.L = 54206;
	call (P0);
	R0 = 36281 (Z);
	R0 <<= 2;
	R5 = R5 + R0;
	R0 = [FP];
	cc =R0<=R5 (iu);
	R6 += 1;
	if !cc jump .L87 (bp);
.L51:
	R1 = 0 (X);
	R2 = 0 (X);
	jump.s .L40;
.L52:
	R1 = 255 (X);
	R2 = R1;
	jump.s .L40;
.L86:
	R0 = R2 >> 1;
	jump.s .L44;
.L84:
	[P1+28] = R0;
	jump.s .L6;
.L16:
	P0 = I2;
	[P5] = P0;
	P5 = B0;
	[P2] = P5;
	jump.s .L17;
.L25:
	P2.H = _kill_ms;
	P2.L = _kill_ms;
	P0 = [P2];
	P2.H = _stage;
	P2.L = _stage;
	R3 = [P2];
	R0 = 33125 (Z);
	R0 <<= 2;
	P1 = B0;
	R3 <<= 4;
	R5.H = 65531;
	R3 = R3 + R0;
	P1 -= P0;
	R6 = 0 (X);
	R2 = 31 (X);
	R0 = 0 (X);
	R7 = 1 (X);
	R5.L = 62680;
	P2 = 32 (X);
	LSETUP (.L28, .L90) LC1 = P2;
.L28:
	R1 = R3;
	R1 >>= R2;
	R1 = R1 & R7;
	R0 <<= 1;
	R0 = R1 | R0;
	R1 = 2855 (X);
	BITSET (R1, 18);
	cc =R0<=R1 (iu);
	R6 <<= 1;
	if cc jump .L27 (bp);
	R0 = R0 + R5;
	BITSET (R6, 0);
.L27:
.L90:
	R2 += -1;
	P5.H = _stage_top;
	P5.L = _stage_top;
	R7 = [P5];
	R4.H = 65531;
	R7 <<= 4;
	R2 = 0 (X);
	R3 = 31 (X);
	R0 = 0 (X);
	R5 = 1 (X);
	R4.L = 62680;
	P2 = 32 (X);
	LSETUP (.L30, .L89) LC1 = P2;
.L30:
	R1 = R7;
	R1 >>= R3;
	R1 = R1 & R5;
	R0 <<= 1;
	R0 = R1 | R0;
	R1 = 2855 (X);
	BITSET (R1, 18);
	cc =R0<=R1 (iu);
	R2 <<= 1;
	if cc jump .L29 (bp);
	R0 = R0 + R4;
	BITSET (R2, 0);
.L29:
.L89:
	R3 += -1;
	R3 = 15 (X);
	cc =R2<=R3 (iu);
	R0 = 15 (X);
	P0 = 399 (X);
	if cc R0 = R2;
	cc =P1<=P0 (iu);
	[SP+28] = R0;
	R5 = 0 (X);
	R4 = CC;
	jump.s .L39;
.L31:
	R0 = 0 (X);
	P1.H = 32771;
	[SP+16] = R0;
	[SP+12] = R0;
	R2 = 0 (X);
	R0 = R5;
	R1 = 255 (X);
	P1.L = 54206;
	call (P1);
	R5 += 1;
	R0 = 16 (X);
	cc =R5==R0;
	if cc jump .L34;
.L39:
	CC = R4;
	if cc jump .L31 (bp);
	R7 = 0 (X);
.L32:
	R3 = [SP+28];
	cc =R3==R5;
	if cc jump .L88;
.L33:
	cc =R5<R6 (iu);
	if cc jump .L36 (bp);
	P0.H = 32771;
	R0 = ROT R5 BY 0 ||
	[SP+16] = R7 ||
	nop;
	[SP+12] = R7;
	R2 = 0 (X);
	R1 = 0 (X);
	P0.L = 54206;
	call (P0);
	R5 += 1;
	R0 = 16 (X);
	cc =R5==R0;
	if cc jump .L34;
	R3 = [SP+28];
	cc =R3==R5;
	if !cc jump .L33 (bp);
.L88:
	R0 = [P5];
	cc =R0==0;
	if cc jump .L33 (bp);
	P0 = 200 (X);
	R0 = 8 (X);
	P1.H = 32771;
	[SP+12] = R0;
	[SP+16] = P0;
	R0 = R5;
	R2 = 8 (X);
	R1 = 8 (X);
	P1.L = 54206;
	call (P1);
	R5 += 1;
	R0 = 16 (X);
	cc =R5==R0;
	if !cc jump .L32 (bp);
	jump.s .L34;
.L36:
	R1 = 9 (X);
	cc =R5<=R1 (iu);
	if !cc jump .L37;
	P0.H = 32771;
	R0 = ROT R5 BY 0 ||
	[SP+16] = R7 ||
	nop;
	[SP+12] = R7;
	R2 = 160 (X);
	R1 = 0 (X);
	P0.L = 54206;
	call (P0);
	R5 += 1;
	jump.s .L32;
.L37:
	R0 = 12 (X);
	cc =R5<=R0 (iu);
	if !cc jump .L31;
	P0.H = 32771;
	R0 = ROT R5 BY 0 ||
	[SP+16] = R7 ||
	nop;
	[SP+12] = R7;
	R2 = 160 (X);
	R1 = 140 (X);
	P0.L = 54206;
	call (P0);
	R5 += 1;
	jump.s .L32;
.L47:
	R0 = R2 >>> 1;
	P0 = R0;
	P2.H = _report;
	P2.L = _report;
	R1 = R2 & R7;
	cc = !BITTST (R2,0);
	P2 = P2 + P0;
	R0 = B [P2] (X);
	R1 += 24;
	if cc jump .L48 (bp);
	R2 = 15 (X);
	R0 = R0 & R2;
	R0 += 1;
	jump.s .L49;
	.size	_meter_frame, .-_meter_frame
	.align 4
.global _meter_key;
.type _meter_key, STT_FUNC;
_meter_key:
	[--SP] = RETS;
	cc =R2==-1;
	SP += -36;
	P2 = R0;
	if !cc jump .L104 (bp);
	cc =P2==0;
	if cc jump .L104;
	R0 = B [P2+34] (Z);
	cc =R0==0;
	if cc jump .L104;
	R0 = 49 (X);
	cc =R1==R0;
	if cc jump .L109;
	R0 = 48 (X);
	cc =R1==R0;
	if cc jump .L110;
.L104:
	R0 = 0 (X);
.L96:
	SP += 36;
	RETS = [SP++];
	rts;
.L109:
	P2.H = _on;
	P2.L = _on;
	R0 = B [P2] (X);
	R1 = R0;
	R0 = R0.B (Z);
	BITTGL (R1, 0);
	cc =R0==1;
	B [P2] = R1;
	if !cc jump .L111;
	R0 = 1 (X);
	jump.s .L96;
.L110:
	P0.H = _report;
	P0.L = _report;
	P1 = P0;
	R0 = 0 (X);
	P2 = 39 (X);
	LSETUP (.L100, .L112) LC1 = P2;
.L100:
	R1 = B [P1++] (X);
.L112:
	R0 = R1 + R0;
	P2.H = _telling;
	B [P0+39] = R0;
	P2.L = _telling;
	R0 = 0 (X);
	[P2] = R0;
	R0 = 1 (X);
	jump.s .L96;
.L111:
// 77 "meter.c" 1
	CLI R1;
// 0 "" 2
	P2.H = _meter_stage;
	P2.L = _meter_stage;
	R0 = [P2];
	[SP+24] = R0;
	R0 = [P2+4];
	[SP+28] = R0;
	R0 = [P2+8];
	[SP+32] = R0;
	R0 = 0 (X);
	[P2+8] = R0;
	[P2+4] = R0;
	[P2] = R0;
// 80 "meter.c" 1
	STI R1;
// 0 "" 2
// 77 "meter.c" 1
	CLI R1;
// 0 "" 2
	P2.H = _meter_total;
	P2.L = _meter_total;
	R2 = [P2];
	[SP+12] = R2;
	R2 = [P2+4];
	[SP+16] = R2;
	R2 = [P2+8];
	[P2+8] = R0;
	[P2+4] = R0;
	[P2] = R0;
// 80 "meter.c" 1
	STI R1;
// 0 "" 2
	P2.H = _acc_n;
	P2.L = _acc_n;
	[P2] = R0;
	P2.H = _total_acc;
	P2.L = _total_acc;
	[P2] = R0;
	P2.H = _stage_acc;
	P2.L = _stage_acc;
	[P2] = R0;
	P2.H = _total;
	P2.L = _total;
	[P2] = R0;
	P2.H = _stage_top;
	P2.L = _stage_top;
	[P2] = R0;
	P2.H = _stage;
	P2.L = _stage;
	[P2] = R0;
	P2.H = _report;
	P2.L = _report;
	[P2+32] = R0;
	[P2+28] = R0;
	[P2+20] = R0;
	[P2+16] = R0;
	[P2+12] = R0;
	[P2+8] = R0;
	[P2+4] = R0;
	[P2+24] = R0;
	P2.H = _meter_kills;
	P2.L = _meter_kills;
	R0 = [P2];
	P2.H = _kills_seen;
	P2.L = _kills_seen;
	[P2] = R0;
	P2.H = 32770;
	P2.L = 33428;
	call (P2);
	P1.H = _top_ms;
	P1.L = _top_ms;
	[P1] = R0;
	P2 = R0;
	P1.H = _frame_ms;
	P1.L = _frame_ms;
	[P1] = R0;
	P1.H = _last_ms;
	P1.L = _last_ms;
	[P1] = R0;
	P1 = -10000 (X);
	P2 = P2 + P1;
	P1.H = _kill_ms;
	P1.L = _kill_ms;
	[P1] = P2;
	R0 = 1 (X);
	jump.s .L96;
	.size	_meter_key, .-_meter_key
	.text
	.align 4
	.type	_telling, @object
	.size	_telling, 4
_telling:
	.long	-1
	.align 4
	.type	_acc_n, @object
	.size	_acc_n, 4
_acc_n:
	.zero	4
	.align 4
	.type	_total_acc, @object
	.size	_total_acc, 4
_total_acc:
	.zero	4
	.align 4
	.type	_stage_acc, @object
	.size	_stage_acc, 4
_stage_acc:
	.zero	4
	.align 4
	.type	_total, @object
	.size	_total, 4
_total:
	.zero	4
	.align 4
	.type	_stage_top, @object
	.size	_stage_top, 4
_stage_top:
	.zero	4
	.align 4
	.type	_stage, @object
	.size	_stage, 4
_stage:
	.zero	4
	.align 4
	.type	_kills_seen, @object
	.size	_kills_seen, 4
_kills_seen:
	.zero	4
	.align 4
	.type	_kill_ms, @object
	.size	_kill_ms, 4
_kill_ms:
	.zero	4
	.align 4
	.type	_top_ms, @object
	.size	_top_ms, 4
_top_ms:
	.zero	4
	.align 4
	.type	_frame_ms, @object
	.size	_frame_ms, 4
_frame_ms:
	.zero	4
	.align 4
	.type	_last_ms, @object
	.size	_last_ms, 4
_last_ms:
	.zero	4
	.type	_on, @object
	.size	_on, 1
_on:
	.zero	1
.global _report;
	.align 4
	.type	_report, @object
	.size	_report, 40
_report:
	.ascii	"GZL1"
	.zero	36
.global _meter_kills;
	.align 4
	.type	_meter_kills, @object
	.size	_meter_kills, 4
_meter_kills:
	.zero	4
.global _meter_total;
	.align 4
	.type	_meter_total, @object
	.size	_meter_total, 12
_meter_total:
	.zero	12
.global _meter_stage;
	.align 4
	.type	_meter_stage, @object
	.size	_meter_stage, 12
_meter_stage:
	.zero	12
