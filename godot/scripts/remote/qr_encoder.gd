class_name QrEncoder
extends RefCounted
## Codificador de códigos QR en GDScript puro: modo byte (UTF-8), corrección M, versiones 1–10
## y máscara óptima (la de menor penalización según IS/IEC 18004). Sin dependencias.
##
##   var qr := QrEncoder.new()
##   if qr.encode("http://192.168.0.23:8765/"):
##       var tex: ImageTexture = qr.to_texture(12, 2)
##
## La matriz es Array[PackedByteArray]: fila por fila, 1 = módulo oscuro.

const MIN_VERSION: int = 1
const MAX_VERSION: int = 10
## Codewords de corrección por bloque y cantidad de bloques, nivel M, versiones 0(sin uso)..10.
const ECC_CODEWORDS_PER_BLOCK_M: Array[int] = [-1, 10, 16, 26, 18, 24, 16, 18, 22, 22, 26]
const NUM_BLOCKS_M: Array[int] = [-1, 1, 1, 1, 2, 2, 4, 4, 4, 5, 5]
## Bits de formato del nivel M (L=1, M=0, Q=3, H=2).
const ECL_M_FORMAT_BITS: int = 0
const PENALTY_N1: int = 3
const PENALTY_N2: int = 3
const PENALTY_N3: int = 40
const PENALTY_N4: int = 10

## Versión elegida (1..10), 0 si no se codificó.
var version: int = 0
## Máscara elegida (0..7), -1 si no se codificó.
var mask: int = -1
## Lado de la matriz en módulos (21 + 4·(versión − 1)).
var size: int = 0

var _modules: Array[PackedByteArray] = []
var _is_function: Array[PackedByteArray] = []


## Codifica el texto. false si no entra en la versión 10-M (máximo 213 bytes UTF-8).
func encode(text: String) -> bool:
	var data: PackedByteArray = text.to_utf8_buffer()
	var ver: int = 0
	for v: int in range(MIN_VERSION, MAX_VERSION + 1):
		var cap_bits: int = num_data_codewords(v) * 8
		if 4 + _char_count_bits(v) + data.size() * 8 <= cap_bits:
			ver = v
			break
	if ver == 0:
		version = 0
		mask = -1
		size = 0
		_modules.clear()
		return false
	version = ver
	size = ver * 4 + 17
	var codewords: PackedByteArray = _add_ecc_and_interleave(_make_data_codewords(data, ver), ver)
	_modules.clear()
	_is_function.clear()
	for i: int in size:
		var row := PackedByteArray()
		row.resize(size)
		_modules.append(row)
		var frow := PackedByteArray()
		frow.resize(size)
		_is_function.append(frow)
	_draw_function_patterns()
	_draw_codewords(codewords)
	# Elegir la máscara con menor penalización.
	var best: int = 0
	var best_penalty: int = 1 << 30
	for m: int in 8:
		_apply_mask(m)
		_draw_format_bits(m)
		var p: int = penalty_score()
		if p < best_penalty:
			best = m
			best_penalty = p
		_apply_mask(m)  # XOR: deshace
	mask = best
	_apply_mask(best)
	_draw_format_bits(best)
	_is_function.clear()
	return true


## Copia de la matriz (1 = oscuro).
func matrix() -> Array[PackedByteArray]:
	var out: Array[PackedByteArray] = []
	for r: PackedByteArray in _modules:
		out.append(r.duplicate())
	return out


func is_dark(row: int, col: int) -> bool:
	return row >= 0 and col >= 0 and row < size and col < size and _modules[row][col] == 1


## Imagen RGB8: module_px píxeles por módulo y quiet módulos de margen (4 = estándar).
func to_image(module_px: int = 8, quiet: int = 4, dark: Color = Color("#0E2420"), light: Color = Color.WHITE) -> Image:
	return QrEncoder.matrix_to_image(_modules, module_px, quiet, dark, light)


func to_texture(module_px: int = 8, quiet: int = 4, dark: Color = Color("#0E2420"), light: Color = Color.WHITE) -> ImageTexture:
	return ImageTexture.create_from_image(to_image(module_px, quiet, dark, light))


