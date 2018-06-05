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

    # luminance factors * 10000,
    # luminance = (lumR * R + lumG * G + lumB * B)/10000
    lumR = 2126
    lumG = 7152
    lumB = 722

    scale: .ascii "$@B%8&WM*oahkbdpqwmZO0QLCJUYXzvunxrjft/|()1{}]?-_+~<>i!lI:,^`'. "
                  
    f_in: .ascii "test.ppm\0"
    f_out: .ascii "out.txt\0"

    string: .asciz "%s"
    decimal: .asciz "%d"
    file_q: .asciz "Podaj nazwe pliku\n"
    size_q: .asciz "Podaj szerokosc czcionki\n"
    file_err: .asciz "Zla nazwa pliku\n"

.bss
    .comm file_buf, bufLen
    .comm red, colBufLen
    .comm green, colBufLen
    .comm blue, colBufLen
    .comm lum, colBufLen
    .comm file_out, colBufLen
    .comm file_len, 8
    .comm width, 8
    .comm height, 8
    .comm fontWidth, 8
    .comm fontHeight, 8
    .comm columnCount, 8
    .comm rowCount, 8
    .comm ignore, 8
    .comm to_numBuf, 4      # buf to get_width char to numbers
    
.text
    .global main
    main:

    mov $0, %rax
    mov $file_q, %rdi
    call printf

    mov $0, %rax
    mov $string, %rdi
    mov $f_in, %rsi
    call scanf

    mov $0, %rax
    mov $size_q, %rdi
    call printf

    mov $0, %rax
    mov $decimal, %rdi
    mov $fontWidth, %rsi
    call scanf

load_file:
    movq $SYSOPEN, %rax
    movq $f_in, %rdi
    movq $O_RDONLY, %rsi
    movq $0666, %rdx
    syscall

    cmp $-2, %rax
    je wrong_file_name

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

    mov width, %rax
    mov $0, %rdx
    divq fontWidth
    mov %rax, columnCount
    mov %rdx, ignore

    mov fontWidth, %rax
    mov $2, %rdi
    mul %rdi
    mov %rax, fontHeight

    mov height, %rax
    mov $0, %rdx
    divq fontHeight
    mov %rax, rowCount

    mov fontHeight, %rax
    dec %rax
    mulq width
    add %rax, ignore    # skip pixels covered by font char

    mov $0, %r8     # current pixel index
    mov $0, %r9     # current row
    mov $0, %r11    # lum/char table iterator
nextRow:
    mov $0, %r10    # current column
    nextCol:
        call getRect
        add fontWidth, %r8
        inc %r10
        cmp columnCount, %r10
        jl nextCol
    add ignore, %r8
    inc %r9
    cmp rowCount, %r9
    jl nextRow

    mov $0, %r8
    mov $4, %r9
    mov $0, %rdi
    mov $0, %rsi

to_chars:
    mov $0, %rax
    mov $0, %r10
    movb lum(, %r8, 1), %al
    mov $0, %rdx
    div %r9
    mov scale(, %rax, 1), %r10b
    mov %r10b, file_out(, %rdi, 1) 
    inc %rdi
    inc %r8
    inc %rsi
    cmp columnCount, %rsi
    jl to_chars_skip

    movb $'\n', file_out(, %rdi, 1)
    inc %rdi
    mov $0, %rsi

    to_chars_skip:
    cmp %r11, %r8
    jl to_chars

    mov %rdi, %r15

    movq $SYSOPEN, %rax
    movq $f_out, %rdi
    movq $O_WR_CRT_TRNC, %rsi
    movq $0666, %rdx
    syscall

    movq %rax, %rdi  # file handle
    movq $SYSWRITE, %rax
    movq $file_out, %rsi
    movq %r15, %rdx
    syscall

    movq $SYSCLOSE, %rax    # file handle still in %rdi
    syscall
    

exit:
    movq $SYSEXIT, %rax
    movq $EXIT_SUCCESS, %rdi
    syscall

wrong_file_name:
    mov $0, %rax
    mov $file_err, %rdi
    call printf
    jmp exit


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

getRect:    # r8 - buf index
    mov %r8, %rdi
    mov $10000, %r14    # factors were multiplied by 10000
    mov $0, %r15
    mov $0, %rbx    # RectRows iterator
    RectRows:
        mov $0, %rcx    # cols iterator
        RectCols:
            mov $0, %rax
            movb red(, %rdi, 1), %al
            mov $lumR, %r12
            mul %r12
            mov %rax, %r13

            mov $0, %rax
            movb green(, %rdi, 1), %al
            mov $lumG, %r12
            mul %r12
            add %rax, %r13

            mov $0, %rax
            movb blue(, %rdi, 1), %al
            mov $lumB, %r12
            mul %r12
            add %r13, %rax
            mov $0, %rdx
            div %r14
            add %rax, %r15

            inc %rdi
            inc %rcx
            cmp fontWidth, %rcx
            jl RectCols
        sub fontWidth, %rdi
        add width, %rdi
        inc %rbx
        cmp fontHeight, %rbx
        jl RectRows
    mov fontWidth, %rax
    mulq fontHeight
    mov %rax, %rdi
    mov %r15, %rax
    mov $0, %rdx
    div %rdi

    mov %rax, lum(, %r11, 1)
    inc %r11
    ret

