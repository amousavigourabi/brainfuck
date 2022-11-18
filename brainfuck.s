.global brainfuck

.text

# your brainfuck subroutine will receive one argument:
# a zero termianted string containing the code to execute.
brainfuck:
        # prologue + callee saved pushes
        pushq   %rbp
        movq    %rsp, %rbp

        pushq   %rbx
        pushq   %r15
        pushq   %r14
        pushq   %r13

        # allocate space for the binary
        # r15 is the mem addr, r14 points to the instructions within the binary
        leaq    -1000000(%rbp), %r15
        xorq    %r14, %r14

        # find the start of the actual brainfuck, this way we can skip over comments swiftly
        # rdi is the mem addr, r13 points to the instructions within the .b
        # as .<] would be illegal or just not really do anything at the start, we can ignore these instructions in this loop
        # and encountering [ is exceedingly unlikely
        xorq    %r13, %r13
find_first_code_loop:
        movb    (%rdi, %r13, 1), %r8b

        cmpb    $62, %r8b                               # >
        je      inc_ptr_cmp

        cmpb    $43, %r8b                               # +
        je      inc_cell_cmp

        cmpb    $45, %r8b                               # -
        je      dec_cell_cmp

        cmpb    $44, %r8b                               # ,
        je      input_cmp

        cmpb    $91, %r8b                               # [
        je      start_loop_cmp

        addq    $1, %r13
        jmp     find_first_code_loop

# compiles the .b into the binary, just with loop jump addresses, packing, [-]/[+], [>], and [<]
# 0x00 quit $0x00
# 0x03 mutate to cell contents by x(byte) +++ or ---
# 0x06 mutate ptr by x(quad) >>> or <<<
# 0x07 loop start + jmp addr(quad) [
# 0x08 loop end (jmp addr(quad) will be at tos) ]
# 0x09 mov 0x00 to cell [-],[+]
# 0x0C print cell .
# 0x0D get user input ,
# 0x0E jump to first empty cell in jumps of x(quad) cells [>>>] or [<<<]
# 0x0F add cell to next, empty src [->+<]
# 0x10 add cell to previous, empty src [-<+>]
# 0x19 mov 0x0000 to two cells [-]>[-]
# 0x29 mov 0x00000000 to four cells [-]>[-]>[-]>[-]
# iterates over the brainfuck code to compile the instructions
compile_brainfuck_loop:
        addq    $1, %r13
compile_brainfuck_loop_next_instr:
        movb    (%rdi, %r13, 1), %r8b
compile_brainfuck_loop_fetched:
        cmpb    $44, %r8b                               # ,
        je      input_cmp

        cmpb    $46, %r8b                               # .
        je      output_cmp

        cmpb    $45, %r8b                               # -
        je      dec_cell_cmp

        cmpb    $43, %r8b                               # +
        je      inc_cell_cmp

        cmpb    $91, %r8b                               # [
        je      start_loop_cmp

        cmpb    $93, %r8b                               # ]
        je      end_loop_cmp

        cmpb    $60, %r8b                               # <
        je      dec_ptr_cmp

        cmpb    $62, %r8b                               # >
        je      inc_ptr_cmp

        cmpb    $0, %r8b                                # quit programme
        je      q_cmp

        jmp     compile_brainfuck_loop                  # we encountered a comment!

# compiles the + instruction and sequences thereof
inc_cell_cmp:
        addq    $1, %r13
        movb    (%rdi, %r13, 1), %r8b

        movw    $2, %r10w
        cmpb    $43, %r8b                               # checks if we can pack stuff
        cmove   %r10w, %r9w                             # initializes r9 to 2 if we are going to jump can
        je      inc_cell_packing_newline

        movw    $0x0103, (%r15, %r14, 1)
        addq    $2, %r14

        jmp     compile_brainfuck_loop_fetched

# compiles the - instruction and sequences thereof
dec_cell_cmp:
        addq    $1, %r13
        movb    (%rdi, %r13, 1), %r8b

        # movw instead of movb because of caching with cmovew
        movw    $0x00FE, %r10w
        cmpb    $45, %r8b                               # checks if we can pack stuff
        cmovew  %r10w, %r9w                             # initializes r9 to -2 if we are going to jump can
        je      dec_cell_packing_newline

        movw    $0xFF03, (%r15, %r14, 1)
        addq    $2, %r14

        jmp     compile_brainfuck_loop_fetched

