class_name BoundedHistory


const BOUND := 5

var arr := []
var pointer := 0
var n := 0
var i := 0


func _init():
	for i in range(BOUND):
		arr.append(-1)


func _to_string():
	return str(arr)


func push(elem) -> bool:
	pointer = (pointer + i - n + BOUND) % BOUND
	n = min(i, n)
	
	arr[pointer] = elem
	pointer = (pointer + 1) % BOUND
	var _n = n
	n = min(n + 1, BOUND)
	i = n
	return _n == n


func move_forward():
	assert(i < n)
	i = i + 1
	var temp = arr[(pointer + i - n - 1 + BOUND) % BOUND]
	return temp


func can_move_forward():
	return i < n


func move_backward():
	assert(i > 0)
	var temp = arr[(pointer + i - n - 1 + BOUND) % BOUND]
	i = i - 1
	return temp


func can_move_backward():
	return i > 0
