class_name NetUtils
extends RefCounted
## Utilidades de red: IP LAN preferida para el QR y para responder al descubrimiento. Solo IPv4.

## Prefijos de interfaces que nunca son la LAN local (datos móviles, VPN, túneles, loopback).
const EXCLUDED_PREFIXES: Array[String] = ["rmnet", "ccmni", "pdp", "ppp", "tun", "dummy", "clat", "v4-",
	"ipsec", "ip6tnl", "sit", "gre", "erspan", "ifb", "veth", "lo"]


## IP LAN preferida (Wi-Fi/Ethernet, red privada 192.168 > 10 > 172.16–31), o "" si no hay red.
static func lan_ip() -> String:
	var ips: Array[String] = lan_ips()
	return ips[0] if not ips.is_empty() else ""


## Todas las IPv4 LAN utilizables, de mejor a peor.
static func lan_ips() -> Array[String]:
	return rank_ipv4(IP.get_local_interfaces())


## Ordena las IPv4 de IP.get_local_interfaces() (o equivalente: [{name, addresses}]).
## Criterio: privadas primero; luego por tipo de interfaz (wlan > eth > hotspot > otras > docker);
## luego 192.168 > 10 > 172.16–31.
static func rank_ipv4(interfaces: Array) -> Array[String]:
	var cands: Array[Array] = []
	for it: Variant in interfaces:
		if typeof(it) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = it
		var iname: String = String(d.get("name", "")).to_lower()
		if not is_usable_interface(iname):
			continue
		for a: Variant in d.get("addresses", []):
			var ip: String = String(a)
			if not is_ipv4(ip) or ip.begins_with("127.") or ip.begins_with("169.254.") or ip == "0.0.0.0":
				continue
			var rank: int = private_rank(ip)
			cands.append([1 if rank > 0 else 0, interface_score(iname), rank, ip])
	cands.sort_custom(func(x: Array, y: Array) -> bool:
		for k: int in 3:
			if x[k] != y[k]:
				return x[k] > y[k]
		return false)
	var out: Array[String] = []
	for c: Array in cands:
		if not out.has(c[3]):
			out.append(c[3])
	return out


static func is_usable_interface(iname: String) -> bool:
	var n: String = iname.to_lower()
	for p: String in EXCLUDED_PREFIXES:
		if n.begins_with(p):
			return false
	return true


## Puntaje por nombre de interfaz: Wi-Fi primero, luego Ethernet, hotspot, el resto, contenedores.
static func interface_score(iname: String) -> int:
	var n: String = iname.to_lower()
	if n.begins_with("wlan") or n.begins_with("wl"):
		return 100
	if n.begins_with("eth") or n.begins_with("en"):
		return 90
	if n.begins_with("ap") or n.begins_with("swlan") or n.begins_with("softap"):
		return 80
	if n.begins_with("docker") or n.begins_with("br-") or n.begins_with("virbr"):
		return 5
	return 20


static func is_ipv4(ip: String) -> bool:
	return ip.is_valid_ip_address() and not ip.contains(":")


## 3 = 192.168/16, 2 = 10/8, 1 = 172.16/12, 0 = otra.
static func private_rank(ip: String) -> int:
	var p: PackedStringArray = ip.split(".")
	if p.size() != 4:
		return 0
	var b0: int = p[0].to_int()
	var b1: int = p[1].to_int()
	if b0 == 192 and b1 == 168:
		return 3
	if b0 == 10:
		return 2
	if b0 == 172 and b1 >= 16 and b1 < 32:
		return 1
	return 0


static func is_private_ipv4(ip: String) -> bool:
	return is_ipv4(ip) and private_rank(ip) > 0


static func _to_u32(ip: String) -> int:
	var p: PackedStringArray = ip.split(".")
	return (p[0].to_int() << 24) | (p[1].to_int() << 16) | (p[2].to_int() << 8) | p[3].to_int()


## IP local para responderle a `remote`: loopback si pregunta desde la misma máquina; si no, la
## candidata que comparte el prefijo más largo (Godot no expone máscaras ni "connect" UDP para
## preguntarle al sistema la ruta, así que se aproxima: misma subred = mismo prefijo).
static func best_local_for(remote: String, candidates: Array[String]) -> String:
	var r: String = remote.trim_prefix("::ffff:")
	if r.begins_with("127."):
		return "127.0.0.1"
	if candidates.is_empty():
		return ""
	if not is_ipv4(r):
		return candidates[0]
	var rv: int = _to_u32(r)
	var best: String = candidates[0]
	var best_bits: int = -1
	for c: String in candidates:
		var x: int = rv ^ _to_u32(c)
		var bits: int = 32
		while x != 0:
			x >>= 1
			bits -= 1
		if bits > best_bits:
			best_bits = bits
			best = c
	return best