# packs sequences of +
inc_cell_packing:
        addb    $1, %r9b
inc_cell_packing_newline:
        addq    $1, %r13
        cmpb    $43, (%rdi, %r13, 1)
        je      inc_cell_packing
        
        cmpb    $10, (%rdi, %r13, 1)
        je      inc_cell_packing_newline

        movb    $0x03, (%r15, %r14, 1)
        movb    %r9b, 1(%r15, %r14, 1)
        addq    $2, %r14
        jmp     compile_brainfuck_loop_next_instr

# packs sequences of -
dec_cell_packing:
        subb    $1, %r9b
dec_cell_packing_newline:
        addq    $1, %r13
        cmpb    $45, (%rdi, %r13, 1)
        je      dec_cell_packing

        cmpb    $10, (%rdi, %r13, 1)
        je      dec_cell_packing_newline

        movb    $0x03, (%r15, %r14, 1)
        movb    %r9b, 1(%r15, %r14, 1)
        addq    $2, %r14
        jmp     compile_brainfuck_loop_next_instr

# compiles the > instruction and sequences thereof
inc_ptr_cmp:
        addq    $1, %r13
        movb    (%rdi, %r13, 1), %r8b

        cmpb    $62, %r8b                               # checks if we can pack stuff
        je      inc_ptr_packing

        movb    $0x06, (%r15, %r14, 1)
        movq    $1, 1(%r15, %r14, 1)
        addq    $9, %r14

        jmp     compile_brainfuck_loop_fetched

# compiles the < instruction and sequences thereof
dec_ptr_cmp:
        addq    $1, %r13
        movb    (%rdi, %r13, 1), %r8b

        cmpb    $60, %r8b                               # checks if we can pack stuff
        je      dec_ptr_packing

        movb    $0x06, (%r15, %r14, 1)
        movq    $-1, 1(%r15, %r14, 1)
        addq    $9, %r14

        jmp     compile_brainfuck_loop_fetched

# packs sequences of >
inc_ptr_packing:
        movq    $1, %r9
inc_ptr_packing_loop:
        addq    $1, %r9
inc_ptr_packing_newline:
        addq    $1, %r13
        cmpb    $62, (%rdi, %r13, 1)
        je      inc_ptr_packing_loop
        
        cmpb    $10, (%rdi, %r13, 1)
        je      inc_ptr_packing_newline

inc_ptr_packing_write:
        movb    $0x06, (%r15, %r14, 1)
        movq    %r9, 1(%r15, %r14, 1)
        addq    $9, %r14
        jmp     compile_brainfuck_loop_next_instr

# packs sequences of <
dec_ptr_packing:
        movq    $-1, %r9
dec_ptr_packing_loop:
        subq    $1, %r9
dec_ptr_packing_newline:
        addq    $1, %r13
        cmpb    $60, (%rdi, %r13, 1)
        je      dec_ptr_packing_loop
        
        cmpb    $10, (%rdi, %r13, 1)
        je      dec_ptr_packing_newline

dec_ptr_packing_write:
        movb    $0x06, (%r15, %r14, 1)
        movq    %r9, 1(%r15, %r14, 1)
        addq    $9, %r14
        jmp     compile_brainfuck_loop_next_instr

# compiles the . instruction
output_cmp:
        movb    $0x0C, (%r15, %r14, 1)
        addq    $1, %r14

        jmp     compile_brainfuck_loop

# compiles the , instruction
input_cmp:
        movb    $0x0D, (%r15, %r14, 1)
        addq    $1, %r14

        jmp     compile_brainfuck_loop

# compiles the [ instruction and its somewhat optimizable variants, i.e. [-]; [+]; [>]; and [<]
start_loop_cmp:
        cmpb    $93, 2(%rdi, %r13, 1)                   # checks if the loop is of format [X]
        jne     no_loop_simple_optimizations

        movb    1(%rdi, %r13, 1), %r8b

        cmpb    $43, %r8b                               # [+]
        je      zero_out_cell_cmp

        cmpb    $62, %r8b                               # [>]
        je      scan_empty_inc_cmp

        cmpb    $60, %r8b                               # [<]
        je      scan_empty_dec_cmp

        cmpb    $45, %r8b                               # [-]
        je      zero_out_cell_cmp

