class_name UITheme
extends RefCounted
## 발헤임풍 UI 테마 — 어두운 목재/양피지 톤 + 금빛 테두리.
## 한글 폰트(나눔바른고딕/나눔명조)를 내장해 어떤 환경에서도 한글이 깨지지 않는다.

const FONT_BODY := "res://assets/fonts/NanumBarunGothic.ttf"
const FONT_BOLD := "res://assets/fonts/NanumBarunGothicBold.ttf"
const FONT_TITLE := "res://assets/fonts/NanumMyeongjo.ttf"

const BG := Color(0.09, 0.08, 0.07, 0.95)
const BG_SOFT := Color(0.14, 0.12, 0.10, 0.92)
const SLOT := Color(0.17, 0.15, 0.13, 0.95)
const SLOT_HL := Color(0.30, 0.25, 0.17, 0.98)
const GOLD := Color(0.79, 0.66, 0.38)
const GOLD_DIM := Color(0.48, 0.40, 0.24)
const TEXT := Color(0.92, 0.89, 0.82)
const TEXT_DIM := Color(0.62, 0.59, 0.53)
const RED := Color(0.78, 0.22, 0.20)
const GREEN := Color(0.44, 0.72, 0.32)
const BLUE := Color(0.36, 0.60, 0.82)
const YELLOW := Color(0.88, 0.76, 0.30)

static var _theme: Theme = null
static var _body: FontFile = null
static var _title: FontFile = null

static func body_font() -> FontFile:
	if _body == null:
		_body = load(FONT_BODY)
	return _body

static func title_font() -> FontFile:
	if _title == null:
		_title = load(FONT_TITLE)
	return _title

static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	var f := body_font()
	var fb := load(FONT_BOLD)
	t.default_font = f
	t.default_font_size = 17

	# 패널
	t.set_stylebox("panel", "Panel", panel_box(BG))
	t.set_stylebox("panel", "PanelContainer", panel_box(BG))

	# 버튼
	var normal := panel_box(Color(0.18, 0.16, 0.13, 0.96), GOLD_DIM)
	var hover := panel_box(Color(0.26, 0.22, 0.16, 0.98), GOLD)
	var pressed := panel_box(Color(0.32, 0.27, 0.18, 1.0), GOLD)
	var disabled := panel_box(Color(0.13, 0.12, 0.11, 0.7), Color(0.3, 0.28, 0.24))
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color(1, 0.96, 0.85))
	t.set_color("font_disabled_color", "Button", Color(0.5, 0.48, 0.44))
	t.set_font("font", "Button", fb)
	t.set_font_size("font_size", "Button", 17)

	t.set_color("font_color", "Label", TEXT)
	t.set_font("font", "Label", f)

	# 스크롤
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.05, 0.05, 0.6)
	sb.corner_radius_top_left = 3
	sb.corner_radius_bottom_right = 3
	t.set_stylebox("scroll", "VScrollBar", sb)
	var grab := StyleBoxFlat.new()
	grab.bg_color = GOLD_DIM
	grab.corner_radius_top_left = 3
	grab.corner_radius_bottom_right = 3
	t.set_stylebox("grabber", "VScrollBar", grab)
	var grab_h := StyleBoxFlat.new()
	grab_h.bg_color = GOLD
	t.set_stylebox("grabber_highlight", "VScrollBar", grab_h)
	t.set_stylebox("grabber_pressed", "VScrollBar", grab_h)

	# 진행 바
	t.set_stylebox("background", "ProgressBar", panel_box(Color(0.06, 0.05, 0.05, 0.85)))
	var fill := StyleBoxFlat.new()
	fill.bg_color = GOLD
	t.set_stylebox("fill", "ProgressBar", fill)

	# 입력창
	t.set_stylebox("normal", "LineEdit", panel_box(Color(0.08, 0.07, 0.06, 0.95), GOLD_DIM))
	t.set_stylebox("focus", "LineEdit", panel_box(Color(0.10, 0.09, 0.07, 1.0), GOLD))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("caret_color", "LineEdit", GOLD)

	# 툴팁
	t.set_stylebox("panel", "TooltipPanel", panel_box(Color(0.06, 0.05, 0.05, 0.98), GOLD))
	t.set_color("font_color", "TooltipLabel", TEXT)

	_theme = t
	return t

static func panel_box(bg: Color, border: Color = Color(0.30, 0.26, 0.20),
		radius: int = 4, width: int = 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s

static func slot_box(highlight: bool = false, equipped: bool = false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = SLOT_HL if highlight else SLOT
	s.border_color = GOLD if equipped else Color(0.32, 0.28, 0.22)
	s.set_border_width_all(3 if equipped else 2)
	s.set_corner_radius_all(3)
	return s

## 제목 라벨
static func title(text: String, size: int = 26, col: Color = GOLD) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", title_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 5)
	return l

static func label(text: String, size: int = 16, col: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 4)
	return l

static func button(text: String, size: int = 17) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.focus_mode = Control.FOCUS_NONE
	return b

## 체력/스태미나 등에 쓰는 커스텀 바
static func make_bar(col: Color, w: float, h: float) -> ProgressBar:
	var p := ProgressBar.new()
	p.custom_minimum_size = Vector2(w, h)
	p.show_percentage = false
	p.max_value = 1.0
	p.value = 1.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.04, 0.04, 0.80)
	bg.border_color = Color(0.28, 0.24, 0.18, 0.9)
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(3)
	var fg := StyleBoxFlat.new()
	fg.bg_color = col
	fg.set_corner_radius_all(2)
	p.add_theme_stylebox_override("background", bg)
	p.add_theme_stylebox_override("fill", fg)
	return p
