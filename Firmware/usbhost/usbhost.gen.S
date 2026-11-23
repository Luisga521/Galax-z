/* made by tools/usbhost_build.py from usbhost.c: do not edit */
.file "usbhost.c";
	.text
	.align 4
.type _ports, STT_FUNC;
_ports:
	P0 = R0;
	P2 = R1;
	[--SP] = RETS;
	SP += -16;
	P1 = P0 + P2;
	R0 = [P1];
	cc =R0==0;
	if cc jump .L1;
	P2 = R2;
	P0 = P0 + P2;
	R0 = [P0];
	cc =R0==0;
	if cc jump .L11;
.L1:
	SP += 16;
	RETS = [SP++];
	rts;
.L11:
	P2.H = 32768;
	[SP+12] = P0;
	R0 = 20 (X);
	P2.L = 46824;
	call (P2);
	cc =R0==0;
	R1 = ROT R0 BY 0 ||
	P0 = [SP+12] ||
	nop;
	if cc jump .L1;
	P1 = R0;
	P2 = 20 (X);
	R0 = 0 (X);
	LSETUP (.L5, .L12) LC1 = P2;
.L5:
.L12:
	B [P1++] = R0;
	P2 = R1;
	R0 = 20 (X);
	SP += 16;
	B [P2] = R0;
	R0 = 37 (X);
	B [P2+1] = R0;
	R0 = 1 (X);
	B [P2+2] = R0;
	R0 = 16 (X);
	B [P2+3] = R0;
	[P0] = R1;
	RETS = [SP++];
	rts;
	.size	_ports, .-_ports
	.align 4
.global _usb_role;
.type _usb_role, STT_FUNC;
_usb_role:
	P1 = R0;
	cc =P1==0;
	if cc jump .L13;
	P0.H = _report;
	P0.L = _report;
	R0 = B [P0+4] (X);
	R1 = R0;
	R1 += 1;
	B [P0+4] = R1;
	R1 = 7 (X);
	R0 = R0 & R1;
	R0 += 4;
	R0 = R0.B (Z);
	P2 = R0;
	P1 += 12;
	P2 = P0 + (P2 << 2);
	P0 = 4 (X);
	LSETUP (.L15, .L20) LC1 = P0;
.L15:
	R0 = B [P1++] (X);
.L20:
	B [P2++] = R0;
.L13:
	rts;
	.size	_usb_role, .-_usb_role
	.align 4
.global _usb_new;
.type _usb_new, STT_FUNC;
_usb_new:
	P2.H = _report;
	P2.L = _report;
	R0 = B [P2+5] (X);
	R0 += 1;
	B [P2+5] = R0;
	P1.H = 33024;
	R0 = 0 (X);
	W [P2+14] = R0;
	W [P2+12] = R0;
	P1.L = 18652;
	R0 = B [P1] (X);
	B [P2+10] = R0;
	P2.H = _fold;
	P2.L = _fold;
	R0 = 0 (X);
	B [P2] = R0;
	rts;
	.size	_usb_new, .-_usb_new
	.align 4
.global _usb_started;
.type _usb_started, STT_FUNC;
_usb_started:
	P1.H = _report;
	P1.L = _report;
	cc =R0==0;
	[--sp] = ( p5:4 );

	R2 = R0;
	B [P1+48] = R1;
	if cc jump .L22;
	P0 = R0;
	P2 = R2;
	P5 = P1;
	P5 += 52;
	R0 = B [P0] (X);
	P0 = 92 (X);
	P0 = P2 + P0;
	B [P1+49] = R0;
	P2 = 18 (X);
	LSETUP (.L24, .L43) LC1 = P2;
.L24:
	R0 = B [P0++] (X);
.L43:
	B [P5++] = R0;
	P4 = R2;
	R0 = 0 (X);
	W [P1+70] = R0;
	P5 = [P4+120];
	P2 = [P4+116];
	cc =P5==0;
	if cc jump .L22;
	R0 = [P5];
	cc =R0==0;
	if cc jump .L22;
	cc =P2==0;
	if cc jump .L22;
	R0 = W [P2+2] (X);
	P0 = 72 (X);
	W [P1+70] = R0;
	R2 = R0.L (Z);
	P1 = P1 + P0;
	R0 = 0 (X);
	P2 = 256 (X);
	LSETUP (.L26, .L42) LC1 = P2;
.L26:
	cc =R2<=R0 (iu);
	if cc jump .L27 (bp);
	P4 = R0;
	P0 = [P5];
	P0 = P0 + P4;
	R1 = B [P0] (X);
.L25:
	B [P1++] = R1;
.L42:
	R0 += 1;
.L22:
	( p5:4 ) = [sp++];

	rts;
.L27:
	R1 = 0 (X);
	jump.s .L25;
	.size	_usb_started, .-_usb_started
	.align 4
.global _usb_adopt;
.type _usb_adopt, STT_FUNC;
_usb_adopt:
	cc =R0==0;
	[--sp] = ( r7:6, p5:5 );

	R2 = R0;
	P2 = R1;
	if cc jump .L44;
	P0 = R0;
	P1 = [P0+116];
	cc =P1==0;
	if cc jump .L44;
	R0 = B [P1+4] (Z);
	cc =R0<=R1 (iu);
	if cc jump .L44;
	R1 = [P1+12];
	cc =R1==0;
	if cc jump .L44;
	P2 = P2 + (P2 << 1);
	R0 = P2;
	R0 <<= 3;
	R0 = R1 + R0;
	P2 = R0;
	P0 = [P2];
	cc =P0==0;
	if cc jump .L44;
	P2 = [P2+8];
	R0 = P2;
	R0 += -1;
	cc =R0<=7 (iu);
	if !cc jump .L44;
	R3.H = _report;
	R3.L = _report;
	P1 = R3;
	P2 = P2 + (P2 << 1);
	R1 = P2;
	R1 <<= 3;
	R1 += -24;
	R0 = B [P1+6] (X);
	R0 += 1;
	B [P1+6] = R0;
	R0 = B [P0+5] (X);
	B [P1+50] = R0;
	R0 = B [P0+6] (X);
	B [P1+51] = R0;
	R0.H = 2730;
	R0.L = 43691;
	R1 >>= 3;
	R1 *= R0;
	R0 = -1 (X);
	R0.H = 8191;
	R1 = R1 & R0;
	I2 = 0 (X);
	R1 += 1;
	LC0 = R1;
	LSETUP (.L58, .L101) LC0;
.L58:
	R0 = B [P0+5] (Z);
	R6 = 255 (X);
	cc =R0==R6;
	if !cc jump .L48 (bp);
	R0 = B [P0] (Z);
	R7 = 8 (X);
	cc =R0<=R7 (iu);
	if cc jump .L48;
	R0 = B [P0+4] (Z);
	cc =R0<=R7;
	if !cc jump .L48;
	P1 = [P0+12];
	R6 = P1;
	cc =R6==0;
	B1 = P1;
	if cc jump .L48;
	cc =R0==0;
	if cc jump .L48;
	R0 <<= 4;
	M0 = R0;
	R0 += -16;
	R0 >>= 4;
	I1 = P1;
	B0 = P1;
	P2 = P1;
	P1 = R0;
	I1 += M0;
	B2 = 0 (X);
	M0 = 0 (X);
	B3 = 0 (X);
	P1 += 1;
	LSETUP (.L51, .L100) LC1 = P1;
.L51:
	R0 = B [P2+3] (X);
	R6 = 3 (X);
	R0 = R0 & R6;
	R0 = R0.B (Z);
	R0 += -2;
	cc =R0<=1 (iu);
	if !cc jump .L49;
	R7 = B [P2+2] (X);
	cc =R7<0;
	R0 = [P2+8];
	if cc jump .L97;
	B2 = 1 (X);
.L50:
	cc =R0==0;
	if cc jump .L49;
	R6 = [P2+12];
	cc =R6<=3;
	if cc jump .L49 (bp);
	P5 = R0;
	R6 = 37 (X);
	R7 = B [P5+1] (Z);
	cc =R7==R6;
	if !cc jump .L49 (bp);
	R0 = B [P5+2] (Z);
	cc =R0==1;
	R7 = M0;
	R0 = CC;
	R7 = R7 | R0;
	M0 = R7;
