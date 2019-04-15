##Author: Grzegorz Rogozinski
##ARKO assignment
##
##Draws Julia Sets with given parameters

.data

buffer:			.space 8
filename:		.space 64

#header
signature:		.ascii "BM"
offset:			.byte 54, 0, 0, 0
dib_size:		.byte 40, 0, 0, 0
planes:			.byte 1, 0
bits_per_px:		.byte 24, 0
four_zeros:		.byte 0, 0, 0, 0
eight_zeros:		.byte 0, 0, 0, 0, 0, 0, 0, 0
two:			.double 2.0
four:			.double 4.0

zero:			.byte 0

#input messages
string_get_filename:	.asciiz "\nFilename: "
string_get_width:	.asciiz "\nWidth: "
string_get_height:	.asciiz "\nHeight: "
string_get_iter:	.asciiz "\nIterations: "
string_get_real:	.asciiz "\nReal part: "
string_get_imag:	.asciiz "\nImaginary part: "

.text
main:
	#read filename
	li $v0, 4
	la $a0, string_get_filename
	syscall
	
	li $v0, 8
	la $a0, filename
	la $a1, 64
	syscall
	
	#endline to zero
	la $t0, filename
	
	etz_loop:	#endline-to-zero loop
	lb $t1, ($t0)
	add $t0, $t0, 1
	bne $t1, '\n', etz_loop
	sb $zero, -1($t0)
	
	#read width
	li $v0, 4
	la $a0, string_get_width
	syscall
	
	li $v0, 5
	syscall
	move $s0, $v0
	
	#read height
	li $v0, 4
	la $a0, string_get_height
	syscall
	
	li $v0, 5
	syscall
	move $s1, $v0
	
	#read number of iterations
	li $v0, 4
	la $a0, string_get_iter
	syscall
	
	li $v0, 5
	syscall
	move $s2, $v0
	
	#read real
	li $v0, 4
	la $a0, string_get_real
	syscall
	
	li $v0, 7
	syscall
	mov.d $f20, $f0
	
	#read imaginary
	li $v0, 4
	la $a0, string_get_imag
	syscall
	
	li $v0, 7
	syscall
	mov.d $f22, $f0
		
## $s0 - width
## $s1 - height
## $s2 - iterations
## $f20 - Real(i)
## $f22 - Imaginary(i)
	
begin:
	#calculate number of end line bytes to fill
	mulu $t0, $s0, 3
	li $t1, 4
	divu $t0, $t1
	mfhi $t0
	
	#open file
	li $v0, 13
	la $a0, filename
	li $a1, 1
	li $a2, 0
	syscall
	
	move $t1, $v0 #file descriptor
	
	#create header
	
	#save signature
	li $v0, 15
	move $a0, $t1
	la $a1, signature
	li $a2, 2
	syscall
	
	#file size calculation
	mulu $a0, $s0, 3
	addu $a0, $a0, $t0
	mulu $a0, $a0, $s1
	addu $a0, $a0, 54
	#convert size to string
	la $a1, buffer
	li $a2, 4
	jal itoh
	#save file size
	li $v0, 15
	move $a0, $t1
	la $a1, buffer
	li $a2, 4
	syscall
	
	#save reserved bytes
	li $v0, 15
	move $a0, $t1
	la $a1, four_zeros
	li $a2, 4
	syscall
	
	#save offset
	li $v0, 15
	move $a0, $t1
	la $a1, offset
	li $a2, 4
	syscall
	
	#save dib_size
	li $v0, 15
	move $a0, $t1
	la $a1, dib_size
	li $a2, 4
	syscall
	
	#convert width to string
	move $a0, $s0
	la $a1, buffer
	li $a2, 4
	jal itoh
	#save width
	li $v0, 15
	move $a0, $t1
	la $a1, buffer
	li $a2, 4
	syscall
	
	#convert height to string
	move $a0, $s1
	la $a1, buffer
	li $a2, 4
	jal itoh
	#save height
	li $v0, 15
	move $a0, $t1
	la $a1, buffer
	li $a2, 4
	syscall
	
	#save planes
	li $v0, 15
	move $a0, $t1
	la $a1, planes
	li $a2, 2
	syscall
	
	#save bits_per_px
	li $v0, 15
	move $a0, $t1
	la $a1, bits_per_px
	li $a2, 2
	syscall
	
	#save compression
	li $v0, 15
	move $a0, $t1
	la $a1, four_zeros
	li $a2, 4
	syscall
	
	#save image size
	li $v0, 15
	move $a0, $t1
	la $a1, four_zeros
	li $a2, 4
	syscall
	
	#save resolution
	li $v0, 15
	move $a0, $t1
	la $a1, eight_zeros
	li $a2, 8
	syscall
	
	#save colours
	li $v0, 15
	move $a0, $t1
	la $a1, eight_zeros
	li $a2, 8
	syscall
	