# compiles a plain [
no_loop_simple_optimizations:
        cmpb    $93, 5(%rdi, %r13, 1)                   # checks if the loop is of format [XXXX]
        jne     no_loop_medium_optimizations

        movl    1(%rdi, %r13, 1), %r9d

        # check for [<+>-]
        cmpl    $0x2d3e2b3c, %r9d
        je      add_cell_to_prev

        # check for [>+<-]
        cmpl    $0x2d3c2b3e, %r9d
        je      add_cell_to_next

        # check for [-<+>]
        cmpl    $0x3e2b3c2d, %r9d
        je      add_cell_to_prev

        # check for [->+<]
        cmpl    $0x3c2b3e2d, %r9d
        je      add_cell_to_next

no_loop_medium_optimizations:
        # todo cmove this one!
        movb    1(%rdi, %r13, 1), %r8b
        addq    $1, %r13

        cmpb    $62, %r8b
        je      scan_for_empty_cell_inc_cmp

        cmpb    $60, %r8b
        je      scan_for_empty_cell_dec_cmp

        movb    $0x07, (%r15, %r14, 1)
        pushq   %r14                                    # pushes r14 so that end_loop_cmp will know where to put the jump address!
        addq    $9, %r14

        jmp     compile_brainfuck_loop_fetched

# compiles [->+<]
add_cell_to_next:
        movb    $0x0F, (%r15, %r14, 1)
        addq    $1, %r14
        addq    $6, %r13
        jmp     compile_brainfuck_loop_next_instr

# compiles [-<+>]
add_cell_to_prev:
        movb    $0x10, (%r15, %r14, 1)
        addq    $1, %r14
        addq    $6, %r13
        jmp     compile_brainfuck_loop_next_instr

# compiles [>>>] and variations, fallback to simply writing [>>>
scan_for_empty_cell_inc_cmp:
        xorq    %r9, %r9
scan_for_empty_cell_inc_loop:
        addq    $1, %r13
        addq    $1, %r9
        movb    (%rdi, %r13, 1), %r8b

        cmpb    $62, %r8b
        je      scan_for_empty_cell_inc_loop

        cmpb    $93, %r8b
        jne     abort_scan_for_empty_cell_write

        movb    $0x0E, (%r15, %r14, 1)
        movq    %r9, 1(%r15, %r14, 1)
        addq    $9, %r14

        jmp     compile_brainfuck_loop

# compiles [<<<] and variations, fallback to simply writing [<<<
scan_for_empty_cell_dec_cmp:
        xorq    %r9, %r9
scan_for_empty_cell_dec_loop:
        addq    $1, %r13
        subq    $1, %r9
        movb    (%rdi, %r13, 1), %r8b

        cmpb    $60, %r8b
        je      scan_for_empty_cell_dec_loop

        cmpb    $93, %r8b
        jne     abort_scan_for_empty_cell_write

        movb    $0x0E, (%r15, %r14, 1)
        movq    %r9, 1(%r15, %r14, 1)
        addq    $9, %r14

        jmp     compile_brainfuck_loop

# fallback to writing [<<< or [>>>
abort_scan_for_empty_cell_write:
        movb    $0x07, (%r15, %r14, 1)
        pushq   %r14                                    # pushes r14 so that end_loop_cmp will know where to put the jump address!

        movb    $0x06, 9(%r15, %r14, 1)
        movq    %r9, 10(%r15, %r14, 1)

        addq    $18, %r14

        jmp     compile_brainfuck_loop_fetched

# optimizes for [-] and [+]
zero_out_cell_cmp:
        cmpl    $0x5d2d5b3e, 3(%rdi, %r13, 1)
        jne     zero_out_cell_simple

        movq    $0x5d2d5b3e5d2d5b3e, %r8                # moves the cmp value for >[-]>[-] to register
        cmpq    %r8, 7(%rdi, %r13, 1)                   # because cmpq cannot deal with such big literals
        jne     zero_out_cell_double

        # compiles [-]>[-]>[-]>[-]
        movb    $0x29, (%r15, %r14, 1)
        addq    $1, %r14
        addq    $15, %r13

        jmp     compile_brainfuck_loop_next_instr

