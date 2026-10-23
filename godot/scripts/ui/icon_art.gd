class_name IconArt
extends RefCounted
## Íconos con volumen (relleno, degradé, borde, sombra y brillo), definidos como formas SVG en
## una grilla de 64×64 y rasterizados en tiempo de ejecución al tamaño exacto en que se usan
## (nítidos en cualquier pantalla, sin archivos de imagen que importar).
##
## Cada ícono se arma en tres capas que `HudIcon` dibuja en orden:
##   shadow  silueta negra corrida 3 px hacia abajo (no se tiñe)
##   body    cuerpo en escala de grises con degradé de luz arriba y sombra abajo, más detalles
##           oscuros; se tiñe con el color del ícono (multiplica), así el volumen se conserva
##           en amarillo, oscuro o blanco
##   gloss   brillo blanco translúcido en la mitad de arriba (no se tiñe)
##
## Formas: cada elemento es [rol, svg] donde el svg trae el marcador `F` (relleno) o `S`
## (trazo) que se reemplaza según la capa. Roles: "body" (relleno), "line" (trazo grueso que
## cuenta como cuerpo) y "dark" (detalle oscuro, solo en la capa body).

const LAYERS: Array[StringName] = [&"shadow", &"body", &"gloss"]

static var _cache: Dictionary[String, ImageTexture] = {}

