.global gba_setup
gba_setup:
	push {r4-r11,r14}
	//Make sure interupts are disabled!
	ldr r0,= 0x4000210
	mov r1, #0
	str r1, [r0]
	bl gba_setup_itcm

	//setup protection regions
	//region 0	bg region		0x00000000-0xFFFFFFFF	2 << 31		r/w/x
	//region 1	io region		0x04000000-0x04FFFFFF	2 << 23		-/-/-
	//region 2 card				0x08000000-0x0FFFFFFF	2 << 26		-/-/-
	//- region 2	card region	1	0x08000000-0x0BFFFFFF	2 << 25		-/-/-
	//- region 3	card region 2	0x0C000000-0x0DFFFFFF	2 << 24		-/-/-
	//- region 4	save region		0x0E000000-0x0E00FFFF	2 << 15		-/-/-
	//region 3	oam vram region	0x06010000-0x06017FFF	2 << 14		-/-/-
	//region 4  bg vram relative to fixed oam	0x063F0000 - 0x063FFFFF	2 << 15	-/-/-
	//region 5 real card region for i-cache	0x02000000-0x023FFFFF	r/w/x
	//-region 6 exclusion region for i-cache	0x02000000-0x0203FFFF	r/w/x

	
	ldr r0,= (1 | (31 << 1) | 0)
	mcr p15, 0, r0, c6, c0, 0

	ldr r0,= (1 | (23 << 1) | 0x04000000)
	mcr p15, 0, r0, c6, c1, 0

	ldr r0,= (1 | (26 << 1) | 0x08000000)
	mcr p15, 0, r0, c6, c2, 0

	//ldr r0,= (1 | (25 << 1) | 0x08000000)
	//mcr p15, 0, r0, c6, c2, 0

	//ldr r0,= (1 | (24 << 1) | 0x0C000000)
	//mcr p15, 0, r0, c6, c3, 0
	
	//ldr r0,= (1 | (15 << 1) | 0x0E000000)
	//mcr p15, 0, r0, c6, c4, 0

	ldr r0,= (1 | (14 << 1) | 0x06010000)
	mcr p15, 0, r0, c6, c3, 0

	ldr r0,= (1 | (15 << 1) | 0x063F0000)
	mcr p15, 0, r0, c6, c4, 0

	ldr r0,= (1 | (21 << 1) | 0x02000000)
	mcr p15, 0, r0, c6, c5, 0

	ldr r0,= (1 | (14 << 1) | 0x03000000)
	mcr p15, 0, r0, c6, c6, 0

	mov r0, #0
	//mcr p15, 0, r0, c6, c5, 0
	//mcr p15, 0, r0, c6, c6, 0
	mcr p15, 0, r0, c6, c7, 0

	mov r0, #3
	orr r0, r0, #(0x33 << (4 * 5))
	mcr p15, 0, r0, c5, c0, 2
	mcr p15, 0, r0, c5, c0, 3

	//no cacheabilty
	mov r0, #0
	mcr p15, 0, r0, c2, c0, 0
	orr r0, r0, #(3 << 5)
	mcr p15, 0, r0, c2, c0, 1

	//no write buffer
	mcr p15, 0, r0, c3, c0, 0


	//Copy GBA Bios in place
	ldr r0,= bios_bin
	mov r1, #0x4000
	mov r2, #0