## Atajo: matriz del texto, o vacía si no entra.
static func matrix_for(text: String) -> Array[PackedByteArray]:
	var q := QrEncoder.new()
	if not q.encode(text):
		return [] as Array[PackedByteArray]
	return q.matrix()


static func matrix_to_image(m: Array[PackedByteArray], module_px: int = 8, quiet: int = 4,
		dark: Color = Color("#0E2420"), light: Color = Color.WHITE) -> Image:
	var n: int = m.size()
	var px: int = maxi(1, module_px)
	var side: int = (n + quiet * 2) * px
	var img := Image.create(side, side, false, Image.FORMAT_RGB8)
	img.fill(light)
	for r: int in n:
		var row: PackedByteArray = m[r]
		for c: int in n:
			if row[c] == 1:
				img.fill_rect(Rect2i((c + quiet) * px, (r + quiet) * px, px, px), dark)
	return img


static func _char_count_bits(ver: int) -> int:
	return 8 if ver <= 9 else 16


## Módulos disponibles para datos (sin patrones de función), incluidos los bits sobrantes.
static func num_raw_data_modules(ver: int) -> int:
	var result: int = (16 * ver + 128) * ver + 64
	if ver >= 2:
		var num_align: int = ver / 7 + 2
		result -= (25 * num_align - 10) * num_align - 55
		if ver >= 7:
			result -= 36
	return result


static func num_data_codewords(ver: int) -> int:
	return num_raw_data_modules(ver) / 8 - ECC_CODEWORDS_PER_BLOCK_M[ver] * NUM_BLOCKS_M[ver]


static func alignment_positions(ver: int) -> Array[int]:
	var out: Array[int] = []
	if ver == 1:
		return out
	var num_align: int = ver / 7 + 2
	var step: int = (ver * 8 + num_align * 3 + 5) / (num_align * 4 - 4) * 2
	out.append(6)
	var pos: int = ver * 4 + 17 - 7
	while out.size() < num_align:
		out.insert(1, pos)
		pos -= step
	return out


# ---------- Datos ----------

static func _make_data_codewords(data: PackedByteArray, ver: int) -> PackedByteArray:
	var cap_bits: int = num_data_codewords(ver) * 8
	var bits := PackedByteArray()
	_append_bits(bits, 0x4, 4)                        # modo byte
	_append_bits(bits, data.size(), _char_count_bits(ver))
	for b: int in data:
		_append_bits(bits, b, 8)
	_append_bits(bits, 0, mini(4, cap_bits - bits.size()))   # terminador
	_append_bits(bits, 0, (8 - bits.size() % 8) % 8)
	var pad: int = 0xEC
	while bits.size() < cap_bits:
		_append_bits(bits, pad, 8)
		pad = 0x11 if pad == 0xEC else 0xEC
	var out := PackedByteArray()
	out.resize(bits.size() / 8)
	for i: int in bits.size():
		if bits[i] == 1:
			out[i >> 3] = out[i >> 3] | (1 << (7 - (i & 7)))
	return out


static func _append_bits(bits: PackedByteArray, val: int, n: int) -> void:
	for i: int in range(n - 1, -1, -1):
		bits.append((val >> i) & 1)


static func _add_ecc_and_interleave(data: PackedByteArray, ver: int) -> PackedByteArray:
	var num_blocks: int = NUM_BLOCKS_M[ver]
	var block_ecc_len: int = ECC_CODEWORDS_PER_BLOCK_M[ver]
	var raw_codewords: int = num_raw_data_modules(ver) / 8
	var num_short_blocks: int = num_blocks - raw_codewords % num_blocks
	var short_block_len: int = raw_codewords / num_blocks
	var divisor: PackedByteArray = reed_solomon_divisor(block_ecc_len)
	var blocks: Array[PackedByteArray] = []
	var k: int = 0
	for i: int in num_blocks:
		var dat_len: int = short_block_len - block_ecc_len + (0 if i < num_short_blocks else 1)
		var dat: PackedByteArray = data.slice(k, k + dat_len)
		k += dat_len
		var ecc: PackedByteArray = reed_solomon_remainder(dat, divisor)
		if i < num_short_blocks:
			dat.append(0)
		dat.append_array(ecc)
		blocks.append(dat)
	var result := PackedByteArray()
	for i: int in blocks[0].size():
		for j: int in blocks.size():
			if i != short_block_len - block_ecc_len or j >= num_short_blocks:
				result.append(blocks[j][i])
	return result


static func reed_solomon_divisor(degree: int) -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(degree)
	result[degree - 1] = 1
	var root: int = 1
	for i: int in degree:
		for j: int in result.size():
			result[j] = _gf_mul(result[j], root)
			if j + 1 < result.size():
				result[j] = result[j] ^ result[j + 1]
		root = _gf_mul(root, 0x02)
	return result


static func reed_solomon_remainder(data: PackedByteArray, divisor: PackedByteArray) -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(divisor.size())
	for b: int in data:
		var factor: int = b ^ result[0]
		result.remove_at(0)
		result.append(0)
		for i: int in result.size():
			result[i] = result[i] ^ _gf_mul(divisor[i], factor)
	return result


static func _gf_mul(x: int, y: int) -> int:
	var z: int = 0
	for i: int in range(7, -1, -1):
		z = (z << 1) ^ ((z >> 7) * 0x11D)
		z ^= ((y >> i) & 1) * x
	return z & 0xFF


# ---------- Dibujo ----------

func _set_function(x: int, y: int, dark: bool) -> void:
	_modules[y][x] = 1 if dark else 0
	_is_function[y][x] = 1


func _draw_function_patterns() -> void:
	for i: int in size:
		_set_function(6, i, i % 2 == 0)
		_set_function(i, 6, i % 2 == 0)
	_draw_finder(3, 3)
	_draw_finder(size - 4, 3)
	_draw_finder(3, size - 4)
	var pos: Array[int] = alignment_positions(version)
	var n: int = pos.size()
	for i: int in n:
		for j: int in n:
			if (i == 0 and j == 0) or (i == 0 and j == n - 1) or (i == n - 1 and j == 0):
				continue
			_draw_alignment(pos[i], pos[j])
	_draw_format_bits(0)
	_draw_version()


func _draw_finder(x: int, y: int) -> void:
	for dy: int in range(-4, 5):
		for dx: int in range(-4, 5):
			var dist: int = maxi(absi(dx), absi(dy))
			var xx: int = x + dx
			var yy: int = y + dy
			if xx >= 0 and xx < size and yy >= 0 and yy < size:
				_set_function(xx, yy, dist != 2 and dist != 4)


func _draw_alignment(x: int, y: int) -> void:
	for dy: int in range(-2, 3):
		for dx: int in range(-2, 3):
			_set_function(x + dx, y + dy, maxi(absi(dx), absi(dy)) != 1)


## Bits de formato (nivel + máscara, BCH(15,5) y XOR 0x5412) en sus dos copias + módulo oscuro fijo.
static func format_bits(p_mask: int) -> int:
	var data: int = (ECL_M_FORMAT_BITS << 3) | p_mask
	var rem: int = data
	for i: int in 10:
		rem = (rem << 1) ^ ((rem >> 9) * 0x537)
	return ((data << 10) | rem) ^ 0x5412


func _draw_format_bits(p_mask: int) -> void:
	var bits: int = format_bits(p_mask)
	for i: int in range(0, 6):
		_set_function(8, i, _bit(bits, i))
	_set_function(8, 7, _bit(bits, 6))
	_set_function(8, 8, _bit(bits, 7))
	_set_function(7, 8, _bit(bits, 8))
	for i: int in range(9, 15):
		_set_function(14 - i, 8, _bit(bits, i))
	for i: int in range(0, 8):
		_set_function(size - 1 - i, 8, _bit(bits, i))
	for i: int in range(8, 15):
		_set_function(8, size - 15 + i, _bit(bits, i))
	_set_function(8, size - 8, true)


func _draw_version() -> void:
	if version < 7:
		return
	var rem: int = version
	for i: int in 12:
		rem = (rem << 1) ^ ((rem >> 11) * 0x1F25)
	var bits: int = (version << 12) | rem
	for i: int in 18:
		var bit: bool = _bit(bits, i)
		var a: int = size - 11 + i % 3
		var b: int = i / 3
		_set_function(a, b, bit)
		_set_function(b, a, bit)


static func _bit(x: int, i: int) -> bool:
	return ((x >> i) & 1) != 0


func _draw_codewords(data: PackedByteArray) -> void:
	var i: int = 0
	var total_bits: int = data.size() * 8
	var right: int = size - 1
	while right >= 1:
		if right == 6:
			right = 5
		for vert: int in size:
			for j: int in 2:
				var x: int = right - j
				var upward: bool = ((right + 1) & 2) == 0
				var y: int = size - 1 - vert if upward else vert
				if _is_function[y][x] == 0 and i < total_bits:
					_modules[y][x] = 1 if _bit(data[i >> 3], 7 - (i & 7)) else 0
					i += 1
		right -= 2


func _apply_mask(m: int) -> void:
	for y: int in size:
		var row: PackedByteArray = _modules[y]
		var frow: PackedByteArray = _is_function[y]
		for x: int in size:
			if frow[x] == 1:
				continue
			var invert: bool
			match m:
				0: invert = (x + y) % 2 == 0
				1: invert = y % 2 == 0
				2: invert = x % 3 == 0
				3: invert = (x + y) % 3 == 0
				4: invert = (x / 3 + y / 2) % 2 == 0
				5: invert = x * y % 2 + x * y % 3 == 0
				6: invert = (x * y % 2 + x * y % 3) % 2 == 0
				_: invert = ((x + y) % 2 + x * y % 3) % 2 == 0
			if invert:
				row[x] = row[x] ^ 1
		_modules[y] = row


## Penalización de la matriz actual (reglas N1..N4 de ISO/IEC 18004).
func penalty_score() -> int:
	var result: int = 0
	var n: int = size
	# N1 (rachas ≥5) y N3 (patrón 1:1:3:1:1 con 4 claros a un lado), filas y columnas.
	for pass_i: int in 2:
		for a: int in n:
			var line := PackedByteArray()
			line.resize(n)
			for b: int in n:
				line[b] = _modules[a][b] if pass_i == 0 else _modules[b][a]
			var run: int = 1
			for b: int in range(1, n + 1):
				if b < n and line[b] == line[b - 1]:
					run += 1
				else:
					if run >= 5:
						result += PENALTY_N1 + (run - 5)
					run = 1
			for b: int in range(0, n - 6):
				if line[b] == 1 and line[b + 1] == 0 and line[b + 2] == 1 and line[b + 3] == 1 \
						and line[b + 4] == 1 and line[b + 5] == 0 and line[b + 6] == 1:
					if _light_run(line, b - 4, b) or _light_run(line, b + 7, b + 11):
						result += PENALTY_N3
	# N2: bloques 2×2 del mismo color.
	for y: int in n - 1:
		for x: int in n - 1:
			var c: int = _modules[y][x]
			if c == _modules[y][x + 1] and c == _modules[y + 1][x] and c == _modules[y + 1][x + 1]:
				result += PENALTY_N2
	# N4: proporción de oscuros.
	var dark: int = 0
	for row: PackedByteArray in _modules:
		for v: int in row:
			dark += v
	var total: int = n * n
	var k: int = ceili(absf(dark * 20.0 - total * 10.0) / total) - 1
	result += maxi(0, k) * PENALTY_N4
	return result


## true si line[from..to) es todo claro (fuera de la matriz cuenta como claro: zona de silencio).
static func _light_run(line: PackedByteArray, from: int, to: int) -> bool:
	for i: int in range(from, to):
		if i >= 0 and i < line.size() and line[i] == 1:
			return false
	return true