# compiles [-]>[-]
zero_out_cell_double:
        movb    $0x19, (%r15, %r14, 1)
        addq    $1, %r14
        addq    $7, %r13

        jmp     compile_brainfuck_loop_next_instr

# compiles [-]
zero_out_cell_simple:
        movb    $0x09, (%r15, %r14, 1)
        addq    $1, %r14
        addq    $3, %r13

        jmp     compile_brainfuck_loop_next_instr

# compiles [>]
scan_empty_inc_cmp:
        movw    $0x010E, (%r15, %r14, 1)
        addq    $2, %r14
        addq    $3, %r13

        jmp     compile_brainfuck_loop_next_instr

# compiles [<]
scan_empty_dec_cmp:
        movb    $0xFF0E, (%r15, %r14, 1)
        addq    $2, %r14
        addq    $3, %r13

        jmp     compile_brainfuck_loop_next_instr

# compiles the ] instruction
end_loop_cmp:
        movb    $0x08, (%r15, %r14, 1)
        addq    $1, %r14
        popq    %r8
        movq    %r14, 1(%r15, %r8, 1)                   # puts the jump address next to the start loop instruction

        jmp     compile_brainfuck_loop

# compiles the quit instruction
q_cmp:
        movb    $0x00, (%r15, %r14, 1)

### compiles a quit programme instruction, which because of the nature of brainfuck means this will be the end of the compile step.


        movq    $30000, %rdi                            # allocates room for 30 000 cells of 1B
        call    malloc                                  # todo check if leaq is faster here?

        movq    %rax, %rbx                              # rbx stores the ptr to the block with 30 000 cells

        xorq    %r13, %r13                              # r13 stores the ptr for position within the 30 000 cells

        # runs the binary
        # r15 points to the mem addr of the binary
        # r14 points to the instruction within the binary
        xorq    %r14, %r14
run_first_binary:
        movb    (%r15, %r14, 1), %r9b

        # the first instruction can only be 0x00-0x04, 0x06 or 0x0F
        # we can thus use a smaller jumptable here!
        # the smaller jumptable

        cmpb    $0x03, %r9b
        je      mutate_cell_complex_instr

        cmpb    $0x06, %r9b
        je      change_ptr_complex_instr

        cmpb    $0x0D, %r9b
        je      input_instr

        jmp     quit_interpreter                        # when we reach this, it means the instruction is 0x00, which quits the interpreter.
                                                        # though it would be weird to have this as your first ''instruction'', right??

# standard loop for the binary
run_binary_loop:
        addq    $1, %r14
scanner_binary:
        movb    (%r15, %r14, 1), %r9b

# the full jumptable
# the interpreter adds the following instructions for more optimized code:
# 0x17 for a loop start that cannot be optimized more
# 0x11 +11B garbage +quad ptr shift +12B garbage for variants of [->>>+<<<]
# 0x12 +11B garbage +quad ptr shift +12B garbage for variants of [->>>-<<<]
# 0x13 +9B garbage +quad ptr shift +2B garbage +quad ptr shift + 1B garbage for variants of [>>>[-]>>>]
# 0x14 +9B garbage +quad ptr shift +2B garbage +quad ptr shift + 2B garbage +quad ptr shift + 1B garbage for variants of [>>>[-]>[-]>>>]
# 0x15 +9B garbage +quad ptr shift +2B garbage +quad ptr shift + 2B garbage +quad ptr shift + 2B garbage +quad ptr shift +1B garbage for variants of [>>>[-]>>>[-]>>>[-]>>>]
# 0x20 +11B garbage +quad ptr shift +3B garbage +quad ptr shift +12B garbage for variants of [->>+>+<<<]
#todo order the jumptables?
#todo merge instructions? the size of the jumptable is starting to become a serious issue
#lets at least merge the empty cell instructions
#lets then merge add to next and add to prev
#lets see if merging the no_optim loop start and optim loop start has a positive effect as well
#should save the programme a worst case of ~5 conditionals
scanner_binary_fetched:
        cmpb    $0x03, %r9b
        je      mutate_cell_complex_instr

        cmpb    $0x06, %r9b
        je      change_ptr_complex_instr
        
        cmpb    $0x17, %r9b
        je      no_optim_loop_start_instr

        cmpb    $0x11, %r9b
        je      add_loop_optim_instr

        cmpb    $0x12, %r9b
        je      subtract_loop_optim_instr

        cmpb    $0x08, %r9b
        je      loop_end_instr

        cmpb    $0x07, %r9b
        je      loop_start_instr

        cmpb    $0x0F, %r9b
        je      add_to_next_instr

        cmpb    $0x10, %r9b
        je      add_to_prev_instr

        cmpb    $0x0C, %r9b
        je      output_instr

        cmpb    $0x20, %r9b
        je      complex_add_add_loop_optim_instr

        cmpb    $0x21, %r9b
        je      complex_sub_add_loop_optim_instr

        cmpb    $0x13, %r9b
        je      interpret_single_zero_loop_instr

        cmpb    $0x14, %r9b
        je      interpret_double_zero_loop_instr

        cmpb    $0x09, %r9b
        je      zero_out_cell_instr

        cmpb    $0x19, %r9b
        je      zero_out_double_cell_instr

        cmpb    $0x0E, %r9b
        je      scan_empty_complex_instr

        cmpb    $0x29, %r9b
        je      zero_out_quadruple_cell_instr

        cmpb    $0x0D, %r9b
        je      input_instr

        jmp     quit_interpreter                        # when this is reached we must have hit 0x00 and we can thus quit the programme

