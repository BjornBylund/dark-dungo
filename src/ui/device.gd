## What the game runs on: whether touch input is in use, and whether the screen
## is small enough for the phone layout. The Mobile autoload sets these at
## startup and keeps `touch` current; `--touch` and `--phone` force them for
## testing on desktop.
class_name Device
extends RefCounted

## Phones get the phone layout below this many CSS pixels on the screen's short side.
const PHONE_SHORT_SIDE := 600.0
## The phone layout's logical screen: half of the 1920x1080 the screens are
## authored at, so text and buttons come out twice as large.
const PHONE_SCALE_SIZE := Vector2i(960, 540)
const STAGE_SIZE := Vector2(1920, 1080)

## The last input came from a touchscreen (taps arrive as emulated mouse clicks).
static var touch := false
## Phone layout: the logical screen is PHONE_SCALE_SIZE and screens rearrange.
static var phone := false
## A phone or tablet, which should be held sideways.
static var handheld := false


static func is_phone_size(css_width: float, css_height: float) -> bool:
	return minf(css_width, css_height) < PHONE_SHORT_SIDE


## Scales and centres a screen's 1920x1080 stage in `view_size`. On desktop the
## stage keeps its size and the window letterboxes around it; with the phone
## layout it shrinks to fit, and the phone controls are drawn at full size on top.
static func fit_stage(stage: Control, view_size: Vector2) -> void:
	var scale := stage_scale(view_size)
	stage.scale = Vector2(scale, scale)
	stage.position = ((view_size - STAGE_SIZE * scale) / 2.0).floor()


static func stage_scale(view_size: Vector2) -> float:
	return minf(view_size.x / STAGE_SIZE.x, view_size.y / STAGE_SIZE.y) if phone else 1.0