gba_setup_copyloop:
	ldmia r0!, {r3-r10}
	stmia r2!, {r3-r10}
	subs r1, #0x20
	bne gba_setup_copyloop

	//Setup debugging on the bottom screen
	//Set vram block C for sub bg
	ldr r0,= 0x04000242
	mov r1, #0x84
	strb r1, [r0]
	//decompress debugFont to 0x06200000
	ldr r0,= debugFont
	ldr r1,= 0x06200000
	//ldr r2,=0x1194
	//blx r2
	svc 0x120000

	ldr r0,= 0x04001000
	ldr r1,= 0x10801
	str r1, [r0]

	ldr r0,= 0x0400100E
	ldr r1,= 0x4400
	strh r1, [r0]

	ldr r0,= 0x04001030
	ldr r1,= 0x100
	strh r1, [r0]
	strh r1, [r0, #6]

	ldr r1,= 0x00
	strh r1, [r0, #2]
	strh r1, [r0, #4]

	str r1, [r0, #0xC]

	mov r0, #0
	ldr r1,= 0x06202000
	mov r2, #1024
gba_setup_fill_sub_loop:
	str r0, [r1], #4
	subs r2, #4
	bne gba_setup_fill_sub_loop

	ldr r0,= 0x06202000
	ldr r1,= 0x54534554
	str r1, [r0]

	ldr r0,= 0x05000400
	ldr r1,= 0x7FFF
	strh r1, [r0], #2
	ldr r1,= 0x0000
	strh r1, [r0]

	//map the gba cartridge to the arm7
	ldr r0,= 0x4000204
	ldrh r1, [r0]
	orr r1, #0x80
	strh r1, [r0]

	//put the dtcm at 10000000 for the abort mode stack
	ldr r0,= 0x1000000A
	mcr p15, 0, r0, c9, c1, 0

	//copy simple gba rom to 02040000
	ldr r0,= rom_bin //simpleRom
	ldr r1,= rom_bin_size //simpleRomSize
	ldr r1, [r1]
	mov r2, #0x02040000
	//Copy in reverse to prevent overwriting itself
	add r0, r1
	add r2, r1
gba_setup_copyloop_rom2:
	ldmdb r0!, {r3-r10}
	stmdb r2!, {r3-r10}
	subs r1, #0x20
	bgt gba_setup_copyloop_rom2

	//Make bios jump to 02040000
	ldr r0,= 0xE3A0E781
	ldr r1,= 0xCC
	str r0, [r1]

	//Move wram into place
	ldr r0,= 0x4000247
	mov r1, #0
	strb r1, [r0]
	//Move bg vram into place
	ldr r0,= 0x04000244
	mov r1, #0x81
	strb r1, [r0]

	ldr r0,= 0x04000245
	mov r1, #0x91
	strb r1, [r0]

	ldr r0,= 0x04000246
	mov r1, #0x99
	strb r1, [r0]

	ldr r0,= 0x04000240
	mov r1, #0x82
	strb r1, [r0]

	//map vram h to lcdc for use with eeprom shit
	ldr r0,= 0x04000248
	mov r1, #0x80
	strb r1, [r0]

	mov r0, #0 //#0xFFFFFFFF
	ldr r1,= (0x02400000 - 1536 - (32 * 1024))//0x06898000
	mov r2, #(32 * 1024)
gba_setup_fill_H_loop:
	str r0, [r1], #4
	subs r2, #4
	bne gba_setup_fill_H_loop

	ldr r0,= 0x74
	mov r1, #0
	str r1, [r0]//fix post boot redirect
	ldr r0,= 0x800
	ldr r1,= 0x4770
	strh r1, [r0]//fix sound bias hang

	//We need to get into privileged mode, misuse the undefined mode for it
	ldr r0,= gba_start_bkpt
	sub r0, #0xC	//relative to source address
	sub r0, #8	//pc + 8 compensation
	mov r1, #0xEA000000
	orr r1, r0, lsr #2
	mov r0, #0xC
	str r1, [r0]
	bkpt #0
	//Try out bios checksum
	//swi #0xD0000
	//ldr r1,= 0xBAAE187F
	//cmp r0, r1
	//ldreq r0,= 0x05000000
	//ldreq r1,= 0x3E0
	//streqh r1, [r0]
	//ldr r0,= swi_handler
	//sub r0, #8	//relative to source address
	//sub r0, #8	//pc + 8 compensation
	//mov r1, #0xEA000000
	//orr r1, r0, lsr #2
	//mov r0, #8
	//str r1, [r0]
	//swi #0
gba_setup_loop:
	b gba_setup_loop
	pop {r4-r11,pc}

//.section .itcm
//swi_handler:
//	push {r0-r12,r14}
//	ldr r0,= 0x05000000
//	ldr r1,= 0x3E0
//	strh r1, [r0]
//swi_handler_loop:
//	b swi_handler_loop
//	pop {r0-r12,r14}
//	movs pc, r14

.section .itcm
//.org 0x4000
//Jump to reset vector
gba_start_bkpt:
	//set abort exception handlers
	ldr r0,= instruction_abort_handler
	sub r0, #0xC	//relative to source address
	sub r0, #8	//pc + 8 compensation
	mov r1, #0xEA000000
	orr r1, r0, lsr #2
	mov r0, #0xC
	str r1, [r0]

	ldr r0,= data_abort_handler
	sub r0, #0x10	//relative to source address
	sub r0, #8	//pc + 8 compensation
	mov r1, #0xEA000000
	orr r1, r0, lsr #2
	mov r0, #0x10
	str r1, [r0]

	ldr r0,= undef_inst_handler
	sub r0, #0x4	//relative to source address
	sub r0, #8	//pc + 8 compensation
	mov r1, #0xEA000000
	orr r1, r0, lsr #2
	mov r0, #0x4
	str r1, [r0]

	//for debugging
	ldr r0,= irq_handler
	sub r0, #0x18	//relative to source address
	sub r0, #8	//pc + 8 compensation
	mov r1, #0xEA000000
	orr r1, r0, lsr #2
	mov r0, #0x18
	str r1, [r0]

	//set the abort mode stack
	mrs r0, cpsr
	and r0, r0, #0xE0
	orr r1, r0, #0x17
	msr cpsr_c, r1
	ldr sp,= 0x10003FFC
	orr r1, r0, #0x13
	msr cpsr_c, r1

	ldr r0,= 0x05000000
	ldr r1,= 0x3E0
	strh r1, [r0]
	mrc p15, 0, r0, c1, c0, 0
	orr r0, #(1<<15)
	orr r0, #1	//enable pu
	orr r0, #(1 << 12) //and cache
	mcr p15, 0, r0, c1, c0, 0

	//invalidate instruction cache
	mov r0, #0
	mcr p15, 0, r0, c7, c5, 0

	mov r0, #0
	bx r0

gba_setup_itcm:
	//disable the cache from within the itcm
	mrc p15, 0, r0, c1, c0, 0
	ldr r1,= (0x3004 | 1)
	bic r0, r1
	mcr p15, 0, r0, c1, c0, 0
	bx lr

instruction_abort_handler:
	sub lr, #0x5000000
	sub lr, #0x0FC0000
	subs pc, lr, #4

.global nibble_to_char
nibble_to_char:
.byte	0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46

.align 4

undef_inst_handler:
	mrc p15, 0, r0, c1, c0, 0
	bic r0, #1	//disable pu
	bic r0, #(1 << 12) //and cache
	mcr p15, 0, r0, c1, c0, 0

	ldr r0,= 0x06202000
	ldr r1,= 0x46444E55
	str r1, [r0]

	mov r0, lr
	ldr r1,= nibble_to_char
	ldr r4,= (0x06202000 + 32 * 8)
	//print address to bottom screen
	ldrb r2, [r1, r0, lsr #28]
	mov r0, r0, lsl #4
	ldrb r3, [r1, r0, lsr #28]
	mov r0, r0, lsl #4
	orr r2, r2, r3, lsl #8
	strh r2, [r4], #2

	ldrb r2, [r1, r0, lsr #28]
	mov r0, r0, lsl #4
	ldrb r3, [r1, r0, lsr #28]
	mov r0, r0, lsl #4
	orr r2, r2, r3, lsl #8
	strh r2, [r4], #2

	ldrb r2, [r1, r0, lsr #28]
	mov r0, r0, lsl #4
	ldrb r3, [r1, r0, lsr #28]
	mov r0, r0, lsl #4
	orr r2, r2, r3, lsl #8
	strh r2, [r4], #2

	ldrb r2, [r1, r0, lsr #28]
	mov r0, r0, lsl #4
	ldrb r3, [r1, r0, lsr #28]
	mov r0, r0, lsl #4
	orr r2, r2, r3, lsl #8
	strh r2, [r4], #2

undef_inst_handler_loop:
	b undef_inst_handler_loop

//inbetween to catch the current running function in usermode
irq_handler:
	STMFD   SP!, {R0-R3,R12,LR}

//	ldr r1,= nibble_to_char
//	ldr r12,= (0x06202000 + 32 * 11)
	//print address to bottom screen
//	ldrb r2, [r1, r0, lsr #28]
//	mov r0, r0, lsl #4
//	ldrb r3, [r1, r0, lsr #28]
//	mov r0, r0, lsl #4
//	orr r2, r2, r3, lsl #8
//	strh r2, [r12], #2

//	ldrb r2, [r1, r0, lsr #28]
//	mov r0, r0, lsl #4
//	ldrb r3, [r1, r0, lsr #28]
//	mov r0, r0, lsl #4
//	orr r2, r2, r3, lsl #8
//	strh r2, [r12], #2

//	ldrb r2, [r1, r0, lsr #28]
//	mov r0, r0, lsl #4
//	ldrb r3, [r1, r0, lsr #28]
//	mov r0, r0, lsl #4
//	orr r2, r2, r3, lsl #8
//	strh r2, [r12], #2

//	ldrb r2, [r1, r0, lsr #28]
//	mov r0, r0, lsl #4
//	ldrb r3, [r1, r0, lsr #28]
//	mov r0, r0, lsl #4
//	orr r2, r2, r3, lsl #8
//	strh r2, [r12], #2

//	sub r0, lr, #4
//	ldr r1,= nibble_to_char
//	ldr r12,= (0x06202000 + 32 * 10)
	//print address to bottom screen
//	ldrb r2, [r1, r0, lsr #28]
//	mov r0, r0, lsl #4
//	ldrb r3, [r1, r0, lsr #28]
//	mov r0, r0, lsl #4
//	orr r2, r2, r3, lsl #8
//	strh r2, [r12], #2

//	ldrb r2, [r1, r0, lsr #28]
//	mov r0, r0, lsl #4
//	ldrb r3, [r1, r0, lsr #28]
//	mov r0, r0, lsl #4
//	orr r2, r2, r3, lsl #8
//	strh r2, [r12], #2

//	ldrb r2, [r1, r0, lsr #28]
//	mov r0, r0, lsl #4
//	ldrb r3, [r1, r0, lsr #28]
//	mov r0, r0, lsl #4
//	orr r2, r2, r3, lsl #8
//	strh r2, [r12], #2

//	ldrb r2, [r1, r0, lsr #28]
//	mov r0, r0, lsl #4
//	ldrb r3, [r1, r0, lsr #28]
//	mov r0, r0, lsl #4
//	orr r2, r2, r3, lsl #8
//	strh r2, [r12], #2

	MOV     R0, #0x4000000
	ADR     LR, loc_138
	LDR     PC, [R0,#-4]
loc_138:
	LDMFD   SP!, {R0-R3,R12,LR}
	SUBS    PC, LR, #4

.global thumb_string
thumb_string:
	.string "Thumb"
	.byte 0

.global unk_string
unk_string:
	.string "Unk"
	.byte 0

.global ok_string
ok_string:
	.string "Ok"
	.byte 0

.global NIBBLE_LOOKUP
NIBBLE_LOOKUP:
	.byte	0, 1, 1, 2, 1, 2, 2, 3
	.byte	1, 2, 2, 3, 2, 3, 3, 4

.align 4

.global DISPCNT_copy
DISPCNT_copy:
	.word 0

.global WAITCNT_copy
WAITCNT_copy:
	.word 0

.global counter
counter:
	.word 0