# deals with the instructions for singular +
inc_cell_simple_instr:
        addb    $1, (%rbx, %r13, 1)
        jmp     run_binary_loop

# deals with the instructions for singular -
dec_cell_simple_instr:
        subb    $1, (%rbx, %r13, 1)
        jmp     run_binary_loop

# deals with the instructions for sequences of + and -
mutate_cell_complex_instr:
        movb    1(%r15, %r14, 1), %r9b
        addq    $2, %r14
        addb    %r9b, (%rbx, %r13, 1)
        jmp     scanner_binary

# deals with the instructions for singular >
inc_ptr_simple_instr:
        addq    $1, %r13
        jmp     run_binary_loop

# deals with the instructions for singular <
dec_ptr_simple_instr:
        subq    $1, %r13
        jmp     run_binary_loop

# deals with the instructions for sequences of > and <
change_ptr_complex_instr:
        addq    1(%r15, %r14, 1), %r13
        addq    $9, %r14
        jmp     scanner_binary

# deals with the instructions for simple [ which cannot be optimized any further
no_optim_loop_start_instr:
        cmpb    $0, (%rbx, %r13, 1)
        jne     no_optim_loop_start_continue

        movq    1(%r15, %r14, 1), %r14
        jmp     scanner_binary

no_optim_loop_start_continue:
        # todo get rid of this add
        addq    $9, %r14
        pushq   %r14
        jmp     scanner_binary

# deals with the instructions for simple [
loop_start_instr:
        cmpb    $0, (%rbx, %r13, 1)
        jne     loop_start_continue

        movq    1(%r15, %r14, 1), %r14
        jmp     scanner_binary

loop_start_continue:
        # todo get rid of this add
        addq    $9, %r14

        # filters [19B] loops for optimizations (i.e. hopefully, [>>>[-]>>>] or [>>>[-]>[-]>>>] and variations)
        cmpb    $0x08, 19(%r15, %r14, 1)
        je      interpreted_loop_optimizations_19

        # filters [21B] loops for optimizations (i.e. hopefully, [>>>[-]>[-]>[-]>>>] and variations)
        // cmpb    $0x08, 21(%r15, %r14, 1)
        // je      interpreted_loop_optimizations_21

        # filters [22B] loops for optimizations (i.e. hopefully, [-<<<+>>>] and variations)
        cmpb    $0x08, 22(%r15, %r14, 1)
        je      interpreted_loop_optimizations_22

        # filters [33B] loops for optimizations (i.e. hopefully, [-<<+<+>>>] and variations)
        # todo! add these!
        cmpb    $0x08, 33(%r15, %r14, 1)
        je      interpreted_loop_optimizations_33

no_interpreted_loop_optimizations:
        movb    $0x17, -9(%r15, %r14, 1)
        pushq   %r14
        jmp     scanner_binary