.L49:
.L100:
	P2 += 16;
	R0 = B3;
	cc =R0==0;
	if cc jump .L48;
	R6 = B2;
	cc =R6==0;
	if cc jump .L48;
	R7 = M0;
	cc =R7==0;
	if !cc jump .L52 (bp);
	P2 = [P0+16];
	cc =P2==0;
	if cc jump .L48;
	P1 = [P0+20];
	cc =P1<=2;
	if cc jump .L48;
	P5 = R2;
	R6 = 1177 (X);
	R0 = W [P5+100] (Z);
	cc =R0==R6;
	R6 = CC;
	B2 = R6;
	R6 = 1410 (X);
	cc =R0==R6;
	R6 = CC;
	B3 = R6;
	jump.s .L53;
.L54:
	P5 = R0;
	P1 -= P5;
	cc =P1<=2;
	P2 = P2 + P5;
	if cc jump .L48;
.L53:
	R0 = B [P2] (Z);
	cc =R0<=2 (iu);
	if cc jump .L48;
	R6 = P1;
	cc =R0<=R6;
	if !cc jump .L48;
	R7 = B [P2+1] (Z);
	R6 = 36 (X);
	cc =R7==R6;
	if !cc jump .L54 (bp);
	R6 = B2;
	CC = R6;
	if cc jump .L98;
	R6 = B3;
	CC = R6;
	if !cc jump .L54;
	R7 = B [P2+2] (Z);
	R6 = 241 (X);
	cc =R7==R6;
	if !cc jump .L54 (bp);
	cc =R0<=5 (iu);
	if cc jump .L54 (bp);
	R7 = B [P2+3] (Z);
	cc =R7==2;
	if !cc jump .L54 (bp);
.L52:
	R0 = 1 (X);
	B [P0+5] = R0;
	R0 = 3 (X);
	B [P0+6] = R0;
	R0 = 0 (X);
	B [P0+7] = R0;
	R7 = I1;
	R0 = 0 (X);
	R6 = B1;
	[P0+20] = R0;
	R0 = R7 - R6;
	R0 += -16;
	R0 >>= 4;
	P2 = R0;
	P1 = 0 (X);
	P2 += 1;
	LSETUP (.L57, .L99) LC1 = P2;
.L57:
	P5 = B0;
	[P5+12] = P1;
	P5 += 16;
.L99:
	B0 = P5;
	P1 = R3;
	I2 = 1 (X);
	R0 = B [P1+7] (X);
	R0 += 1;
	B [P1+7] = R0;
.L48:
.L101:
	P0 += 24;
	R0 = I2;
	cc = !BITTST (R0,0);
	if cc jump .L44;
	P2.H = _fold;
	P2.L = _fold;
	R0 = 1 (X);
	B [P2] = R0;
.L44:
	( r7:6, p5:5 ) = [sp++];

	rts;
.L97:
	B3 = 1 (X);
	jump.s .L50;
.L98:
	R7 = B [P2+2] (X);
	I3 = R7;
	M0 = -2 (X);
	I3 += M0;
	R6 = I3;
	R6 = R6.B (Z);
	cc =R6<=1 (iu);
	if !cc jump .L54 (bp);
	jump.s .L52;
	.size	_usb_adopt, .-_usb_adopt
	.align 4
.global _usb_endpoints;
.type _usb_endpoints, STT_FUNC;
_usb_endpoints:
	P1 = R0;
	P2.H = _report;
	[--sp] = ( p5:5 );

	P2.L = _report;
	[--SP] = RETS;
	R0 = R1;
	cc =P1==0;
	R1 = B [P2+8] (X);
	SP += -12;
	R1 += 1;
	if cc jump .L103;
	cc =R0==0;
	if !cc jump .L103 (bp);
	P5 = [P1+96];
	R0 = 0 (X);
	B [P2+8] = R1;
	B [P2+9] = R0;
	cc =P5==0;
	if cc jump .L107;
	R2 = 264 (X);
	R1 = 260 (X);
	R0 = P5;
	call _ports;
	R0 = P5;
	R2 = 272 (X);
	R1 = 268 (X);
	call _ports;
	R0 = [P5+260];
	cc =R0==0;
	if cc jump .L107;
	R0 = [P5+264];
	SP += 12;
	cc =R0==0;
	RETS = [SP++];
	R0 = CC;
	R0 = -R0;
	( p5:5 ) = [sp++];

	rts;
