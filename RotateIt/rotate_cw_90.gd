
extends Node2D

# member variables here, example:
# var a=2
# var b="textvar"

func _ready():
	# Initalization here
	print ("my init")
	get_node("sprite").get_node("anim").play("rotate")
	pass


