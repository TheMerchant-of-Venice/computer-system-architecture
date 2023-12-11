IDEAL
RADIX   16
P286
MODEL   LARGE

STRUC   desc_struc              
        limit   dw      0       
        base_l  dw      0       
        base_h  db      0       
        access  db      0       
        rsrv    dw      0       
ENDS    desc_struc

ACC_PRESENT     EQU     10000000b 
ACC_CSEG        EQU     00011000b 
ACC_DSEG        EQU     00010000b 
ACC_EXPDOWN     EQU     00000100b 
ACC_CONFORM     EQU     00000100b 
ACC_DATAWR      EQU     00000010b 

DATA_ACC = ACC_PRESENT OR ACC_DSEG OR ACC_DATAWR

CODE_ACC = ACC_PRESENT OR ACC_CSEG OR ACC_CONFORM

STACK_ACC = ACC_PRESENT OR ACC_DSEG OR ACC_DATAWR OR ACC_EXPDOWN

STACK_SIZE      EQU     0400    
B_DATA_SIZE     EQU     0300    
B_DATA_ADDR     EQU     0400    
MONO_SEG        EQU     0b000   
                                
COLOR_SEG       EQU     0b800                               
CRT_SIZE        EQU     4000                                
MONO_SIZE       EQU     1000    
CRT_LOW         EQU     8000                                   
MONO_LOW        EQU     0000    
                                
CRT_SEG         EQU     0Bh     
                                
DS_DESCR        =       (gdt_ds - gdt_0)
CS_DESCR        =       (gdt_cs - gdt_0)
SS_DESCR        =       (gdt_ss - gdt_0)
BIOS_DESCR      =       (gdt_bio - gdt_0)
CRT_DESCR       =       (gdt_crt - gdt_0)
MDA_DESCR       =       (gdt_mda - gdt_0)

CMOS_PORT       EQU     70h     
PORT_6845       EQU     0063h   
                                                 
COLOR_PORT      EQU     03d4h   
MONO_PORT       EQU     03b4h   
STATUS_PORT     EQU     64h   
SHUT_DOWN       EQU     0feh    
VIRTUAL_MODE    EQU     0001h  
A20_PORT        EQU     0d1h    
A20_ON          EQU     0dfh   
A20_OFF         EQU     0ddh    
KBD_PORT_A      EQU     60h     
KBD_PORT_B      EQU     61h     
INT_MASK_PORT   EQU     21h     

STACK   STACK_SIZE      

DATASEG                 

DSEG_BEG        =       THIS WORD

        real_ss dw      ?
        real_sp dw      ?
        real_es dw      ?

GDT_BEG         = $
LABEL   gdtr            WORD

        gdt_0   desc_struc      <0,0,0,0,0> 
        gdt_gdt desc_struc      <GDT_SIZE-1,,,DATA_ACC,0>
        gdt_ds  desc_struc      <DSEG_SIZE-1,,,DATA_ACC,0>
        gdt_cs  desc_struc      <CSEG_SIZE-1,,,CODE_ACC,0>
        gdt_ss  desc_struc      <STACK_SIZE-1,,,DATA_ACC,0>
        gdt_bio         desc_struc      <B_DATA_SIZE-1,B_DATA_ADDR,0,DATA_ACC,0>
        gdt_crt         desc_struc      <CRT_SIZE-1,CRT_LOW,CRT_SEG,DATA_ACC,0>
        gdt_mda         desc_struc      <MONO_SIZE-1,MONO_LOW,CRT_SEG,DATA_ACC,0>

GDT_SIZE        = ($ - GDT_BEG) 

CODESEG         

PROC    start

        mov     ax,DGROUP
        mov     ds,ax
        call    set_crt_base
        mov     bh, 77h
        call    clrscr
        call    init_protected_mode
        call    set_protected_mode
        call    write_m1_msg 
        call    pause           
        call    set_real_mode
        mov     bh, 07h
        call    clrscr
        mov     ah,4Ch
        int     21h

ENDP    start

MACRO setgdtentry
        mov     [(desc_struc bx).base_l],ax
        mov     [(desc_struc bx).base_h],dl
ENDM