.L103:
	SP += 12;
	R2 = R0 << 8;
	R1 = R1.B (Z);
	RETS = [SP++];
	R1 = R1 | R2;
	W [P2+8] = R1;
	( p5:5 ) = [sp++];

	rts;
.L107:
	SP += 12;
	RETS = [SP++];
	R0 = 0 (X);
	( p5:5 ) = [sp++];

	rts;
	.size	_usb_endpoints, .-_usb_endpoints
	.align 4
.global _usb_tidy;
.type _usb_tidy, STT_FUNC;
_usb_tidy:
	cc =R0==0;
	[--sp] = ( r7:7, p5:5 );

	I0 = R0;
	R2 = R1;
	if cc jump .L115;
	cc =R1<=0;
	if cc jump .L115;
	R1 = 3 (X);
	R1 = R2 & R1;
	cc =R1==0;
	if !cc jump .L115;
	P1.H = _report;
	P1.L = _report;
	R7 = W [P1+12] (X);
	P2 = 328 (X);
	R0 = R7.L (Z);
	P1 = P1 + P2;
	I2 = R7;
	I3 = R0;
	R3 = 0 (X);
	B1 = P1;
	P0 = 8 (X);
	LSETUP (.L121, .L150) LC0 = P0;
.L121:
	R7 = I3;
	R0 = R3 >>> 2;
	R0 = R0 + R7;
	R7 = 7 (X);
	cc =R0<=R7;
	if cc jump .L116;
.L120:
	R3 += 4;
	cc =R2<=R3;
	if cc jump .L118;
.L150:
	nop;
.L118:
	R0 = I2;
	P1.H = _report;
	P1.L = _report;
	R0 += 1;
	W [P1+12] = R0;
	R0 = W [P1+14] (X);
	R0 = R2 + R0;
	W [P1+14] = R0;
	P1.H = _fold;
	P1.L = _fold;
	R0 = B [P1] (Z);
	cc =R0==0;
	P2 = I0;
	R7 = CC;
	P2 += 4;
	R3 = 0 (X);
	I2 = R7;
	jump.s .L130;
.L127:
	R7 = 15 (X);
	R7 = R0 & R7;
	B [P2+-4] = R7;
	R7 = 14 (X);
	R0 = R0 & R7;
	R0 = R0.B (Z);
	cc =R0==0;
	if cc jump .L146;
	cc =R3==R1;
	if !cc jump .L147;
.L128:
	R1 += 4;
	cc =R2<=R1;
	R3 += 4;
	P2 += 4;
	if cc jump .L133;
.L130:
	R7 = I2;
	CC = R7;
	R0 = B [P2+-4] (X);
	if !cc jump .L127 (bp);
	R0 = R0.B (Z);
	R7 = R0 >> 4;
	cc =R7==0;
	if cc jump .L125;
.L144:
	R1 += 4;
	cc =R1<R2;
	if !cc jump .L133;
	R0 = B [P2] (X);
	R0 = R0.B (Z);
	R7 = R0 >> 4;
	cc =R7==0;
	P2 += 4;
	if !cc jump .L144 (bp);
.L125:
	cc =R0<=1 (iu);
	if cc jump .L144;
	cc =R3==R1;
	if cc jump .L128 (bp);
.L147:
	P5 = R1;
	P1 = I0;
	R7 = I0;
	R0 = R7 + R3;
	P0 = P1 + P5;
	P1 = P2;
	P1 -= P0;
	LSETUP (.L129, .L149) LC1 = P1;
.L129:
	P5 = R0;
	R7 = B [P0++] (X);
	B [P5++] = R7;
.L149:
	R0 = P5;
	R1 += 4;
	cc =R2<=R1;
	R3 += 4;
	P2 += 4;
	if !cc jump .L130 (bp);
.L133:
	R2 = R3;
.L115:
	R0 = R2;
	( r7:7, p5:5 ) = [sp++];

	rts;
.L116:
	R0 = R0.L (Z);
	P2 = R0;
	P1 = B1;
	R7 = I0;
	R0 = R7 + R3;
	P2 = P1 + (P2 << 2);
	P1 = 4 (X);
	LSETUP (.L119, .L148) LC1 = P1;
.L119:
	P5 = R0;
	R7 = B [P5++] (X);
	R0 = P5;
.L148:
	B [P2++] = R7;
	jump.s .L120;
.L146:
	R1 += 4;
	cc =R1<R2;
	if !cc jump .L133;
	P2 += 4;
	R0 = B [P2+-4] (X);
	jump.s .L127;
	.size	_usb_tidy, .-_usb_tidy
	.align 4
.global _host_key;
.type _host_key, STT_FUNC;
_host_key:
	[--sp] = ( p5:4 );

	[--SP] = RETS;
	cc =R2==-1;
	SP += -40;
	R3 = R1;
	if !cc jump .L163 (bp);
	cc =R0==0;
	if cc jump .L163;
	P0 = R0;
	R1 = B [P0+34] (Z);
	cc =R1==0;
	if cc jump .L163;
	R1 = 5 (X);
	cc =R3==R1;
	if cc jump .L167;
	R0 = 6 (X);
	cc =R3==R0;
	if cc jump .L168;
.L163:
	R0 = 0 (X);
.L151:
	SP += 40;
	RETS = [SP++];
	( p5:4 ) = [sp++];

	rts;
.L168:
	P0.H = _report;
	P0.L = _report;
	P1 = P0;
	R0 = 0 (X);
	P2 = 361 (X);
	LSETUP (.L159, .L171) LC1 = P2;
.L159:
	R1 = B [P1++] (X);
.L171:
	R0 = R1 + R0;
	P2.H = _telling;
	B [P0+361] = R0;
	P2.L = _telling;
	R0 = 0 (X);
	[P2] = R0;
	R0 = 1 (X);
	jump.s .L151;
.L167:
	P0.H = _instrument;
	P0.L = _instrument;
	R1 = B [P0] (Z);
	cc =R1==0;
	if !cc jump .L169;
	P2 = R0;
	P1 = [P2+1676];
	cc =P1<=0;
	if cc jump .L156;
	R1 = 292 (X);
	R1 = R0 + R1;
	P2 = R1;
	R3 = 0 (X);
	jump.s .L158;
.L170:
	R1 = 50 (X);
	cc =R3==R1;
	P2 += 28;
	if cc jump .L156;
.L158:
	R0 = B [P2] (Z);
	R1 = 15 (X);
	cc =R0<=R1 (iu);
	if !cc jump .L157 (bp);
	R1 = B [P2+2] (X);
	R2 = R1.B (X);
	cc =R2<0;
	if cc jump .L157 (bp);
	P4 = R0;
	P5.H = 33180;
	P5.L = 10900;
	R1 = R1.B (Z);
	P0 = P4 + P5;
	R2 = B [P0] (Z);
	[SP+20] = R2;
	R2 = 1 (X);
	[SP+16] = R2;
	P0.H = 32772;
	R2 = 8192 (X);
	[SP+12] = R2;
	[SP+32] = R3;
	[SP+36] = P1;
	[SP+28] = P2;
	R2 = -1 (X);
	P0.L = 8632;
	call (P0);
	P2 = [SP+28];
	P1 = [SP+36];
	R3 = [SP+32];
.L157:
	R3 += 1;
	R0 = P1;
	cc =R0==R3;
	if !cc jump .L170 (bp);
.L156:
	P2.H = 33180;
	P2.L = 11188;
	P1.H = _before;
	R0 = B [P2] (X);
	R1 = -88 (X);
	P1.L = _before;
	B [P1] = R0;
	R0 = R0 & R1;
	R1 = 3 (X);
	R0 = R0 | R1;
	P0.H = _instrument;
	B [P2] = R0;
	P0.L = _instrument;
	R0 = 1 (X);
	B [P0] = R0;
	R0 = 0 (X);
	[SP+24] = R0;
	[SP+20] = R0;
	R1 = 47 (X);