const ART: Dictionary[StringName, Array] = {
	&"sun": [
		["body", '<circle cx="32" cy="32" r="14" F/>'],
		["body", '<g F><rect x="29" y="2" width="6" height="11" rx="3"/><rect x="29" y="51" width="6" height="11" rx="3"/><rect x="2" y="29" width="11" height="6" rx="3"/><rect x="51" y="29" width="11" height="6" rx="3"/><rect x="29" y="2" width="6" height="11" rx="3" transform="rotate(45 32 32)"/><rect x="29" y="51" width="6" height="11" rx="3" transform="rotate(45 32 32)"/><rect x="2" y="29" width="11" height="6" rx="3" transform="rotate(45 32 32)"/><rect x="51" y="29" width="11" height="6" rx="3" transform="rotate(45 32 32)"/></g>'],
	],
	&"play": [["body", '<path d="M20 12 Q16 10 16 15 V49 Q16 54 20 52 L50 35 Q54 32 50 29 Z" F/>']],
	&"pause": [["body", '<rect x="14" y="12" width="13" height="40" rx="4" F/>'], ["body", '<rect x="37" y="12" width="13" height="40" rx="4" F/>']],
	&"cart": [
		["body", '<path d="M14 20 H56 L50 42 Q49 45 46 45 H24 Q21 45 20 42 Z" F/>'],
		["body", '<rect x="4" y="12" width="16" height="7" rx="3.5" F/>'],
		["body", '<circle cx="26" cy="52" r="6" F/>'], ["body", '<circle cx="45" cy="52" r="6" F/>'],
		["dark", '<rect x="26" y="26" width="4" height="13" rx="2" F/><rect x="36" y="26" width="4" height="13" rx="2" F/>'],
	],
	&"helmet": [
		["body", '<path d="M10 42 C10 20 22 12 32 12 C42 12 54 20 54 42 Z" F/>'],
		["body", '<rect x="4" y="40" width="56" height="10" rx="5" F/>'],
		["dark", '<rect x="28" y="12" width="8" height="28" rx="4" F/>'],
	],
	&"gear": [
		["body", '<g F><rect x="27" y="4" width="10" height="14" rx="3"/><rect x="27" y="46" width="10" height="14" rx="3"/><rect x="4" y="27" width="14" height="10" rx="3"/><rect x="46" y="27" width="14" height="10" rx="3"/><rect x="27" y="4" width="10" height="14" rx="3" transform="rotate(45 32 32)"/><rect x="27" y="46" width="10" height="14" rx="3" transform="rotate(45 32 32)"/><rect x="4" y="27" width="14" height="10" rx="3" transform="rotate(45 32 32)"/><rect x="46" y="27" width="14" height="10" rx="3" transform="rotate(45 32 32)"/></g>'],
		["body", '<circle cx="32" cy="32" r="18" F/>'],
		["dark", '<circle cx="32" cy="32" r="7" F/>'],
	],
	&"gift": [
		["body", '<ellipse cx="24" cy="16" rx="9" ry="6" transform="rotate(-20 24 16)" F/>'],
		["body", '<ellipse cx="40" cy="16" rx="9" ry="6" transform="rotate(20 40 16)" F/>'],
		["body", '<rect x="12" y="30" width="40" height="26" rx="4" F/>'],
		["body", '<rect x="8" y="21" width="48" height="12" rx="4" F/>'],
		["dark", '<rect x="29" y="21" width="6" height="35" F/>'],
	],
	&"lock": [
		["line", '<path d="M21 30 V22 A11 11 0 0 1 43 22 V30" fill="none" stroke-width="7" stroke-linecap="round" S/>'],
		["body", '<rect x="12" y="28" width="40" height="28" rx="6" F/>'],
		["dark", '<circle cx="32" cy="40" r="4.5" F/><rect x="30" y="41" width="4" height="9" rx="2" F/>'],
	],
	&"star_fill": [["body", '<path d="M32 5 L39.6 22.6 L58.6 24.4 L44.3 37 L48.5 55.7 L32 46 L15.5 55.7 L19.7 37 L5.4 24.4 L24.4 22.6 Z" stroke-linejoin="round" F/>']],
	&"map": [
		["body", '<path d="M6 14 L23 8 L41 14 L58 8 V50 L41 56 L23 50 L6 56 Z" stroke-linejoin="round" F/>'],
		["dark", '<rect x="21.5" y="9" width="3" height="41" F/><rect x="39.5" y="14" width="3" height="41" F/>'],
	],
	&"retry": [
		["line", '<path d="M50 34 A18 18 0 1 1 42 17" fill="none" stroke-width="8" stroke-linecap="round" S/>'],
		["body", '<path d="M36 6 L54 14 L40 28 Z" stroke-linejoin="round" F/>'],
	],
	&"next": [["line", '<path d="M24 12 L44 32 L24 52" fill="none" stroke-width="10" stroke-linecap="round" stroke-linejoin="round" S/>']],
	&"back": [["line", '<path d="M40 12 L20 32 L40 52" fill="none" stroke-width="10" stroke-linecap="round" stroke-linejoin="round" S/>']],
	&"check": [["line", '<path d="M12 34 L26 48 L52 18" fill="none" stroke-width="10" stroke-linecap="round" stroke-linejoin="round" S/>']],
	&"close": [["line", '<path d="M16 16 L48 48 M48 16 L16 48" fill="none" stroke-width="10" stroke-linecap="round" S/>']],
	&"plus": [["body", '<rect x="27" y="10" width="10" height="44" rx="5" F/>'], ["body", '<rect x="10" y="27" width="44" height="10" rx="5" F/>']],
	&"minus": [["body", '<rect x="10" y="27" width="44" height="10" rx="5" F/>']],
	&"bolt": [["body", '<path d="M38 4 L12 36 H29 L24 60 L52 26 H35 Z" stroke-linejoin="round" F/>']],
	&"panel": [
		["body", '<rect x="28" y="40" width="8" height="18" rx="2" F/>'],
		["body", '<path d="M14 10 H50 L60 44 H4 Z" stroke-linejoin="round" F/>'],
		["dark", '<path d="M26 10 L22 44 M38 10 L42 44 M9 27 H55" fill="none" stroke="#4a4a4a" stroke-width="2.5"/>'],
	],
	&"battery-plus": [
		["body", '<rect x="52" y="25" width="8" height="14" rx="3" F/>'],
		["body", '<rect x="4" y="16" width="50" height="32" rx="6" F/>'],
		["dark", '<rect x="26" y="22" width="6" height="20" rx="2" F/><rect x="19" y="29" width="20" height="6" rx="2" F/>'],
	],
	&"meter": [
		["body", '<rect x="13" y="4" width="38" height="56" rx="8" F/>'],
		["dark", '<rect x="18" y="9" width="28" height="17" rx="3" F/><circle cx="32" cy="43" r="9" F/>'],
	],
	&"search": [
		["line", '<circle cx="27" cy="27" r="15" fill="none" stroke-width="8" S/>'],
		["line", '<path d="M39 39 L54 54" fill="none" stroke-width="10" stroke-linecap="round" S/>'],
	],
	&"sound": [
		["body", '<path d="M8 24 H20 L34 12 V52 L20 40 H8 Z" stroke-linejoin="round" F/>'],
		["line", '<path d="M42 24 Q47 32 42 40 M49 17 Q58 32 49 47" fill="none" stroke-width="5" stroke-linecap="round" S/>'],
	],
	&"mute": [
		["body", '<path d="M8 24 H20 L34 12 V52 L20 40 H8 Z" stroke-linejoin="round" F/>'],
		["line", '<path d="M42 24 L56 40 M56 24 L42 40" fill="none" stroke-width="6" stroke-linecap="round" S/>'],
	],
	&"wind": [["line", '<path d="M6 22 H38 A7 7 0 1 0 31 15 M6 34 H48 A7 7 0 1 1 41 41 M6 46 H28" fill="none" stroke-width="6" stroke-linecap="round" S/>']],
	&"cloud": [
		["body", '<g F><circle cx="22" cy="36" r="12"/><circle cx="35" cy="27" r="15"/><circle cx="47" cy="37" r="11"/><rect x="12" y="34" width="44" height="14" rx="7"/></g>'],
	],
	&"hint": [
		["body", '<circle cx="32" cy="25" r="17" F/>'],
		["body", '<rect x="23" y="36" width="18" height="12" rx="3" F/>'],
		["dark", '<rect x="25" y="49" width="14" height="7" rx="3" F/><path d="M27 26 L32 33 L37 26" fill="none" stroke="#4a4a4a" stroke-width="2.5" stroke-linecap="round"/>'],
	],
	&"drone": [
		["body", '<g F><ellipse cx="13" cy="16" rx="10" ry="4"/><ellipse cx="51" cy="16" rx="10" ry="4"/><rect x="11" y="18" width="4" height="12" rx="2"/><rect x="49" y="18" width="4" height="12" rx="2"/><rect x="12" y="27" width="40" height="6" rx="3"/></g>'],
		["body", '<rect x="22" y="24" width="20" height="20" rx="7" F/>'],
		["dark", '<circle cx="32" cy="35" r="4" F/>'],
	],
	&"pump": [
		["body", '<rect x="38" y="28" width="22" height="12" rx="4" F/>'],
		["body", '<circle cx="26" cy="34" r="18" F/>'],
		["dark", '<circle cx="26" cy="34" r="7" F/>'],
	],
	&"loose": [
		["body", '<rect x="4" y="24" width="22" height="16" rx="5" F/>'],
		["body", '<rect x="40" y="24" width="20" height="16" rx="5" F/>'],
		["dark", '<rect x="26" y="27" width="7" height="3.5" rx="1.5" F/><rect x="26" y="33.5" width="7" height="3.5" rx="1.5" F/>'],
		["dark", '<path d="M35 14 L31 26 L37 26 L33 38" fill="none" stroke="#ffffff" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>'],
	],
	&"coins": [["body", '<circle cx="26" cy="38" r="17" F/>'], ["body", '<circle cx="40" cy="26" r="17" F/>'], ["dark", '<circle cx="40" cy="26" r="9" fill="none" stroke="#5a5a5a" stroke-width="3"/>']],
}


