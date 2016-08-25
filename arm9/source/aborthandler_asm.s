.section .itcm

//data_abort_handler_new:
//	push {lr}
//	mrs lr, spsr
//	tst lr, #0x20 //thumb bit
//	bne data_abort_handler_new_thumb
//data_abort_handler_new_arm:
//	ldr lr, [sp]
//	ldr lr, [lr]
//	and lr, lr, #(7 << 25)
//	add pc, lr, lsr #23

	//since pc points to pc+8, use 2 nops padding
//	nop
//	nop
//	b data_abort_handler_new_arm_half_load_store
//	b data_abort_handler_new_arm_unk
//	b data_abort_handler_new_arm_single_load_store
//	b data_abort_handler_new_arm_single_load_store
//	b data_abort_handler_new_arm_block_load_store
//	b data_abort_handler_new_arm_unk
//	b data_abort_handler_new_arm_unk
//	b data_abort_handler_new_arm_unk

//data_abort_handler_new_arm_half_load_store:
//	pop {lr}
//	b data_abort_handler
	
//data_abort_handler_new_arm_single_load_store:
	//change the instruction to quickly get the address with the processor
//	ldr lr, [sp]
//	ldr lr, [lr]
//	bic lr, lr, #0xF0000000 //condition
//	bic lr, lr, #0x0000F000 //dst register
//	tst lr, #(1 << 24)
//	biceq lr, lr, #0xFFF00FFF //#0xF3000FFF is enough
//	orreq lr, lr, #0x05000000
//	orr lr, lr, #0xE0000000 //condition
//	orr lr, lr, #0x00300000 //writeback and load
//	str lr, [pc, #0x28]
//	mov lr, lr, lsr #16
//	and lr, lr, #0xF
//	orr lr, lr, #0xE1000000
//	orr lr, lr, #0x00A00000	//mov r0, rb
//	str lr, [pc, #0x20]

//	push {r0-r2}
//	mrs lr, spsr
//	ands lr, lr, #0xF
//	moveq lr, #0xF
//	orr lr, lr, #0x90
//	msr cpsr_c, lr
//	nop //move instruction here
//	nop //move instruction here
//	nop	//load instruction will be placed here
//	nop //move instruction will be placed here
//	msr cpsr_c, #0x97
	//address is in r0 now
//	mov lr, r0, lsr #24
//	cmp lr, #0xE

//	pop {r0-r2}

//data_abort_handler_new_arm_block_load_store:
//	pop {lr}
//	b data_abort_handler

//data_abort_handler_new_arm_unk:
//	pop {lr}
//	b data_abort_handler
	//b data_abort_handler_new_arm_unk


//data_abort_handler_new_thumb:
//	pop {lr}

reg_table = 0x10000000

.global data_abort_handler
data_abort_handler:
	push {lr}
	mrs lr, spsr
	tst lr, #0x20 //thumb bit
	bne data_abort_handler_thumb
data_abort_handler_arm:
	ldr lr,= reg_table
	stmia lr!, {r0-r12}	//non-banked registers
	mov r12, lr
	mrs lr, spsr
	ands lr, lr, #0xF
	cmpne lr, #0xF
	stmeqia r12, {sp,lr}^	//read user bank registers
	beq data_abort_handler_cont
	orr lr, lr, #0x90
	msr cpsr_c, lr
	stmia r12, {sp,lr}
	msr cpsr_c, #0x97