# optimizes for [>>>[-]>>>] and [>>>[-]>[-]>>>] like sequences
interpreted_loop_optimizations_19:
        cmpb    $0x06, (%r15, %r14, 1)
        jne     no_interpreted_loop_optimizations

        cmpb    $0x06, 10(%r15, %r14, 1)
        jne     no_interpreted_loop_optimizations

        cmpb    $0x09, 9(%r15, %r14, 1)
        je      interpret_single_zero_loop

        cmpb    $0x19, 9(%r15, %r14, 1)
        je      interpret_double_zero_loop

        jmp     no_interpreted_loop_optimizations

# deals with [>>>[-]>>>] sequences
interpret_single_zero_loop:
        # writes the 0x13 instruction
        movb    $0x13, -9(%r15, %r14, 1)

        movq    1(%r15, %r14, 1), %r8
        movq    11(%r15, %r14, 1), %r9
interpret_single_zero_loop_loop:
        cmpb    $0, (%rbx, %r13, 1)
        je      interpret_single_zero_loop_exit

        addq    %r8, %r13
        movb    $0, (%rbx, %r13, 1)
        addq    %r9, %r13

        jmp     interpret_single_zero_loop_loop
interpret_single_zero_loop_exit:
        addq    $20, %r14
        jmp     scanner_binary

# deals with [>>>[-]>[-]>>>] sequences
interpret_double_zero_loop:
        # writes the 0x14 instruction
        movb    $0x14, -9(%r15, %r14, 1)
        movq    1(%r15, %r14, 1), %r8
        movq    11(%r15, %r14, 1), %r9
        addq    $1, %r9
interpret_double_zero_loop_loop:
        cmpb    $0, (%rbx, %r13, 1)
        je      interpret_double_zero_loop_exit

        addq    %r8, %r13
        movw    $0, (%rbx, %r13, 1)
        addq    %r9, %r13
        jmp     interpret_double_zero_loop_loop
interpret_double_zero_loop_exit:
        addq    $20, %r14
        jmp     scanner_binary

# deals with pre-processed [>>>[-]>>>] sequences
interpret_single_zero_loop_instr:
        movq    10(%r15, %r14, 1), %r8
        movq    20(%r15, %r14, 1), %r9
interpret_single_zero_loop_instr_loop:
        cmpb    $0, (%rbx, %r13, 1)
        je      interpret_single_zero_loop_instr_exit

        addq    %r8, %r13
        movb    $0, (%rbx, %r13, 1)
        addq    %r9, %r13

        jmp     interpret_single_zero_loop_instr_loop
interpret_single_zero_loop_instr_exit:
        addq    $29, %r14
        jmp     scanner_binary

# deals with pre-processed [>>>[-]>[-]>>>] sequences
interpret_double_zero_loop_instr:
        movq    10(%r15, %r14, 1), %r8
        movq    20(%r15, %r14, 1), %r9
        addq    $1, %r9
interpret_double_zero_loop_instr_loop:
        cmpb    $0, (%rbx, %r13, 1)
        je      interpret_double_zero_loop_instr_exit

        addq    %r8, %r13
        movw    $0, (%rbx, %r13, 1)
        addq    %r9, %r13
        jmp     interpret_double_zero_loop_instr_loop
interpret_double_zero_loop_instr_exit:
        addq    $29, %r14
        jmp     scanner_binary

# optimizes for [->>+>+<<<] like sequences
interpreted_loop_optimizations_33:
        cmpw    $0xFF03, (%r15, %r14, 1)
        jne     no_interpreted_loop_optimizations

        movq    3(%r15, %r14, 1), %r9
        addq    14(%r15, %r14, 1), %r9
        addq    25(%r15, %r14, 1), %r9

        # checks if the loop ends up at the same cell it started
        // cmpq    $0, %r9                                         # not necessary after arithmetic operation
        jne     no_interpreted_loop_optimizations

        cmpb    $0x06, 2(%r15, %r14, 1)
        jne     no_interpreted_loop_optimizations

        cmpb    $0x06, 13(%r15, %r14, 1)
        jne     no_interpreted_loop_optimizations

        cmpb    $0x06, 24(%r15, %r14, 1)
        jne     no_interpreted_loop_optimizations

        cmpw    $0x0103, 22(%r15, %r14, 1)
        jne     no_interpreted_loop_optimizations

        cmpw    $0x0103, 11(%r15, %r14, 1)
        je      interpret_complex_add_add_loop_optim

        cmpw    $0xFF03, 11(%r15, %r14, 1)
        je      interpret_complex_sub_add_loop_optim

        jmp     no_interpreted_loop_optimizations

