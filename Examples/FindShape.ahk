#NoEnv
#SingleInstance Force
SetBatchLines -1
recColor := 0x00FFFF
return 

f7::
	coordmode,pixel,screen
	coordmode,mouse,screen	
	mousegetpos,sx,sy	
	tooltip % sx "`n" sy
	PixelGetColor, clr, % sx, % sy,RGB
	if(clr != recColor)
	{
		msgbox % "hover over the rectangle before starting.`nsearch color " . recColor . " color hovered " . clr
	}
	else
	{
		rec := findRectangle(recColor,sx,sy)
        centerX := (rec.p1.x + rec.p2.x) // 2
        centerY := (rec.p1.y + rec.p2.y) // 2

		; msgbox % "Upper left : " . rec.p1.x . "," . rec.p1.y . "`n" . "Bottom Right : " . rec.p2.x . "," . rec.p2.y  
		mousemove % rec.p1.x , % rec.p1.y,10
		sleep 250
		mousemove % rec.p2.x , % rec.p1.y,10
		sleep 250
		mousemove % rec.p2.x , % rec.p2.y,10
		sleep 250
		mousemove % rec.p1.x , % rec.p2.y,10
        sleep 250
        MouseMove, %centerX%, %centerY%, 10
	}
return

findRectangle(searchColor,guessX,guessY)
{
	pos := findEdge(searchColor,guessX,guessY,-50,0) ;rough scan left 25 px step
	leftEdge := findEdge(searchColor,pos.x ,pos.y,-1,0) ;precice scan to find edge from last know good pos
	
	pos := findEdge(searchColor,guessX,guessY,50,0) 
	rightEdge := findEdge(searchColor,pos.x ,pos.y,1,0) 
	
	pos := findEdge(searchColor,guessX,guessY,0,-50) 
	topEdge := findEdge(searchColor,pos.x ,pos.y,0,-1) 
	
	pos := findEdge(searchColor,guessX,guessY,0,50) 
	bottomEdge := findEdge(searchColor,pos.x ,pos.y,0,1) 
	return {p1:{x:leftEdge.x,y:topEdge.y},p2:{x:rightEdge.x,y:bottomEdge.y}}
}

findEdge(searchClr,sx,sy,xstep,ystep)
{
	lastSuccess := ""
	Loop
	{
		s := a_index - 1 
		px := sx+s*xstep
		py := sy+s*ystep
		PixelGetColor, clr, % px,  % py,RGB
		if(clr != searchClr)
		{			
			return lastSuccess 
		}
		lastSuccess := {x:px,y:py}
	}
}