data_abort_handler_cont:
	pop {r5}	//lr
	ldr r1,= reg_table

	mrc p15, 0, r6, c1, c0, 0
	bic r2, r6, #(1 | (1 << 2))	//disable pu and data cache
	bic r2, #(1 << 12) //and cache
	mcr p15, 0, r2, c1, c0, 0

	ldr r0, [r5, #-8]
	and r0, r0, #0x0FFFFFFF

	and r8, r0, #(0xF << 16)
	ldr r9, [r1, r8, lsr #14]

	mov r2, r0, lsr #25
	add pc, r2, lsl #2

	nop
	b ldrh_strh_address_calc
	b address_calc_unknown
	b ldr_str_address_calc
	b ldr_str_address_calc
	b ldm_stm_address_calc
	b address_calc_unknown
	b address_calc_unknown
	b address_calc_unknown

.global data_abort_handler_cont_finish
data_abort_handler_cont_finish:
	mcr p15, 0, r6, c1, c0, 0

	push {r5}	//lr
	ldr r12,= (reg_table + (4 * 13))
	mrs lr, spsr
	ands lr, lr, #0xF
	cmpne lr, #0xF
	ldmeqia r12, {sp,lr}^	//write user bank registers
	beq data_abort_handler_cont2
	orr lr, lr, #0x90
	msr cpsr_c, lr
	ldmia r12, {sp,lr}
	msr cpsr_c, #0x97
	
data_abort_handler_cont2:
	ldr lr,= reg_table
	ldmia lr, {r0-r12}	//non-banked registers
	pop {lr}

	subs pc, lr, #8

data_abort_handler_thumb:
	ldr lr,= reg_table
	stmia lr, {r0-r7}	//non-banked registers
	pop {r5}	//lr
	ldr r1,= reg_table
	//sub r0, r5, #8

	mrc p15, 0, r6, c1, c0, 0
	bic r2, r6, #(1 | (1 << 2))	//disable pu and data cache
	bic r2, #(1 << 12) //and cache
	mcr p15, 0, r2, c1, c0, 0
	
	ldrh r0, [r5, #-8]
	mov r2, r0, lsr #13
	mov r7, sp
	msr cpsr_c, #0x91
	mov sp, r7
	add pc, r2, lsl #2

	nop

	b address_calc_unknown
	b address_calc_unknown
	b thumb7_8_address_calc
	b thumb9_address_calc
	b thumb10_address_calc
	b address_calc_unknown
	b thumb15_address_calc
	b address_calc_unknown

.global data_abort_handler_thumb_finish
data_abort_handler_thumb_finish:
	msr cpsr_c, #0x97
	mcr p15, 0, r6, c1, c0, 0

	//cmp r0, #0
	//addeq lr, r5, #2
	//movne lr, r5
	mov lr, r5

	ldr r5,= reg_table
	ldmia r5, {r0-r7}	//non-banked registers

	subs pc, lr, #8

address_calc_unknown:
	b address_calc_unknown


.global count_bits_initialize
count_bits_initialize:
	ldr r0,= 0x10000040
	mov r1, #0
count_bits_initialize_loop:
	and	r3, r1, #0xAA
	sub	r2, r1, r3, lsr #1
		
	and	r3, r2, #0xCC
	and	r2, r2, #0x33
	add	r2, r2, r3, lsr #2
		
	add	r2, r2, r2, lsr #4
	and	r2, r2, #0xF
	strb r2, [r0], #1
	add r1, r1, #1
	cmp r1, #0x100
	bne count_bits_initialize_loop
	bx lr

count_bits_set_16_lookup:
	ldr r2,= 0x10000040
	and r1, r0, #0xFF
	ldrb r1, [r2, r1]
	ldrb r0, [r2, r0, lsr #8]
	add r0, r0, r1
	bx lr

count_bits_set_8_lookup:
	ldr r1,= 0x10000040
	ldrb r0, [r1, r0]
	bx lr

//count_bits_set_16:
//	mov	r2, #0xff
//	eor	r2, r2, r2, lsl #4
//	eor	r3, r2, r2, lsl #2
//	eor	r1, r3, r3, lsl #1
		
//	and	r1, r1, r0, lsr #1
//	sub	r0, r0, r1
		
//	and	r1, r3, r0, lsr #2
//	and	r0, r3, r0
//	add	r0, r0, r1
		
//	add	r0, r0, r0, lsr #4
//	and	r0, r0, r2
		
//	add	r0, r0, r0, lsr #8
//	and	r0, r0, #0x1F
//	bx lr

//count_bits_set_8:
//	and	r1, r0, #0xAA
//	sub	r0, r0, r1, lsr #1
		
//	and	r1, r0, #0xCC
//	and	r0, r0, #0x33
//	add	r0, r0, r1, lsr #2
		
//	add	r0, r0, r0, lsr #4
//	and	r0, r0, #0xF
//	bx lr

.global print_address
print_address:
	push {r0-r4}
	ldr r1,= nibble_to_char
	ldr r4,= (0x06202000 + 32 * 10)
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
	pop {r0-r4}
	bx lr

.global print_address2
print_address2:
	push {r0-r4}
	ldr r1,= nibble_to_char
	ldr r4,= (0x06202000 + 32 * 11)
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
	pop {r0-r4}
	bx lr