static func has_icon(icon_name: StringName) -> bool:
	return ART.has(icon_name)


## Textura de una capa a `px` píxeles de lado (se cachea por nombre, capa y tamaño).
static func texture(icon_name: StringName, layer: StringName, px: int) -> ImageTexture:
	px = clampi(px, 8, 512)
	var key: String = "%s|%s|%d" % [icon_name, layer, px]
	if _cache.has(key):
		return _cache[key]
	var svg: String = build_svg(icon_name, layer)
	var img: Image = Image.new()
	var err: Error = img.load_svg_from_string(svg, float(px) / 64.0)
	var tex: ImageTexture = ImageTexture.create_from_image(img) if err == OK else null
	_cache[key] = tex
	return tex


## Documento SVG de una capa (público para tests y para exportar los íconos si hace falta).
static func build_svg(icon_name: StringName, layer: StringName) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for el: Array in (ART.get(icon_name, []) as Array):
		var role: String = el[0]
		var shape: String = el[1]
		match layer:
			&"shadow":
				if role == "dark":
					continue
				parts.append(_paint(shape, 'fill="#000000" fill-opacity="0.28"', 'stroke="#000000" stroke-opacity="0.28"'))
			&"body":
				if role == "dark":
					parts.append(_paint(shape, 'fill="#4a4a4a"', 'stroke="#4a4a4a"'))
				else:
					parts.append(_paint(shape, 'fill="url(#g)" stroke="#8c8c8c" stroke-width="2"', 'stroke="url(#gs)"'))
			_:
				if role == "dark":
					continue
				parts.append(_paint(shape, 'fill="url(#h)"', 'stroke="url(#hs)"'))
	var body: String = "".join(parts)
	if layer == &"shadow":
		body = '<g transform="translate(0 3)">%s</g>' % body
	return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 67" width="64" height="67"><defs>'
		+ '<linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffffff"/><stop offset="0.55" stop-color="#e9e9e9"/><stop offset="1" stop-color="#a8a8a8"/></linearGradient>'
		+ '<linearGradient id="gs" gradientUnits="userSpaceOnUse" x1="0" y1="4" x2="0" y2="60"><stop offset="0" stop-color="#ffffff"/><stop offset="1" stop-color="#b0b0b0"/></linearGradient>'
		+ '<linearGradient id="h" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffffff" stop-opacity="0.6"/><stop offset="0.45" stop-color="#ffffff" stop-opacity="0"/></linearGradient>'
		+ '<linearGradient id="hs" gradientUnits="userSpaceOnUse" x1="0" y1="4" x2="0" y2="40"><stop offset="0" stop-color="#ffffff" stop-opacity="0.55"/><stop offset="1" stop-color="#ffffff" stop-opacity="0"/></linearGradient>'
		+ '</defs>%s</svg>' % body)


## Reemplaza el marcador ` F/>`, ` F>` o ` S/>` por los atributos de pintura de la capa.
static func _paint(shape: String, fill_attrs: String, stroke_attrs: String) -> String:
	return shape.replace(" F/>", " %s/>" % fill_attrs).replace(" F>", " %s>" % fill_attrs).replace(" S/>", " %s/>" % stroke_attrs)