PROC    init_protected_mode     NEAR


        mov     ax,DGROUP
        mov     dl,ah
        shr     dl,4
        shl     ax,4

        mov     si,ax
        mov     di,dx

        add     ax,OFFSET gdtr
        adc     dl,0
        mov     bx,OFFSET gdt_gdt
        setgdtentry

        mov     bx,OFFSET gdt_ds
        mov     ax,si
        mov     dx,di
        setgdtentry

        mov     bx,OFFSET gdt_cs
        mov     ax,cs
        mov     dl,ah
        shr     dl,4
        shl     ax,4
        setgdtentry

        mov     bx,OFFSET gdt_ss
        mov     ax,ss
        mov     dl,ah
        shr     dl,4
        shl     ax,4
        setgdtentry

        push    ds
        mov     ax,40
        mov     ds,ax
        mov     [WORD 67],OFFSET shutdown_return
        mov     [WORD 69],cs
        pop     ds

        cli
        mov     al,8f
        out     CMOS_PORT,al
        jmp     next1           
next1:

        mov     al,5
        out     CMOS_PORT+1,al  

        ret

ENDP    init_protected_mode

PROC    set_protected_mode      NEAR

        mov     ax,[rl_crt]     
        mov     es,ax           
        call    enable_a20      
        mov     [real_ss],ss   
        mov     [real_es],es    
        lgdt    [QWORD gdt_gdt]
        mov     ax,VIRTUAL_MODE
        lmsw    ax

        db      0ea
        dw      OFFSET flush
        dw      CS_DESCR

LABEL   flush   FAR

        mov     ax,SS_DESCR
        mov     ss,ax
        mov     ax,DS_DESCR
        mov     ds,ax
        ret

ENDP    set_protected_mode

PROC    set_real_mode   NEAR

        mov     [real_sp],sp
        mov     al,SHUT_DOWN
        out     STATUS_PORT,al

wait_reset:
        hlt
        jmp     wait_reset

LABEL   shutdown_return FAR

        mov     ax,DGROUP
        mov     ds,ax
        assume  ds:DGROUP
        mov     ss,[real_ss]
        mov     sp,[real_sp]
        mov     es,[real_es]
        call    disable_a20
        mov     ax,000dh        
        out     CMOS_PORT,al
        in      al,INT_MASK_PORT 
        and     al,0
        out     INT_MASK_PORT,al
        sti
        ret
ENDP    set_real_mode

PROC    enable_a20      NEAR
        mov     al,A20_PORT
        out     STATUS_PORT,al
        mov     al,A20_ON
        out     KBD_PORT_A,al
        ret
ENDP    enable_a20

PROC    disable_a20     NEAR
        mov     al,A20_PORT
        out     STATUS_PORT,al
        mov     al,A20_OFF
        out     KBD_PORT_A,al
        ret
ENDP    disable_a20

PROC    pause           NEAR
        push    cx
        mov     cx,50
ploop0:
        push    cx
        xor     cx,cx
ploop1:
        loop    ploop1
        pop     cx
        loop    ploop0
        pop     cx
        ret
ENDP    pause

DATASEG
        columns db      80d     
        rows    db      25d     
        rl_crt  dw      COLOR_SEG       
        vir_crt dw      CRT_DESCR      
        curr_line       dw      0d      

CODESEG

PROC    set_crt_base    NEAR

        mov     ax,40
        mov     es,ax
        mov     bx,[WORD es:4a]
        mov     [columns],bl
        mov     bl,[BYTE es:84]
        inc     bl
        mov     [rows],bl
        mov     bx,[WORD es:PORT_6845]
        cmp     bx,COLOR_PORT
        je      set_crt_exit
        mov     [rl_crt],MONO_SEG
        mov     [vir_crt],MDA_DESCR

set_crt_exit:
        ret
ENDP    set_crt_base


PROC    writexy         NEAR
        push    si
        push    di
        mov     dl,[columns]
        mul     dl
        add     ax,bx
        shl     ax,1
        mov     di,ax
        mov     ah,dh   


wxy_write:
        lodsb   
        stosw   
        loop    wxy_write       

        pop     di
        pop     si
        ret
ENDP    writexy

PROC    clrscr          NEAR
        xor     cx,cx
        mov     dl,[columns]
        mov     dh,[rows]
        mov     ax,0600h        
        int     10h
        ret
ENDP    clrscr

DATASEG

m1_msg db " Protected mode"

CODESEG

PROC    write_m1_msg NEAR

        mov     ax,[vir_crt]   
        mov     es,ax           
        mov     bx,0           
        mov     ax,[curr_line]
        inc     [curr_line]     
        mov     si,OFFSET m1_msg
        mov     cx,SIZE m1_msg
        mov     dh,30h  
        call    writexy 
        ret
ENDP    write_m1_msg

CSEG_SIZE       = ($ - start) 
DATASEG
DSEG_SIZE       = ($ - DSEG_BEG) 

        END     start