[org 0x1000]

dw 0x55aa

mov si, loading
call print

dectec_memory:
    xor ebx, ebx
    ; es:di struct position
    mov ax, 0
    mov es, ax
    mov edi, ards_buffer
    mov edx, 0x534d4150 ; fixed signature
.next:
    mov eax, 0xe820
    mov ecx, 20
    int 0x15
    ; CF set for error
    jc error
    add di, cx
    inc word [ards_count]
    cmp ebx, 0
    jnz .next

    mov si, memory_checking
    call print

;     xchg bx, bx
;; check the struct data
;     mov cx, [ards_count]
;     mov si, 0
; .show:
;     mov eax, [si + ards_buffer]
;     mov ebx, [si + ards_buffer + 8]
;     mov edx, [si + ards_buffer + 16]
;     add si, 20
;     xchg bx, bx
;     loop .show
    ; mov byte [0xb8000], 'P'; invalid in real mode, just for test
    jmp prepare_protect_mode

prepare_protect_mode:
    xchg bx, bx

    cli; close int

    ; open A20
    in al, 0x92
    or al, 0b10
    out 0x92, al

    ;load gdt
    lgdt [gdt_ptr]

    ;start Protext Mode
    mov eax, cr0
    or eax, 1
    mov cr0, eax

    ;use jmp to refresh cache?
    jmp dword code_selector:protect_mode

print:
    mov ah, 0x0e
.next:
    mov al, [si]
    cmp al, 0
    jz .done
    int 0x10
    inc si
    jmp .next
.done:
    ret

loading db "Loading LongOS...", 10, 13, 0
memory_checking db "Memory Checking SUCCESSED!", 10, 13, 0

error:
    mov si, .msg
    call print
    hlt; Stop CPU
    .msg db "Memory Checking Failed with Error!", 10, 13, 0


[bits 32]
protect_mode:
    mov ax, data_selector
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax; initial seg regesters

    mov esp, 0x10000 ;stack top

    mov byte [0xb8000+240], 'P'
    ;mov byte [0x20000], 'P'
    mov edi, 0x10000
    mov ecx, 10
    mov bl, 200
    call read_disk
    jmp dword code_selector:0x10000
    ud2; fault
jmp $

read_disk:
    ;set number of read
    mov dx, 0x1f2
    mov al, bl
    out dx, al

    inc dx
    mov al, cl
    out dx, al

    inc dx
    shr ecx, 8
    mov al, cl
    out dx, al

    inc dx
    shr ecx, 8
    mov al, cl
    out dx, al

    inc dx
    shr ecx, 8
    and cl, 0b1111
    mov al, 0b1110_0000
    or al, cl
    out dx, al

    inc dx
    mov al, 0x20 ;read
    out dx, al

    xor ecx, ecx
    mov cl, bl
    .read:
        push cx
        call .waits
        call .reads
        pop cx
        loop .read
    ret
    .waits:
        mov dx, 0x1f7
        .check:
            in al, dx
            jmp $+2
            jmp $+2
            jmp $+2
            and al, 0b1000_1000
            cmp al, 0b0000_1000
            jnz .check
        ret
    .reads:
        mov dx, 0x1f0
        mov cx, 256; words=2bytes
        .readw:
            in ax, dx
            nop
            mov [edi], ax
            add edi, 2
            loop .readw
        ret        

code_selector equ (1<<3)
data_selector equ (2<<3)
memory_base equ 0 ; base address
memory_limit equ ((1024*1024*1024*4) / (1024*4)) -1
gdt_ptr:
    dw (gdt_end-gdt_base) - 1 ; gdt limit:16bit
    dd gdt_base; gdt start-addr:32bit
gdt_base:
    dd 0,0
gdt_code:
    dw memory_limit & 0xffff; seg limit 0~15bit
    dw memory_base & 0xffff; seg base 0~15bit
    db (memory_base >> 16) & 0xff; seg base 16~23bit
    db 0b_1_00_1_1_0_1_0;
    db 0b1_1_0_0_0000 | (memory_limit >> 16) &0xf;
    db (memory_base >> 24) & 0xff; seg base 24~32bit
gdt_data:
    dw memory_limit & 0xffff; seg limit 0~15bit
    dw memory_base & 0xffff; seg base 0~15bit
    db (memory_base >> 16) & 0xff; seg base 16~23bit
    db 0b_1_00_1_0_0_1_0;
    db 0b1_1_0_0_0000 | (memory_limit >> 16) &0xf;
    db (memory_base >> 24) & 0xff; seg base 24~32bit
gdt_end:
ards_count:
    dw 0
ards_buffer:
