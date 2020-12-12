#####################################################################
# Bitmap Display Configuration:
# - Unit width in pixels: 8
# - Unit height in pixels: 8
# - Display width in pixels: 256
# - Display height in pixels: 256
# - Base Address for Display: 0x10008000 ($gp)
#####################################################################

.data
	displayAddress: .word 0x10008000 
	backgroundColour: .word 0x00ffe5cc 
	
	platformColour1: .word 0x0099ff33 
	platformColour2: .word 0x0000ff00 
	platformColour3: .word 0x00009900 
	platformMoveDown: .word 0 # how many units left should platfrom move down
	firstPlatformAddress: .word 0x10008580
	firstPlatformAddressBuffer: .word 0x10008580
	secondPlatformAddress: .word 0x10008A80
	secondPlatformAddressBuffer: .word 0x10008A80
	thirdPlatformAddress: .word 0x10008F80
	thirdPlatformAddressBuffer: .word 0x10008F80
	
	doodlerColour: .word 0x00a0a0a0 
	doodlerAddress: .word 0x10008B40 # 268471104
	doodlerDirection: .word 1 # 1 means doodler moves upwards, 0 means downwards
	doodlerPower: .word 10 # 0 power left to move upwards
	doodlerProgress: .word 0 # how many steps already taken
	
	cloudColour: .word 0x99ccff
	cloudAddress: .word 0x10008000
	cloudDirection: .word 0 # 0 means moving right, 1 means moving left
	
	notificationColour: .word 0x00fc973f
	notificationAddress: .word 0x10008100
	notificationCountDown: .word 0
	notificationProgress: .word 10
	
	GGAddress: .word 0x10008528