## $s0 - widht
## $s1 - height
## $s2 - iterations
## $f20 - Real(i)
## $f22 - Imaginary(i)
## $f24 - scaled real
## $f26 - scaled imaginary
## $t0 - bits to fill 
## $t1 - descriptor
## $t2 - current width
## $t3 - current height
## $t4 - current iteration

	move $t3, $zero
vloop: #vertical loop
	beq $t3, $s1, julia_done
	li $t2, 0
hloop: #horizontal loop
	beq $t2, $s0, next_line
	move $t4, $s2 #current iteration
	
	#scaling real part
	mtc1 $t2, $f4 
	mtc1 $s0, $f6
	jal scale_coordinate
	mov.d $f24, $f0
	
	#scaling imaginary part
	mtc1 $t3, $f4
	mtc1 $s1, $f6
	jal scale_coordinate
	mov.d $f26, $f0
julia:
	beqz $t4, paint_pixel #if max iteration is reached, paint the pixel
	jal condition
	
	beqz $v0, paint_pixel #condition is false, paint the pixel
	
	#xtemp = zx * zx - zy * zy
        #zy = 2 * zx * zy  + cy 
        #zx = xtemp + cx
	mul.d $f12, $f24, $f24
	mul.d $f14, $f26, $f26
	sub.d $f28, $f12, $f14
	
	mul.d $f26, $f24, $f26
	la $t9, two
	l.d $f4, ($t9)
	mul.d $f26, $f26, $f4
	add.d $f26, $f26, $f22
	
	add.d $f24, $f28, $f20
	
	subu $t4, $t4, 1 #iteration done
	b julia
julia_done:
	b end		

paint_pixel:
	#scale reached iterations to hue
	mulu $t8, $t4, 255
	divu $t8, $s2
	mflo $t8
	li $t9, 255
	
	#modifying colours
	sub $t8, $t9, $t8
	li $t9, 60
	
	sb $t9, buffer
	sb $t8, buffer+1
	sb $t8, buffer+2	

	#save pixel
	li $v0, 15
	move $a0, $t1
	la $a1, buffer
	li $a2, 3
	syscall
	
next_pixel:
	addiu $t2, $t2, 1
	b hloop
next_line:
	#copy the amount of 0's to fill
	move $t4, $t0
fill_line:
	#write needed amount of 0's
	beqz $t4, fill_done
	li $v0, 15
	move $a0, $t1
	la $a1, zero
	li $a2, 1
	syscall
	subu $t4, $t4, 1
	b fill_line
fill_done:
	addiu $t3, $t3, 1
	b vloop	
	
scale_coordinate:
	#scale current coordinate in $a0 to (-2,2)
	cvt.d.w $f4, $f4	#word to double
	cvt.d.w $f6, $f6
	la $t8, two
	l.d $f8, ($t8)
	la $t9, four
	l.d $f10, ($t9)
	
	# 4*coordinate/max_value - 2
	mul.d $f4, $f4, $f10
	div.d $f4, $f4, $f6
	sub.d $f0, $f4, $f8
	jr $ra
	
condition:
	#checks if zx^2 + zy^2 < 4
	#zx - scaled real, zy - scaled imaginary
	mul.d $f6, $f24, $f24
	mul.d $f8, $f26, $f26
	add.d $f4, $f6, $f8
	la $t9, four
	l.d $f10, ($t9)
	c.lt.d $f4, $f10
	bc1t true
	li $v0, 0
	jr $ra
true:
	li $v0, 1
	jr $ra
		
itoh:
	#converts integer to a format needed in header
	#reverts the order of bytes by dividing by 2^8 and saving remainder
	li $t8, 256
itoh_loop:
	beqz $a0, itoh_fill
	divu $a0, $t8
	mfhi $t9
	mflo $a0
	sb $t9, ($a1)
	addiu $a1, $a1, 1
	subu $a2, $a2, 1
	b itoh_loop
itoh_fill:
	beqz $a2, itoh_done
	sb $zero, ($a1)
	addiu $a1, $a1, 1
	subu $a2, $a2, 1
	b itoh_fill
itoh_done:
	jr $ra
	
end:
	li $v0, 10
	syscall
