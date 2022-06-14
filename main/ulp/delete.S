	psr
	jump write_intro 
	ld r2,r3,8 //+16




    //this block is equivalent to the above
    //psr macro is replaced 
	.set _next2,(\pos+16)
	move \sr,_next2 //+4
	push \sr //+8
    jump write_intro //+12
    ld r2,r3,8 //+16
