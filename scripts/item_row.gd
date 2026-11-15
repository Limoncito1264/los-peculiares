extends Control
## res://scripts/item_row.gd
## Fila de material/circuito con botones [-] n [+] (0 a 99).

const Catalog = preload("res://data/shop_catalog.gd")

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


func _ready() -> void:
	btn_menos.pressed.connect(func(): set_cantidad(cantidad - 1))
	btn_mas.pressed.connect(func(): set_cantidad(cantidad + 1))
	_apply_static()
	_refresh_qty()


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
	set_cantidad(0, false)


func set_locked(locked: bool) -> void:
	_locked = locked
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
