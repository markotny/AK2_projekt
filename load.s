.data
    SYSEXIT = 60
    EXIT_SUCCESS = 0
    SYSREAD = 0
    SYSWRITE = 1
    STDOUT = 1
    SYSOPEN = 2
    SYSCLOSE = 3
    O_RDONLY = 00
    O_WRONLY = 01
    O_WR_CRT_TRNC = 01101

    bufLen = 50000000
    colBufLen = 10000000

    f_in: .ascii "test.ppm\0"

.bss
    .comm file_buf, bufLen
    .comm red, colBufLen
    .comm green, colBufLen
    .comm blue, colBufLen
    .comm file_len, 8
    .comm width, 8
    .comm height, 8
    .comm to_numBuf, 4      # buf to get_width char to numbers
    
.text
    .globl _start
    _start:

load_file:
    movq $SYSOPEN, %rax
    movq $f_in, %rdi
    movq $O_RDONLY, %rsi
    movq $0666, %rdx
    syscall

    movq %rax, %rdi  # file handle
    movq $SYSREAD, %rax
    movq $file_buf, %rsi
    movq $bufLen, %rdx
    syscall

    dec %rax                # -'\n'
    mov %rax, file_len

    movq $SYSCLOSE, %rax    # file handle still in %rdi
    syscall

    push $file_buf
    call divide_by_color

exit:
    movq $SYSEXIT, %rax
    movq $EXIT_SUCCESS, %rdi
    syscall


divide_by_color:    
    push %rbp
    mov %rsp, %rbp
    # sub $16, %rsp
    mov 16(%rbp), %rsi  # %rsi - reg holding buf addr
    mov $0, %rdi        # %rdi - file_buf iterator
    mov $0, %r15        # %r15 - pixel colors iterator

    movw (%rsi, %rdi, 1), %bx   # PPM file begins with P3 magic number
    cmp $'P', %bl
    jne wrong_format
    cmp $'3', %bh
    jne wrong_format

    movq $3, %rdi   # skip 'P3\n'
    mov $0, %rcx
read_header:
    movb (%rsi, %rdi, 1), %bl
    inc %rdi
    cmp $'#', %bl
    je comment
    
    cmp $' ', %bl
    je get_width

    cmp $'\n', %bl
    je get_height

    movb %bl, to_numBuf(, %rcx, 1)
    inc %rcx
    jmp read_header

get_width:
    push %rcx
    push $to_numBuf
    call to_number
    pop width
    mov $0, %rcx
    jmp read_header

get_height:
    push %rcx
    push $to_numBuf
    call to_number
    pop height
    mov $0, %rcx
    add $4, %rdi    # skip color depth (255)
    jmp read_pixel

comment:
    movb (%rsi, %rdi, 1), %bl
    inc %rdi
    cmp $'\n', %bl
    jne comment
    je read_header

read_pixel:
    read_red:
        movb (%rsi, %rdi, 1), %bl
        inc %rdi
        cmp $'\n', %bl  # after new line (every 5 pixels)
        je read_red
        movb %bl, to_numBuf(, %rcx, 1)
        inc %rcx
        cmp $'0', %bl   # ' ', '\n' < '0'
        jge read_red

        dec %rcx        # don't include ' '
        push %rcx
        push $to_numBuf
        call to_number
        pop %rbx
        movb %bl, red(, %r15, 1)
        mov $0, %rcx
    read_green:
        movb (%rsi, %rdi, 1), %bl
        inc %rdi
        movb %bl, to_numBuf(, %rcx, 1)
        inc %rcx
        cmp $'0', %bl
        jge read_green

        dec %rcx
        push %rcx
        push $to_numBuf
        call to_number
        pop %rbx
        movb %bl, green(, %r15, 1)
        mov $0, %rcx
    read_blue:
        movb (%rsi, %rdi, 1), %bl
        inc %rdi
        movb %bl, to_numBuf(, %rcx, 1)
        inc %rcx
        cmp $'0', %bl
        jge read_blue

        dec %rcx
        push %rcx
        push $to_numBuf
        call to_number
        pop %rbx
        movb %bl, blue(, %r15, 1)
        mov $0, %rcx
    inc %r15
    cmp file_len, %rdi
    jl read_pixel

wrong_format:
    mov %rbp, %rsp
    pop %rbp
ret

to_number:
    push %rbp   
    mov %rsp, %rbp
    sub $16, %rsp
    mov %rsi, -8(%rbp)   # preserve prev %rsi and %rdi
    mov %rdi, -16(%rbp) 

    mov 16(%rbp), %rsi
    mov $10, %r10	# base
    mov $0, %rax	# in decimal
    mov $0, %rdi
    mov $0, %rbx

    num_decode:
        movb (%rsi, %rdi, 1), %bl
        inc %rdi
        sub $'0', %bl
        mul %r10
        add %rbx, %rax
        cmp 24(%rbp), %rdi
        jl num_decode

    mov %rax, 24(%rbp)
    mov 8(%rbp), %rax
    mov %rax, 16(%rbp)  
    mov -8(%rbp), %rsi    # restore prev %rsi and %rdi
    mov -16(%rbp), %rdi
    mov %rbp, %rsp
    pop %rbp
    add $8, %rsp
ret
