class_name AresUI
extends RefCounted
## Colores, fuentes y fábricas de widgets del diseño ARES (Figma NASA).
## Todo se construye por código: no necesita Theme ni recursos extra.

# --- Paleta [Figma] ---
const BG_DEEP := Color("070b13")
const BG_INSET := Color("0b131f")
const BG_PANEL := Color("101a28")
const GRID := Color("162737")
const BORDER := Color("2e4254")
const TEXT := Color("e4ecdd")
const MUTED := Color("9aadb8")
const AMBER := Color("f5bc67")
const TEAL := Color("79c9b1")
const STEPPER_BG := Color("172b31")
const LAUNCH_BG := Color("25251f")
const LAUNCH_BORDER := Color("82663c")
const OVERLAY := Color(0.027, 0.043, 0.075, 0.94)   # rgba(7,11,19,0.94)

# Descarga las fuentes de Google Fonts y ponlas aquí (si no existen, usa la fuente por defecto).
const FONT_TITLE_PATH := "res://assets/fonts/PixelifySans-Bold.ttf"
const FONT_BODY_PATH := "res://assets/fonts/IBMPlexMono-Regular.ttf"

static var _fonts: Dictionary = {}


static func _font(path: String) -> Font:
	if not _fonts.has(path):
		if ResourceLoader.exists(path):
			_fonts[path] = load(path)
		else:
			_fonts[path] = null
	return _fonts[path]


static func box(bg: Color, border: Color = BORDER, margin: float = 0.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_content_margin_all(margin)
	return sb


static func label(text: String, size: int = 12, color: Color = TEXT, title: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	var f := _font(FONT_TITLE_PATH if title else FONT_BODY_PATH)
	if f != null:
		l.add_theme_font_override("font", f)
	return l


static func wrapped(text: String, size: int = 14, color: Color = MUTED) -> Label:
	var l := label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


static func hline() -> ColorRect:
	var r := ColorRect.new()
	r.color = BORDER
	r.custom_minimum_size = Vector2(0, 1)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func spacer() -> Control:
	var c := Control.new()
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func _btn_box(bg: Color, bd: Color) -> StyleBoxFlat:
	var sb := box(bg, bd)
	sb.content_margin_left = 15
	sb.content_margin_right = 15
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb


## variant: "primary" (ámbar), "secondary" (borde gris), "teal" (contorno verde)
static func button(text: String, variant: String = "secondary", height: float = 48.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, height)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", 13)
	var f := _font(FONT_BODY_PATH)
	if f != null:
		b.add_theme_font_override("font", f)
	var bg := BG_INSET
	var bd := BORDER
	var fg := TEXT
	match variant:
		"primary":
			bg = AMBER
			bd = AMBER
			fg = BG_DEEP
		"teal":
			bd = TEAL
			fg = TEAL
	b.add_theme_stylebox_override("normal", _btn_box(bg, bd))
	b.add_theme_stylebox_override("hover", _btn_box(bg.lightened(0.12), bd.lightened(0.15)))
	b.add_theme_stylebox_override("pressed", _btn_box(bg.darkened(0.15), bd))
	b.add_theme_stylebox_override("disabled", _btn_box(BG_INSET, BORDER))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg)
	b.add_theme_color_override("font_pressed_color", fg)
	b.add_theme_color_override("font_disabled_color", MUTED.darkened(0.35))
	return b


## Botón "-" / "+" del selector de trabajadores.
static func stepper_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(40, 42)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", 19)
	var f := _font(FONT_TITLE_PATH)
	if f != null:
		b.add_theme_font_override("font", f)
	b.add_theme_stylebox_override("normal", box(STEPPER_BG, STEPPER_BG))
	b.add_theme_stylebox_override("hover", box(STEPPER_BG.lightened(0.15), STEPPER_BG.lightened(0.15)))
	b.add_theme_stylebox_override("pressed", box(STEPPER_BG.darkened(0.2), STEPPER_BG.darkened(0.2)))
	b.add_theme_stylebox_override("disabled", box(BG_INSET, BG_INSET))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", TEAL)
	b.add_theme_color_override("font_hover_color", TEAL)
	b.add_theme_color_override("font_pressed_color", TEAL)
	b.add_theme_color_override("font_disabled_color", MUTED.darkened(0.4))
	return b


## Modal a pantalla completa: fondo oscuro + tarjeta de 800 px centrada con barra de acento de 5 px.
## Devuelve {"root": Control, "body": VBoxContainer}. Añade "root" a un nodo Control de pantalla completa.
static func modal(accent: Color, height: float) -> Dictionary:
	var root := ColorRect.new()
	root.color = OVERLAY
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP   # bloquea clics al fondo

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(800, height)
	card.add_theme_stylebox_override("panel", box(BG_PANEL, accent))
	center.add_child(card)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	card.add_child(col)

	var bar := ColorRect.new()
	bar.color = accent
	bar.custom_minimum_size = Vector2(0, 5)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(bar)

	var margin := MarginContainer.new()
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	col.add_child(margin)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	margin.add_child(body)

	return {"root": root, "body": body}
