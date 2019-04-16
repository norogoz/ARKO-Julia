##Author: Grzegorz Rogozinski
##ARKO assignment
##
##Draws Julia Sets with given parameters

.data
filename:		.space 64

#header
offset:			.byte 54, 0, 0, 0
dib_size:		.byte 40, 0, 0, 0
four_zeros:		.byte 0, 0, 0, 0
two:			.double 2.0
four:			.double 4.0
signature:		.ascii "BM"
planes:			.byte 1, 0
bits_per_px:		.byte 24, 0

header_buffer:		.space 54
pixel_buffer:		.space 65536

#input messages
string_get_filename:	.asciiz "Filename: "
string_get_width:	.asciiz "Width: "
string_get_height:	.asciiz "Height: "
string_get_iter:	.asciiz "Iterations: "
string_get_real:	.asciiz "Real part: "
string_get_imag:	.asciiz "Imaginary part: "


			

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
etz_loop:
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
	beqz $t0, calculated
	subu $t0, $t1, $t0 #if remainder not 0, number of 0's to fill is 4 - remainder
	
calculated:
	#open file
	li $v0, 13
	la $a0, filename
	li $a1, 1
	li $a2, 0
	syscall
	
	move $t1, $v0 #file descriptor
	
	#create header

	#save signature
	lh $t9, signature
	sh $t9, header_buffer
	
	#file size calculation
	mulu $a0, $s0, 3
	addu $a0, $a0, $t0
	mulu $a0, $a0, $s1
	addu $t5, $a0, 54
	#convert size to header format and save
	li $t6, 2
	li $t7, 4
	jal itoh
	
	#save reserved bytes
	lw $t9, four_zeros
	sw $t9, header_buffer+6
	
	#save offset
	lw $t9, offset
	sw $t9, header_buffer+10
	
	#save dib_size
	lw $t9, dib_size
	sw $t9, header_buffer+14
	
	#convert width to header format and save
	move $t5, $s0
	li $t6, 18
	li $t7, 4
	jal itoh
	
	#convert height to header format and save
	move $t5, $s1
	li $t6, 22
	li $t7, 4
	jal itoh
	
	#save planes
	lh $t9, planes
	sh $t9, header_buffer+26
	
	#save bits_per_px
	lh $t9, bits_per_px
	sh $t9, header_buffer+28
	
	#save compression
	lw $t9, four_zeros
	sw $t9, header_buffer+30
	
	#save image size
	sw $t9, header_buffer+34
	
	#save resolution
	sw $t9, header_buffer+38
	sw $t9, header_buffer+42
	
	#save colours
	sw $t9, header_buffer+46
	sw $t9, header_buffer+50
	
	#save buffer to file
	li $v0, 15
	move $a0, $t1
	la $a1, header_buffer
	li $a2, 54
	syscall
	
## $s0 - widht
## $s1 - height
## $s2 - iterations
## $s3 - pixel buffer size
## $f20 - Real(i)
## $f22 - Imaginary(i)
## $f24 - scaled real
## $f26 - scaled imaginary
## $t0 - bits to fill 
## $t1 - descriptor
## $t2 - current width
## $t3 - current height
## $t4 - current iteration
## $t5- pixel buffer iterator

	move $t3, $zero
	li $s3, 65536
	li $t5, 0
vloop: #vertical loop
	li $t2, 0
hloop: #horizontal loop
	move $t4, $s2 #current iteration for pixel
	
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
	jal condition
	
	beqz $v0, paint_pixel # if condition is false, paint the pixel
	
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
	bnez $t4, julia #if max iteration is reached, paint the pixel

paint_pixel:
	addiu $t2, $t2, 1 #prepare next pixel
	
	#scale reached iterations to hue
	sll $t8, $t4, 8
	subu $t8, $t8, $t4
	divu $t8, $s2
	mflo $t8
	li $t9, 255
	
	#modifying colours
	sub $t8, $t9, $t8
	li $t9, 60
	
	subu $t7, $s3, $t5
	la $ra, px_to_buff
	bgt $t7, 3, save_pixels #if not enough space in buffer, save buffer to file
	
px_to_buff:
	la $t6, pixel_buffer($t5)
	sb $t9, 0($t6)
	sb $t8, 1($t6)
	sb $t8, 2($t6)
	addiu $t5, $t5, 3
	bne $t2, $s0, hloop #if it wasn't the last pixel in line, go to hloop
	
next_line:
	addiu $t3, $t3, 1 #prepare next line
	beqz $t0, fill_done #conditional jump leading to conditional jump, but I have found no way around
	move $t4, $t0 #copy the amount of 0's to fill
	
	subu $t7, $s3, $t5
	la $ra, fill_line
	blt $t7, $t0, save_pixels #if not enough space in buffer, save buffer to file
	
fill_line:
	#write needed amount of 0's to pixel_buffer
	move $a1, $zero
	sb $a1, pixel_buffer
	addu $t5, $t5, 1
	subu $t4, $t4, 1
	bnez $t4, fill_line
	
fill_done:
	bne $t3, $s1, vloop #if it wasn't the last line, go to vloop
	
end:
	jal save_pixels
	li $v0, 10
	syscall
	
## scale coordinate - scales coordinate to (-2,2)
## $f0 - result
## $f4 - coordinate to scale
## #f6 - max value of coordinate
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
	
## condition - checks if zx^2 + zy^2 < 4
## where zx - scaled real, zy - scaled imaginary
## $v0 - result
## $f24 - scaled real
## $f26 - scaled imaginary
condition:
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
	
## itoh - converts integer to a format needed in header, saves to header_buffer
## reverts the order of bytes by dividing by 2^8 and saving remainder
## $t5 - number to convert
## $t6 - header_buffer offset
## $t7 - total bytes to write	
itoh:
	li $t8, 256
itoh_loop:
	divu $t5, $t8
	mfhi $t9
	mflo $t5
	sb $t9, header_buffer($t6)
	addiu $t6, $t6, 1
	subu $t7, $t7, 1
	bnez $t5, itoh_loop
itoh_fill:
	sb $zero, header_buffer($t6)
	addiu $t6, $t6, 1
	subu $t7, $t7, 1
	bgez $t7, itoh_fill
itoh_done:
	jr $ra

##saves pixel_buffer to file (if buffer not empty)
save_pixels:
	beqz $t5, save_done
	
	li $v0, 15
	move $a0, $t1
	la $a1, pixel_buffer
	move $a2, $t5
	syscall
	
	li $t5, 0
save_done:
	jr $ra