# deals with [->>>+>>+<<<<<] like sequences with -++ order
interpret_complex_add_add_loop_optim:
        # writes the 0x20 instruction
        movb    $0x20, -9(%r15, %r14, 1)
        movq    3(%r15, %r14, 1), %r8
        movq    14(%r15, %r14, 1), %r9
        
        # adds the cell's value to the two other cells
        addq    %r13, %r8
        movb    (%rbx, %r13, 1), %r10b
        addq    %r8, %r9
        addb    %r10b, (%rbx, %r8, 1)
        addb    %r10b, (%rbx, %r9, 1)

        # clears the src cell and moves the binary ptr
        movb    $0, (%rbx, %r13, 1)
        addq    $34, %r14
        jmp     scanner_binary

# deals with [->>>->>+<<<<<] like sequences with -++ order
interpret_complex_sub_add_loop_optim:
        # writes the 0x20 instruction
        movb    $0x21, -9(%r15, %r14, 1)
        movq    3(%r15, %r14, 1), %r8
        movq    14(%r15, %r14, 1), %r9
        
        # adds the cell's value to the two other cells
        addq    %r13, %r8
        movb    (%rbx, %r13, 1), %r10b
        addq    %r8, %r9
        subb    %r10b, (%rbx, %r8, 1)
        addb    %r10b, (%rbx, %r9, 1)

        # clears the src cell and moves the binary ptr
        movb    $0, (%rbx, %r13, 1)
        addq    $34, %r14
        jmp     scanner_binary

# optimizes for [->>>-<<<] and [-<<<+>>>] like sequences!
# todo include [>>>+<<<-] and variations if possible and performance enhancing
interpreted_loop_optimizations_22:
        cmpw    $0xFF03, (%r15, %r14, 1)
        jne     no_interpreted_loop_optimizations
        movq    3(%r15, %r14, 1), %r9
        addq    14(%r15, %r14, 1), %r9

        // cmpq    $0, %r9                                         # not necessary after arithmetic operation
        jne     no_interpreted_loop_optimizations

        cmpb    $0x06, 13(%r15, %r14, 1)
        jne     no_interpreted_loop_optimizations

        cmpb    $0x06, 2(%r15, %r14, 1)
        jne     no_interpreted_loop_optimizations

        cmpw    $0x0103, 11(%r15, %r14, 1)
        je      interpret_add_loop_optim

        cmpw    $0xFF03, 11(%r15, %r14, 1)
        je      interpret_subtract_loop_optim

        jmp     no_interpreted_loop_optimizations

# deals with [->>>+<<<]
interpret_add_loop_optim:
        # writes the 0x11+quad instruction
        movb    $0x11, -9(%r15, %r14, 1)
        movq    3(%r15, %r14, 1), %r9

        # performs the loop
        movb    (%rbx, %r13, 1), %r10b
        addq    %r13, %r9
        addb    %r10b, (%rbx, %r9, 1)

        movb    $0, (%rbx, %r13, 1)
        addq    $23, %r14

        jmp     scanner_binary

# deals with [->>>-<<<]
interpret_subtract_loop_optim:
        # writes the 0x12+quad instruction
        movb    $0x12, -9(%r15, %r14, 1)
        movq    3(%r15, %r14, 1), %r9

        # performs the loop
        movb    (%rbx, %r13, 1), %r10b
        addq    %r13, %r9
        subb    %r10b, (%rbx, %r9, 1)

        movb    $0, (%rbx, %r13, 1)
        addq    $23, %r14
        jmp     scanner_binary

# deals with [->+<]
add_to_next_instr:
        movb    (%rbx, %r13, 1), %r10b
        movb    $0, (%rbx, %r13, 1)
        addb    %r10b, 1(%rbx, %r13, 1)
        jmp     run_binary_loop

# deals with [-<+>]
add_to_prev_instr:
        movb    (%rbx, %r13, 1), %r10b
        movb    $0, (%rbx, %r13, 1)
        addb    %r10b, -1(%rbx, %r13, 1)
        jmp     run_binary_loop