.text
	Initialize:
	
	# Draw background
	lw $t0, displayAddress # Store display address in $t0
	lw $t1, backgroundColour # Store background colour in $t1
	addi $t2, $t0, 16384 # Store the end point of display address in $t3
	BackgroundFillIn:
		beq $t0, $t2, ExitBackgroundFillIn
		sw $t1, 0($t0)
		addi $t0, $t0, 4
		j BackgroundFillIn
	ExitBackgroundFillIn:
	
	# Draw three platforms
	lw $t0, firstPlatformAddress # y-axis of first platform
	lw $t1, platformColour1
	jal DrawSinglePlatform
	add $t0, $t0, $a0
	sw $t0, firstPlatformAddress
	
	lw $t0, secondPlatformAddress
	lw $t1, platformColour2
	jal DrawSinglePlatform
	add $t0, $t0, $a0
	sw $t0, secondPlatformAddress
	
	lw $t0, thirdPlatformAddress
	lw $t1, platformColour3
	jal DrawSinglePlatform
	add $t0, $t0, $a0
	sw $t0, thirdPlatformAddress
	
	# Draw doodler
	lw $t0, doodlerAddress # Doodler base address
	lw $t1, doodlerColour # colour of doodler
	jal DrawDoodler
	
	jal DrawCloud
	
	main:
	
	jal DrawWow
	
	jal ReDrawPlatform
	
	jal MoveDoodlerUpOrDown
	
	# check moving left or right or stay
	lw $t8, 0xffff0000
	beq $t8, 1, ReadyLeftOrRight
	j NotReadyLeftOrRight
	ReadyLeftOrRight:
		jal PossibleLeftOrRight
	NotReadyLeftOrRight:
	
	
	# if doodler drops, press s to retry
	lw $t0, doodlerAddress
	lw $t1, displayAddress
	addi $t1, $t1, 3968 # 128 * 31
	bgt $t0, $t1, Retry
	
	jal PlayBackgroundMusic
	
	jal DrawCloud
	
	# increase speed as doodler takes more steps,
	# but system sleep time is at least 50
	lw $t0, doodlerProgress
	mul $t0, $t0, 5
	addi $t1, $zero, 200
	sub $t0, $t1, $t0
	bgt $t0, 50, SystemSleep
	addi $t0, $zero, 50
	
	SystemSleep:
	li $v0, 32
	add $a0, $t0, $zero # li $a0, 200
	syscall
	j main
	
	
	DrawSinglePlatform:
		# move the pointer, and store $ra
		addi $sp, $sp, -4
		sw $ra, 0($sp)
		# Generate a random number between 28 and 42 in $a0
		li $v0, 42
		li $a0, 0
		li $a1, 28
		syscall
		mul $a0, $a0, 4 # multiply by 4
		add $t3, $t0, $a0 # store the location in $t3
		add $t2, $t3, 20
		jal SinglePlatform
		# move the pointer, and restore $ra
		lw $ra, 0($sp)
		addi $sp, $sp, 4
		jr $ra
		
	SinglePlatform:
		# move the pointer, and store $ra
		addi $sp, $sp, -4
		sw $ra, 0($sp)
		
		# $t1 is colour, $t3 is starting address, $t2 is ending address
		StartDrawSinglePlatform:
			beq $t3, $t2, EndSinglePlatform
			sw $t1, 0($t3)
			addi $t3, $t3, 4
			j StartDrawSinglePlatform
		EndSinglePlatform:
		
		# move the pointer, and restore $ra
		lw $ra, 0($sp)
		addi $sp, $sp, 4
		jr $ra
		
	ReDrawPlatform:
		# If doodler is high enough, move down three platforms 
		# If the bottom platform disappear, genearte a new one randomly
		# and change the order of three platforms
		
		# move the pointer, and store $ra
		addi $sp, $sp, -4
		sw $ra, 0($sp)
		
		addi $s7, $zero, 0 # to detect if platform move
		
		lw $t4, firstPlatformAddress
		sw $t4, firstPlatformAddressBuffer
		lw $t5, secondPlatformAddress
		sw $t5, secondPlatformAddressBuffer
		lw $t6, thirdPlatformAddress
		sw $t6, thirdPlatformAddressBuffer
		
		
		# if doodler is high enough, and platform not moving down, set platformMoveDown to 10
		lw $t0, doodlerAddress
		lw $t1, displayAddress
		addi $t1, $t1, 1408 # doodler should higher than $t1 to let platforms move
		blt $t1, $t0, IfPlatformOutOfBound # if doodler is not high enough
		lw $t3, platformMoveDown
		bne $t3, 0, MovePlatformAddress # platform is moving
		
		# set platformMoveDown to 10
		addi $t3, $zero, 10
		sw $t3, platformMoveDown
		
		MovePlatformAddress:
			# move platform down
			addi $t3, $t3, -1
			sw $t3, platformMoveDown # power off by 1
			
			addi $t4, $t4, 128 # move down one line
			sw $t4, firstPlatformAddress
			
			addi $t5, $t5, 128 # move down one line
			sw $t5, secondPlatformAddress
			
			addi $t6, $t6, 128 # move down one line
			sw $t6, thirdPlatformAddress
			
			addi $s7, $s7, 1 # platform move, record it
		
		IfPlatformOutOfBound:
			# If the bottom platform out of bound, genearte a new one randomly
			# and change the order of three platforms
			lw $t3, displayAddress
			addi $t7, $t3, 4096
			bgt $t7, $t6, CheckIfNeedToReDraw # if the bottom platform is out of bound
			addi $s7, $s7, 1 # platform move, record it
			# generate a new address for highest platform
			addi $t7, $t3, 256
			li $v0, 42
			li $a0, 0
			li $a1, 28
			syscall # Generate a random number between 28 and 42 in $a0
			mul $a0, $a0, 4 # multiply by 4
			add $t7, $t7, $a0 # address for new platform
			sw $t4, secondPlatformAddress
			sw $t5, thirdPlatformAddress
			sw $t7, firstPlatformAddress
			addi $t3, $zero, 9
			sw $t3, platformMoveDown
		
		CheckIfNeedToReDraw:
		beq $s7, 0, NotNeedToReDraw
		
		ReDrawThreePlatform:
		jal EraseThreePlatforms
		
		NotNeedToReDraw:
		jal DrawThreePlatforms
		# move the pointer, and restore $ra
		lw $ra, 0($sp)
		addi $sp, $sp, 4
		jr $ra
		
	EraseThreePlatforms:
		# $t1 is colour
		# move the pointer, and store $ra
		addi $sp, $sp, -4
		sw $ra, 0($sp)
		
		lw $t1, backgroundColour
		lw $t3, firstPlatformAddressBuffer
		addi $t2, $t3, 20
		jal SinglePlatform
		
		
		lw $t1, backgroundColour
		lw $t3, secondPlatformAddressBuffer
		addi $t2, $t3, 20
		jal SinglePlatform
		
		lw $t1, backgroundColour
		lw $t3, thirdPlatformAddressBuffer
		addi $t2, $t3, 20
		jal SinglePlatform
		# move the pointer, and restore $ra
		lw $ra, 0($sp)
		addi $sp, $sp, 4
		jr $ra
		
	
	DrawThreePlatforms:
		# $t1 is colour
		# move the pointer, and store $ra
		addi $sp, $sp, -4
		sw $ra, 0($sp)
		
		lw $t1, platformColour1
		lw $t3, firstPlatformAddress
		addi $t2, $t3, 20
		jal SinglePlatform
		
		
		
		lw $t1, platformColour2
		lw $t3, secondPlatformAddress
		addi $t2, $t3, 20
		jal SinglePlatform 
		
		
		
		lw $t1, platformColour3
		lw $t3, thirdPlatformAddress
		addi $t2, $t3, 20
		jal SinglePlatform
		
		
		# requirement for SinglePlatform:
		# $t3 is starting address, $t2 is ending address
		
		
		# move the pointer, and restore $ra
		lw $ra, 0($sp)
		addi $sp, $sp, 4
		jr $ra
		
	
	DrawDoodler:
		# move the pointer, and store $ra
		addi $sp, $sp, -4
		sw $ra, 0($sp)
		
		sw $t1, -8($t0)
		sw $t1, -140($t0)
		sw $t1, 8($t0)
		sw $t1, -116($t0)
		sw $t1, 0($t0)
		sw $t1, 124($t0)
		sw $t1, 128($t0)
		sw $t1, 132($t0)
		sw $t1, 252($t0)
		sw $t1, 260($t0)
		
		# move the pointer, and restore $ra
		lw $ra, 0($sp)
		addi $sp, $sp, 4
		jr $ra
		
	MoveDoodlerUpOrDown:
		# move the pointer, and store $ra
		addi $sp, $sp, -4
		sw $ra, 0($sp)
		
		# earse doodler first
		lw $t0, doodlerAddress # Doodler current address
		lw $t1, backgroundColour
		jal DrawDoodler
		
		# store the left most bottom address of doodler
		addi $t3, $t0, 380
		
		# Check if doodler touches the platforms
		lw $t4, thirdPlatformAddress # left most address of platform
		jal CheckIfDoodlerTouchesPlatform
		lw $t4, secondPlatformAddress
		jal CheckIfDoodlerTouchesPlatform
		lw $t4, firstPlatformAddress
		jal CheckIfDoodlerTouchesPlatform
		
		lw $t2, doodlerDirection # Moving direction
		beq $t2, 1, MovingUp
		add $t0, $t0, 128
		j AfterMovingUpOrDown
		MovingUp: 
			add $t0, $t0, -128
			lw $s0, doodlerPower
			addi $s0, $s0, -1
			sw $s0, doodlerPower
			beq $s0, 0, ChangeToDown
			j AfterMovingUpOrDown
			ChangeToDown:
				sw $s0, doodlerDirection
		
		AfterMovingUpOrDown:
		sw $t0, doodlerAddress
		lw $t1, doodlerColour
		jal DrawDoodler
		
		
		# move the pointer, and restore $ra
		lw $ra, 0($sp)
		addi $sp, $sp, 4
		jr $ra
	
	
	CheckIfDoodlerTouchesPlatform:
		# move the pointer, and store $ra
		addi $sp, $sp, -4
		sw $ra, 0($sp)
		
		# doodler has to be moving down
		lw $s1, doodlerDirection
		bne $s1, 0, FinishChecking
		addi $t5, $zero, -8 # use $t5 to store the offset of left most address of platform
		IfDoodlerTouchesPlatform:
			beq $t5, 20, FinishChecking
			add $t6, $t4, $t5
			addi $t5, $t5, 4
			beq $t6, $t3, TouchesTogether
			j IfDoodlerTouchesPlatform
			TouchesTogether:
				# play sound effect
				li $v0, 31
				li $a0, 40
				li $a1, 20
				li $a2, 120
				li $a3, 90
				syscall
				# change variables
				lw $t5, doodlerProgress
				addi $t5, $t5, 1
				sw $t5, doodlerProgress
				addi $t5, $zero, 1
				sw $t5, doodlerDirection
				lw $t5, doodlerPower
				bne $t5, 0, FinishChecking
				addi $t5, $zero, 11
				sw $t5, doodlerPower
		
		FinishChecking:
		
		# move the pointer, and restore $ra
		lw $ra, 0($sp)
		addi $sp, $sp, 4
		jr $ra
		
		
	MoveDoodlerLeftOrRight:
		# move the pointer, and store $ra
		addi $sp, $sp, -4
		sw $ra, 0($sp)
		
		# earse doodler first
		lw $t0, doodlerAddress # Doodler current address
		lw $t1, backgroundColour
		jal DrawDoodler
		
		# depending on $a1 to updating doodler address to left or right
		# if $a1=0 move to left
		beq $a1, 0, MoveLeft
		addi $t0, $t0, 4
		j AfterMovingLeftOrRight
		MoveLeft: addi $t0, $t0, -4
		
		AfterMovingLeftOrRight:
		sw $t0, doodlerAddress
		lw $t1, doodlerColour
		jal DrawDoodler
		
		# move the pointer, and restore $ra
		lw $ra, 0($sp)
		addi $sp, $sp, 4
		jr $ra
		
	PossibleLeftOrRight:
		# move the pointer, and store $ra
		addi $sp, $sp, -4
		sw $ra, 0($sp)
		
		# check keyboard input value
		lw $t7, 0xffff0004
		beq $t7, 0x6a, jPressed # j is pressed
		beq $t7, 0x6b, kPressed # k is pressed
		j NothingPressed
		jPressed:
			li $a1, 0
			j StartMoveLeftOrRight
		kPressed:
			li $a1, 1
			j StartMoveLeftOrRight
		StartMoveLeftOrRight:
			jal MoveDoodlerLeftOrRight
		NothingPressed:
		
		
		# move the pointer, and restore $ra
		lw $ra, 0($sp)
		addi $sp, $sp, 4
		jr $ra
		
	
	DrawCloud:
		# move the pointer, and store $ra
		addi $sp, $sp, -4
		sw $ra, 0($sp)
		
		lw $a0, backgroundColour
		lw $a1, cloudAddress
		jal CloudShape
		
		lw $t2, displayAddress
		addi $t2, $t2, 108
		lw $t1, cloudDirection
		# update cloud address
		# check right edge
		beq $t1, 1, CheckLeftEdge
		blt $a1, $t2, CloudMoveRight
		addi $t0, $zero, 1
		sw $t0, cloudDirection
		j CloudMoveLeft
		
		
		CloudMoveRight:
			addi $a1, $a1, 4
			sw $a1, cloudAddress
			j ReDrawCloud
		
		CheckLeftEdge:
			bne $a1, 0x10008000, CloudMoveLeft
			addi $t0, $zero, 0
			sw $t0, cloudDirection
			j CloudMoveRight
			
		CloudMoveLeft:
			addi $a1, $a1, -4
			sw $a1, cloudAddress
			j ReDrawCloud
		
		
		ReDrawCloud:
		lw $a0, cloudColour
		jal CloudShape
		
		# move the pointer, and restore $ra
		lw $ra, 0($sp)
		addi $sp, $sp, 4
		jr $ra
		
	CloudShape:
		sw $a0, 0($a1)
		sw $a0, 8($a1)
		sw $a0, 16($a1)
		sw $a0, 132($a1)
		sw $a0, 136($a1)
		sw $a0, 140($a1)
		jr $ra
		
	DrawWow:
		# move the pointer, and store $ra
		addi $sp, $sp, -4
		sw $ra, 0($sp)
		
		lw $t3, notificationProgress
		lw $t4, doodlerProgress
		bne $t3, $t4, CheckWowCountDown
		addi $t3, $t3, 10
		sw $t3, notificationProgress
		lw $t2, notificationCountDown
		addi $t2, $t2, 10
		sw $t2, notificationCountDown
		
		CheckWowCountDown:
		lw $t2, notificationCountDown
		beq $t2, 0, NoNotification
		lw $t0, notificationColour
		addi $t2, $t2, -1
		sw $t2, notificationCountDown
		j DrawingWow
		
		NoNotification:
			lw $t0, backgroundColour
		
		DrawingWow:
		jal WowShape
		
		# move the pointer, and restore $ra
		lw $ra, 0($sp)
		addi $sp, $sp, 4
		jr $ra
	
	WowShape:
		# move the pointer, and store $ra
		addi $sp, $sp, -4
		sw $ra, 0($sp)
		
		lw $t1, notificationAddress
		
		# big W
		sw $t0, 0($t1)
		sw $t0, 24($t1)
		sw $t0, 132($t1)
		sw $t0, 140($t1)
		sw $t0, 148($t1)
		sw $t0, 264($t1)
		sw $t0, 272($t1)
		
		# o
		sw $t0, 36($t1)
		sw $t0, 160($t1)
		sw $t0, 168($t1)
		sw $t0, 288($t1)
		sw $t0, 296($t1)
		sw $t0, 420($t1)
		
		# little w
		sw $t0, 176($t1)
		sw $t0, 184($t1)
		sw $t0, 192($t1)
		sw $t0, 308($t1)
		sw $t0, 316($t1)
		
		# exclamation mark
		sw $t0, 72($t1)
		sw $t0, 200($t1)
		sw $t0, 328($t1)
		sw $t0, 584($t1)
		
		# move the pointer, and restore $ra
		lw $ra, 0($sp)
		addi $sp, $sp, 4
		jr $ra
		
	
	GGShape:
		# move the pointer, and store $ra
		addi $sp, $sp, -4
		sw $ra, 0($sp)
		
		lw $t0, notificationColour
		lw $t1, GGAddress
		
		sw $t0, 4($t1)
		sw $t0, 8($t1)
		sw $t0, 12($t1)
		sw $t0, 128($t1)
		sw $t0, 144($t1)
		sw $t0, 256($t1)
		sw $t0, 272($t1)
		sw $t0, 384($t1)
		sw $t0, 512($t1)
		sw $t0, 520($t1)
		sw $t0, 524($t1)
		sw $t0, 640($t1)
		sw $t0, 656($t1)
		sw $t0, 772($t1)
		sw $t0, 776($t1)
		sw $t0, 780($t1)
		
		addi $t1, $t1, 24
		sw $t0, 4($t1)
		sw $t0, 8($t1)
		sw $t0, 12($t1)
		sw $t0, 128($t1)
		sw $t0, 144($t1)
		sw $t0, 256($t1)
		sw $t0, 272($t1)
		sw $t0, 384($t1)
		sw $t0, 512($t1)
		sw $t0, 520($t1)
		sw $t0, 524($t1)
		sw $t0, 640($t1)
		sw $t0, 656($t1)
		sw $t0, 772($t1)
		sw $t0, 776($t1)
		sw $t0, 780($t1)
		
		# move the pointer, and restore $ra
		lw $ra, 0($sp)
		addi $sp, $sp, 4
		jr $ra
		
		
	PlayBackgroundMusic:
		# move the pointer, and store $ra
		addi $sp, $sp, -4
		sw $ra, 0($sp)
		
		li $v0, 31 # set system
		lw $a2, doodlerProgress # set instrument
		blt $a2, 127, PartyBegins
		addi $a2, $zero, 5
		
		PartyBegins:
		# play sound
		li $a0, 40 # pitch
		li $a1, 15 # duration
		li $a3, 20 # volume
		syscall
		
		li $a3, 80
		syscall
		
		li $a0, 60
		li $a1, 30
		syscall
		
		
		# move the pointer, and restore $ra
		lw $ra, 0($sp)
		addi $sp, $sp, 4
		jr $ra
		
		
	Retry:
		lw $t8, 0xffff0000
		bne $t8, 1, NoRetry
		
		lw $t8, 0xffff0004
		bne $t8, 0x73, NoRetry
		
		addi $t1, $zero, 0
		sw $t1, platformMoveDown
		addi $t1, $zero, 0x10008580
		sw $t1, firstPlatformAddress
		addi $t1, $zero, 0x10008A80
		sw $t1, secondPlatformAddress
		addi $t1, $zero, 0x10008F80
		sw $t1, thirdPlatformAddress
		addi $t1, $zero, 0x10008B40
		sw $t1, doodlerAddress
		addi $t1, $zero, 1
		sw $t1, doodlerDirection
		addi $t1, $zero, 10
		sw $t1, doodlerPower
		sw $t1, notificationProgress
		addi $t1, $zero, 0
		sw $t1, doodlerProgress
		
		
		j Initialize
		
		NoRetry:
		jal GGShape
		j Retry
		
		
