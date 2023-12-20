.model small
.data
a	dw 100 dup(0)
b	dw 100 dup(0)
n	dw ?
                        ;формируем строки для вывода
stra	db 0dh,0ah,'A($'
strb	db 0dh,0ah,'B($'
str1	db ')= $'
buf	db 8,10 dup(0)	     ;принимает строку, введенную с клавиатуры
msg1	db 13,10,'Size of vectors: $'
msg2	db 13,10,'<A*B> = $'
.stack 256
.code
start:
	mov ax,@data	
	mov ds,ax
	mov ah,9		;функция вывода сообщения на экран
	lea dx,msg1		
	int 21h			
	mov ah,0ah		;функция ввода строки с клавиатуры
	mov dx,offset buf       
	int 21h			;пользователь вводит в текстовом виде в buf значение числа
	lea si,buf[2]	
	call str2dw		;преобразовываем строку в значение
	mov n,ax		
	lea bx,A		
	mov cx,1		;номер элемента(начинаем с 1)
inpmas1:
	mov ah,9		
	lea dx,stra	
	int 21h			
        mov ax,cx		;номер элемента
	call printdec		;преобразуем номер элемента в строку и выводим на экран
	mov ah,9		
	lea dx,str1		
	int 21h			
	mov ah,0ah		
	mov dx,offset buf	
	int 21h			 
	lea si,buf[2]		
	call str2dw		
	mov [bx],ax		;заносим значение в массив
	add bx,2		;следующий элемент
	inc cx			;номер следующего элемента
	cmp cx,n		;если не равен N
	jbe inpmas1		;то продолжить


	lea bx,B		;начало массива
	mov cx,1		;номер элемента(начинаем с 1)
inpmas2:
	mov ah,9		
	lea dx,strb
	int 21h			
        mov ax,cx		
	call printdec	
	mov ah,9		
	lea dx,str1		
	int 21h			
	mov ah,0ah		
	mov dx,offset buf	
	int 21h		
	lea si,buf[2]		
	call str2dw		
	mov [bx],ax		
	add bx,2		
	inc cx			
	cmp cx,n	
	jbe inpmas2		
;скалярное произведение
	mov bx,0		;сумма=0
	mov si,0		;индекс текущего вектора=0
	mov cx,n		;кол-во элементов
mlp:
	mov ax,A[si]		;взять Ai
	imul B[si]		;Ai*Bi
	add bx,ax		;сумма=сумма+Ai*Bi
	add si,2		;i=i+1
	loop mlp		;продолжить цикл

	mov ah,9		
	lea dx,msg2		
	int 21h			
	mov ax,bx		
	call printdec		
	mov ah,8	
	int 21h
	mov ax,4c00h
	int 21h
;преобразование числа из ах в десятичную строку и вывод на экран

printdec proc
	push cx		
	push dx
	push bx
	push si
	mov si,ax	
	mov bx,10	;основание системы
	xor cx,cx	;в сх будет количество цифр в десятичном числе
	test ax,ax	;если число положительное
	jns @@m1a	;то пропускаем
	neg ax		;если отрицательное, то меняем знак
@@m1a:	xor dx,dx	
	div bx		;делим число на степени 10
	add dl,'0'	;преобразовываем цифру в ASCII символ
	push dx		;и сохраняем остаток от деления(коэффициенты при степенях) в стек
	inc cx		
	test ax,ax	
	jnz @@m1a	
	test si,si	;число отрицательное?
	jns @@m3a	;если нет, пропустить
	push '-'	;иначе дописать перед числом минус
	inc cx		;увеличить количество цифр числа
@@m3a:	mov ah,2       
@@m2a:	pop dx		
	int 21h		
	loop @@m2a	
	pop si		
	pop bx
	pop dx
	pop cx
	ret		;выход из подпрограммы
printdec endp
str2dw	proc
;Преобразование строки в число
	push bx		
	push dx
	push si
	xor bx,bx
	xor dx,dx	
@lp1:	xor ax,ax
	lodsb	
	cmp al,13	
	jz @ex		
	cmp al,'-'	
	jnz @m1
	mov bx,1	
	jmp @lp1	
@m1:	cmp al,'9'	
	jnbe @lp1	
	cmp al,'0'      
	jb @lp1		
	sub ax,'0'	
	shl dx,1	
	add ax, dx
	shl dx, 2
	add dx, ax	
	jmp @lp1	
@ex:	test bx,bx	
	jz @ex1
	neg dx		
@ex1:	mov ax,dx	
	pop si
	pop dx
	pop bx
	ret		
str2dw	endp

end start