# deals with pre-optimized [->>>+>>+<<<<<] like sequences
complex_add_add_loop_optim_instr:
        movq    12(%r15, %r14, 1), %r8
        movq    23(%r15, %r14, 1), %r9
        
        # adds the cell's value to the two other cells
        addq    %r13, %r8
        movb    (%rbx, %r13, 1), %r10b
        addq    %r8, %r9
        addb    %r10b, (%rbx, %r8, 1)
        addb    %r10b, (%rbx, %r9, 1)

        # clears the src cell and moves the binary ptr
        movb    $0, (%rbx, %r13, 1)
        addq    $43, %r14
        jmp     scanner_binary

# deals with pre-optimized [->>>->>+<<<<<] like sequences
complex_sub_add_loop_optim_instr:
        movq    12(%r15, %r14, 1), %r8
        movq    23(%r15, %r14, 1), %r9
        
        # adds the cell's value to the two other cells
        addq    %r13, %r8
        movb    (%rbx, %r13, 1), %r10b
        addq    %r8, %r9
        subb    %r10b, (%rbx, %r8, 1)
        addb    %r10b, (%rbx, %r9, 1)

        # clears the src cell and moves the binary ptr
        movb    $0, (%rbx, %r13, 1)
        addq    $43, %r14
        jmp     scanner_binary

# deals with pre-optimized [->>>+<<<] like sequences
add_loop_optim_instr:
        movq    12(%r15, %r14, 1), %r9

        movb    (%rbx, %r13, 1), %r10b
        addq    %r13, %r9
        addb    %r10b, (%rbx, %r9, 1)

        movb    $0, (%rbx, %r13, 1)
        addq    $32, %r14
        jmp     scanner_binary

# deals with pre-optimized [->>>-<<<] like sequences
subtract_loop_optim_instr:
        movq    12(%r15, %r14, 1), %r9

        movb    (%rbx, %r13, 1), %r10b
        addq    %r13, %r9
        subb    %r10b, (%rbx, %r9, 1)

        movb    $0, (%rbx, %r13, 1)
        addq    $32, %r14
        jmp     scanner_binary

# deals with the instructions for simple ]
loop_end_instr:
        cmpb    $0, (%rbx, %r13, 1)
        je      loop_end_continue

        movq    (%rsp), %r14
        jmp     scanner_binary

loop_end_continue:
        addq    $8, %rsp
        jmp     run_binary_loop

# deals with the instructions for [-] and [+]
zero_out_cell_instr:
        movb    $0, (%rbx, %r13, 1)
        jmp     run_binary_loop

# deals with the instructions for [-]>[-]
zero_out_double_cell_instr:
        movw    $0, (%rbx, %r13, 1)
        addq    $1, %r13
        jmp     run_binary_loop

# deals with the instructions for [-]>[-]>[-]>[-]
zero_out_quadruple_cell_instr:
        movl    $0, (%rbx, %r13, 1)
        addq    $3, %r13
        jmp     run_binary_loop

# deals with the instructions for [>]
scan_empty_inc_instr:
        cmpb    $0, (%rbx, %r13, 1)
        je      run_binary_loop
        addq    $1, %r13
        jmp     scan_empty_inc_instr

# deals with the instructions for [<]
scan_empty_dec_instr:
        cmpb    $0, (%rbx, %r13, 1)
        je      run_binary_loop
        subq    $1, %r13
        jmp     scan_empty_dec_instr

# deals with the instructions for .
output_instr:
        # todo check if overhead can be reduced here!
        movb    (%rbx, %r13, 1), %dil
        call    putchar
        jmp     run_binary_loop

# deals with the instructions for ,
# todo check if the syscall overhead for writes can somehow be reduced here
input_instr:
        call    getchar
        # stores the input in the array
        movb    %al, (%rbx, %r13, 1)
        jmp     run_binary_loop

# deals with the instructions for [>>>] and variants
scan_empty_complex_instr:
        movq    1(%r15, %r14, 1), %r9
        addq    $9, %r14
scan_empty_complex_loop:
        cmpb    $0, (%rbx, %r13, 1)
        je      scanner_binary
        addq    %r9, %r13
        jmp     scan_empty_complex_loop

# quits with err code 0
quit_interpreter:
        # epilogue + callee saved pops
        popq    %r13
        popq    %r14
        popq    %r15
        popq    %rbx

        movq    $0, %rax                                # sets error code 0

        movq    %rbp, %rsp
        popq    %rbp

        ret