.L166:
	P2.H = 33025;
	[SP+16] = R1;
	[SP+12] = R0;
	P2.L = 24220;
	R0 = [P2];
	P2.H = 32771;
	R2 = 600 (X);
	R1 = 3 (X);
	P2.L = 50700;
	call (P2);
	R0 = 1 (X);
	jump.s .L151;
.L169:
	P2.H = 33180;
	P2.L = 11188;
	P1.H = _before;
	R0 = B [P2] (X);
	R1 = -88 (X);
	P1.L = _before;
	R0 = R0 & R1;
	R2 = 87 (X);
	R1 = B [P1] (X);
	R1 = R1 & R2;
	R0 = R0 | R1;
	B [P2] = R0;
	R0 = 0 (X);
	B [P0] = R0;
	R0 = 0 (X);
	[SP+24] = R0;
	[SP+20] = R0;
	R1 = 31 (X);
	jump.s .L166;
	.size	_host_key, .-_host_key
	.align 4
.global _host_tick;
.type _host_tick, STT_FUNC;
_host_tick:
	P2.H = _telling;
	[--SP] = RETS;
	P2.L = _telling;
	R0 = [P2];
	cc =R0<0;
	SP += -32;
	if cc jump .L172;
	cc =R0==0;
	if !cc jump .L181;
	P1.H = _report;
	P1.L = _report;
	R0 = B [P1] (X);
	R1 = 24 (X);
.L176:
	R0 = R0.B (Z);
	R0 >>= 4;
	R0 += 1;
.L177:
	P1.H = 33180;
	P1.L = 10900;
	R2 = B [P1] (Z);
	[SP+24] = R2;
	R2 = 1 (X);
	[SP+20] = R2;
	R2 = 8192 (X);
	[SP+16] = R2;
	P1.H = 32772;
	R2 = -1 (X);
	[SP+12] = R2;
	[SP+28] = P2;
	R2 = R0.B (Z);
	P1.L = 8512;
	R0 = 0 (X);
	call (P1);
	P2 = [SP+28];
	R0 = [P2];
	R0 += 1;
	[P2] = R0;
.L172:
	SP += 32;
	RETS = [SP++];
	rts;
.L181:
	P1.H = 33180;
	R1 = 63 (X);
	P1.L = 10900;
	R0 += -1;
	R0 = R0 & R1;
	R1 = B [P1] (Z);
	[SP+20] = R1;
	R1 = 1 (X);
	R0 += 24;
	[SP+16] = R1;
	P1.H = 32772;
	R1 = 8192 (X);
	[SP+12] = R1;
	R2 = -1 (X);
	R1 = ROT R0 BY 0 ||
	[SP+28] = P2 ||
	nop;
	R0 = 0 (X);
	P1.L = 8632;
	call (P1);
	P2 = [SP+28];
	R3 = 723 (X);
	R2 = [P2];
	cc =R2<=R3;
	if cc jump .L175;
	R0 = -1 (X);
	[P2] = R0;
	SP += 32;
	RETS = [SP++];
	rts;
.L175:
	R0 = R2 >>> 1;
	P0 = R0;
	P1.H = _report;
	P1.L = _report;
	R3 = 63 (X);
	R1 = R2 & R3;
	P1 = P1 + P0;
	cc = !BITTST (R2,0);
	R0 = B [P1] (X);
	R1 += 24;
	if cc jump .L176 (bp);
	R2 = 15 (X);
	R0 = R0 & R2;
	R0 += 1;
	jump.s .L177;
	.size	_host_tick, .-_host_tick
	.text
	.align 4
	.type	_telling, @object
	.size	_telling, 4
_telling:
	.long	-1
	.type	_before, @object
	.size	_before, 1
_before:
	.zero	1
	.type	_instrument, @object
	.size	_instrument, 1
_instrument:
	.zero	1
	.type	_fold, @object
	.size	_fold, 1
_fold:
	.zero	1
.global _report;
	.align 2
	.type	_report, @object
	.size	_report, 362
_report:
	.ascii	"GZU1"
	.zero	358
