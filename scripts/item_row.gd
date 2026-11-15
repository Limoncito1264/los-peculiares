extends Control
## res://scripts/item_row.gd
## Fila de material/circuito con botones [-] n [+] (0 a 99).

const Catalog = preload("res://data/shop_catalog.gd")
const HOLD_DELAY := 1.0
const REPEAT_INTERVAL := 0.07

signal quantity_changed(item_id: String, qty: int)

@onready var lbl_nombre: Label = %LblNombre
@onready var lbl_precio: Label = %LblPrecio
@onready var lbl_entrega: Label = %LblEntrega
@onready var btn_menos: Button = %BtnMenos
@onready var lbl_cantidad: Label = %LblCantidad
@onready var btn_mas: Button = %BtnMas

var item_id: String = ""
var cantidad: int = 0
var _data: Dictionary = {}
var _locked: bool = false

var _hold_dir: int = 0
var _hold_elapsed: float = 0.0
var _repeat_accum: float = 0.0


func _ready() -> void:
	btn_menos.button_down.connect(_start_hold.bind(-1))
	btn_menos.button_up.connect(_stop_hold)
	btn_mas.button_down.connect(_start_hold.bind(1))
	btn_mas.button_up.connect(_stop_hold)
	set_process(false)
	_apply_static()
	_refresh_qty()


func _process(delta: float) -> void:
	if _locked or _hold_dir == 0:
		_stop_hold()
		return
	var btn := btn_mas if _hold_dir > 0 else btn_menos
	if btn.disabled or not btn.button_pressed:
		_stop_hold()
		return
	_hold_elapsed += delta
	if _hold_elapsed >= HOLD_DELAY:
		_repeat_accum += delta
		while _repeat_accum >= REPEAT_INTERVAL:
			_repeat_accum -= REPEAT_INTERVAL
			set_cantidad(cantidad + _hold_dir)
			if btn.disabled:
				_stop_hold()
				return


func _start_hold(dir: int) -> void:
	if _locked:
		return
	_hold_dir = dir
	_hold_elapsed = 0.0
	_repeat_accum = 0.0
	set_cantidad(cantidad + dir)
	set_process(true)


func _stop_hold() -> void:
	_hold_dir = 0
	_hold_elapsed = 0.0
	_repeat_accum = 0.0
	set_process(false)


## item: {id, nombre, precio, dias} (de Catalog.materials()/circuits())
func setup(item: Dictionary) -> void:
	_data = item
	item_id = str(item["id"])
	if is_node_ready():
		_apply_static()


func set_cantidad(n: int, emit: bool = true) -> void:
	cantidad = clampi(n, 0, Catalog.MAX_QTY)
	_refresh_qty()
	if emit:
		quantity_changed.emit(item_id, cantidad)


func reset() -> void:
	_stop_hold()
	set_cantidad(0, false)


func set_locked(locked: bool) -> void:
	_locked = locked
	if _locked:
		_stop_hold()
	if is_node_ready():
		_refresh_qty()


func _apply_static() -> void:
	if _data.is_empty():
		return
	lbl_nombre.text = str(_data["nombre"])
	lbl_precio.text = "$%d" % int(_data["precio"])
	lbl_entrega.text = "%d d" % int(_data["dias"])


func _refresh_qty() -> void:
	lbl_cantidad.text = str(cantidad)
	btn_menos.disabled = _locked or cantidad <= 0
	btn_mas.disabled = _locked or cantidad >= Catalog.MAX_QTY
